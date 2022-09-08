require './lib.rb'

CONFIG_CONTROLLER_COUNT = 1
CONFIG_WORKER_COUNT = 1
CONFIG_DOMAIN = 'k0s.test'
CONFIG_PANDORA_FQDN = "pandora.#{CONFIG_DOMAIN}"
CONFIG_PANDORA_IP_ADDRESS = '10.10.0.2'
CONFIG_CONTROLLER_FQDN = "controller.#{CONFIG_DOMAIN}"
CONFIG_CONTROLLER_IP_ADDRESS = '10.10.0.3'
CONFIG_CONTROLLER_IP_ADDRESSES = generate_ip_addresses('10.10.0.10', CONFIG_CONTROLLER_COUNT)
CONFIG_WORKER_IP_ADDRESSES = generate_ip_addresses('10.10.0.15', CONFIG_WORKER_COUNT)
CONFIG_METALLB_IP_ADDRESSES = '10.10.0.100-10.10.0.150'
CONFIG_DOCKER_VERSION = '20.10.17' # NB execute apt-cache madison docker-ce to known the available versions.
CONFIG_K0SCTL_VERSION = 'v0.13.2' # see https://github.com/k0sproject/k0sctl/releases
CONFIG_K0S_VERSION = 'v1.24.4+k0s.0' # see https://github.com/k0sproject/k0s/releases
CONFIG_KUBECTL_VERSION = CONFIG_K0S_VERSION.gsub(/v([\.\d]+).+/, '\1')
CONFIG_K9S_VERSION = 'v0.26.3' # see https://github.com/derailed/k9s/releases
CONFIG_KREW_VERSION = 'v0.4.3' # see https://github.com/kubernetes-sigs/krew/releases
CONFIG_ETCDCTL_VERSION = 'v3.5.4' # see https://github.com/etcd-io/etcd/releases BUT make sure you use a version compatible with k0s go.mod.
CONFIG_HELM_VERSION = 'v3.9.4' # see https://github.com/helm/helm/releases BUT make sure you use a version compatible with k0s go.mod.
CONFIG_HELMFILE_VERSION = 'v0.144.0' # see https://github.com/roboll/helmfile/releases

hosts = """
127.0.0.1	localhost
#{CONFIG_PANDORA_IP_ADDRESS} #{CONFIG_PANDORA_FQDN}
#{CONFIG_CONTROLLER_IP_ADDRESS} #{CONFIG_CONTROLLER_FQDN}
#{CONFIG_CONTROLLER_IP_ADDRESSES.map.with_index{|ip_address, i|"#{ip_address} controller#{i+1}.#{CONFIG_DOMAIN}"}.join("\n")}
#{CONFIG_WORKER_IP_ADDRESSES.map.with_index{|ip_address, i|"#{ip_address} worker#{i+1}.#{CONFIG_DOMAIN}"}.join("\n")}

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
"""

def nodes
  result = []
  [
    ['controller', CONFIG_CONTROLLER_IP_ADDRESSES],
    ['worker', CONFIG_WORKER_IP_ADDRESSES],
  ].each do |type, ip_addresses|
    ip_addresses.each_with_index do |ip_address, i|
      name = "#{type}#{i+1}"
      fqdn = "#{name}.#{CONFIG_DOMAIN}"
      result << [type, name, fqdn, ip_address]
    end
  end
  result
end

def save_config
  config = {
    'k0sctlVersion' => CONFIG_K0SCTL_VERSION,
    'k0sVersion' => CONFIG_K0S_VERSION,
    'kubectlVersion' => CONFIG_KUBECTL_VERSION,
    'pandoraFqdn' => CONFIG_PANDORA_FQDN,
    'controllerFqdn' => CONFIG_CONTROLLER_FQDN,
    'controllerIpAddress' => CONFIG_CONTROLLER_IP_ADDRESS,
    'metallbIpAddresses' => CONFIG_METALLB_IP_ADDRESSES,
    'nodes' => nodes.map {|type, name, fqdn, ip_address|
      {
        'type' => type,
        'name' => name,
        'fqdn' => fqdn,
        'ipAddress' => ip_address,
      }
    }
  }
  FileUtils.mkdir_p 'shared'
  File.write('shared/config.json', JSON.pretty_generate(config))
end

