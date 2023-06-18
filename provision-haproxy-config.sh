#!/bin/bash
source /vagrant/lib.sh

command="$1"; shift || true
controller_fqdn="$1"; shift || true
controller_ip_address="$1"; shift || true
controller_ip_addresses="$1"; shift || true
if [ "$command" == 'set-health-checks' ]; then
  haproxy_sa_token_path="$1"; shift || true
  haproxy_sa_ca_path="$1"; shift || true
fi

if [ ! -f /etc/haproxy/haproxy.cfg.ubuntu ]; then
  mv /etc/haproxy/haproxy.cfg{,.ubuntu}
fi

# configure haproxy as L4 TCP forwarding load balancer.
# NB when boostrapping this ignores the backend servers certificates,
#    after bootstrap, this properly verifies them.
# see https://docs.k0sproject.io/v1.26.5+k0s.0/high-availability/#example-configuration-haproxy
# see Bind and server options at https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#5
# see https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#4.2-bind
# see https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#4.2-server
# see https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#option%20tcp-check
# see https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#4-option%20httpchk
# see https://cbonte.github.io/haproxy-dconv/1.8/configuration.html#4.2-option%20tcp-check
install -m 600 /dev/null /etc/haproxy/haproxy.cfg
cat >/etc/haproxy/haproxy.cfg <<EOF
global
  log /dev/log local0
  log /dev/log local1 notice
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
  stats timeout 30s
  user haproxy
  group haproxy
  daemon

defaults
  log     global
  mode    http
  option  httplog
  option  dontlognull
  option  log-health-checks
  timeout connect 5000
  timeout client  50000
  timeout server  50000
  errorfile 400 /etc/haproxy/errors/400.http
  errorfile 403 /etc/haproxy/errors/403.http
  errorfile 408 /etc/haproxy/errors/408.http
  errorfile 500 /etc/haproxy/errors/500.http
  errorfile 502 /etc/haproxy/errors/502.http
  errorfile 503 /etc/haproxy/errors/503.http
  errorfile 504 /etc/haproxy/errors/504.http

defaults
  mode tcp
  timeout client 20s
  timeout server 20s
  timeout connect 4s

listen stats
  bind $controller_ip_address:9000
  mode http
  stats enable
  stats admin if TRUE
  stats uri /
EOF
(
cat <<'EOF' | while read port name healthz_path healthz_http_port; do
6443 kubeApi /healthz
8132 konnectivity /healthz 8092
9443 controllerJoinApi
EOF
  cat <<EOF

listen $name
  bind $controller_ip_address:$port name $name
  option tcplog
  option tcp-check
EOF
  # HTTP health check.
  if [ "$command" == 'set-health-checks' -a -n "$healthz_http_port" ]; then
    cat <<EOF
  # HTTP health check.
  option httpchk GET $healthz_path "HTTP/1.0\r\nHost:$controller_fqdn"
  http-check expect string ok
EOF
  # HTTPS health check.
  elif [ "$command" == 'set-health-checks' -a -n "$healthz_path" ]; then
    cat <<EOF
  # HTTPS health check.
  option httpchk GET $healthz_path "HTTP/1.0\r\nHost:$controller_fqdn\r\nAuthorization:Bearer $(cat $haproxy_sa_token_path)"
  http-check expect string ok
EOF
  fi
  cat <<EOF
  log global
  timeout server 1h
  balance roundrobin
  default-server inter 10s rise 3 fall 3 slowstart 60s maxconn 250 maxqueue 256 weight 100
EOF
  i=0
  for ip_address in `echo "$controller_ip_addresses" | tr , ' '`; do
    ((i=i+1))
    # HTTP health check.
    if [ "$command" == 'set-health-checks' -a -n "$healthz_http_port" ]; then
      cat <<EOF
  # HTTP health check.
  # you can verify the health check with:
  #   (printf "GET $healthz_path HTTP/1.0\r\nHost:$controller_fqdn\r\n\r\n"; sleep 2) | nc $ip_address $healthz_http_port
  server $name$i $ip_address:$port check port $healthz_http_port
EOF
    # HTTPS health check.
    elif [ "$command" == 'set-health-checks' -a -n "$healthz_path" ]; then
      cat <<EOF
  # HTTPS health check.
  # you can verify the health check with:
  #   (printf "GET $healthz_path HTTP/1.0\r\nHost:$controller_fqdn\r\nAuthorization:Bearer \$(cat $haproxy_sa_token_path)\r\n\r\n"; sleep 2) | openssl s_client -connect $ip_address:$port -servername $controller_fqdn -CAfile $haproxy_sa_ca_path
  server $name$i $ip_address:$port check check-ssl check-sni $controller_fqdn ca-file $haproxy_sa_ca_path
EOF
    # TLS health check WITHOUT application level health check.
    elif [ "$command" == 'set-health-checks' ]; then
      cat <<EOF
  # TLS health check WITHOUT application level health check.
  # you can verify the health check with:
  #   (sleep 2) | openssl s_client -connect $ip_address:$port -servername $controller_fqdn -CAfile $haproxy_sa_ca_path
  server $name$i $ip_address:$port check check-ssl check-sni $controller_fqdn ca-file $haproxy_sa_ca_path
EOF
    # TLS health check WITHOUT application level health check AND WITHOUT server certificate verification.
    else
      cat <<EOF
  # TLS health check WITHOUT application level health check AND WITHOUT server certificate verification.
  # you can verify the health check with:
  #   (sleep 2) | openssl s_client -connect $ip_address:$port -servername $controller_fqdn
  server $name$i $ip_address:$port check check-ssl check-sni $controller_fqdn verify none
EOF
    fi
  done
done
)>>/etc/haproxy/haproxy.cfg

# restart to apply changes.
systemctl restart haproxy

# show current statistics.
# NB this is also available at $controller_ip_address:9000.
echo 'show stat' | nc -U /run/haproxy/admin.sock
