#!/bin/bash
source /vagrant/lib.sh

config_k0s_version="${1:-v1.27.13+k0s.0}"; shift || true

# disable k0s telemetry.
echo 'export DISABLE_TELEMETRY=true' >/etc/profile.d/disable-telemetry.sh
source /etc/profile.d/disable-telemetry.sh

# install the binaries.
if [ ! -f /usr/local/bin/k0s ]; then
    wget -qOk0s "https://github.com/k0sproject/k0s/releases/download/$config_k0s_version/k0s-$config_k0s_version-amd64"
    install -m 755 k0s /usr/local/bin
    rm k0s
fi

# install the bash completions.
k0s completion bash >/usr/share/bash-completion/completions/k0s
