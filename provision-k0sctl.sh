#!/bin/bash
source /vagrant/lib.sh

config_k0sctl_version="${1:-v0.12.6}"; shift || true

# disable k0s telemetry.
echo 'export DISABLE_TELEMETRY=true' >/etc/profile.d/disable-telemetry.sh
source /etc/profile.d/disable-telemetry.sh

# install the binaries.
if [ ! -f /usr/local/bin/k0sctl ]; then
    wget -qOk0sctl "https://github.com/k0sproject/k0sctl/releases/download/$config_k0sctl_version/k0sctl-linux-x64"
    install -m 755 k0sctl /usr/local/bin
    rm k0sctl
fi
