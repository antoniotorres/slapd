FROM debian:stretch

# explicitly set user/group IDs
RUN groupadd -r openldap --gid=1021 && useradd -r -g openldap --uid=1021 openldap

RUN apt-get update && \
    LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y ldap-utils slapd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /etc/ldap/slapd.d/*

# Default configuration: can be overridden at the docker command line
ENV LDAP_CONFIGPASS=secret \
    LDAP_CONFIGPASS_FILE=/tmp/ldap_configpass \
    LDAP_ROOTPASS=secret \
    LDAP_ROOTPASS_FILE=/tmp/ldap_rootpass \
    LDAP_ORGANISATION=dcm4che.org \
    LDAP_BASE_DN=dc=dcm4che,dc=org \
    LDAP_URLS="ldap:///" \
    LDAP_TLS_CACERT=/etc/certs/cacert.pem \
    LDAP_TLS_CERT=/etc/certs/cert.pem \
    LDAP_TLS_KEY=/etc/certs/key.pem \
    LDAP_TLS_VERIFY=never \
    LDAP_TLS_REQCERT=never \
    LDAP_REPLICATION_HOSTS=

ENV LDAP_REPLICATION_DB_SYNCPROV="binddn=\"cn=admin,$LDAP_BASE_DN\" bindmethod=simple credentials=$LDAP_ROOTPASS searchbase=\"$LDAP_BASE_DN\" type=refreshOnly interval=00:00:00:10 retry=\"5 5 300 +\" timeout=1"

VOLUME [ "/var/lib/ldap", "/etc/ldap/slapd.d" ]

COPY docker-entrypoint.sh /
COPY ldap /etc/ldap
COPY certs /etc/certs
COPY bin /usr/bin

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 389
CMD ["slapd", "-d", "32768", "-u", "openldap", "-g", "openldap"]
