YAML_FILES = csi-f3-controller.yaml csi-f3-driverinfo.yaml csi-f3-node.yaml f3-sc.yaml rbac-csi-f3-controller.yaml

.PHONY: deploy-csi
deploy-csi:
	for f in $(YAML_FILES); do kubectl apply -f $$f; done
