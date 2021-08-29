#!/bin/bash
source lib.sh

pod_filter="$1"; shift || true

export KUBECONFIG=$PWD/shared/kubeconfig
j="$(kubectl get pods -o json $pod_filter)"
vm_name="$(jq -r '.items[].spec.nodeName' <<<"$j")"
pod_ip="$(jq -r '.items[].status.podIP' <<<"$j")"
capture_filter="host $pod_ip"

./wireshark.sh $vm_name 'kube-bridge' "$capture_filter"
