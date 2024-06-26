#!/bin/bash
source /vagrant/lib.sh

ubuntu_mirror="${1:-http://mirrors.up.pt/ubuntu/}"; shift || true
pandora_fqdn="${1:-pandora.k0s.test}"; shift || true
pandora_ip_address="${1:-10.10.0.2}"; shift || true

# prevent apt-get et al from asking questions.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# show mac addresses and the machine uuid to troubleshoot they are unique within the cluster.
ip link
cat /sys/class/dmi/id/product_uuid

# configure the ubuntu mirror.
sed -i -E "s,(deb(-src)?) [^ ]+ ,\\1 $ubuntu_mirror ,g" /etc/apt/sources.list

# configure APT to use our apt-cacher cache APT proxy.
# NB we cannot use APT::Update::Pre-Invoke in apt.confi because that is invoked
#    after sources.list is loaded, so we had to override the apt-get command
#    with our own version.
cat >/usr/local/bin/apt-get <<EOF
#!/bin/bash
if [ "\$1" == 'update' ]; then
    for p in \$(find /etc/apt/sources.list /etc/apt/sources.list.d -type f); do
        sed -i -E '/http:\\/\\/$pandora_fqdn:3142/! s,(deb(-src)? .*)http://,\1http://$pandora_fqdn:3142/,g' \$p
        sed -i -E '/http:\\/\\/$pandora_fqdn:3142/! s,(deb(-src)? .*)https://,\1http://$pandora_fqdn:3142/HTTPS///,g' \$p
    done
fi
exec /usr/bin/apt-get "\$@"
EOF
chmod +x /usr/local/bin/apt-get
hash -r

# configure the hosts file.
echo "$pandora_ip_address $pandora_fqdn" >>/etc/hosts

# update the package cache.
apt-get update

# install jq.
apt-get install -y jq

# install vim.
apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF

# configure the shell.
cat >/etc/profile.d/login.sh <<'EOF'
[[ "$-" != *i* ]] && return
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
# NB until https://github.com/k0sproject/k0s/issues/1040 lands, use alias.
alias ctr='k0s ctr'
EOF
if [ 'pandora' == "$(hostname)" ]; then
    cat >>/etc/profile.d/login.sh <<'EOF'
export KUBECONFIG="$HOME/.kube/config"
EOF
else
    cat >>/etc/profile.d/login.sh <<'EOF'
export KUBECONFIG="/vagrant/shared/kubeconfig"
EOF
fi

cat >/etc/inputrc <<'EOF'
set input-meta on
set output-meta on
set show-all-if-ambiguous on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
EOF

# add support for bash completions.
apt-get install -y bash-completion

# install useful tools.
apt-get install -y python3-tabulate python3-yaml

# let the root user login with a ssh key.
sed -i -E 's,#?(PermitRootLogin) .*,\1 prohibit-password,g' /etc/ssh/sshd_config
systemctl reload sshd

# generate the root ssh key.
if [ "$(hostname)" == 'pandora' ]; then
    if [ ! -f /vagrant/shared/ssh/id_rsa ]; then
        mkdir -p /vagrant/shared/ssh
        ssh-keygen -f /vagrant/shared/ssh/id_rsa -t rsa -b 2048 -C "$USER@$(hostname --fqdn)" -N ''
    fi
    if [ ! -f ~/.ssh/id_rsa ]; then
        install -d -m 700 ~/.ssh
        install -m 600 /vagrant/shared/ssh/* ~/.ssh
    fi
fi

# trust the pandora root ssh key.
if [ ! -f ~/.ssh/authorized_keys ]; then
    install -d -m 700 ~/.ssh
    install -m 600 /dev/null ~/.ssh/authorized_keys
fi
pandora_ssh_public_key="$(cat /vagrant/shared/ssh/id_rsa.pub)"
if ! grep "$pandora_ssh_public_key" ~/.ssh/authorized_keys >/dev/null; then
    echo "$pandora_ssh_public_key" >>~/.ssh/authorized_keys
fi

# trust the pandora example ca.
# NB this step is skipped in the pandora box; this file is created later
#    in provision-certificate.sh.
if [ -f /vagrant/shared/tls/example-ca/example-ca-crt.pem ]; then
    cp /vagrant/shared/tls/example-ca/example-ca-crt.pem /usr/local/share/ca-certificates/example-ca.crt
    update-ca-certificates -v
fi

# install iptables.
apt-get install -y iptables

# install tcpdump.
apt-get install -y tcpdump

# install curl.
apt-get install -y curl

# install ipvsadm.
apt-get install -y ipvsadm

# load the ipvs kernel modules.
cat >/etc/modules-load.d/ipvs.conf <<'EOF'
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_lc
ip_vs_sh
EOF
cat /etc/modules-load.d/ipvs.conf | xargs -L1 modprobe
