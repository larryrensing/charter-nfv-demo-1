#!/bin/bash

set -x
USER=$(whoami)
source /home/$USER/charter-nfv-demo/bootkube-ci/.bootkube_env
sudo mv ${HOME}/.kube/config ${HOME}/

### Create Valid Kubernetes User Config:
sudo kubectl config set-cluster local --server=https://${KUBE_MASTER}:${KUBE_SVC_PORT} --certificate-authority=${BOOTKUBE_DIR}/.bootkube/tls/ca.crt
sudo kubectl config set-context default --cluster=local --user=kubelet
sudo kubectl config use-context default
sudo kubectl config set-credentials kubelet --client-certificate=${BOOTKUBE_DIR}/.bootkube/tls/kubelet.crt  --client-key=${BOOTKUBE_DIR}/.bootkube/tls/kubelet.key
sudo chown -R ${USER} ${HOME}/.kube

chmod 755 $BOOTKUBE_DIR/.kube/config
chmod 755 $BOOTKUBE_DIR/.bootkube/tls/*

echo 'Cleaning up jobs'
export job_array=`(kubectl get jobs -n openstack | (awk -F"," '{print $1}') | (cut -d' ' -f1) | (sed '1d') | (awk '/[^[:upper:] ]/') | grep -v ceph)`
for job in $job_array;do
 `kubectl delete job $job -n openstack`
done

echo 'Launching OSH using Armada'

sudo docker run -d --net host \
  --name armada  \
  -v /home/$USER/charter-nfv-demo/.bootkube/tls:/.bootkube/tls \
  -v ~/.kube/config:/armada/.kube/config \
  -v /home/dev/charter-nfv-demo/scripts/kubernetes/manifests:/examples \
  -v /home/dev/.bootkube/tls:/home/dev/.bootkube/tls \
  quay.io/attcomdev/armada:latest || true

sudo docker exec armada armada tiller --status 
sudo docker exec armada armada apply /examples/newton-armada-osh.yaml
