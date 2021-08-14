#!/bin/bash
source /vagrant/lib.sh

# install go.
# see https://golang.org/dl/
# see https://golang.org/doc/install
artifact_url=https://golang.org/dl/go1.16.7.linux-amd64.tar.gz
artifact_sha=7fe7a73f55ba3e2285da36f8b085e5c0159e9564ef5f63ee0ed6b818ade8ef04
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
