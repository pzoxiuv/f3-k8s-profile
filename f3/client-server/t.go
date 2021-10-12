package main

import (
	"context"
	"fmt"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

func main() {
	fmt.Println("hello")

	// creates the in-cluster config
	config, err := rest.InClusterConfig()
	config.BearerTokenFile = "/var/run/secrets/kubernetes.io/podwatcher/token"
	if err != nil {
		panic(err.Error())
	}
	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	pods, err := clientset.CoreV1().Pods("").List(context.TODO(), metav1.ListOptions{
		FieldSelector: "spec.nodeName=kubes1", LabelSelector: "app=csi-f3-node"})
		//FieldSelector: "spec.nodeName=kubes1", LabelSelector: selector})
	if err != nil {
		panic(err.Error())
	}
	if (len(pods.Items) > 1) {
		fmt.Println("!!!")
	}
	fmt.Println(pods.Items[0].Status.PodIP);
}
