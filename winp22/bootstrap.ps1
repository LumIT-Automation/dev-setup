# Install and configure CyberArk Vault Synchronizer.
if (!(Test-Path C:\VaultConjurSynchronizer-Rls-v13.5.zip)) {
    Invoke-WebRequest "http://10.0.111.32:8400/VaultConjurSynchronizer-Rls-v13.5.zip" -OutFile "C:\VaultConjurSynchronizer-Rls-v13.5.zip"
}

if (!(Test-Path C:\VaultConjurSynchronizer\Installation\InstallerLauncher.exe)) {
    Expand-Archive C:\VaultConjurSynchronizer-Rls-v13.5.zip -DestinationPath C:\VaultConjurSynchronizer
}

"
######################################################################
### Welcome to the CyberArk Vault Synchronizer Silent installation ###
### Fill in the details as described                               ###
######################################################################

# https://docs.cyberark.com/conjur-enterprise/latest/en/content/conjur/cv_installation_pas11.4plus.htm?tocpath=Setup%7CCyberArk%20Vault%20Synchronizer%7CInstall%20CyberArk%20Vault%20Synchronizer%7C_____1#tabset-1-tab-2

[Main]

# Are you installing the Vault Synchronizer for Conjur Cloud (enter true/false)?
# For Conjur Enterprise: Set to 'false'
# For Conjur Cloud: Set to 'true'
ConjurCloudSelected=false

# For Conjur Enterprise: Set to 'true' if this Vault Synchronizer will be part of a Vault Synchronizer cluster; otherwise set to 'false'
# For Conjur Cloud: Set to 'false'
MultiNodeEnabled=false

# For Conjur Enterprise:
#   If MultiNodeEnabled=true, specify the Vault Synchronizer cluster key. It can't be empty.
#   If MultiNodeEnabled=false, specify the Vault Synchronizer instance name. If left empty will use computer name.
# For Conjur Cloud: Leave empty
ClusterKey=

# Enter the target installation path for the Vault Synchronizer
InstallationTargetPath=C:\Program Files\CyberArk\Synchronizer

# PVWA AND VAULT DETAILS

# Enter an alias for your Vault
VaultName=VaultDemo

# Enter the URL of the PVWA, starting with https:// and excluding the full path
PVWAURL=https://democyberark.demo.local

# Enter the Vault address. If the Vault has multiple addresses, provide a comma-separated list without spaces
VaultAddress=10.32.21.32

# Enter the Vault port (default=1858)
VaultPort=1858

# Enter the name of the Synchronzer Safe for storing accounts used to manage this Vault Synchronizer
SyncSafeName=SafeVaultSynchronizer202506

# CONJUR DETAILS

# For Conjur Enterprise: Enter the Conjur Enterprise hostname and port (port is optional) in the following format: https://hostname[:port]
# For Conjur Cloud: Paste the Conjur Cloud API URL that you copied from the Conjur Cloud UI
ConjurServerDNS=https://apisecops

#ConjurCredentialsFilePath=

# For Conjur Enterprise: Enter the Conjur Entrprise account name
# For Conjur Cloud: Enter 'conjur'
ConjurAccount=dgs-lab

# LOB (LINE-OF-BUSINESS) DETAILS (FOR CONJUR ENTERPRISE WITH PAS >= 11.4 / PRIVILEGE CLOUD ONLY)

# Enter a name for the LOB
LOBName=LOB_Demo202506

# Enter the platform used by the LOB account (default: CyberArk Vault)
LOBPlatform=CyberArk Vault
" | Out-File -FilePath C:\VaultConjurSynchronizer\Installation\silent.ini

# Install all certificates from 10.0.111.32:8400 into RootCerts.
if (!(Test-Path C:\conjur.cer)) {
    Invoke-WebRequest "http://10.0.111.32:8400/conjur.cer" -OutFile "C:\conjur.cer"
    Import-Certificate -FilePath C:\conjur.cer -CertStoreLocation Cert:\LocalMachine\Root
}

if (!(Test-Path C:\cyberark.cer)) {
    Invoke-WebRequest "http://10.0.111.32:8400/cyberark.cer" -OutFile "C:\cyberark.cer"
    Import-Certificate -FilePath C:\cyberark.cer -CertStoreLocation Cert:\LocalMachine\Root
}

# Add "apisecops 10.0.111.32 entry" to the hosts file.
Add-Content -Path $env:windir\System32\drivers\etc\hosts -Value "`n10.0.111.32`tapisecops" -Force

# Install Microsoft Visual C++ x64 and x86 redistributable packages for 2022
if (!(Test-Path C:\VC_redist.x64.exe)) {
    Invoke-WebRequest "http://10.0.111.32:8400/VC_redist.x64.exe" -OutFile "C:\VC_redist.x64.exe"
    Invoke-WebRequest "http://10.0.111.32:8400/VC_redist.x86.exe" -OutFile "C:\VC_redist.x86.exe"
    Start-Process -Wait -FilePath "C:\VC_redist.x64.exe" -ArgumentList "/S" -PassThru
    Start-Process -Wait -FilePath "C:\VC_redist.x86.exe" -ArgumentList "/S" -PassThru
}

# Change SyncSafeName= (above) at every new installation.
# @todo: safes cleanup?

# Install.
# Note: CyberArk and Conjur endpoints must be available when installing.
C:\VaultConjurSynchronizer\Installation\InstallerLauncher.exe trustPVWAAndConjurCert vaultAdminUsername="Administrator" vaultAdminPassword="Ux7ScZ1hs!" conjurUsername="admin" conjurApiKey="CyberArk@123!"

# Set the USE_DISK_SIGNATURE parameter in VaultConjurSynchronizer.exe.config to FALSE. For more information, see VaultConjurSynchronizer.exe.config.
# @todo: not working.
#(Get-Content "C:\Program Files\CyberArk\Synchronizer\VaultConjurSynchronizer.exe.config") -replace '<add key="USE_DISK_SIGNATURE" value=true" />', '<add key="USE_DISK_SIGNATURE" value=false" />' | Out-File -FilePath "C:\Program Files\CyberArk\Synchronizer\VaultConjurSynchronizer.exe.config"

# Run service and set as automatically start upon boot.
Set-Service CyberArkVaultConjurSynchronizer -StartupType Automatic
start-Service CyberArkVaultConjurSynchronizer

# Logs: %SystemRoot%\System32\winevt\Logs -> Event Viewer.