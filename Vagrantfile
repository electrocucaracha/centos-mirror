# -*- mode: ruby -*-
# vi: set ft=ruby :
##############################################################################
# Copyright (c) 2020
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

$no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
# NOTE: This range is based on vagrant-libvirt network definition CIDR 192.168.121.0/24
(1..254).each do |i|
  $no_proxy += ",192.168.121.#{i}"
end
$no_proxy += ",10.0.2.15,10.10.17.4"

Vagrant.configure("2") do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.box = "centos/7"
  config.vm.synced_folder './', '/vagrant', type: "rsync",
    rsync__args: ["--verbose", "--archive", "--delete", "-z"]

  [:virtualbox, :libvirt].each do |provider|
  config.vm.provider provider do |p|
      p.cpus = 1
      p.memory = ENV['MEMORY'] || 512
    end
  end

  # External volume setup
  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
    sudo sfdisk /dev/sdb --no-reread << EOF
;
EOF
    sudo mkfs -t ext4 /dev/sdb1
    sudo mkdir -p /var/mrepo
    sudo mount /dev/sdb1 /var/mrepo
    echo "/dev/sdb1 /var/mrepo           ext4    errors=remount-ro,noatime,barrier=0 0       1" | sudo tee --append /etc/fstab
  SHELL

  $volume_file = "sda.vdi"
  config.vm.provider 'virtualbox' do |v, override|
    unless File.exist?($volume_file)
      v.customize ['createmedium', 'disk', '--filename', $volume_file, '--size', (15 * 1024)]
    end
    v.customize ['storageattach', :id, '--storagectl', 'IDE', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', $volume_file]
  end

  config.vm.provider :libvirt do |v|
    v.cpu_mode = 'host-passthrough'
    v.random_hostname = true
    v.management_network_address = "192.168.121.0/24"
    v.storage :file, :bus => 'sata', :device => 'sda', :size => 15
  end

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil
    if Vagrant.has_plugin?('vagrant-proxyconf')
      config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ""
      config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ""
      config.proxy.no_proxy = $no_proxy
      config.proxy.enabled = { docker: false, git: false }
    end
  end
  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
    cd /vagrant
    ./postinstall.sh | tee ~/postinstall.log
  SHELL
end
