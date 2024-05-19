#!/bin/bash
source /vagrant/lib.sh

kubernetes_version="${1:-1.26.15}"; shift || true
krew_version="${1:-v0.4.4}"; shift || true # NB see https://github.com/kubernetes-sigs/krew

# see https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management
# see https://wiki.debian.org/DebianRepository/Format
# see https://pkgs.k8s.io/core:/stable:/v1.26/deb/InRelease
# see https://pkgs.k8s.io/core:/stable:/v1.26/deb/Packages
# e.g. https://pkgs.k8s.io/core:/stable:/v1.26/deb/
kubernetes_repository_version="$(echo "$kubernetes_version" | cut -d. -f1,2)"
wget -qO- "https://pkgs.k8s.io/core:/stable:/v$kubernetes_repository_version/deb/Release.key" \
    | gpg --dearmor -o /etc/apt/keyrings/pkgs.k8s.io.gpg
echo "deb [signed-by=/etc/apt/keyrings/pkgs.k8s.io.gpg] https://pkgs.k8s.io/core:/stable:/v$kubernetes_repository_version/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
apt-get update
kubectl_package_version="$(apt-cache madison kubectl | awk "/$kubernetes_version-/{print \$3}")"
apt-get install -y "kubectl=$kubectl_package_version"
kubectl completion bash >/usr/share/bash-completion/completions/kubectl
kubectl version --client
cp /usr/bin/kubectl /vagrant/shared

# install the krew kubectl package manager.
echo "installing the krew $krew_version kubectl package manager..."
apt-get install -y --no-install-recommends git
wget -qO- "https://github.com/kubernetes-sigs/krew/releases/download/$krew_version/krew-linux_amd64.tar.gz" | tar xzf - ./krew-linux_amd64
wget -q "https://github.com/kubernetes-sigs/krew/releases/download/$krew_version/krew.yaml"
./krew-linux_amd64 install --manifest=krew.yaml
rm krew-linux_amd64
cat >/etc/profile.d/krew.sh <<'EOF'
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
EOF
source /etc/profile.d/krew.sh
kubectl krew version

# install get-all.
# see https://github.com/corneliusweig/ketall/blob/master/doc/USAGE.md
kubectl krew install get-all

# install rakkess access-matrix.
# see https://github.com/corneliusweig/rakkess/blob/master/doc/USAGE.md
kubectl krew install access-matrix
