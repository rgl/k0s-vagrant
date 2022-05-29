# About

This is a [HA k0s kubernetes cluster](https://docs.k0sproject.io/v1.23.6+k0s.1/high-availability/) wrapped in a vagrant environment.

## Usage

Install the [ubuntu-20.04-amd64](https://github.com/rgl/ubuntu-vagrant) vagrant box.

Launch the environment:

```bash
time ./bring-up.sh
```

Configure your host DNS resolver to delegate the `k0s.test` domain to the `pandora` machine like [described in this document](#host-dns-resolver). Or add the environment hosts to your machine `hosts` file:

```plain
10.10.0.2 pandora.k0s.test
10.10.0.3 controller.k0s.test
```

The load balancer statistics are at http://controller.k0s.test:9000.

The docker registry is at https://pandora.k0s.test:5000.

The apt-cacher is at http://pandora.k0s.test:3142/acng-report.html (click the "Count Data" button to see the cache statistics).

The traefik ingress dashboard is at https://traefik.k0s.test.

An example application is at https://example-app.k0s.test.

You can access the example cluster from the host with, e.g.:

```bash
export KUBECONFIG=$PWD/shared/kubeconfig
kubectl version --short
kubectl cluster-info
kubectl get nodes -o wide # NB by design, no controller node is displayed.
kubectl api-versions
kubectl api-resources -o wide
kubectl get namespaces
kubectl get all --all-namespaces -o wide
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp
kubectl get charts --all-namespaces # aka charts.helm.k0sproject.io
```

## Kubernetes Dashboard

Access the Kubernetes Dashboard at:

  https://kubernetes-dashboard.k0s.test

Then select `Token` and use the contents of `shared/admin-token.txt` as the token.

You can also launch the kubernetes API server proxy in background:

```bash
export KUBECONFIG=$PWD/shared/kubeconfig
kubectl proxy &
```

And access the kubernetes dashboard at:

  http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

## K9s Dashboard

The [K9s](https://github.com/derailed/k9s) console UI dashboard is also
installed in the server node. You can access it by running:

```bash
vagrant ssh controller1
sudo -i
k9s
```

## DNS

Make sure that all of the following commands execute successfully:

```bash
vagrant ssh pandora
sudo -i

# get a docker container dns resolver configuration. must return the pandora dns
# nameserver 10.10.0.2.
docker run -it --rm --name test busybox:1.34 cat /etc/resolv.conf
# resolve a internet domain.
docker run -it --rm --name test busybox:1.34 nslookup -type=a ruilopes.com

# get a k8s container dns resolver configuration. it must return the cluster
# kube-dns service cluster ip address. something alike:
#   search default.svc.cluster.local svc.cluster.local cluster.local
#   nameserver 10.96.0.10
#   options ndots:5
# see https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
kubectl run -it --rm --restart=Never busybox --image=busybox:1.34 -- cat /etc/resolv.conf
# resolve a internet domain. must return something alike:
#   Server:		10.96.0.10
#   Address:	10.96.0.10:53
#   Non-authoritative answer:
#   Name:	ruilopes.com
#   Address: 172.67.174.199
#   Name:	ruilopes.com
#   Address: 104.21.67.125
kubectl run -it --rm --restart=Never busybox --image=busybox:1.34 -- nslookup -type=a ruilopes.com
# resolve a cluster external-dns managed domain. must return something alike:
#   Server:		10.96.0.10
#   Address:	10.96.0.10:53
#   Name:	traefik.k0s.test
#   Address: 10.10.0.100
kubectl run -it --rm --restart=Never busybox --image=busybox:1.34 -- nslookup -type=a traefik.k0s.test
```

## Host DNS resolver

To delegate the `k0s.test` zone to the kubernetes managed external dns server (running in pandora) you need to configure your system to delegate that DNS zone to the pandora DNS server, for that, you can configure your system to only use dnsmasq.

For example, on my Ubuntu 20.04 Desktop, I have uninstalled `resolvconf`, disabled `NetworkManager`, and manually configured the network interfaces:

```bash
sudo su -l
for n in NetworkManager NetworkManager-wait-online NetworkManager-dispatcher network-manager; do
    systemctl mask --now $n
done
apt-get remove --purge resolvconf
cat >/etc/network/interfaces <<'EOF'
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

auto enp3s0
iface enp3s0 inet dhcp
EOF
reboot
```

Then, replaced `systemd-resolved` with `dnsmasq`:

```bash
sudo su -l
apt-get install -y --no-install-recommends dnsutils dnsmasq
systemctl mask --now systemd-resolved
cat >/etc/dnsmasq.d/local.conf <<EOF
no-resolv
bind-interfaces
interface=lo
listen-address=127.0.0.1
# delegate the k0s.test zone to the pandora DNS server IP address.
server=/k0s.test/10.10.0.2
# delegate to the Cloudflare/APNIC Public DNS IP addresses.
# NB iif there's no entry in /etc/hosts.
server=1.1.1.1
server=1.0.0.1
# delegate to the Google Public DNS IP addresses.
# NB iif there's no entry in /etc/hosts.
#server=8.8.8.8
#server=8.8.4.4
EOF
rm /etc/resolv.conf
cat >/etc/resolv.conf <<EOF
nameserver 127.0.0.1
EOF
systemctl restart dnsmasq
exit
```

Then start all the machines and test the DNS resolution:

```bash
vagrant up
dig pandora.k0s.test
dig controller.k0s.test
```

## Network Packet Capture

You can easily capture and see traffic from the host with the `wireshark.sh`
script, e.g., to capture the traffic from the `eth1` interface:

```bash
./wireshark.sh pandora eth1
```

To capture a pod traffic:

```bash
# NB the filter must only return a single pod.
./wireshark-pod.sh '-l app.kubernetes.io/name=kubernetes-dashboard'
```

## Notes

* Controller nodes
  * They do not run the `kubelet` nor a container runtime like containerd.
    * This means [`kubectl get nodes` only returns the worker nodes](https://docs.k0sproject.io/v1.23.6+k0s.1/FAQ/#why-doesnt-kubectl-get-nodes-list-the-k0s-controllers).
    * Instead they use the `k0s` process supervisor to launch the daemons as naked processes.

## References

* https://docs.k0sproject.io
* https://kubernetes.io/docs/reference/kubectl/cheatsheet/
* https://learnk8s.io/production-best-practices
