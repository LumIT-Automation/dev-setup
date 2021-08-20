#!/bin/bash


ssl="n"
ouUsers="CN=Users"
ouGroups="CN=Users"
uPn="n"

HELP="usage: $0
-i [The ldap server ip address/hostname.]
-d [The active directory domain (full domain, not netbios like).]
-u [The user to connect to the ldap server and check the autentication.
        Should be a dedicated user.]
-p [Password for the connect user.]
-o [CN/OU where users are found in the active directory. Default: \"CN=Users\".]
-g [CN/OU where groups are found in the active directory. Default: \"CN=Users\".]
-G [Only users in this AD group can login. Required.]
-P [Allow to login using userPrincipalName as username (user@domain.org).]
-s [With this option the ldap connection is made over ssl.]
        This require the installation of the ca certificate of the active directory in the sso server.]
[-h] this help

Mandatory options: -i -d -u -p -G
"

while getopts "i:d:u:p:o:g:G:Psh" opt
     do
        case $opt in
                i  ) adIp="$OPTARG" ;;
                d  ) fullDomain="$OPTARG" ;;
                u  ) connectUser="$OPTARG" ;;
                p  ) connectUserPwd="$OPTARG" ;;
                o  ) ouUsers="$OPTARG" ;;
                g  ) ouGroup="$OPTARG" ;;
                G  ) requiredGroup="$OPTARG" ;;
                P  ) uPn="y" ;;
                s  ) ssl="y" ;;
                h  ) echo "$HELP"; exit 0 ;;
                *  ) echo "$HELP"; exit 0
              exit 0
        esac
done
shift $(($OPTIND - 1))

if [ -z "$adIp" ] || [ -z "$fullDomain" ] || [ -z "$connectUser" ]  || [ -z "$connectUserPwd" ] || [ -z "$requiredGroup" ]; then
    echo -e "$HELP"
    exit 1
fi

ldapUrl="ldap://${adIp}:389"
if [ "$ssl" == "y" ]; then
    ldapUrl="ldaps://${adIp}:636"
fi

domainDcString=$(
    inputString=$fullDomain
    array=(${inputString//./ })
    printf "DC=%s," "${array[@]}" | sed 's/.$//'
)

if [ -n "$ouUsers" ]; then
    usersSearchString="${ouUsers},${domainDcString}"
else
    echo "Users must be in an OU or CN"
    exit 1
fi

if [ -n "$ouGroups" ]; then
    groupsSearchString="${ouGroups},${domainDcString}"
else
    echo "Groups must be in an OU or CN"
    exit 1
fi

if [ "$uPn" == "y" ]; then
    includeDjangoAuthLdap="from django_auth_ldap.config import LDAPSearch, LDAPGroupQuery, LDAPGroupType, GroupOfNamesType, PosixGroupType, LDAPSearchUnion"
    ldapUserSearch="AUTH_LDAP_USER_SEARCH = LDAPSearchUnion(
    LDAPSearch(\"${usersSearchString}\", ldap.SCOPE_SUBTREE, \"(sAMAccountName=%(user)s)\"),
    LDAPSearch(\"${usersSearchString}\", ldap.SCOPE_SUBTREE, \"userPrincipalName=%(user)s\")
)"
else
    includeDjangoAuthLdap="from django_auth_ldap.config import LDAPSearch, LDAPGroupQuery, LDAPGroupType, GroupOfNamesType, PosixGroupType"
    ldapUserSearch="AUTH_LDAP_USER_SEARCH = LDAPSearch(\"${usersSearchString}\", ldap.SCOPE_SUBTREE, \"(sAMAccountName=%(user)s)\")"
fi

# Generate AD identity provider file.
echo "import ldap
$includeDjangoAuthLdap


# URI.
AUTH_LDAP_SERVER_URI = \"$ldapUrl\"

# SETTINGS.

AUTH_LDAP_BIND_DN = \"CN=${connectUser},${usersSearchString}\"
AUTH_LDAP_BIND_PASSWORD = \"${connectUserPwd}\"

AUTH_LDAP_BIND_AS_AUTHENTICATING_USER = True

$ldapUserSearch

AUTH_LDAP_GROUP_SEARCH = LDAPSearch(
    \"$groupsSearchString\",
    ldap.SCOPE_SUBTREE,
    \"(objectClass=group)\",
)

AUTH_LDAP_GROUP_TYPE = GroupOfNamesType(name_attr=\"ou\")
AUTH_LDAP_REQUIRE_GROUP = \"CN=${requiredGroup},${groupsSearchString}\"
AUTH_LDAP_USER_QUERY_FIELD = \"username\"
AUTH_LDAP_USER_ATTR_MAP = {
    \"username\": \"userPrincipalName\",
    \"first_name\": \"givenName\",
    \"last_name\": \"\",
    \"email\": \"mail\",
    # extend using django_auth_ldap.backend.populate_user signal's listener: see sso/__init__'s customUserPopulate().
}

AUTH_LDAP_ALWAYS_UPDATE_USER = True
AUTH_LDAP_NO_NEW_USERS = False
AUTH_LDAP_FIND_GROUP_PERMS = True
AUTH_LDAP_CACHE_TIMEOUT = 1
"

