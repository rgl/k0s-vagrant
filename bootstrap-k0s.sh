#!/bin/bash
source /vagrant/lib.sh

registry_domain="${1:-pandora.k0s.test}"; shift || true
registry_host="$registry_domain:5000"
registry_url="https://$registry_host"
registry_username='vagrant'
registry_password='vagrant'
domain="$(hostname --domain)"

# see https://artifacthub.io/packages/helm/traefik/traefik
# see https://github.com/traefik/traefik-helm-chart/releases
# see https://github.com/traefik/traefik
# renovate: datasource=helm depName=traefik registryUrl=https://helm.traefik.io/traefik
traefik_chart_version='28.0.0' # app version 3.0.0.

# see https://artifacthub.io/packages/helm/bitnami/metallb
# see https://github.com/metallb/metallb
# renovate: datasource=helm depName=metallb registryUrl=https://charts.bitnami.com/bitnami
metallb_chart_version='6.1.7' # app version 0.14.5.

# see https://artifacthub.io/packages/helm/bitnami/external-dns
# see https://github.com/kubernetes-sigs/external-dns
# renovate: datasource=helm depName=external-dns registryUrl=https://charts.bitnami.com/bitnami
external_dns_chart_version='7.3.4' # app version 0.14.2.

# see https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard
# see https://github.com/kubernetes/dashboard
# renovate: datasource=helm depName=kubernetes-dashboard registryUrl=https://kubernetes.github.io/dashboard
kubernetes_dashboard_chart_version='7.4.0' # app version 7.4.0.

# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://github.com/cert-manager/cert-manager
# renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
cert_manager_chart_version='1.14.5' # app version 1.14.5.

# ensure haproxy is in bootstrap mode.
bash /vagrant/provision-haproxy-config.sh \
  bootstrap \
  "$(jq -r .controllerFqdn /vagrant/shared/config.json)" \
  "$(jq -r .controllerIpAddress /vagrant/shared/config.json)" \
  "$(jq -r '.nodes[] | select(.type == "controller") | .ipAddress' /vagrant/shared/config.json | tr '\n' ',' | sed -E 's/,$//g')"

# generate the k0sctl.yaml configuration file.
# see https://docs.k0sproject.io/v1.30.0+k0s.0/k0sctl-install/
# see https://docs.k0sproject.io/v1.30.0+k0s.0/configuration/
python3 <<EOF
import json
import textwrap

def load_config():
    with open('/vagrant/shared/config.json', 'r') as f:
        return json.load(f)