save_config

Vagrant.configure(2) do |config|
  config.vm.box = 'ubuntu-20.04-amd64'

  config.vm.provider 'libvirt' do |lv, config|
    lv.memory = 2*1024
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    lv.nested = true
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.provider 'virtualbox' do |vb|
    vb.linked_clone = true
    vb.memory = 2*1024
    vb.cpus = 4
  end

  config.vm.define :pandora do |config|
    config.vm.provider 'libvirt' do |lv, config|
      lv.memory = 1*1024
    end
    config.vm.provider 'virtualbox' do |vb|
      vb.memory = 1*1024
    end
    config.vm.hostname = CONFIG_PANDORA_FQDN
    config.vm.network :private_network, ip: CONFIG_PANDORA_IP_ADDRESS, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
    config.vm.network :private_network, ip: CONFIG_CONTROLLER_IP_ADDRESS, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
    config.vm.provision 'shell', inline: 'echo "$1" >/etc/hosts', args: [hosts]
    config.vm.provision 'shell', path: 'provision-apt-cacher.sh', args: [CONFIG_PANDORA_FQDN]
    config.vm.provision 'shell', path: 'provision-base.sh', args: [CONFIG_PANDORA_FQDN]
    config.vm.provision 'shell', path: 'provision-certificate.sh', args: [CONFIG_PANDORA_FQDN]
    config.vm.provision 'shell', path: 'provision-dns-server.sh', args: [CONFIG_PANDORA_IP_ADDRESS, CONFIG_PANDORA_FQDN]
    config.vm.provision 'shell', path: 'provision-docker.sh', args: [CONFIG_DOCKER_VERSION, CONFIG_PANDORA_IP_ADDRESS]
    config.vm.provision 'shell', path: 'provision-registry-proxy.sh', args: [CONFIG_PANDORA_FQDN]
    config.vm.provision 'shell', path: 'provision-registry.sh', args: [CONFIG_PANDORA_FQDN]
    config.vm.provision 'shell', path: 'provision-haproxy.sh', args: [CONFIG_CONTROLLER_FQDN, CONFIG_CONTROLLER_IP_ADDRESS, CONFIG_CONTROLLER_IP_ADDRESSES.join(',')]
    config.vm.provision 'shell', path: 'provision-k0s.sh', args: [CONFIG_K0S_VERSION]
    config.vm.provision 'shell', path: 'provision-k0sctl.sh', args: [CONFIG_K0SCTL_VERSION]
    config.vm.provision 'shell', path: 'provision-kubectl.sh', args: [CONFIG_KUBECTL_VERSION, CONFIG_KREW_VERSION]
    config.vm.provision 'shell', path: 'provision-k9s.sh', args: [CONFIG_K9S_VERSION]
    config.vm.provision 'shell', path: 'provision-etcdctl.sh', args: [CONFIG_ETCDCTL_VERSION]
    config.vm.provision 'shell', path: 'provision-helm.sh', args: [CONFIG_HELM_VERSION]
    config.vm.provision 'shell', path: 'provision-helmfile.sh', args: [CONFIG_HELMFILE_VERSION]
    config.vm.provision 'shell', path: 'provision-go.sh'
    #config.vm.provision 'shell', path: 'provision-k0sctl-custom.sh'
  end

  nodes.each do |type, name, fqdn, ip_address|
    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 1*1024
      end
      config.vm.provider 'virtualbox' do |vb|
        vb.memory = 1*1024
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: [CONFIG_PANDORA_FQDN, CONFIG_PANDORA_IP_ADDRESS]
      config.vm.provision 'shell', path: 'provision-dns-client.sh', args: [CONFIG_PANDORA_IP_ADDRESS]
      if type == 'controller'
        config.vm.provision 'shell', path: 'provision-k0sctl.sh', args: [CONFIG_K0SCTL_VERSION]
        config.vm.provision 'shell', path: 'provision-kubectl.sh', args: [CONFIG_KUBECTL_VERSION, CONFIG_KREW_VERSION]
        config.vm.provision 'shell', path: 'provision-k9s.sh', args: [CONFIG_K9S_VERSION]
        config.vm.provision 'shell', path: 'provision-etcdctl.sh', args: [CONFIG_ETCDCTL_VERSION]
      end
    end
  end
end
