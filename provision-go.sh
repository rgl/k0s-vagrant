#!/bin/bash
source /vagrant/lib.sh

# install go.
# see https://go.dev/dl/
# see https://go.dev/doc/install
# renovate: datasource=github-tags depName=golang/go extractVersion=go(?<version>.+)
go_version='1.22.3'
artifact_url=https://go.dev/dl/go$go_version.linux-amd64.tar.gz
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
rm -rf /usr/local/go
install -d /usr/local/go
tar xf $artifact_path -C /usr/local/go --strip-components 1
rm $artifact_path

# add go to all users path.
cat >/etc/profile.d/go.sh <<'EOF'
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/go/bin"
EOF