def save_k0sctl_config():
    config = load_config()
    k0sctl_config = {
        'apiVersion': 'k0sctl.k0sproject.io/v1beta1',
        'kind': 'Cluster',
        'metadata': {
            'name': 'example',
        },
        'spec': {
            'k0s': {
                'version': config['k0sVersion'].lstrip('v'),
                'config': {
                    'spec': {
                        'telemetry': {
                            'enabled': False,
                        },
                        'api': {
                            'address': config['controllerIpAddress'],
                            'externalAddress': config['controllerFqdn'],
                            'sans': [
                                config['controllerIpAddress'],
                            ],
                        },
                        'network': {
                            'kubeProxy': {
                                'mode': 'ipvs',
                            },
                        },
                        'extensions': {
                            'helm': {
                                'repositories': [
                                    {
                                        'name': 'traefik',
                                        'url': 'https://helm.traefik.io/traefik'
                                    },
                                    {
                                        'name': 'bitnami',
                                        'url': 'https://charts.bitnami.com/bitnami'
                                    },
                                    {
                                        'name': 'kubernetes-dashboard',
                                        'url': 'https://kubernetes.github.io/dashboard'
                                    },
                                ],
                                # NB these charts are translated to charts.helm.k0sproject.io resources.
                                # see https://github.com/k0sproject/k0s/blob/main/docs/helm-charts.md
                                'charts': [
                                    # see https://artifacthub.io/packages/helm/traefik/traefik
                                    # see https://github.com/traefik/traefik-helm-chart
                                    # see https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml
                                    # see https://docs.k0sproject.io/v1.30.0+k0s.0/examples/traefik-ingress/
                                    {
                                        'name': 'traefik',
                                        'chartname': 'traefik/traefik',
                                        'version': '$traefik_chart_version',
                                        'namespace': 'cluster-traefik',
                                        'values': textwrap.dedent(
                                            '''\
                                            ports:
                                              # enable tls.
                                              # NB this is not really configured. it will use a dummy
                                              #    self-signed certificate. this is only here to be
                                              #    able to login into the kubernetes dashboard.
                                              websecure:
                                                tls:
                                                  enabled: true
                                            # publish the traefik service IP address in the Ingress
                                            # resources.
                                            providers:
                                              kubernetesIngress:
                                                publishedService:
                                                  enabled: true
                                            # disable the dashboard IngressRoute.
                                            # NB we will create the Ingress ourselves and expose the
                                            #    dashboard with external-dns too.
                                            ingressRoute:
                                              dashboard:
                                                enabled: false
                                            logs:
                                              # set the logging level.
                                              general:
                                                level: DEBUG
                                              # enable the access logs.
                                              access:
                                                enabled: true
                                            # disable pilot.
                                            pilot:
                                              enabled: false
                                              dashboard: false
                                            # disable the telemetry (this is done by emptying globalArguments) and
                                            # configure traefik to skip certificate validation.
                                            # NB this is needed to expose the k8s dashboard as an ingress at
                                            #    https://kubernetes-dashboard.k0s.test when the dashboard is using
                                            #    tls.
                                            # NB without this, traefik returns "internal server error" when it
                                            #    encounters a server certificate signed by an unknown CA.
                                            # NB we need to use https, because the kubernetes-dashboard require it
                                            #    to allow us to login.
                                            # TODO see how to set the CAs in traefik.
                                            # NB this should never be done at production.
                                            globalArguments:
                                              - --serverstransport.insecureskipverify=true
                                            '''),
                                    },
                                    # see https://artifacthub.io/packages/helm/bitnami/metallb
                                    # see https://metallb.universe.tf/configuration/#layer-2-configuration
                                    # see https://github.com/bitnami/charts/tree/master/bitnami/metallb
                                    {
                                        'name': 'metallb',
                                        'chartname': 'bitnami/metallb',
                                        'version': '$metallb_chart_version',
                                        'namespace': 'cluster-metallb'
                                    },
                                    # see https://artifacthub.io/packages/helm/bitnami/external-dns
                                    # see https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/pdns.md
                                    # see https://github.com/kubernetes-sigs/external-dns/blob/master/docs/initial-design.md
                                    {
                                        'name': 'external-dns',
                                        'chartname': 'bitnami/external-dns',
                                        'version': '$external_dns_chart_version',
                                        'namespace': 'cluster-external-dns',
                                        'values': textwrap.dedent(
                                            f'''\
                                            logLevel: debug
                                            interval: 30s
                                            sources:
                                              - ingress
                                            txtOwnerId: k8s
                                            domainFilters:
                                              - {config['pandoraFqdn'].split('.', 1)[-1]}
                                            provider: pdns
                                            pdns:
                                              apiUrl: http://{config['pandoraFqdn']}
                                              apiKey: vagrant
                                            '''),
                                    },
                                    # see https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard
                                    # see https://github.com/kubernetes/dashboard/blob/master/aio/deploy/helm-chart/kubernetes-dashboard/values.yaml
                                    {
                                        'name': 'kubernetes-dashboard',
                                        'chartname': 'kubernetes-dashboard/kubernetes-dashboard',
                                        'version': '$kubernetes_dashboard_chart_version',
                                        'namespace': 'cluster-dashboard',
                                        'values': textwrap.dedent(
                                            f'''\
                                            kong:
                                              proxy:
                                                http:
                                                  enabled: true
                                            '''),
                                    },
                                ]
                            }
                        }
                    }
                }
            },
            'hosts': [
                {
                    'role': 'worker' if node['type'] != 'controller' else 'controller',
                    'privateInterface': 'eth1',
                    'privateAddress': node['ipAddress'],
                    'ssh': {
                        'address': node['ipAddress'],
                        'port': 22,
                        'user': 'root',
                        'keyPath': '/root/.ssh/id_rsa',
                    },
                    'uploadBinary': True,
                    'k0sBinaryPath': '/usr/local/bin/k0s',
                }
                for node in config['nodes']
            ],
        },
    }
    #del k0sctl_config['spec']['k0s']['config']['spec']['extensions']
    with open('/vagrant/shared/k0sctl.yaml', 'w') as f:
        json.dump(k0sctl_config, f, indent=4)

