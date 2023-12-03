#!/bin/bash
source /vagrant/lib.sh

package_mirror="${1:-http://mirrors.up.pt/ubuntu/}"; shift || true
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
apt-get install -y --no-install-recommends wget apt-cacher-ng

os_id=$(lsb_release -is | tr '[A-Z]' '[a-z]')

# disable all mirrors (except ubuntu or debian).
sed -i -E 's,^(Remap-.+),#\1,' /etc/apt-cacher-ng/acng.conf

case "${os_id}" in
  debian)
    sed -i -E 's,^#(Remap-debrep.+|Remap-secdeb.+),\1,' /etc/apt-cacher-ng/acng.conf
    ;;
  ubuntu)
    sed -i -E 's,^#(Remap-uburep.+),\1,' /etc/apt-cacher-ng/acng.conf
    ;;
  *)
    printf "ERROR: Distro %s is not suppported\n" "${os_id}" 1>&2
    exit 1
    ;;
esac

# allow 80 and 443 ports.
sed -i -E 's,^#?\s*(AllowUserPorts:).+,\1 80 443,' /etc/apt-cacher-ng/acng.conf

# use IPv4 over IPv6 as priority.
sed -i -E 's,^#?\s*(ConnectProto:).+,\1 v4 v6,' /etc/apt-cacher-ng/acng.conf

# set the APT mirror that apt-cacher-ng uses.
echo "$package_mirror" >/etc/apt-cacher-ng/backends_${os_id}

# restart apt-cacher-ng.
systemctl restart apt-cacher-ng

# force IPv4 to be default.
sed 's,^#\(precedence ::ffff:0:0/96\s\+100\),\1,' -i /etc/gai.conf

# wait for apt-cacher-ng to be available.
bash -c "while ! wget -q --spider 'http://$pandora_fqdn:3142/acng-report.html'; do sleep 1; done;"
