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

# see https://github.com/moby/moby/releases
# NB execute apt-cache madison docker-ce to known the available versions.
# renovate: datasource=github-releases depName=moby/moby
CONFIG_DOCKER_VERSION = '26.1.3'

# see https://github.com/k0sproject/k0sctl/releases
# renovate: datasource=github-releases depName=k0sproject/k0sctl
CONFIG_K0SCTL_VERSION = 'v0.17.8'

# see https://github.com/k0sproject/k0s/releases
# renovate: datasource=github-releases depName=k0sproject/k0s
CONFIG_K0S_VERSION = 'v1.27.13+k0s.0'
CONFIG_KUBECTL_VERSION = CONFIG_K0S_VERSION.gsub(/v([\.\d]+).+/, '\1')

# see https://github.com/derailed/k9s/releases
# renovate: datasource=github-releases depName=derailed/k9s
CONFIG_K9S_VERSION = 'v0.32.4'

# see https://github.com/kubernetes-sigs/krew/releases
# renovate: datasource=github-releases depName=kubernetes-sigs/krew
CONFIG_KREW_VERSION = 'v0.4.4'

# see https://github.com/etcd-io/etcd/releases
# NB make sure you use a version compatible with k0s go.mod.
# renovate: datasource=github-releases depName=etcd-io/etcd
CONFIG_ETCDCTL_VERSION = 'v3.5.13'

# see https://github.com/helm/helm/releases
# NB make sure you use a version compatible with k0s go.mod.
# renovate: datasource=github-releases depName=helm/helm
CONFIG_HELM_VERSION = 'v3.15.0'

# see https://github.com/helmfile/helmfile/releases
# renovate: datasource=github-releases depName=helmfile/helmfile
CONFIG_HELMFILE_VERSION = '0.164.0'

# see https://launchpad.net/ubuntu/+archivemirrors
# see https://launchpad.net/ubuntu/+mirror/mirrors.up.pt-archive
CONFIG_UBUNTU_MIRROR = 'http://mirrors.up.pt/ubuntu/'

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
  config.vm.box = 'ubuntu-22.04-amd64'

  config.vm.provider 'libvirt' do |lv, config|
    lv.memory = 2*1024
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    lv.nested = true
    lv.keymap = 'pt'
    lv.machine_virtual_size = 16 # [GiB]
    lv.disk_driver :discard => 'unmap', :cache => 'unsafe'
    # NB virtiofs is currently broken on my system; so this uses nfs instead.
    # # configure the vagrant synced folder.
    # lv.memorybacking :source, :type => 'memfd'  # required for virtiofs.
    # lv.memorybacking :access, :mode => 'shared' # required for virtiofs.
    # config.vm.synced_folder '.', '/vagrant', type: 'virtiofs'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.provision "shell", path: "provision-resize-disk.sh"

  config.vm.define :pandora do |config|
    config.vm.provider 'libvirt' do |lv, config|
      lv.memory = 1*1024
    end
    config.vm.hostname = CONFIG_PANDORA_FQDN
    config.vm.network :private_network, ip: CONFIG_PANDORA_IP_ADDRESS, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
    config.vm.network :private_network, ip: CONFIG_CONTROLLER_IP_ADDRESS, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
    config.vm.provision 'shell', inline: 'echo "$1" >/etc/hosts', args: [hosts]
    config.vm.provision 'shell', path: 'provision-apt-cacher.sh', args: [CONFIG_UBUNTU_MIRROR, CONFIG_PANDORA_FQDN]
    config.vm.provision 'shell', path: 'provision-base.sh', args: [CONFIG_UBUNTU_MIRROR, CONFIG_PANDORA_FQDN]
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
        lv.memory = 2*1024
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: [CONFIG_UBUNTU_MIRROR, CONFIG_PANDORA_FQDN, CONFIG_PANDORA_IP_ADDRESS]
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