save_k0sctl_config()
EOF

# dump the chart values.
python3 <<EOF
import json
import textwrap

def load_config():
    with open('/vagrant/shared/k0sctl.yaml', 'r') as f:
        return json.load(f)

config = load_config()

config_spec = config['spec']['k0s']['config']['spec']
if 'extensions' in config_spec:
  config_extensions = config_spec['extensions']
  if 'helm' in config_extensions:
    config_helm_extension = config_extensions['helm']
    for c in config_helm_extension['charts']:
      print(f'chart {c["name"]} {c["version"]}')
      if 'values' in c:
        print('  values:')
        print(f'{textwrap.indent(textwrap.dedent(c["values"]).strip(), "    ")}')
EOF

# apply the configuration.
k0sctl apply --config /vagrant/shared/k0sctl.yaml

# save the kubectl configuration.
install -d -m 700 ~/.kube
install -m 600 /dev/null ~/.kube/config
k0sctl kubeconfig --config /vagrant/shared/k0sctl.yaml >~/.kube/config
cp ~/.kube/config /vagrant/shared/kubeconfig
export KUBECONFIG=~/.kube/config

# configure metallb.
bash -euo pipefail <<'EOF'
while [ -z "$(helm ls -n cluster-metallb -o json | jq -r '.[] | select(.status == "deployed")')" ]; do sleep 5; done
while ! kubectl get -n cluster-metallb service/metallb-webhook-service 2>&1 >/dev/null; do sleep 5; done
EOF
# NB we have to sit in a loop until the metallb-webhook-service endpoint is
#    available. while its starting, it will fail with:
#       Error from server (InternalError): error when creating "STDIN": Internal error occurred: failed calling webhook "ipaddresspoolvalidationwebhook.metallb.io": failed to call webhook: Post "https://metallb-webhook-service.cluster-metallb.svc:443/validate-metallb-io-v1beta1-ipaddresspool?timeout=10s": dial tcp 10.103.0.220:443: connect: connection refused
metallb_ip_addresses="$(jq -r .metallbIpAddresses /vagrant/shared/config.json)"
while ! kubectl apply -n cluster-metallb -f - <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
spec:
  addresses:
    - $metallb_ip_addresses
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
EOF
do sleep 5; done

# create the haproxy service account (and secret).
# NB by default, any service account allowed to access the healthz endpoint.
# see https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets
kubectl apply -n kube-system -f - <<'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: haproxy
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: haproxy
  annotations:
    kubernetes.io/service-account.name: haproxy
EOF
haproxy_sa_secret_json="$(kubectl -n kube-system get secret haproxy -o json)"
haproxy_sa_token_path='/etc/haproxy/sa-token.txt'
haproxy_sa_ca_path='/etc/haproxy/sa-ca.pem'
install -m 600 /dev/null "$haproxy_sa_token_path"
install -m 600 /dev/null "$haproxy_sa_ca_path"
jq -r '.data.token' <<<"$haproxy_sa_secret_json" | base64 -d >"$haproxy_sa_token_path"
jq -r '.data."ca.crt"' <<<"$haproxy_sa_secret_json" | base64 -d >"$haproxy_sa_ca_path"

