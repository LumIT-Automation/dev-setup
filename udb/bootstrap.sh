#!/bin/bash

#set -e

function System()
{
    base=$FUNCNAME
    this=$1

    # Declare methods.
    for method in $(compgen -A function)
    do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done

    # Properties list.
    ACTION="$ACTION"
    PROXY="$PROXY"

    DATABASE_ROOT_PASSWORD="root"
    SYSTEM_USERS_PASSWORD="Password01!"
}

# ##################################################################################################################################################
# Public
# ##################################################################################################################################################

#
# Void System_run().
#
function System_run()
{
    if [ "$ACTION" == "install" ]; then
        if System_checkEnvironment; then
            printf "\n* Installing packages...\n"
            echo "This script requires a fresh-installation of Debian Bullseye ..."

            System_rootPasswordConfig "$SYSTEM_USERS_PASSWORD"
            System_sshConfig
            System_proxySet "$PROXY"
            System_installDependencies
            System_networkManager
            System_ldapInstall
            System_sambaInstall
            System_freeradiusInstall "$DATABASE_ROOT_PASSWORD"
        else
            echo "A Debian Bullseye operating system is required for the installation. Aborting."
            exit 1
        fi
    else
        exit 1
    fi
}

# ##################################################################################################################################################
# Private static
# ##################################################################################################################################################

function System_checkEnvironment()
{
    if [ -f /etc/os-release ]; then
        if ! grep -qi 'bullseye' /etc/os-release; then
            return 1
        fi
    else
        return 1
    fi

    return 0
}


function System_rootPasswordConfig()
{
    printf "\n* Setting a password for root [Vagrant installation]...\n"

    printf "$1\n$1" | passwd
}


function System_sshConfig()
{
    printf "\n* Enabling SSH with password auth [Vagrant installation]...\n"

    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    systemctl restart ssh
}


function System_proxySet()
{
    printf "\n* Setting up system proxy...\n"

    if ! grep -qi "http_proxy" /etc/environment; then
        echo "http_proxy=$1" >> /etc/environment
        echo "https_proxy=$1" >> /etc/environment
    else
        sed -i "s|http_proxy=.*|http_proxy=$1|g" /etc/environment
        sed -i "s|https_proxy=.*|https_proxy=$1|g" /etc/environment
    fi

    export http_proxy=$1
    export https_proxy=$1
}



function System_networkManager()
{
    dns=`grep nameserver /etc/resolv.conf | head -n1 | awk '{print $2}'`
    domainName=`dnsdomainname`
    apt install network-manager -y

    nmcli c add connection.type 802-3-ethernet con-name eth0 ifname eth0
    nmcli c modify eth0 ipv4.dns "127.0.0.1 $dns"
    nmcli c modify eth0 ipv4.dns-search $domainName
    nmcli c modify eth0 ipv4.ignore-auto-dns yes
    
    nmcli c add connection.type 802-3-ethernet con-name eth1 ifname eth1
    nmcli c modify eth1 ipv4.addresses 10.0.111.110/24
    nmcli connection modify eth1 ipv4.method manual
    
    
    nmcli c add connection.type 802-3-ethernet con-name eth2 ifname eth2
    nmcli c modify eth2 ipv4.addresses 10.0.111.111/24
    nmcli connection modify eth2 ipv4.method manual
    
    sed -i -e '/iface lo inet loopback/,/-1/d' /etc/network/interfaces
    sed -i -e '$ a\iface lo inet loopback' /etc/network/interfaces
    systemctl restart networking
    systemctl restart NetworkManager
}



