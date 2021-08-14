#!/bin/bash
set -eu

registry_domain="${1:-pandora.k0s.test}"; shift || true
registry_host="$registry_domain:5001"
registry_url="https://$registry_host"
registry_image='registry:2.7.1' # see https://hub.docker.com/_/registry
registry_container_name='registry-proxy'

# copy certificate.
install -d -m 700 /opt/registry-proxy
install -d -m 700 /opt/registry-proxy/secrets
cp /vagrant/shared/tls/example-ca/$registry_domain-crt.pem /opt/registry-proxy/secrets/crt.pem
cp /vagrant/shared/tls/example-ca/$registry_domain-key.pem /opt/registry-proxy/secrets/key.pem

# create the http secret.
install -d -m 700 /opt/registry-proxy/secrets
echo -n 'http secret' >/opt/registry-proxy/secrets/http

# launch the registry as a docker proxy caching server.
# see https://docs.docker.com/registry/deploying/
echo "starting the registry $registry_url..."
install -d -m 700 /opt/registry-proxy/data
docker run -d \
    --restart=unless-stopped \
    --name $registry_container_name \
    -p 5001:5001 \
    -v /opt/registry-proxy/data:/var/lib/registry \
    -v /opt/registry-proxy/secrets:/run/secrets \
    -e REGISTRY_HTTP_SECRET=/run/secrets/http \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:5001 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/run/secrets/crt.pem \
    -e REGISTRY_HTTP_TLS_KEY=/run/secrets/key.pem \
    -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
    "$registry_image"

# wait for the registry to be available.
echo "waiting for the registry $registry_url to become available..."
while ! wget -q --spider "$registry_url/v2/"; do sleep 1; done;

# dump the registry configuration.
echo "registry proxy version:"
docker exec $registry_container_name registry --version
echo "registry proxy environment variables:"
docker exec $registry_container_name env
echo "registry proxy config:"
docker exec $registry_container_name cat /etc/docker/registry/config.yml
echo "after you pull some images check whether the registry proxy has cached some images with:"
echo "  docker rmi debian:buster-slim"
echo "  docker run --rm debian:buster-slim cat /etc/os-release"
echo "  wget -qO- $registry_url/v2/_catalog | jq ."
echo "  wget -qO- $registry_url/v2/library/debian/manifests/buster-slim"
echo "troubleshoot with:"
echo "  docker logs $registry_container_name --follow"
echo "  journalctl -u docker --follow"
echo "  find /opt/registry-proxy -type f"
