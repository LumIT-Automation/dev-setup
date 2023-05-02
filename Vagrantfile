# -*- mode: ruby -*-
# vi: set ft=ruby :

module OS
    # https://stackoverflow.com/questions/26811089/vagrant-how-to-have-host-platform-specific-provisioning-steps

  def OS.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def OS.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def OS.unix?
    !OS.windows?
  end

  def OS.linux?
    OS.unix? and not OS.mac?
  end
end



# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.

# The most common configuration options are documented and commented below.
# For a complete reference, please see the online documentation at
# https://docs.vagrantup.com.

Vagrant.configure("2") do |config|

  config.env.enable # enable vagrant-env(.env).

  Dir.glob('./vagrantfile-*') do |vagrantApiFile|
    eval File.read(vagrantApiFile)
  end

  ############################################################################################
  # Hostsystem: Log collector, smtp
  ############################################################################################

  config.vm.define :hostsystem do |hostsystem|
    hostsystem.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "512"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    hostsystem.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "512"
      libvrt.cpus = 1
    end

    # OS.
    hostsystem.vm.box = "debian/bullseye64"
    #hostsystem.vm.box_version = "11.20220912.1"

    # Network.
    hostsystem.vm.network :private_network, ip: "10.0.111.253"
    hostsystem.vm.hostname = "hostsystem"

    # Synced folders.
    if OS.linux?
      hostsystem.vm.synced_folder "../log", "/var/syslog-ng", type: "nfs", nfs_version: 4
      hostsystem.vm.synced_folder "../smtp", "/var/smtp", type: "nfs", nfs_version: 4
    end

    # Alternative debian mirror.
    if File.exist?("hostsystem/sources.list")
      hostsystem.vm.provision "file", source: "hostsystem/sources.list", destination: "/tmp/sources.list"
    end

    # Copy syslog-ng config files from container repos.
    if File.exist?("../api-f5/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../api-f5/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/api-f5_syslog-ng"
    end
    if File.exist?("../api-infoblox/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../api-infoblox/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/api-infoblox_syslog-ng"
    end
    if File.exist?("../api-fortinetdb/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../api-fortinetdb/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/api-fortinetdb_syslog-ng"
    end
    if File.exist?("../api-vmware/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../api-vmware/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/api-vmware_syslog-ng"
    end
    if File.exist?("../aaa/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../aaa/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/sso_syslog-ng"
    end
    if File.exist?("../dns/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../dns/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/dns_syslog-ng"
    end
    if File.exist?("../revp/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../revp/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/revp_syslog-ng"
    end
    if File.exist?("../ui-backend/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../ui-backend/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/uib_syslog-ng"
    end
    if File.exist?("../ui-frontend-ng/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d")
      hostsystem.vm.provision "file", source: "../ui-frontend-ng/CONTAINER-DEBIAN-PKG/etc/syslog-ng/conf.d", destination: "/tmp/uif_syslog-ng"
    end

    # SMTP config variables.
    if File.exist?(".env")
      hostsystem.vm.provision "file", source: ".env", destination: "/tmp/smtp-vars.conf"
    end

    # Provision.
    hostsystem.vm.provision "shell" do |s|
      s.path = "hostsystem/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

  ############################################################################################
  # DOTNET STUB (for future use... maybe)
  ############################################################################################

  config.vm.define :dotnet do |dotnet|
    dotnet.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "2048"
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    dotnet.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "4096"
      libvrt.cpus = 2
    end

    # OS.
    dotnet.vm.box = "debian/bullseye64"
    #dotnet.vm.box_version = "11.20220912.1"

    # Network.
    dotnet.vm.network :private_network, ip: "10.0.111.30"
    dotnet.vm.hostname = "dotnet"

    # Synced folders.
    if OS.linux?
      dotnet.vm.synced_folder "../dotnet", "/var/www/dotnet", type: "nfs", nfs_udp: false, nfs_version: 3, fsnotify: true, :mount_options => ["nolock" ] # use these options for fsnotify to properly work (nfs_version v3). Also, nolock on NFS v3. https://github.com/dotnet/runtime/issues/48757
    end

    # Alternative debian mirror.
    if File.exist?("dotnet/sources.list")
      dotnet.vm.provision "file", source: "dotnet/sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    dotnet.vm.provision "shell" do |s|
      s.path = "dotnet/bootstrap.sh"
      s.args = ["--action", "install"]
    end

    # Triggers.
    if OS.linux?
      dotnet.trigger.before :up do |trigger|
        trigger.name = "fsnotify: increase host max_user_watches limit"
        trigger.run = { inline: "bash ./set-inotify.sh dotnet start" }
      end
      dotnet.trigger.after :up do |trigger|
        trigger.name = "vagrant-fsnotify-dotnet"
        trigger.run = { inline: "bash -c '(vagrant fsnotify dotnet) > /dev/null 2>&1 &' " }
      end
      dotnet.trigger.after :halt, :destroy do |trigger|
        trigger.name = "fsnotify: restore host max_user_watches limit"
        trigger.run = { inline: "bash ./set-inotify.sh dotnet stop" }
      end
      dotnet.trigger.after :halt, :destroy do |trigger|
        trigger.name = "kill vagrant-fsnotify-dotnet"
        trigger.run = { inline: "pkill -f '/usr/bin/vagrant fsnotify dotnet'" }
        trigger.exit_codes = [ 0, 1 ]
      end
    end
  end

  ############################################################################################
  # Empty Centos8 vm
  ############################################################################################

  config.vm.define :centos8 do |centos8|
    centos8.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]

      if Vagrant.has_plugin?("vagrant-disksize")
        centos8.disksize.size = "20GB"
      end
    end

    centos8.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1024"
      libvrt.cpus = 1
    end

    # OS.
    centos8.vm.box = "centos/8"

    # Network.
    centos8.vm.network :private_network, ip: "10.0.111.201"
    centos8.vm.hostname = "centos8"

    # Provision.
    centos8.vm.provision "shell" do |s|
      s.path = "centos8/bootstrap.sh"
      s.args = ["--action", "install"]
    end

    # Triggers.
    # Use a script to expand the vdisk with libvirtd.
    #if ! Vagrant.has_plugin?("vagrant-disksize")
    #  centos8.trigger.after :up do |trigger|
    #    trigger.info = "Expanding disk..."
    #    trigger.run = {inline: "sudo resize_libvirtd.sh centos8 5 > /tmp/res.log"}
    #  end
    #end

    centos8.trigger.after :up do |trigger|
      trigger.info = "Expanding filesystem..."
      trigger.run_remote = {inline: "diskDevice=`fdisk -l| grep 'Disk /dev' | awk '{print $2}' | sed 's/://'`; printf 'd\nn\n\n\n\n\nw\n' | fdisk $diskDevice; sync; xfs_growfs ${diskDevice}1"}
    end
  end

  ############################################################################################
  # Empty Debian 11 vm
  ############################################################################################

  config.vm.define :deb11 do |empty|
    empty.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "2048"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    empty.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "2048"
      libvrt.cpus = 1
    end

    # OS.
    empty.vm.box = "debian/bullseye64"
    #empty.vm.box_version = "11.20220912.1"

    # Network.
    empty.vm.network :private_network, ip: "10.0.111.202"
    empty.vm.hostname = "deb11"

    # Provision.
    empty.vm.provision "shell" do |s|
      s.path = "deb11/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

  ############################################################################################
  # Empty Ubuntu 20.04
  ############################################################################################

  config.vm.define :ubu20 do |empty|
    empty.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "2048"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    empty.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "2048"
      libvrt.cpus = 1
    end

    # OS.
    empty.vm.box = "generic/ubuntu2004"

    # Network.
    empty.vm.network :private_network, ip: "10.0.111.203"
    empty.vm.hostname = "ubu20"

    # Provision.
    empty.vm.provision "shell" do |s|
      s.path = "ubu20/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

end