function System_installDependencies()
{
    printf "\n* Preparing the environment: removing the cdrom entry in apt/sources.list, if present...\n"
    printf "\n* Installing system dependencies (if a sources.list file is found within /, it will be used instead of the Vagrant's one)...\n"

    if [ -r /tmp/sources.list ]; then
        cp -f /tmp/sources.list /etc/apt/sources.list
    fi

    apt update

cat > /tmp/grub-pc.selections<<EOF
grub-pc grub2/kfreebsd_cmdline_default string quiet
grub-pc grub-pc/timeout string 1
grub-pc grub2/force_efi_extra_removable boolean false
grub-pc grub-pc/install_devices string /dev/vda
grub-pc grub-pc/disk_description string
grub-pc grub-pc/install_devices_failed_upgrade boolean true
grub-pc grub-pc/postrm_purge_boot_grub boolean false
grub-pc grub2/linux_cmdline string
grub-pc grub2/kfreebsd_cmdline string
grub-pc grub-pc/install_devices_disks_changed boolean
grub-pc grub-pc/chainload_from_menu.lst boolean true
grub-pc grub-pc/install_devices_empty boolean false
grub-pc grub-pc/hidden_timeout boolean false
grub-pc grub2/update_nvram boolean true
grub-pc grub-pc/kopt_extracted boolean false
grub-pc grub-pc/partition_description string
grub-pc grub-pc/mixed_legacy_and_grub2 boolean true
grub-pc grub2/linux_cmdline_default string "console=tty0 console=tty1 console=ttyS0,38400n8"
grub-pc grub-pc/install_devices_failed boolean false
EOF

    debconf-set-selections /tmp/grub-pc.selections
    
    # DEBIAN_FRONTEND=noninteractive apt -y upgrade    

    apt install -y wget git unzip net-tools dos2unix # base.
    apt install -y mariadb-server
    apt install -y php7.4-mysql php7.4-mbstring 
    apt install -y php7.4-gd php7.4-curl php7.4-xml php-mail php-pear; pear install DB
    apt install -y libapache2-mod-php7.4
    apt clean
}


function System_ldapInstall()
{
    printf "\n* Installing OpenLDAP slapd service...\n"

    ipAddrLdap=`ip addr show |grep 'inet 10.0.111' | tail -1 | awk '{print$2}' | sed -r 's#/[0-9]+##g'`

    # Debconf selections for a noninteractive apt installation.
cat >/tmp/slapd.selections<<EOF
slapd slapd/password1 string password
slapd slapd/password2 string password
slapd slapd/internal/generated_adminpw string password
slapd slapd/internal/adminpw string password
slapd slapd/domain string lab.local
slapd shared/organization string ateam
EOF

    debconf-set-selections /tmp/slapd.selections
    DEBIAN_FRONTEND=noninteractive apt install -y slapd ldap-utils

    # Configurations.
    # Enable logging.
    printf "\n* OpenLDAP: enable logging...\n"
    cat >/tmp/slapd.logEnable.ldif<<EOF
dn: cn=config
changeType: modify
replace: olcLogLevel
olcLogLevel: 256
EOF

    ldapmodify -Y external -H ldapi:/// -f /tmp/slapd.logEnable.ldif

    # Groups.
    printf "\n* OpenLDAP: groups...\n"
    cat >/tmp/slapd.groups.ldif<<EOF
dn: ou=monkeys,dc=lab,dc=local
objectClass: organizationalUnit
ou: monkeys

dn: ou=lions,dc=lab,dc=local
objectClass: organizationalUnit
ou: lions

dn: ou=birds,dc=lab,dc=local
objectClass: organizationalUnit
ou: birds
EOF

    ldapadd -x -D cn=admin,dc=lab,dc=local -w password -f /tmp/slapd.groups.ldif

    # Users.
    printf "\n* OpenLDAP: users...\n"
    domain1="lab"
    domain2="local"
    uid=1000
    gid=1000

    for org in "monkeys" "lions" "birds"; do
        cat >/tmp/slapd.user.ldif<<EOF
dn: cn=user-${org},ou=${org},dc=${domain1},dc=${domain2}
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: ${uid}
uid: user-${org}
uidNumber: ${uid}
gidNumber: ${gid}
homeDirectory: /home/user-${org}
loginShell: /bin/bash
gecos: user-${org}
userPassword: {crypt}x
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0
EOF

        let uid='uid+1'
        ldapadd -x -D cn=admin,dc=lab,dc=local -w password -f /tmp/slapd.user.ldif # add user.
        ldappasswd -H ldap://127.0.0.1 -x -D "cn=admin,dc=lab,dc=local" -w password -s password "cn=user-${org},ou=${org},dc=lab,dc=local" # set password.
    done

    newAlias="alias ldap_slapdall='ldapsearch -H ldap://${ipAddrLdap} -D \"cn=admin,dc=lab,dc=local\" -w password -b \"dc=lab,dc=local\" \"(cn=*)\"'"
    echo $newAlias >> /root/.bashrc
    # slapcat
    #

    # Listen only on the openldap interface
    sed -i -e "s/^SLAPD_SERVICES=/##SLAPD_SERVICES=/" -e "/##SLAPD_SERVICES=/a SLAPD_SERVICES=\"ldap://${ipAddrLdap}:389 ldaps://${ipAddrLdap}:636 ldapi:///\"" /etc/default/slapd
}


