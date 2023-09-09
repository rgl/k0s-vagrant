#!/bin/bash
source /vagrant/lib.sh

ubuntu_mirror="${1:-http://mirrors.up.pt/ubuntu/}"; shift || true
pandora_fqdn="${1:-pandora.k0s.test}"; shift || true

# provision apt-cacher-ng.
# see https://www.unix-ag.uni-kl.de/~bloch/acng/
# see https://www.unix-ag.uni-kl.de/~bloch/acng/html/index.html
# NB these anwsers were obtained (after installing apt-cacher-ng) with:
#       #sudo debconf-show apt-cacher-ng
#       sudo apt-get install debconf-utils
#       # this way you can see the comments:
#       sudo debconf-get-selections
#       # this way you can just see the values needed for debconf-set-selections:
#       sudo debconf-get-selections | grep -E '^apt-cacher-ng-.+\s+' | sort
debconf-set-selections <<'EOF'
apt-cacher-ng apt-cacher-ng/tunnelenable boolean false
EOF
apt-get install -y --no-install-recommends apt-cacher-ng

# disable all mirrors (except ubuntu).
sed -i -E 's,^(Remap-.+),#\1,' /etc/apt-cacher-ng/acng.conf
sed -i -E 's,^#(Remap-uburep.+),\1,' /etc/apt-cacher-ng/acng.conf

# allow 80 and 443 ports.
sed -i -E 's,^#?\s*(AllowUserPorts:).+,\1 80 443,' /etc/apt-cacher-ng/acng.conf

# set the APT mirror that apt-cacher-ng uses.
echo "$ubuntu_mirror" >/etc/apt-cacher-ng/backends_ubuntu

# restart apt-cacher-ng.
systemctl restart apt-cacher-ng

# wait for apt-cacher-ng to be available.
bash -c "while ! wget -q --spider 'http://$pandora_fqdn:3142/acng-report.html'; do sleep 1; done;"
