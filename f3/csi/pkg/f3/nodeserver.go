/*
Copyright 2017 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package f3

import (
	"os"
	"path"
	"sync"
	"os/exec"
	"io/ioutil"

	"github.com/container-storage-interface/spec/lib/go/csi"
	"golang.org/x/net/context"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"k8s.io/klog/v2"
	"k8s.io/kubernetes/pkg/volume"
	"k8s.io/utils/mount"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

// NodeServer driver
type NodeServer struct {
	Driver  *Driver
	mounter mount.Interface
	fuseProcs map[string]*exec.Cmd
	fuseProcsCount map[string]int
	lock sync.RWMutex
}

// XXX This assumes that there's only one F3/FS PVC
// Need to lookup label applied to pod (f3.action=xxx) and use that
// as label selector in addition to fs.role
func getPVCName(roleSelector, namespace string) (string, error) {
	config, err := rest.InClusterConfig()
	config.BearerTokenFile = "/var/run/secrets/kubernetes.io/podwatcher/token"
	if err != nil {
		return "", err
	}
	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
        return "", err
	}

	pvcs, err := clientset.CoreV1().PersistentVolumeClaims(namespace).List(context.TODO(),
        metav1.ListOptions{LabelSelector: roleSelector})
    klog.Info("pvcs", pvcs.Items[0])
    klog.Info(roleSelector)
	if err != nil {
		panic(err.Error())
	}
	if (len(pvcs.Items) > 1) {
		klog.Info("!!!")
	}

    return pvcs.Items[0].Spec.VolumeName, nil
}

func getFSPvcName(namespace string) (string, error) {
    return getPVCName("f3.role=fs", namespace)
}

func getF3PvcName(namespace string) (string, error) {
    return getPVCName("f3.role=f3", namespace)
}

// NodePublishVolume mount the volume
func (ns *NodeServer) NodePublishVolume(ctx context.Context, req *csi.NodePublishVolumeRequest) (*csi.NodePublishVolumeResponse, error) {
	klog.Infof("NodePublishVolume", req)

	// This is where we actually run the FUSE driver
	// At this point the Ceph volume must be mounted on the host
	// We need to know where that mount point is and use that as the "subdir" arg for the FUSE driver
	// The "tempdir" arg should be set by the F3 storage class (accessible via the Volume req?)
	// The "workdir" will be the target path

	// Need to save the pid of the driver process so we can kill it on Unpublish

	if req.GetVolumeCapability() == nil {
		return nil, status.Error(codes.InvalidArgument, "Volume capability missing in request")
	}
	volumeID := req.GetVolumeId()
	if len(volumeID) == 0 {
		return nil, status.Error(codes.InvalidArgument, "Volume ID missing in request")
	}
	targetPath := req.GetTargetPath()
	if len(targetPath) == 0 {
		return nil, status.Error(codes.InvalidArgument, "Target path not provided")
	}

	if _, err := os.Stat(targetPath); err != nil {
		if os.IsNotExist(err) {
			if err := os.MkdirAll(targetPath, 0750); err != nil {
				return nil, status.Error(codes.Internal, err.Error())
			}
		} else {
			return nil, status.Error(codes.Internal, err.Error())
		}
	}

	podUID := req.GetVolumeContext()["csi.storage.k8s.io/pod.uid"]
	podDir := path.Join("/var/lib/kubelet/pods/", podUID, "volumes/kubernetes.io~csi/")

	files, err := ioutil.ReadDir(podDir)
	if err != nil {
		klog.Infof("XXX uh")
	}

    namespace := req.GetVolumeContext()["csi.storage.k8s.io/pod.namespace"]
    f3Pvc, err := getF3PvcName(namespace)
    if err != nil {
        klog.Errorf(err.Error())
    }
    fsPvc, err := getFSPvcName(namespace)
    if err != nil {
        klog.Errorf(err.Error())
    }
 
    klog.Info("fsPvc", fsPvc)
	cephMount := ""
	for _, f := range files {
		klog.Infof(f.Name())
        if f.Name() == fsPvc {
			cephMount = path.Join(podDir, f.Name(), "mount")
			klog.Infof("Ceph mount: ", cephMount)
		}
	}

	if cephMount == "" {
		klog.Infof("Ceph not mounted yet!  Gotta wait...")
		return nil, status.Error(codes.Unavailable, "Ceph not mounted yet")

	}

	if _, err := os.Stat(cephMount); err != nil {
		if os.IsNotExist(err) {
			return nil, status.Error(codes.Unavailable, "Ceph mount doesn't exist yet")
		} else {
			return nil, status.Error(codes.Internal, err.Error())
		}
	}

    idroot := req.GetVolumeContext()["server"]

	sourcedir := "/var/lib/kubelet/plugins/kubernetes.io/csi/pv/"+fsPvc+"/globalmount"
	workdir := "/var/lib/kubelet/plugins/kubernetes.io/csi/pv/"+f3Pvc+"/globalmount"
	ns.lock.Lock()
	if _, exists := ns.fuseProcs[volumeID]; !exists {
        //klog.Infof("Running", "/f3-fuse-driver --single --debug --nocache --address " + ns.Driver.nodeID+":9999 --idroot " + ns.Driver.tempdir + " --socket-path " + ns.Driver.socketAddress + " --pod-uuid " + podUID[0:8] + " " + sourcedir + " " + workdir)
		klog.Infof("Running", "/f3-fuse-driver --nosplice --single --debug --nocache --address " + ns.Driver.nodeID+":9999 --idroot " + idroot + " --client-socket-path " + ns.Driver.clientSocketAddress + " --server-socker-path " + ns.Driver.serverSocketAddress + " --pod-uuid " + podUID[0:8] + " " + sourcedir + " " + workdir)
		//klog.Infof("Running", "/f3-fuse-driver --single --debug --address " + ns.Driver.nodeID+":9999 --idroot " + idroot + " --client-socket-path " + ns.Driver.clientSocketAddress + " --server-socker-path " + ns.Driver.serverSocketAddress + " --pod-uuid " + podUID[0:8] + " " + sourcedir + " " + workdir)
        //cmd := exec.Command("/f3-fuse-driver", "--single", "--debug", "--nocache", "--address", ns.Driver.nodeID+":9999", "--idroot", ns.Driver.tempdir, "--socket-path", ns.Driver.socketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
        //cmd := exec.Command("/f3-fuse-driver", "--debug", "--nocache", "--address", ns.Driver.nodeID+":9999", "--idroot", ns.Driver.tempdir, "--socket-path", ns.Driver.socketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
        //cmd := exec.Command("/f3-fuse-driver", "--debug", "--nosplice", "--nocache", "--address", ns.Driver.nodeID+":9999", "--idroot", idroot, "--client-socket-path", ns.Driver.clientSocketAddress, "--server-socket-path", ns.Driver.serverSocketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
        // was 0920:
        //cmd := exec.Command("/f3-fuse-driver", "--debug", "--nocache", "--nosplice", "--address", ns.Driver.nodeID+":9999", "--idroot", idroot, "--client-socket-path", ns.Driver.clientSocketAddress, "--server-socket-path", ns.Driver.serverSocketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
        // !!! BEST:
        //cmd := exec.Command("/f3-fuse-driver", "--debug", "--nocache", "--single", "--nosplice", "--address", ns.Driver.nodeID+":9999", "--idroot", idroot, "--client-socket-path", ns.Driver.clientSocketAddress, "--server-socket-path", ns.Driver.serverSocketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
        //cmd := exec.Command("/f3-fuse-driver", "--debug", "--address", ns.Driver.nodeID+":9999", "--idroot", idroot, "--client-socket-path", ns.Driver.clientSocketAddress, "--server-socket-path", ns.Driver.serverSocketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
        cmd := exec.Command("/f3-fuse-driver", "--debug", "--nocache", "--single", "--nosplice", "--address", ns.Driver.nodeID+":9999", "--idroot", idroot, "--client-socket-path", ns.Driver.clientSocketAddress, "--server-socket-path", ns.Driver.serverSocketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)

        // does not work:
        //cmd := exec.Command("/f3-fuse-driver", "--debug", "--single", "--nosplice", "--address", ns.Driver.nodeID+":9999", "--idroot", idroot, "--client-socket-path", ns.Driver.clientSocketAddress, "--server-socket-path", ns.Driver.serverSocketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
        //cmd := exec.Command("/f3-fuse-driver", "--debug", "--nocache", "--nosplice", "--address", ns.Driver.nodeID+":9999", "--idroot", idroot, "--client-socket-path", ns.Driver.clientSocketAddress, "--server-socket-path", ns.Driver.serverSocketAddress, "--pod-uuid", podUID[0:8], sourcedir, workdir)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Start(); err != nil {
			klog.Infof(err.Error())
			ns.lock.Unlock()
			return nil, status.Error(codes.Internal, err.Error())
		}
		ns.fuseProcs[volumeID] = cmd
		ns.fuseProcsCount[volumeID] = 0

		go func(cmd *exec.Cmd, podUID string) {
			err := cmd.Wait()
			klog.Infof("XXX %v", podUID);
			klog.Infof("Error %v", err)
		}(cmd, podUID[0:8])
	}
	ns.fuseProcsCount[volumeID] += 1
	ns.lock.Unlock()

	cmd := exec.Command("mount", "--bind", workdir, targetPath)
	if out, err := cmd.CombinedOutput(); err != nil {
		klog.Infof("Failed to mount", err.Error())
		klog.Infof(string(out))
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &csi.NodePublishVolumeResponse{}, nil
}

// NodeUnpublishVolume unmount the volume
func (ns *NodeServer) NodeUnpublishVolume(ctx context.Context, req *csi.NodeUnpublishVolumeRequest) (*csi.NodeUnpublishVolumeResponse, error) {
	klog.Infof("NodeUnpublishVolume", req)

	volumeID := req.GetVolumeId()
	if len(volumeID) == 0 {
		return nil, status.Error(codes.InvalidArgument, "Volume ID missing in request")
	}
	targetPath := req.GetTargetPath()
	if len(targetPath) == 0 {
		return nil, status.Error(codes.InvalidArgument, "Target path missing in request")
	}

	// XXX what order do we need to do this in? (umount first or kill FUSE first?)
	ns.lock.Lock()
	if cmd, exists := ns.fuseProcs[volumeID]; exists {
		ns.fuseProcsCount[volumeID] -= 1;
		if ns.fuseProcsCount[volumeID] <= 0 {
			klog.Infof("!!! Killing FUSE process!!!", volumeID, ns.fuseProcsCount[volumeID])
			if err := cmd.Process.Kill(); err != nil {
				if err.Error() == "process already finished" {
					klog.Infof("FUSE process already exited")
					delete(ns.fuseProcs, volumeID)
					delete(ns.fuseProcsCount, volumeID)
				} else {
					klog.Infof("failed to kill FUSE proc ", err.Error())
					ns.lock.Unlock()
					return nil, status.Error(codes.Internal, err.Error())
				}
			}
			delete(ns.fuseProcs, volumeID)
			delete(ns.fuseProcsCount, volumeID)
		}
	} else {
		klog.Infof("volumeID not in map, FUSE not running? Nothing to do...")
		delete(ns.fuseProcs, volumeID)
		delete(ns.fuseProcsCount, volumeID)
	}
	ns.lock.Unlock()

	cmd := exec.Command("umount", targetPath)
	if out, err := cmd.CombinedOutput(); err != nil {
		klog.Infof("Failed to umount", err.Error())
		klog.Infof(string(out))
	}

	return &csi.NodeUnpublishVolumeResponse{}, nil
}

// NodeGetInfo return info of the node on which this plugin is running
func (ns *NodeServer) NodeGetInfo(ctx context.Context, req *csi.NodeGetInfoRequest) (*csi.NodeGetInfoResponse, error) {
	return &csi.NodeGetInfoResponse{
		NodeId: ns.Driver.nodeID,
	}, nil
}

// NodeGetCapabilities return the capabilities of the Node plugin
func (ns *NodeServer) NodeGetCapabilities(ctx context.Context, req *csi.NodeGetCapabilitiesRequest) (*csi.NodeGetCapabilitiesResponse, error) {
	return &csi.NodeGetCapabilitiesResponse{
		Capabilities: ns.Driver.nscap,
	}, nil
}

// NodeGetVolumeStats get volume stats
func (ns *NodeServer) NodeGetVolumeStats(ctx context.Context, req *csi.NodeGetVolumeStatsRequest) (*csi.NodeGetVolumeStatsResponse, error) {
	//klog.Infof("NodeGetVolumeStats", req)
	klog.Infof("NodeGetVolumeStats")

	return nil, status.Error(codes.Unimplemented, "")

	if len(req.VolumeId) == 0 {
		return nil, status.Error(codes.InvalidArgument, "NodeGetVolumeStats volume ID was empty")
	}
	if len(req.VolumePath) == 0 {
		return nil, status.Error(codes.InvalidArgument, "NodeGetVolumeStats volume path was empty")
	}

	_, err := os.Stat(req.VolumePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, status.Errorf(codes.NotFound, "path %s does not exist", req.VolumePath)
		}
		return nil, status.Errorf(codes.Internal, "failed to stat file %s: %v", req.VolumePath, err)
	}

	volumeMetrics, err := volume.NewMetricsStatFS(req.VolumePath).GetMetrics()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to get metrics: %v", err)
	}

	available, ok := volumeMetrics.Available.AsInt64()
	if !ok {
		return nil, status.Errorf(codes.Internal, "failed to transform volume available size(%v)", volumeMetrics.Available)
	}
	capacity, ok := volumeMetrics.Capacity.AsInt64()
	if !ok {
		return nil, status.Errorf(codes.Internal, "failed to transform volume capacity size(%v)", volumeMetrics.Capacity)
	}
	used, ok := volumeMetrics.Used.AsInt64()
	if !ok {
		return nil, status.Errorf(codes.Internal, "failed to transform volume used size(%v)", volumeMetrics.Used)
	}

	inodesFree, ok := volumeMetrics.InodesFree.AsInt64()
	if !ok {
		return nil, status.Errorf(codes.Internal, "failed to transform disk inodes free(%v)", volumeMetrics.InodesFree)
	}
	inodes, ok := volumeMetrics.Inodes.AsInt64()
	if !ok {
		return nil, status.Errorf(codes.Internal, "failed to transform disk inodes(%v)", volumeMetrics.Inodes)
	}
	inodesUsed, ok := volumeMetrics.InodesUsed.AsInt64()
	if !ok {
		return nil, status.Errorf(codes.Internal, "failed to transform disk inodes used(%v)", volumeMetrics.InodesUsed)
	}

	return &csi.NodeGetVolumeStatsResponse{
		Usage: []*csi.VolumeUsage{
			{
				Unit:      csi.VolumeUsage_BYTES,
				Available: available,
				Total:     capacity,
				Used:      used,
			},
			{
				Unit:      csi.VolumeUsage_INODES,
				Available: inodesFree,
				Total:     inodes,
				Used:      inodesUsed,
			},
		},
	}, nil
}

// NodeUnstageVolume unstage volume
func (ns *NodeServer) NodeUnstageVolume(ctx context.Context, req *csi.NodeUnstageVolumeRequest) (*csi.NodeUnstageVolumeResponse, error) {
	return nil, status.Error(codes.Unimplemented, "")
}

// NodeStageVolume stage volume
func (ns *NodeServer) NodeStageVolume(ctx context.Context, req *csi.NodeStageVolumeRequest) (*csi.NodeStageVolumeResponse, error) {

	return nil, status.Error(codes.Unimplemented, "")
}

// NodeExpandVolume node expand volume
func (ns *NodeServer) NodeExpandVolume(ctx context.Context, req *csi.NodeExpandVolumeRequest) (*csi.NodeExpandVolumeResponse, error) {
	return nil, status.Error(codes.Unimplemented, "")
}

func makeDir(pathname string) error {
	err := os.MkdirAll(pathname, os.FileMode(0755))
	if err != nil {
		if !os.IsExist(err) {
			return err
		}
	}
	return nil
}
