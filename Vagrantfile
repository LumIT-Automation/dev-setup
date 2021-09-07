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

  ############################################################################################
  # REVERSE PROXY, TLS OFFLOAD: NGINX
  ############################################################################################

  config.vm.define :revp do |revp|
    revp.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "512"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    revp.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "512"
      libvrt.cpus = 1
    end

    # OS.

    revp.vm.box = "debian/buster64"
    revp.vm.box_version = "10.20210409.1"

    # Network.

    revp.vm.network :private_network, ip: "10.0.111.10"
    revp.vm.hostname = "revp"

    # Synced folders.

    if OS.linux?
      revp.vm.synced_folder "../revp", "/var/reverse_proxy", type: "nfs", fsnotify: true
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      revp.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    revp.vm.provision "shell" do |s|
      s.path = "revp/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

  ############################################################################################
  # UI FRONTEND
  ############################################################################################

  config.vm.define :uif do |uif|
    uif.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "2048"
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    uif.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1536"
      libvrt.cpus = 2
    end

    # OS.

    uif.vm.box = "debian/buster64"
    uif.vm.box_version = "10.20210409.1"

    # Network.

    uif.vm.network :private_network, ip: "10.0.111.11"
    uif.vm.hostname = "uif"

    # Synced folders.

    if OS.linux?
      uif.vm.synced_folder "../ui-frontend", "/var/www/ui-frontend", type: "nfs", fsnotify: true
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      uif.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    uif.vm.provision "shell" do |s|
      s.path = "uif/bootstrap.sh"
      s.args = ["--action", "install"]
    end

    # Triggers.
    if OS.linux?
      uif.trigger.before :up do |trigger|
        trigger.name = "fsnotify: increase host max_user_watches limit"
        trigger.run = { inline: "bash ./set-inotify.sh uif start" }
      end
      uif.trigger.after :up do |trigger|
        trigger.name = "vagrant-fsnotify"
        trigger.run = { inline: "bash -c '(vagrant fsnotify uif) > /dev/null 2>&1 &' " }
      end
      uif.trigger.after :halt, :destroy do |trigger|
        trigger.name = "fsnotify: restore host max_user_watches limit"
        trigger.run = { inline: "bash ./set-inotify.sh uif stop" }
      end
      uif.trigger.after :halt, :destroy do |trigger|
        trigger.name = "kill vagrant-fsnotify uif"
        trigger.run = { inline: "pkill -f '/usr/bin/vagrant fsnotify uif'" }
        trigger.exit_codes = [ 0, 1 ]
      end
    end
  end

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  ############################################################################################
  # UI FRONTEND NEXT-GENERATION
  ############################################################################################

  config.vm.define :uifng do |uifng|
    uifng.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "2048"
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    uifng.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1536"
      libvrt.cpus = 2
    end

    # OS.

    uifng.vm.box = "debian/buster64"
    uifng.vm.box_version = "10.20210409.1"

    # Network.

    uifng.vm.network :private_network, ip: "10.0.111.13"
    uifng.vm.hostname = "uifng"

    # Synced folders.

    if OS.linux?
      uifng.vm.synced_folder "../ui-frontend-ng", "/var/www/ui-frontend-ng", type: "nfs", fsnotify: true
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      uifng.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    uifng.vm.provision "shell" do |s|
      s.path = "uifng/bootstrap.sh"
      s.args = ["--action", "install"]
    end

    # Triggers.
    if OS.linux?
      uifng.trigger.before :up do |trigger|
        trigger.name = "fsnotify: increase host max_user_watches limit"
        trigger.run = { inline: "bash ./set-inotify.sh uifng start" }
      end
      uifng.trigger.after :up do |trigger|
        trigger.name = "vagrant-fsnotify"
        trigger.run = { inline: "bash -c '(vagrant fsnotify uifng) > /dev/null 2>&1 &' " }
      end
      uifng.trigger.after :halt, :destroy do |trigger|
        trigger.name = "fsnotify: restore host max_user_watches limit"
        trigger.run = { inline: "bash ./set-inotify.sh uifng stop" }
      end
      uifng.trigger.after :halt, :destroy do |trigger|
        trigger.name = "kill vagrant-fsnotify uifng"
        trigger.run = { inline: "pkill -f '/usr/bin/vagrant fsnotify uifng'" }
        trigger.exit_codes = [ 0, 1 ]
      end
    end
  end

  ############################################################################################
  # UI BACKEND
  ############################################################################################

  config.vm.define :uib do |uib|
    uib.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    uib.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1024"
      libvrt.cpus = 2
    end

    # OS.

    uib.vm.box = "debian/buster64"
    uib.vm.box_version = "10.20210409.1"

    # Network.

    uib.vm.network :private_network, ip: "10.0.111.12"
    uib.vm.hostname = "uib"

    # Synced folders.

    if OS.linux?
      uib.vm.synced_folder "../ui-backend", "/var/www/ui-backend", type: "nfs"
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      uib.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    uib.vm.provision "shell" do |s|
      s.path = "uib/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  ############################################################################################
  # API CiscoNX
  ############################################################################################

  config.vm.define :apicisconx do |api|
    api.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"] # https://serverfault.com/questions/453185/vagrant-virtualbox-dns-10-0-2-3-not-working
    end

    api.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1024"
      libvrt.cpus = 2
    end

    # OS.

    # Every Vagrant development environment requires a box. You can search for
    # boxes at https://vagrantcloud.com/search.

    api.vm.box = "debian/buster64"
    api.vm.box_version = "10.20210409.1"

    # Network.

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    # NOTE: This will enable public access to the opened port

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine and only allow access
    # via 127.0.0.1 to disable public access
    # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    # config.vm.network "private_network", ip: "192.168.33.10"

    api.vm.network :private_network, ip: "10.0.111.20"
    api.vm.hostname = "apicisconx"

    # Synced folders.

    if OS.linux?
      api.vm.synced_folder "../api-cisconx", "/var/www/api", type: "nfs"
    end

    # Set VPN credentials.
    api.vm.provision "shell" do |s|
      s.args = "\"#{ENV['lumit_vpn_username']}\" \"#{ENV['lumit_vpn_password']}\" \"#{ENV['lumit_vpn_host']}\" \"#{ENV['lumit_vpn_port']}\" \"#{ENV['lumit_vpn_trusted_cert']}\" \"#{ENV['openconnect_vpn_username']}\" \"#{ENV['openconnect_vpn_password']}\""
      s.inline = "echo -e \"lumit_vpn_username=${1}\nlumit_vpn_password=${2}\nlumit_vpn_host=${3}\nlumit_vpn_port=${4}\nlumit_vpn_trusted_cert=${5}\nopenconnect_vpn_username=${6}\nopenconnect_vpn_password=${7}\" > /tmp/.vpn.env"
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      api.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    api.vm.provision "shell" do |s|
      s.path = "api-cisconx/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

  ############################################################################################
  # API Infoblox
  ############################################################################################

  config.vm.define :apiinfoblox do |api|
    api.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"] # https://serverfault.com/questions/453185/vagrant-virtualbox-dns-10-0-2-3-not-working
    end

    api.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1024"
      libvrt.cpus = 2
    end

    # OS.

    api.vm.box = "debian/buster64"
    api.vm.box_version = "10.20210409.1"

    # Network.

    api.vm.network :private_network, ip: "10.0.111.21"
    api.vm.hostname = "apiinfoblox"

    # Synced folders.

    if OS.linux?
      api.vm.synced_folder "../api-infoblox", "/var/www/api", type: "nfs"
    end

    # Set VPN credentials.
    api.vm.provision "shell" do |s|
      s.args = "\"#{ENV['lumit_vpn_username']}\" \"#{ENV['lumit_vpn_password']}\" \"#{ENV['lumit_vpn_host']}\" \"#{ENV['lumit_vpn_port']}\" \"#{ENV['lumit_vpn_trusted_cert']}\""
      s.inline = "echo -e \"lumit_vpn_username=${1}\nlumit_vpn_password=${2}\nlumit_vpn_host=${3}\nlumit_vpn_port=${4}\nlumit_vpn_trusted_cert=${5}\" > /tmp/.vpn.env"
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      api.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    api.vm.provision "shell" do |s|
      s.path = "api-infoblox/bootstrap.sh"
      s.args = ["--action", "install"]
    end
    api.vm.provision "db", type: "shell" do |s|
      s.path = "api-infoblox/db-bootstrap.sh"
      s.args = ["--action", "run"]
    end
  end

  ############################################################################################
  # API F5
  ############################################################################################

  config.vm.define :apif5 do |api|
    api.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.cpus = 2
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"] # https://serverfault.com/questions/453185/vagrant-virtualbox-dns-10-0-2-3-not-working
    end

    api.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1024"
      libvrt.cpus = 2
    end

    # OS.

    api.vm.box = "debian/buster64"
    api.vm.box_version = "10.20210409.1"

    # Network.

    api.vm.network :private_network, ip: "10.0.111.22"
    api.vm.hostname = "apif5"

    # Synced folders.

    if OS.linux?
      api.vm.synced_folder "../api-f5", "/var/www/api", type: "nfs"
    end

    # Set VPN credentials.
    api.vm.provision "shell" do |s|
      s.args = "\"#{ENV['lumit_vpn_username']}\" \"#{ENV['lumit_vpn_password']}\" \"#{ENV['lumit_vpn_host']}\" \"#{ENV['lumit_vpn_port']}\" \"#{ENV['lumit_vpn_trusted_cert']}\""
      s.inline = "echo -e \"lumit_vpn_username=${1}\nlumit_vpn_password=${2}\nlumit_vpn_host=${3}\nlumit_vpn_port=${4}\nlumit_vpn_trusted_cert=${5}\" > /tmp/.vpn.env"
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      api.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    api.vm.provision "shell" do |s|
      s.path = "api-f5/bootstrap.sh"
      s.args = ["--action", "install"]
    end
    api.vm.provision "db", type: "shell" do |s|
      s.path = "api-f5/db-bootstrap.sh"
      s.args = ["--action", "run"]
    end
  end

  ############################################################################################
  # AAA
  ############################################################################################

  config.vm.define :aaa do |aaa|
    aaa.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    aaa.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1024"
      libvrt.cpus = 1
    end

    # OS.

    aaa.vm.box = "debian/buster64"
    aaa.vm.box_version = "10.20210409.1"

    # Network.

    aaa.vm.network :private_network, ip: "10.0.111.100"
    aaa.vm.hostname = "aaa"

    # Synced folders.

    if OS.linux?
      aaa.vm.synced_folder "../aaa", "/var/www/aaa", type: "nfs", fsnotify: true
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      aaa.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    aaa.vm.provision "shell" do |s|
      s.path = "aaa/bootstrap.sh"
      s.args = ["--action", "install"]
    end
    aaa.vm.provision "db", type: "shell" do |s|
      s.path = "aaa/db-bootstrap.sh"
      s.args = ["--action", "run"]
    end
  end

  ############################################################################################
  # User Database - UDB
  ############################################################################################

  config.vm.define :udb do |udb|
    udb.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "1024"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    udb.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "1024"
      libvrt.cpus = 1
    end

    # OS.

    udb.vm.box = "debian/buster64"
    udb.vm.box_version = "10.20210409.1"

    # Network.

    udb.vm.network :private_network, ip: "10.0.111.110"
    udb.vm.network :private_network, ip: "10.0.111.111"
    udb.vm.hostname = "ad"

    # Provision.
    udb.vm.provision "file", source: "udb/samba_4.13.2-1_amd64.deb", destination: "samba_4.13.2-1_amd64.deb"
    udb.vm.provision "file", source: "udb/radius.sql", destination: "radius.sql"

    # Alternative debian mirror.
    if File.exist?("sources.list")
      udb.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    udb.vm.provision "shell" do |s|
      s.path = "udb/bootstrap.sh"
      s.args = ["--action", "install"]
    end

  end

  ############################################################################################
  # Log collector - log
  ############################################################################################

  config.vm.define :log do |log|
    log.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "512"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    log.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "512"
      libvrt.cpus = 1
    end

    # OS.

    log.vm.box = "debian/buster64"
    log.vm.box_version = "10.20210409.1"

    # Network.

    log.vm.network :private_network, ip: "10.0.111.253"
    log.vm.hostname = "log"

    # Synced folders.

    if OS.linux?
      log.vm.synced_folder "../log", "/var/syslog-ng", type: "nfs"
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      log.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    log.vm.provision "shell" do |s|
      s.path = "log/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

  ############################################################################################
  # DNS: Consul server // service discovery
  ############################################################################################

  config.vm.define :dns do |dns|
    dns.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "512"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    dns.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "512"
      libvrt.cpus = 1
    end

    # OS.

    dns.vm.box = "debian/buster64"
    dns.vm.box_version = "10.20210409.1"

    # Network.

    dns.vm.network :private_network, ip: "10.0.111.254"
    dns.vm.hostname = "dns"

    # Synced folders.

    if OS.linux?
      dns.vm.synced_folder "../dns", "/var/consul", type: "nfs"
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      dns.vm.provision "file", source: "sources.list", destination: "/tmp/sources.list"
    end

    # Provision.
    dns.vm.provision "shell" do |s|
      s.path = "dns/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end

  ############################################################################################
  # SMTP
  ############################################################################################

  config.vm.define :smtp do |smtp|
    smtp.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = "512"
      vb.cpus = 1
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    smtp.vm.provider "libvirt" do |libvrt|
      libvrt.memory = "512"
      libvrt.cpus = 1
    end

    # OS.

    smtp.vm.box = "debian/bullseye64"
    # smtp.vm.box_version = ""

    # Network.

    smtp.vm.network :private_network, ip: "10.0.111.252"
    smtp.vm.hostname = "smtp"

    # Synced folders.
    if OS.linux?
      smtp.vm.synced_folder "../smtp", "/var/smtp", type: "nfs", nfs_version: 4
    end

    # Alternative debian mirror.
    if File.exist?("sources.list")
      smtp.vm.provision "file", source: "deb11/sources.list", destination: "/tmp/sources.list"
    end

    # SMTP config variables.
    if File.exist?("smtp/smtp-vars.conf")
      smtp.vm.provision "file", source: "smtp/smtp-vars.conf", destination: "/tmp/smtp-vars.conf"
    end

    # Provision.
    smtp.vm.provision "shell" do |s|
      s.path = "smtp/bootstrap.sh"
      s.args = ["--action", "install"]
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
    if ! Vagrant.has_plugin?("vagrant-disksize")
      centos8.trigger.after :up do |trigger|
        trigger.info = "Expanding disk..."
        trigger.run = {inline: "sudo resize_libvirtd.sh centos8 5 > /tmp/res.log"}
      end
    end

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

    # Network.

    empty.vm.network :private_network, ip: "10.0.111.202"
    empty.vm.hostname = "deb11"

    # Provision.
    empty.vm.provision "shell" do |s|
      s.path = "deb11/bootstrap.sh"
      s.args = ["--action", "install"]
    end
  end
end
