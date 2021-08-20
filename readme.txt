Development infrastructure installation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A Vagrant virtual machine is set up and run for each node (a subnet where all nodes are placed is also pulled up by Vagrant).
An Active Directory/Radius node is created for the user authentication as well.

Requirements:
    - Linux host as development machine (tested on modern Debian and Ubuntu OS; any other should work)
    - VirtualBox
    - Vagrant
        Plugins (user-installed):
        vagrant plugin install vagrant-reload
        vagrant plugin install vagrant-env
        vagrant plugin install vagrant-fsnotify
        vagrant plugin install vagrant-disksize

    cd /path/to/projectHome
	git clone all projects

	projectHome
	 |-- dev-setup
	 |-- api-*
	 |-- ui-backend
	 \-- ...



Development infrastructure:
    cd dev-setup
    # vagrant up
    # actually test nodes's creation can be skipped now. A minimal machine set can be run by (for example with F5 support only):
    vagrant up udb aaa dns log revp uifng uib api-f5
        --> guests will mount the nfs share host-side, where related code is saved (all is automated by Vagrant)

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

    See the etc-host.txt file for development network topology.

    See the directory-users.txt file for the configured valid users (development).

    The uif node will be deprecated in the near future: ignore it :)
    The api-cisconx node is making use o AWX for its functioning; again, this will be deprecated soon.

    A .env file can be setup basing on the .env-example in order to VPN connect to the appliance (for example F5); this is used by the core development team.
    You can make use of it, if needed, of course in case modify to suit your needs.



First development run:
    Once all nodes are created and up (with no previous presets),
        - browse to http://10.0.111.10/ to load the web GUI (it's located at the reverse proxy entry point);
        - use the superadmin login, admin@automation.local/password;
        - via the GUI you can connect the platform to the appliances' assets and create the RBAC permissions on the assets
          --> RBAC: grant permissions to the authentication groups (the model is role to group on appliance's asset/"container", where a role is a collection of privileges).
          --> all these actions can be of course directly performed via the api-* nodes' API.

    A Postman collection in saved within any api-* project in order to directly insist upon each producer node.



Notes:
    Update code-base: only a git pull is needed

    Vagrant commands (optional <node> for commanding a single box):
        vagrant halt <node>
        vagrant up <node>
        vagrant ssh <node>

    Destroy everything:
        vagrant destroy -f <node>