#!/bin/bash
source /vagrant/lib.sh

# install go.
# see https://go.dev/dl/
# see https://go.dev/doc/install
artifact_url=https://go.dev/dl/go1.19.2.linux-amd64.tar.gz
artifact_sha=5e8c5a74fe6470dd7e055a461acda8bb4050ead8c2df70f227e3ff7d8eb7eeb6
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
