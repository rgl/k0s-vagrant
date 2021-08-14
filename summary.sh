#!/bin/bash
source /vagrant/lib.sh

registry_domain="${1:-pandora.k0s.test}"; shift || true
registry_host="$registry_domain:5000"
registry_url="https://$registry_host"

# list images.
echo "listing $registry_host images..."
wget -qO- --user vagrant --password vagrant \
    "$registry_url/v2/_catalog" \
    | jq .

# kubernetes info.
kubectl version --short
kubectl cluster-info
kubectl get apiservices
kubectl api-versions | sort
kubectl api-resources -o wide
kubectl get crds
kubectl get all --all-namespaces

# really get all objects.
# see https://github.com/corneliusweig/ketall/blob/master/doc/USAGE.md
kubectl get-all

# kubernetes contexts.
# NB the example context gives you indirect access to the rke cluster api-server endpoint (e.g. https://controller.k0s.test:8443/k8s/clusters/c-g5282).
# NB the example-server context gives you direct access to the rke cluster api-server endpoint (e.g. https://10.10.0.3:6443).
kubectl config get-contexts

# rbac info.
kubectl auth can-i --list
kubectl get serviceaccount --all-namespaces
kubectl get role --all-namespaces
kubectl get rolebinding --all-namespaces
#kubectl get rolebinding --all-namespaces -o json | jq .items[].subjects
kubectl get clusterrole --all-namespaces
kubectl get clusterrolebinding --all-namespaces

# rbac access matrix.
# see https://github.com/corneliusweig/rakkess/blob/master/doc/USAGE.md
kubectl access-matrix version --full
kubectl access-matrix # at cluster scope.
kubectl access-matrix --namespace default

# show installed helm charts.
kubectl get --all-namespaces charts # aka charts.helm.k0sproject.io

title 'addresses'
example_app_url="http://$(kubectl get ingress example-app -o json | jq -r .spec.rules[].host)"
#traefik_url="http://$(kubectl get service -l app.kubernetes.io/name=traefik -o json | jq -r .items[].status.loadBalancer.ingress[].ip)/dashboard/"
traefik_url="http://$(kubectl get ingress traefik -o json | jq -r .spec.rules[].host)"
python3 <<EOF
from tabulate import tabulate

headers = ('service', 'address')

def info():
    yield ('traefik',     '$traefik_url')
    yield ('example-app', '$example_app_url')

print(tabulate(info(), headers=headers))
EOF
