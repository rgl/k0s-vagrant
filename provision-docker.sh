#!/bin/bash
source /vagrant/lib.sh

# NB execute apt-cache madison docker-ce to known the available versions.
docker_version="${1:-20.10.8}"; shift || true
dns_server_ip_address="${1:-10.10.0.2}"; shift || true
registry_proxy_domain="${1:-}"; shift || true
registry_proxy_host="$registry_proxy_domain:5001"
registry_proxy_url="https://$registry_proxy_host"

# prevent apt-get et al from asking questions.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# install docker.
# see https://docs.docker.com/engine/install/ubuntu/
apt-get install -y apt-transport-https software-properties-common gnupg2
wget -qO- https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
docker_apt_version="$(apt-cache madison docker-ce | awk "/$docker_version~/{print \$3}")"
apt-get install -y "docker-ce=$docker_apt_version" "docker-ce-cli=$docker_apt_version" containerd.io

# configure it.
systemctl stop docker
cat >/etc/docker/daemon.json <<EOF
{
    "experimental": false,
    "debug": false,
    "dns": [
        "$dns_server_ip_address"
    ],
    "features": {
        "buildkit": true
    },
    "log-driver": "journald",
    "labels": [
        "os=linux"
    ],
    "hosts": [
        "fd://"
    ],
    "containerd": "/run/containerd/containerd.sock"
}
EOF
# configure docker to get docker hub images from our registry proxy.
if [ "$registry_proxy_domain" != '' ]; then
    python3 <<EOF
import json

with open('/etc/docker/daemon.json', 'r') as f:
    config = json.load(f)

config['registry-mirrors'] = ['$registry_proxy_url']

with open('/etc/docker/daemon.json', 'w') as f:
    json.dump(config, f, indent=4)
EOF
fi
# start docker without any command line flags as its entirely configured from daemon.json.
install -d /etc/systemd/system/docker.service.d
cat >/etc/systemd/system/docker.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF
systemctl daemon-reload
systemctl start docker

# let the vagrant user manage docker.
usermod -aG docker vagrant