# configure the haproxy backend servers health checks.
# TODO this is not really a final solution. we should find a way to configure
#      the token before/while bootstrapping the cluster.
bash /vagrant/provision-haproxy-config.sh \
  set-health-checks \
  "$(jq -r .controllerFqdn /vagrant/shared/config.json)" \
  "$(jq -r .controllerIpAddress /vagrant/shared/config.json)" \
  "$(jq -r '.nodes[] | select(.type == "controller") | .ipAddress' /vagrant/shared/config.json | tr '\n' ',' | sed -E 's/,$//g')" \
  "$haproxy_sa_token_path" \
  "$haproxy_sa_ca_path"

# provision cert-manager.
# NB YOU MUST INSTALL CERT-MANAGER TO THE cert-manager NAMESPACE. the CRDs have it hard-coded.
# NB YOU CANNOT INSTALL MULTIPLE INSTANCES OF CERT-MANAGER IN A CLUSTER.
# NB this cannot be done from k0sctl.yaml because it needs the CRDs to be installaled separately.
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager
# see https://cert-manager.io/docs/installation/supported-releases/
# see https://cert-manager.io/docs/configuration/selfsigned/#bootstrapping-ca-issuers
# see https://cert-manager.io/docs/usage/ingress/
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/v$cert_manager_chart_version/cert-manager.crds.yaml"
helm install cert-manager \
  --namespace cert-manager \
  --version "$cert_manager_chart_version" \
  --create-namespace \
  --wait \
  jetstack/cert-manager
kubectl apply -f - <<'EOF'
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ingress
  namespace: cert-manager
spec:
  isCA: true
  subject:
    organizations:
      - Example
    organizationalUnits:
      - Kubernetes
  commonName: Kubernetes Ingress
  privateKey:
    algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
    size: 256
  duration: 8h # NB this is so low for testing purposes. default is 2160h (90 days).
  secretName: ingress-tls
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ingress
spec:
  ca:
    secretName: ingress-tls
EOF

# wait for all the helm charts to be available.
jq -r '.spec.k0s.config.spec.extensions.helm.charts[] | [.namespace, .name] | @tsv' /vagrant/shared/k0sctl.yaml | while read namespace name; do
  echo "Waiting for helm release $namespace $name to be deployed..."
  while [ -z "$(helm ls -n "$namespace" -o json | jq -r '.[] | select(.status == "deployed")')" ]; do sleep 5; done
done

# trust the ingress ca.
kubectl -n cert-manager get secret/ingress-tls -o jsonpath='{.data.tls\.crt}' \
  | base64 --decode \
  >/usr/local/share/ca-certificates/kubernetes-ingress-ca.crt
update-ca-certificates -v

# expose the traefik dashboard at http://traefik.k0s.test and https://traefik.k0s.test.
traefik_host="traefik.$domain"
kubectl apply -n cluster-traefik -f - <<EOF
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik
spec:
  subject:
    organizations:
      - Example
    organizationalUnits:
      - Kubernetes
  commonName: Traefik Dashboard
  dnsNames:
    - $traefik_host
  duration: 1h # NB this is so low for testing purposes.
  privateKey:
    algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
    size: 256
  secretName: traefik-tls
  issuerRef:
    kind: ClusterIssuer
    name: ingress
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik
spec:
  entryPoints:
    - websecure
  tls:
    secretName: traefik-tls
  routes:
    - match: Host("$traefik_host")
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik
spec:
  rules:
    # NB we do not specify any backend services. this will make traefik ignore
    #    this ingress and just use the IngressRoute we defined earlier. it will
    #    also be used by external-dns to publish the DNS A RR.
    # NB we could just point to the traefik service, but since its deployed by
    #    helm, we do not known its actual service name; its someting alike
    #    traefik-1628581297:
    #       root@controller1:~# kubectl get service -A
    #       NAMESPACE     NAME                      TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
    #       default       traefik-1628581297        LoadBalancer   10.110.59.161    10.10.0.100   80:30074/TCP,443:30484/TCP   9m47s
    # NB due to the external-dns controller this will automatically configure
    #    the external DNS server (installed in the pandora box) based on this
    #    ingress rule.
    #    see https://github.com/kubernetes-sigs/external-dns
    - host: $traefik_host
