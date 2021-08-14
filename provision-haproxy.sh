#!/bin/bash
source /vagrant/lib.sh

controller_fqdn="${1:-controller.k0s.test}"; shift || true
controller_ip_address="${1:-10.10.0.3}"; shift || true
controller_ip_addresses="${1:-10.10.0.10,10.10.0.11,10.10.0.12}"; shift || true

# install.
apt-get install -y haproxy
haproxy -vv

# configure.
bash /vagrant/provision-haproxy-config.sh \
  bootstrap \
  "$controller_fqdn" \
  "$controller_ip_address" \
  "$controller_ip_addresses"