function System_sambaInstall()
{
    apt update
    #DEBIAN_FRONTEND=noninteractive apt -y upgrade
    apt clean
    
    #apt -y install /home/vagrant/samba_4.13.2-1_amd64.deb
    apt -y install samba winbind
    
    # set the needed variables.
    domainLs=lab
    domainLf=lab.local
    domainUs=`echo $domainLs | tr '[:lower:]' '[:upper:]'`
    domainUf=`echo $domainLf | tr '[:lower:]' '[:upper:]'`
    
    hostNameLs=`hostname -s`
    hostNameLf=${hostNameLs}.${domainLf}
    hostNameUs=`echo $hostNameLs | tr '[:lower:]' '[:upper:]'`
    hostNameUf=`echo $hostNameLf | tr '[:lower:]' '[:upper:]'`
  
    hostNameLsLdap=ldap

    ipAddr=`ip addr show |grep 'inet 10.0.111' | head -n 1 | awk '{print$2}' | sed -r 's#/[0-9]+##g'`
    ipAddrLdap=`ip addr show |grep 'inet 10.0.111' | tail -1 | awk '{print$2}' | sed -r 's#/[0-9]+##g'`

    myIpSubnet=`ip addr show |grep 'inet 10.0.111.110' | awk '{print$2}' | sed -r 's#\.[0-9]+/#\.0/#g'`   # 10.0.111.0/24
    myNet=`echo $myIpSubnet | sed -r 's#/.*##'`   # 10.0.111.0

    myIpLastNum=`echo $ipAddr| awk -F'.' '{print $4}'`
    ldapIpLastN=`echo $ipAddrLdap| awk -F'.' '{print $4}'`
    consulIpLastN='254'
    hostNameLsConsul='consul'

    OLDIFS=$IFS
    IFS='.' read -r -a myNetArray <<< "$myNet"
    IFS=$OLDIFS
    myPtrNet=${myNetArray[2]}.${myNetArray[1]}.${myNetArray[0]}.in-addr.arpa
    
    # set /etc/hosts
    # remove the previous entry.
    sed -i "/${hostNameLs}\s/d" /etc/hosts
    
    # set the new entries
    echo "$ipAddr $hostNameLf $hostNameLs" >> /etc/hosts
    echo "$ipAddrLdap ${hostNameLsLdap}.${domainLf} $hostNameLsLdap" >> /etc/hosts
    
    
    # samba main config file.
    cat > /etc/samba/smb.conf << EOF
    [global]
        netbios name = $hostNameUs
        workgroup = $domainUs
        realm = $domainUf

        interfaces = $ipAddr
        bind interfaces only = yes

        wins support = yes
        server role = active directory domain controller
        server services = -nbt -dns
        allow dns updates = false
        domain master = yes
        local master = yes
        preferred master = yes
        os level = 255
        passdb backend = tdbsam
        pid directory = /var/run/samba
        ldap server require strong auth = no
    
        log level = 3
        ea support = yes
        store dos attributes = Yes
    
        security = user
    
        logon path = \\%L\profiles\%u\%m
        logon drive = G:
        logon home = \\${hostNameLf}\%u\.win_profile\%m
    
        time server = yes
        logon script = logon.bat
    
        add user script = /usr/sbin/useradd -d /dev/null -g 100 -s /bin/false -M %u
    
    [netlogon]
        path = /var/lib/samba/sysvol/${domainLf}/scripts
        read only = No
        writable = no
        browsable = no
    
    [sysvol]
        path = /var/lib/samba/sysvol
        read only = No
EOF
    
    MyAdminPassword=Password01
    userPassword=password
    
    systemctl stop slapd # by default slapd and samba cannot run toghether (same tcp port).
    systemctl unmask samba-ad-dc
    systemctl enable samba-ad-dc
    systemctl stop smbd
    systemctl stop nmbd
    systemctl mask smbd
    systemctl mask nmbd

    # create the ad domain.
    samba-tool domain provision --use-rfc2307 --base-schema=2012_R2 --realm=${domainUf} --dns-backend=BIND9_FLATFILE --domain=${domainUs} --server-role=dc --adminpass=$MyAdminPassword
    
    systemctl start samba-ad-dc

    # Allow simple passwords.
    samba-tool domain passwordsettings pso create pso_pwd_simple 1 --complexity=off --history-length=0 --min-pwd-age=0 --max-pwd-age=0 --min-pwd-length=1
    samba-tool domain passwordsettings pso apply pso_pwd_simple "domain users"
    samba-tool domain passwordsettings pso apply pso_pwd_simple "domain admins"

    # Do not expire Administrator password:
    samba-tool user setexpiry Administrator --noexpiry
    
    # create few domain users:
    samba-tool domain passwordsettings set --min-pwd-age=0
    
    samba-tool user create userRo1 $userPassword
    samba-tool user create userRo2 $userPassword
    samba-tool user create userYN $userPassword
    samba-tool user create userStaff $userPassword
    samba-tool user create powerStaff $userPassword
    samba-tool user create userAdmin $userPassword
    
    samba-tool user setexpiry userRo1 --noexpiry
    samba-tool user setexpiry userRo2 --noexpiry
    samba-tool user setexpiry userYN --noexpiry
    samba-tool user setexpiry userStaff --noexpiry
    samba-tool user setexpiry powerStaff --noexpiry
    samba-tool user setexpiry userAdmin --noexpiry

    # create the needed groups.
    samba-tool group add groupRequired      # This one is required to login.
    samba-tool group add groupNotGranted    # This one is not allowed to login.
    samba-tool group add groupReadOnly
    samba-tool group add groupStaff
    samba-tool group add groupPowerStaff
    samba-tool group add groupAdmin


    samba-tool group addmembers groupRequired userRo1
    samba-tool group addmembers groupRequired userRo2
    samba-tool group addmembers groupRequired userYN
    samba-tool group addmembers groupRequired userStaff
    samba-tool group addmembers groupRequired powerStaff
    samba-tool group addmembers groupRequired userAdmin

    samba-tool group addmembers groupNotGranted  userYN

    samba-tool group addmembers groupReadOnly userRo1
    samba-tool group addmembers groupReadOnly userRo2
    samba-tool group addmembers groupReadOnly userYN

    samba-tool group addmembers groupStaff userStaff
    samba-tool group addmembers groupPowerStaff powerStaff
    samba-tool group addmembers groupAdmin userAdmin

    # Create a grandparent group that contains the users groups.
    samba-tool group add groupGranPa
    samba-tool group addmembers groupGranPa groupAdmin
    samba-tool group addmembers groupGranPa groupPowerStaff
    samba-tool group addmembers groupGranPa groupStaff
    samba-tool group addmembers groupGranPa groupReadOnly

    # create a user that will have a token of a long size.
    samba-tool user create lUser $userPassword
    samba-tool user setexpiry lUser --noexpiry
    samba-tool group add gruppoDalNomeLungoLungo.MaLuuuuuuungoMaLuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuungo.AhPensaviFosseFinito.EInveceNoPercheHaUnNomeLuuuuuuuuuuuuuuuuuuuuuuuuuuuuungggggggggoooooooooooooooooooooooo
    for n in `seq 1 20`; do
        samba-tool group add gruppoDalNomePiuttostoLungoInutileFastidiosoEDannosoNumero${n}
    done
    for n in `seq 1 20`; do
        samba-tool group add gruppoConUnAltroNomeAlquantoEstesoRecanteFastidioEInutilmenteNocivoNumero${n}
    done
    for n in `seq 1 20`; do
        samba-tool group add altroGruppoNonUtileMoltoFastidiosoEDiLunghezzaInconsuetaPerPoterRecareDanno${n}
    done
    samba-tool group addmembers gruppoDalNomeLungoLungo.MaLuuuuuuungoMaLuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuungo.AhPensaviFosseFinito.EInveceNoPercheHaUnNomeLuuuuuuuuuuuuuuuuuuuuuuuuuuuuungggggggggoooooooooooooooooooooooo lUser
    for n in `seq 1 20`; do
        samba-tool group addmembers gruppoDalNomePiuttostoLungoInutileFastidiosoEDannosoNumero${n} lUser
    done
    for n in `seq 1 20`; do
        samba-tool group addmembers gruppoConUnAltroNomeAlquantoEstesoRecanteFastidioEInutilmenteNocivoNumero${n} lUser
    done
    for n in `seq 1 20`; do
        samba-tool group addmembers altroGruppoNonUtileMoltoFastidiosoEDiLunghezzaInconsuetaPerPoterRecareDanno${n} lUser
    done
    samba-tool group addmembers groupGranPa gruppoDalNomePiuttostoLungoInutileFastidiosoEDannosoNumero1


    # Create a user to query the AD ldap server and get the token for the users.
    samba-tool user create adToken $userPassword
    
    # test
    newAlias="alias ldap_smball='ldapsearch -H ldap://${ipAddr} -D \"lab\\Administrator\" -w $MyAdminPassword -b \"dc=lab,dc=local\" \"(cn=*)\"'"
    echo $newAlias >> /root/.bashrc

    newAlias="alias ldap_smbuser='ldapsearch -H ldap://${ipAddr} -D \"lab\\Administrator\" -w $MyAdminPassword -b \"dc=lab,dc=local\" \"(cn=user*)\"'"
    echo $newAlias >> /root/.bashrc
   
    ############################
    # CONFIGURE BIND DNS SERVER
    apt-get -y install bind9 dnsutils
    
    # create a bind log file
    mkdir /var/log/named
    chown bind. /var/log/named
    
    cd /etc/bind/
    echo 'include "/var/lib/samba/bind-dns/named.conf";' >> named.conf.local
    # fix apparmor
    sed -i '/# Samba DLZ/a \  /var/lib/samba/bind-dns/** rwk,' /etc/apparmor.d/usr.sbin.named
    
    cp named.conf.options named.conf.options.orig
    
    echo "acl mynets {
            127.0.0.1;
        $myIpSubnet;
        # puth other allowed subnets here
    };
    
    logging {
            channel simple_log {
                    file \"/var/log/named/bind.log\" versions 3 size 5m;
    
                    # severity warning;
                    severity info;
                # severity debug 10;
                    print-time yes;
                    print-severity yes;
                    print-category yes;
            };
            category default{
                    simple_log;
            };
    };
    
    include \"/etc/bind/rndc.key\";
    
    options {
            directory \"/var/cache/bind\";
            auth-nxdomain no;    # conform to RFC1035
            listen-on-v6 { any; };
            allow-query { mynets; };
            allow-recursion { mynets; };
            allow-update { 127.0.0.1; };
    
            dnssec-enable no;
            dnssec-validation no;
            # dnssec-lookaside auto;
            tkey-gssapi-keytab \"/var/lib/samba/bind-dns/dns.keytab\";
            tkey-domain \"$domainUf\";
    };
    
    " > named.conf.options
    
    # setup DNS zones
    cd /var/lib/samba
    chown bind bind-dns
    chmod 700 bind-dns
    cd bind-dns
    
    
    echo "zone \"${domainLf}\" IN {
            type master;
            file \"/var/lib/samba/bind-dns/dns/${domainLf}.zone\";
            update-policy {
                    deny \"*\" name \"localhost.${domainLf}\";
                    deny \"*\" name \"localhost.localdomain.${domainLfl}\";
                    grant rndc-key zonesub any;
            };
    
            check-names ignore;
    };
    
    zone \"${myPtrNet}\" in {
            type master;
            file \"/var/lib/samba/bind-dns/dns/${myPtrNet}.zone\";
            update-policy {
                    deny localhost name *.${myPtrNet}. PTR;
                    deny localhost.localdomain name *.${myPtrNet}. PTR;
                    grant rndc-key zonesub any;
            };
    };
    " > named.conf
    
    # forward zone was already created from the samba setup. Create PTR zone.
    echo "\$ORIGIN .
