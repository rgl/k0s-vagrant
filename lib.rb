require 'open3'
require 'ipaddr'
require 'json'

def generate_ip_addresses(base_ip_address, count)
  ip_address = IPAddr.new base_ip_address
  (1..count).map do |n|
    a, ip_address = ip_address.to_s, ip_address.succ
    a
  end
end
