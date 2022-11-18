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

# show the kubernetes daemons arguments.
function ps-show-args {
    ssh $1 ps -wwweo args \
        | grep -E "^[^ ]*/$2 " \
        | grep -v grep \
        | tr ' ' '\n' \
        | tail +2 \
        | sort \
        | sed -E 's,(.+),    \1,g'
}
ps-show-args controller1 kube-apiserver 
ps-show-args controller1 kube-scheduler
ps-show-args controller1 kube-controller-manager
ps-show-args controller1 konnectivity-server
ps-show-args worker1 proxy-agent # aka konnectivity-agent
ps-show-args worker1 kubelet

# etcd info.
function etcd-info {
    ssh controller1 etcdctl \
        --cert /var/lib/k0s/pki/etcd/server.crt \
        --key /var/lib/k0s/pki/etcd/server.key \
        --cacert /var/lib/k0s/pki/etcd/ca.crt \
        --write-out table \
        "$*"
}
etcd-info member list
etcd-info endpoint status
#etcd-info get / --prefix --keys-only --write-out simple | grep ^/

# show services.
kubectl get services --all-namespaces
kubectl get endpoints --all-namespaces
ssh worker1 ipvsadm --list --numeric

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

# show the ingress ca certificate.
title 'ingress ca certificate'
kubectl \
    -n cert-manager \
    get secret \
    ingress-tls \
    -o json \
    | jq -r '.data."tls.crt"' \
    | base64 --decode \
    | openssl x509 -noout -text

# show the traefik certificate.
title 'traefik certificate'
kubectl \
    -n cluster-traefik \
    get secret \
    traefik-tls \
    -o json \
    | jq -r '.data."tls.crt"' \
    | base64 --decode \
    | openssl x509 -noout -text

# show the returned traefik site certificate.
title 'traefik site certificate'
traefik_host="$(kubectl -n cluster-traefik get ingress traefik -o json | jq -r .spec.rules[].host)"
openssl s_client -connect $traefik_host:443 -servername $traefik_host </dev/null
openssl s_client -connect $traefik_host:443 -servername $traefik_host </dev/null 2>/dev/null | openssl x509 -noout -text

title 'addresses'
example_app_url="https://$(kubectl get ingress example-app -o json | jq -r .spec.rules[].host)"
#traefik_url="http://$(kubectl get service -l app.kubernetes.io/name=traefik -o json | jq -r .items[].status.loadBalancer.ingress[].ip)/dashboard/"
traefik_url="https://$(kubectl -n cluster-traefik get ingress traefik -o json | jq -r .spec.rules[].host)"
kubernetes_dashboard_url="https://$(kubectl -n cluster-dashboard get ingress -l app.kubernetes.io/name=kubernetes-dashboard -o json | jq -r .items[].spec.rules[].host)"
python3 <<EOF
from tabulate import tabulate

headers = ('service', 'address', 'token file')

def info():
    yield ('traefik',               '$traefik_url',                 None)
    yield ('kubernetes-dashboard',  '$kubernetes_dashboard_url',    'shared/admin-token.txt')
    yield ('example-app',           '$example_app_url',             None)

print(tabulate(info(), headers=headers))
EOF
