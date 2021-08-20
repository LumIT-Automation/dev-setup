#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <password>"
    exit 1
else
    pwd="$1"
fi

tDir=`mktemp -d`
# Setup the askpass script.
echo "#!/bin/bash

echo \"$pwd\"
" > ${tDir}/pw.sh

chmod 755 ${tDir}/pw.sh

# Run the ssh command.
caCrt=$(DISPLAY=bogus SSH_ASKPASS="${tDir}/pw.sh" setsid ssh -oStrictHostKeyChecking=no -oCheckHostIP=no -oConnectTimeout=3 -oNumberOfPasswordPrompts=1 root@10.0.111.110 "cat /var/lib/samba/private/tls/ca.pem" 2>&1)

# Delete the askpass script.
rm -fr $tDir 

if echo "$caCrt" | grep -q "BEGIN CERTIFICATE"; then
    mkdir -p /usr/local/share/ca-certificates/ad
    echo "$caCrt" > /usr/local/share/ca-certificates/ad/ad.lab.local.crt
    update-ca-certificates
elif echo "$caCrt" | grep -iq "Permission denied"; then
    echo "Wrong password."
    exit 1
else
    echo "No certificate found."
    exit 1
fi

exit 0

