#!/bin/bash
source /vagrant/lib.sh

registry_domain="${1:-pandora.k0s.test}"; shift || true
registry_host="$registry_domain:5000"
registry_url="https://$registry_host"

cd /vagrant/example-app

# build.
docker build -t "$registry_host/example-app" .
docker push "$registry_host/example-app"

# deploy.
export CONFIG_DOMAIN=$(hostname --domain)
envsubst < resources.yaml | kubectl apply -f -
