#!/bin/bash

set -e

if [ "$1" = 'slapd' ]; then

	if [ -n "$LDAP_ROOTPASS_FILE" ] && [ -f $LDAP_ROOTPASS_FILE ]; then
		LDAP_ROOTPASS=$(cat $LDAP_ROOTPASS_FILE)
	fi

	if  [ -n "$LDAP_CONFIGPASS_FILE" ] && [ -f $LDAP_CONFIGPASS_FILE ]; then
		LDAP_CONFIGPASS=$(cat $LDAP_CONFIGPASS_FILE)
	fi

	if [ ! -f /etc/ldap/slapd.d/cn\=config.ldif ] || [ ! -f /var/lib/ldap/DB_CONFIG ]; then

		LDAP_DOMAIN=$(sed -e s/^dc=// -e s/,dc=/./g <<< $LDAP_BASE_DN)

		cat <<- EOF | debconf-set-selections
			slapd slapd/internal/generated_adminpw password $LDAP_ROOTPASS
			slapd slapd/internal/adminpw password $LDAP_ROOTPASS
			slapd slapd/password2 password $LDAP_ROOTPASS
			slapd slapd/password1 password $LDAP_ROOTPASS
			slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
			slapd slapd/domain string $LDAP_DOMAIN
			slapd shared/organization string $LDAP_ORGANISATION
			slapd slapd/backend string HDB
			slapd slapd/purge_database boolean true
			slapd slapd/move_old_database boolean true
			slapd slapd/allow_ldap_v2 boolean false
			slapd slapd/no_configuration boolean false
			slapd slapd/dump_database select when needed
			EOF

		dpkg-reconfigure -f noninteractive slapd

		slapd -h ldapi:/// -u openldap -g openldap

		ldapmodify -Y EXTERNAL -H ldapi:/// <<- EOF
			dn: olcDatabase={0}config,cn=config
			add: olcRootPW
			olcRootPW: $(slappasswd -s $LDAP_CONFIGPASS)

			dn: olcDatabase={1}hdb,cn=config
			add: olcAccess
			olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break

			dn: cn=config
			add: olcTLSCACertificateFile
			olcTLSCACertificateFile: $LDAP_TLS_CA_FILE
			-
			add: olcTLSCertificateFile
			olcTLSCertificateFile: $LDAP_TLS_CERT_FILE
			-
			add: olcTLSCertificateKeyFile
			olcTLSCertificateKeyFile: $LDAP_TLS_KEY_FILE
			-
			add: olcTLSVerifyClient
			olcTLSVerifyClient: $LDAP_TLS_VERIFY_CLIENT
			EOF

		if [ -f /etc/ldap/configure.sh ]; then
			. /etc/ldap/configure.sh
		fi

		killall slapd

		sleep 2
	fi

	set -- "$@" -h "ldap://$HOSTNAME/ ldap://127.0.0.1/ ldaps://$HOSTNAME/ ldaps://127.0.0.1/"

	ulimit -n 1024
fi

exec "$@"
