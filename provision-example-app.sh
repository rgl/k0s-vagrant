#!/bin/bash
source /vagrant/lib.sh

registry_domain="${1:-pandora.k0s.test}"; shift || true
registry_host="$registry_domain:5000"
registry_url="https://$registry_host"
domain="$(hostname --domain)"
example_app_host="example-app.$domain"

cd /vagrant/example-app

# build.
docker build -t "$registry_host/example-app" .
docker push "$registry_host/example-app"

# deploy.
sed -E "s,example-app\.k0s\.test,$example_app_host," resources.yaml \
    | kubectl apply -f -
kubectl rollout status \
    --timeout 3m \
    daemonset/example-app
bash -c "while ! wget -qO/dev/null 'https://$example_app_host'; do sleep 1; done;"
