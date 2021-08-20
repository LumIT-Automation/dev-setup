# How to setup the ssl connection between django and an active directory server for the authentication.


- On the Active Directory server console run the command "certsrv.msc"

- In the certsrv program interface select the CA for the domain -> dx mousekey -> Properties

- In the Properties select the certificate and click on "View Certificate"

- Select the Details tab and click on the button "Copy to File"

- Export the certificate in a file in Base-64 encoded X.509 format

- Open the exported certificate with notepad. Select all and copy to the clipboard

- In the sso server as root create a new .crt file in the /usr/local/share/ca-certificate folder and paste inside the certificate data.

- dos2unix the crt file

- update-ca-certificates

- systemctl restart apache2

#
# A Guide to configure ssl LDAP ON WINDOWS SERVER 2016:
# https://www.miniorange.com/guide-to-setup-ldaps-on-windows-server
