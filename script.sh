#!/usr/bin/env bash

# Initialisation du serveur
sudo apt update
sudo apt upgrade -y
sudo apt install net-tools -y
sudo apt install mc -y

# Install HELM
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm -y
helm repo update

# Désactivation du firewall et désactivation de la pagination
sudo ufw disable
sudo swapoff -a

# Install Docker
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl enable docker.service

# Install NFS-kernel-server
sudo apt install nfs-kernel-server -y

# Install kubernetes packages
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt-get install -y kubelet kubeadm kubectl

# Initialisation du cluster
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=144.91.84.132
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-

# Install and set as default provider for local-path-storage
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install Calico for pod networking
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# First install CRD for ServiceMonitor
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.44/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.44/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.44/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.44/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.44/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.44/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml

# Create namespaces without quotas
kubectl create namespace monitoring
kubectl create namespace kube-db
kubectl create namespace kube-rbac
kubectl create namespace objectstorage
kubectl create namespace logging
kubectl create namespace wordpress

# Install the metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml

# Install Loki Stack
helm repo add loki https://grafana.github.io/loki/charts
helm repo update
helm upgrade --install loki --namespace=logging loki/loki-stack

# Install rbac-manager
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm install rbac-manager --namespace=kube-rbac fairwinds-stable/rbac-manager

# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install my-ingress-nginx ingress-nginx/ingress-nginx --version 3.15.2 --namespace=kube-db

# Install cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm install my-cert-manager --namespace kube-system jetstack/cert-manager --version 1.1.0

# Install minio
helm repo add minio https://helm.min.io/
helm install my-minio minio/minio --version 8.0.8 --namespace=objectstorage

# Install grafana
helm repo add stable https://charts.helm.sh/stable
helm repo add grafana https://grafana.github.io/helm-charts
helm install prometheus-operator stable/prometheus-operator -n monitoring --set prometheusOperator.createCustomResource=false,grafana.service.type=NodePort
helm install my-grafana grafana/grafana --version 6.1.15 --namespace=monitoring

# Install kube-db
helm repo add appscode https://charts.appscode.com/stable/
helm install my-kubedb appscode/kubedb --version 0.15.2 -n kube-db

# Install wordpress
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-wordpress bitnami/wordpress --version 10.0.10 -n wordpress
