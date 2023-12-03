#!/bin/bash
source /vagrant/lib.sh

dns_server_ip_address="${1:-10.10.0.2}"; shift || true

# change the dns resolver to use our dns server.
# NB at some point in the ubuntu 22.04 lifecycle, using netplan
#    dhcp4-overrides: use-dns: no stopped removing the dns server from eth0.
#    so we now completly ignore systemd-resolved, and replace the
#    /etc/resolv.conf symlink with a file.
systemctl disable --now systemd-resolved

# disable retrieval of dns-related options that overrides /etc/resolv.conf
sed 's/.*domain-name, domain-name-servers, domain-search, host-name,.*//; s/.*dhcp6.name-servers, dhcp6.domain-search,.*//' -i /etc/dhcp/dhclient.conf
service networking restart

# remove /etc/resolv.conf while it might be a symlink.
rm -f /etc/resolv.conf 
cat >/etc/resolv.conf <<EOF
nameserver $dns_server_ip_address
EOF