\$TTL 604800     ; 1 week
${myPtrNet} IN SOA  ${hostNameLf}. hostmaster.${myPtrNet}. (
                                `date '+%Y%m%d01'` ; serial
                                172800     ; refresh (2 days)
                                14400      ; retry (4 hours)
                                3628800    ; expire (6 weeks)
                                604800     ; minimum (1 week)
                                )
                        NS      ${hostNameLf}.
\$ORIGIN ${myPtrNet}.
$myIpLastNum                    PTR     ${hostNameLf}.
$ldapIpLastN                    PTR     ${hostNameLsLdap}.${domainLf}.
$consulIpLastN                  PTR     ${hostNameLsConsul}.${domainLf}.
" > "dns/${myPtrNet}.zone"

    # add openldap and consul entry in the forward zone
    echo "$hostNameLsLdap        IN A    $ipAddrLdap" >> "dns/${domainLf}.zone"
    echo "$hostNameLsConsul        IN A    10.0.111.254" >> "dns/${domainLf}.zone"
    chown -R bind. *

    # apparmor service seems not installed anymore.
    if systemctl --all --type service --state=loaded | grep -q apparmor.service; then
        systemctl restart apparmor
    fi
    systemctl stop bind9
    systemctl start bind9
    
    # set localhost as primary dns server for this host (via systemd-network and systemd-resolved).
    sed -i -e "/search /d" -e "1 i\search lab.local\nnameserver 127.0.0.1" /etc/resolv.conf
    
    # Modify the network config files to maintain the local dns at the next reboot.
    cd /etc/systemd/network

    # Avoid using the dns server advertised by the dhcp server.
    if ls *network > /dev/null 2>&1; then
        dhcpFiles=`grep -l DHCP= *network`
        for F in $dhcpFiles; do
            sed -r -i '/DHCP=.*/a UseDNS=False' $F
        done

        # Add a dns entry in static network config.
        netFile=`grep -El 'Address=[0-9]' *vagrant*.network | head -n 1`
        sed -i "/Address=/a DNS=127.0.0.1\nDomains=${domainLf}" $netFile
    fi

    cd -

    systemctl daemon-reload

    systemctl stop winbind
    systemctl stop samba-ad-dc

    systemctl start slapd 
    systemctl restart bind9
    systemctl start samba-ad-dc
    cd
}



