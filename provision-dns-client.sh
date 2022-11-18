#!/bin/bash
source /vagrant/lib.sh

dns_server_ip_address="${1:-10.10.0.2}"; shift || true

# change the dns resolver to use our dns server.
if [ -d /etc/netplan ]; then
  install -d /etc/systemd/resolved.conf.d
  cat >/etc/systemd/resolved.conf.d/dns-servers.conf <<EOF
[Resolve]
DNS=$dns_server_ip_address
Domains=~.
EOF
  systemctl restart systemd-resolved
  cat >/etc/netplan/01-netcfg.yaml <<EOF
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
      dhcp4-overrides:
        use-dns: false
EOF
  netplan apply
  # wait for the configuration to be applied by systemd-networkd.
  # NB kubelet uses this file as --resolv-conf=/run/systemd/resolve/resolv.conf
  while [ "$(awk '/^nameserver /{print $2}' /run/systemd/resolve/resolv.conf)" != "$dns_server_ip_address" ]; do
    sleep 1
  done
  cat /run/systemd/resolve/resolv.conf
else
  cat >>/etc/dhcp/dhclient.conf <<EOF
# make sure resolv.conf will always have our dns server.
supersede domain-name-servers $dns_server_ip_address;
EOF
  cat >/etc/resolv.conf <<EOF
nameserver $dns_server_ip_address
EOF
fi
