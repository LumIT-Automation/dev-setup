**DEVELOPMENT INFRASTRUCTURE INFORMATION**

A Vagrant virtual machine is set up and run for each node (a subnet where all nodes are placed is also pulled up by Vagrant). An Active Directory/Radius node can be run for the user authentication as well.

**Requirements**
**LINUX**
- Linux host as development machine (tested on modern Debian and Ubuntu OS; any other should work)
- Vagrant
        Use Vagrant repos, https://www.vagrantup.com/downloads
           
      wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/vagrant-archive-keyring.gpg
      sudo echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt update
      sudo apt install vagrant

     Plugins (user-installed):
     
      vagrant plugin install vagrant-reload
      vagrant plugin install vagrant-env
      vagrant plugin install vagrant-fsnotify
      vagrant plugin install vagrant-disksize
- VirtualBox
        On Ubuntu 20+:
        
      sudo apt install -y virtualbox virtualbox-dkms virtualbox-guest-additions-iso virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11
     From VirtualBox 6.1.28 editing the file /etc/vbox/networks.conf is needed:
     
      sudo echo '* 10.0.0.0/8' > /etc/vbox/networks.conf

- Codebases and Vagrant vms

      cd /path/to/projectHome
      git clone all projects

      cd dev-setup
      #vagrant up
      vagrant up udb aaa dns log revp uifng uib apif5 ...
      
    Guests will mount the nfs share host-side, where related code is saved (all is automated by Vagrant)
	
    The first time, vagrant will create all the virtual machines, so it will take a huge amount of time time. Keep relaxed.

    In order to avoid inserting the sudo password every time, use the following sudoers file.
    Make sue sudo is installed and put in /etc/sudoers.d/vagrant (replace YOUR_USERNAME):
    
      cat > /etc/sudoers.d/vagrant<<EOF
      # Host alias specification

      # User alias specification
      User_Alias VAGRANTERS = YOUR_USERNAME

      # Cmnd alias specification
      Cmnd_Alias VAGRANTSH = /usr/bin/chown 0\:0 /tmp/*, /usr/bin/mv -f /tmp/* /etc/exports, /usr/bin/systemctl start nfs-server.service, /usr/bin/systemctl stop nfs-server.service, /usr/bin/systemctl start libvirtd.service, /usr/bin/systemctl stop libvirtd.service, /usr/sbin/exportfs -ar, /usr/sbin/sysctl -w fs.inotify.max_user_watches=*

      VAGRANTERS ALL=(root) NOPASSWD: VAGRANTSH
      EOF

    So, test your sudoer file and the vm set by bringing everything down and up again:
    
      vagrant halt
      vagrant up udb aaa dns log revp uifng uib apif5 # much faster than before eh!?



**WINDOWS**
- Install:
    * git
    * Vagrant    
    * VirtualBox + extension pack (guest additions, download from site and double-click)
    * Python 3.7+
    * PyCharm Community
    * Postman

Admin CLI:

    vagrant plugin install --plugin-clean-sources --plugin-source https://rubygems.org vagrant-env

    cd path\to\Automation
    git clone https://github.com/LumIT-Automation/dev-setup.git
And so for any other node, for example: git clone https://github.com/LumIT-Automation/aaa.git

    cd path\to\Automation\dev-setup
    vagrant up aaa
And so for any aother node, for example: vagrant up apicheckpoint



**OS-INDIPENDENT**

See the etc-host.txt file for development network topology.
See the directory-users.txt file for the configured valid users (development).

First development run:
    Once all nodes are created and running,

 1. browse to https://10.0.111.10/ to load the web GUI (it's located at
    the reverse proxy entry point URL);
            - use the superadmin login, admin@automation.local/password;
            - via the

 2. GUI you can: 
 
	        a) connect the platform to the appliances' assets (save their login information and check that the platform is able to fetch data with the superadmin user), 
	        b) create the RBAC permissions on the assets: grant permissions to the authentication groups (the model is role to group on appliance's asset/"container", where a role is a collection of privileges). This way, you'll be able to login with any other user defined (see directory-users.txt), who will be granted the permissions you set for them. For example use the AD group cn=groupAdmin,cn=users,dc=lab,dc=local (which correspond to the user userAdmin).
 4. All these actions can be of course directly performed via the api-* nodes' API (first get a JWT tokwn from the Single Sign On node).

A Postman collection in saved within any api-* project and within aaa (the Single Sign On, otherwise called sso) in order to directly insist upon each producer node. For postman, save the JWT token in the environment before doing any REST call. JWT validity expires in one day.
Import postman collections and environment from codebases' folders.



**Notes**

The SMTP relay has to be configured via the .env file (see .env-example).
    
Update code-base: only a git pull is needed

Vagrant commands (optional node for commanding a single box):

    vagrant halt node
    vagrant up node
    vagrant ssh node

Update database (only) on an already-created vm: vagrant provision node --provision-with db # for nodes with SQL database.

Destroy everything:

    vagrant destroy -f node

