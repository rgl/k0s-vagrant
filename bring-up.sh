#!/bin/bash
source lib.sh

title 'Starting the machines'
vagrant up --provider=libvirt --no-destroy-on-error pandora
vagrant up --provider=libvirt --no-destroy-on-error

title 'Bootstrapping the cluster'
vagrant ssh -c 'sudo -i -- bash -- /vagrant/bootstrap-k0s.sh $(jq -r .pandoraFqdn /vagrant/shared/config.json)' pandora
