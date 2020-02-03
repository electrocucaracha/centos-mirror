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
$no_proxy += ",10.0.2.15"
$socks_proxy = ENV['socks_proxy'] || ENV['SOCKS_PROXY'] || ""

Vagrant.configure(2) do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.box = "centos/7"
  config.vm.box_version = "1905.01"
  config.vm.synced_folder './', '/vagrant'

  [:virtualbox, :libvirt].each do |provider|
  config.vm.provider provider do |p|
      p.cpus = 4
      p.memory = 8192
    end
  end

  $volume_file = "sda.vdi"
  config.vm.provider 'virtualbox' do |v, override|
    unless File.exist?($volume_file)
      v.customize ['createmedium', 'disk', '--filename', $volume_file, '--size', 100]
    end
    v.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', $volume_file]
  end

  config.vm.provider :libvirt do |v|
    v.cpu_mode = 'host-passthrough'
    v.random_hostname = true
    v.management_network_address = "192.168.121.0/24"
    v.storage :file, :bus => 'sata', :device => 'sda', :size => 100
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
