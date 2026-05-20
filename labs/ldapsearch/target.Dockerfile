FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && printf 'slapd slapd/no_configuration boolean false\n' | debconf-set-selections \
    && printf 'slapd slapd/domain string packetlab.local\n' | debconf-set-selections \
    && printf 'slapd shared/organization string Packetlab Local\n' | debconf-set-selections \
    && printf 'slapd slapd/password1 password packetlab-admin\n' | debconf-set-selections \
    && printf 'slapd slapd/password2 password packetlab-admin\n' | debconf-set-selections \
    && printf 'slapd slapd/purge_database boolean true\n' | debconf-set-selections \
    && printf 'slapd slapd/move_old_database boolean true\n' | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ldap-utils \
        slapd \
        tini \
    && rm -rf /var/lib/apt/lists/*

COPY seed/packetlab.ldif /seed/packetlab.ldif
COPY start-target.sh /usr/local/bin/start-target.sh

RUN chmod +x /usr/local/bin/start-target.sh

EXPOSE 389

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-target.sh"]