function System_freeradiusInstall()
{
    printf "\n* Setting up freeradius + daloRADIUS...\n"
    
    # https://draculaservers.com/tutorials/install-freeradius-daloradius-debian-9-mysql/
    # https://computingforgeeks.com/install-freeradius-and-daloradius-on-debian/    

    rootPassword=$1

    apt -y install freeradius freeradius-mysql freeradius-utils
    cp /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-available/sql.orig
    mv /home/vagrant/freeradius-mod-sql /etc/freeradius/3.0/mods-available/sql
    ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled

    chgrp -h freerad /etc/freeradius/3.0/mods-available/sql
    chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled/sql

    mysql -uroot -p$rootPassword -e 'DROP DATABASE IF EXISTS `radius`;'
    mysql -uroot -p$rootPassword -e 'CREATE DATABASE `radius` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
    mysql -uroot -p$rootPassword -e "grant all on radius.* to 'radius'@'127.0.0.1' identified by 'radius';"
    mysql -uroot -p$rootPassword -e "grant all on radius.* to 'radius'@'localhost' identified by 'radius';"
    
    # daloRADIUS
    wget https://github.com/lirantal/daloradius/archive/refs/tags/1.3.tar.gz
    tar xzf 1.3.tar.gz
    mv daloradius-1.3 /var/www/html/daloradius
    chown -R www-data:www-data /var/www/html/daloradius
    chmod -R 644 /var/www/html/daloradius
    chmod -R +X /var/www/html/daloradius

    cp /var/www/html/daloradius/library/daloradius.conf.php.sample /var/www/html/daloradius/library/daloradius.conf.php
    sed -i "s/^\$configValues\['CONFIG_DB_ENGINE'\].*/\$configValues\['CONFIG_DB_ENGINE'\] = 'mysqli';/g" /var/www/html/daloradius/library/daloradius.conf.php
    sed -i "s/^\$configValues\['CONFIG_DB_USER'\].*/\$configValues\['CONFIG_DB_USER'\] = 'radius';/g" /var/www/html/daloradius/library/daloradius.conf.php
    sed -i "s/^\$configValues\['CONFIG_DB_PASS'\].*/\$configValues\['CONFIG_DB_PASS'\] = 'radius';/g" /var/www/html/daloradius/library/daloradius.conf.php
    
    #mysql -uroot -p$1 radius < /var/www/html/daloradius/contrib/db/fr2-mysql-daloradius-and-freeradius.sql # now in radius.sql. 
    #mysql -uroot -p$1 radius < /var/www/html/daloradius/contrib/db/mysql-daloradius.sql # now in radius.sql.
    
    mysql -uroot -p$rootPassword radius < /home/vagrant/radius.sql    
    
    # Clients configuration.
    cat >>/etc/freeradius/3.0/clients.conf<<EOF
    
client automation {
	ipaddr = 10.0.111.0/24
	secret	= bananaJoe
	
	#  Old-style clients do not send a Message-Authenticator
	#  in an Access-Request.  RFC 5080 suggests that all clients
	#  SHOULD include it in an Access-Request.  The configuration
	#  item below allows the server to require it.  If a client
	#  is required to include a Message-Authenticator and it does

	require_message_authenticator = no	
	
	limit {
		max_connections = 16
		lifetime = 60
		idle_timeout = 30
	}	
}    
EOF
    
    systemctl restart freeradius
    systemctl enable freeradius
    
    # Restart at every database change!
    
    # radtest user-tigers password localhost 0 testing123
}



# ##################################################################################################################################################
# Main
# ##################################################################################################################################################

ACTION=""
PROXY=""

# Must be run as root (sudo).
ID=$(id -u)
if [ $ID -ne 0 ]; then
    echo "This script needs super cow powers."
    exit 1
fi

# Parse user input.
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --action)
            ACTION="$2"
            shift
            shift
            ;;

        --proxy)
            PROXY="$2"
            shift
            shift
            ;;

        *)
            shift
            ;;
    esac
done

if [ -z "$ACTION" ]; then
    echo "Missing parameters. Use --action install for installation."
else
    System "system"
    $system_run
fi

exit 0
