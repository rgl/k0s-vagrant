#!/bin/bash
source /vagrant/lib.sh

# install go.
# see https://go.dev/dl/
# see https://go.dev/doc/install
artifact_url=https://go.dev/dl/go1.19.linux-amd64.tar.gz
artifact_sha=464b6b66591f6cf055bc5df90a9750bf5fbc9d038722bb84a9d56a2bea974be6
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
if [ "$(sha256sum $artifact_path | awk '{print $1}')" != "$artifact_sha" ]; then
    echo "downloaded $artifact_url failed the checksum verification"
    exit 1
fi
rm -rf /usr/local/go
install -d /usr/local/go
tar xf $artifact_path -C /usr/local/go --strip-components 1
rm $artifact_path

# add go to all users path.
cat >/etc/profile.d/go.sh <<'EOF'
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/go/bin"
EOF