EOF
bash -c "while ! wget -qO/dev/null 'https://$traefik_host'; do sleep 1; done;"

# create the kubernetes-dashboard ingress.
kubernetes_dashboard_host="kubernetes-dashboard.$domain"
kubectl apply -n cluster-dashboard -f - <<EOF
---
# see https://kubernetes.io/docs/concepts/services-networking/ingress/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.30/#ingress-v1-networking-k8s-io
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
spec:
  rules:
    - host: $kubernetes_dashboard_host
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-kong-proxy
                port:
                  name: kong-proxy
  tls:
    - secretName: kubernetes-dashboard-tls
---
# see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kubernetes-dashboard
spec:
  subject:
    organizations:
      - Example
    organizationalUnits:
      - Kubernetes
  commonName: kubernetes-dashboard
  dnsNames:
    - $kubernetes_dashboard_host
  duration: 1h # NB this is so low for testing purposes.
  privateKey:
    algorithm: ECDSA # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
    size: 256
  secretName: kubernetes-dashboard-tls
  issuerRef:
    kind: ClusterIssuer
    name: ingress
EOF
bash -c "while ! wget -qO/dev/null 'https://$kubernetes_dashboard_host'; do sleep 1; done;"

# create the admin user for use in the kubernetes-dashboard.
# see https://github.com/kubernetes/dashboard/wiki/Creating-sample-user
# see https://github.com/kubernetes/dashboard/wiki/Access-control
kubectl apply -n cluster-dashboard -f - <<'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
---
# see https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: admin
  annotations:
    kubernetes.io/service-account.name: admin
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin
    namespace: cluster-dashboard
EOF
# save the admin token.
kubectl -n cluster-dashboard get secret admin -o json \
  | jq -r .data.token \
  | base64 --decode \
  >/vagrant/shared/admin-token.txt

# wait for all the API services to be available.
# NB without this, calls like kubectl api-versions will fail.
while [ -n "$(kubectl get apiservices -o json | jq -r '.items[] | select(.status.conditions[] | select(.type == "Available" and .status != "True")) | .metadata.name')" ]; do sleep 5; done

# blindly trust the controller1 and worker1 ssh server key.
ssh-keyscan -H controller1 >>~/.ssh/known_hosts
ssh-keyscan -H worker1 >>~/.ssh/known_hosts

# show the controller1 node system information.
ssh controller1 k0s sysinfo

# show etcd information.
function etcd-info {
    ssh controller1 etcdctl \
        --cert /var/lib/k0s/pki/etcd/server.crt \
        --key /var/lib/k0s/pki/etcd/server.key \
        --cacert /var/lib/k0s/pki/etcd/ca.crt \
        --write-out table \
        "$*"
}
etcd-info member list
etcd-info endpoint status

# show the nodes.
# NB the controller nodes do not appear in this list.
# see https://docs.k0sproject.io/v1.30.0+k0s.0/FAQ/#why-doesnt-kubectl-get-nodes-list-the-k0s-controllers
kubectl get nodes -o wide

# add the custom registry to the default service account (in the default namespace).
# see https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
# NB without this you need to explicitly add imagePullSecrets to your pod definitions, e.g.:
#       apiVersion: apps/v1
#       kind: Pod
#       spec:
#           imagePullSecrets:
#               - name: pandora-k0s-test-5000
registry_name="$(echo "$registry_host" | sed -E 's,[^a-z0-9],-,g')"
kubectl create secret \
    docker-registry \
    $registry_name \
    --docker-server "$registry_host" \
    --docker-username "$registry_username" \
    --docker-password "$registry_password" \
    --dry-run=client \
    --output yaml \
    | kubectl apply -f -
kubectl patch serviceaccount default -p '{"imagePullSecrets":[{"name":"'$registry_name'"}]}'
#kubectl get serviceaccount default -o yaml

# provision example application.
bash /vagrant/provision-example-app.sh "$registry_domain"

# show summary.
bash /vagrant/summary.sh "$registry_domain"
