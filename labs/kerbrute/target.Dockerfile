FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        krb5-admin-server \
        krb5-kdc \
        tini \
    && rm -rf /var/lib/apt/lists/*

COPY krb5.conf /etc/krb5.conf
COPY kdc.conf /etc/krb5kdc/kdc.conf
COPY kadm5.acl /etc/krb5kdc/kadm5.acl
COPY start-target.sh /usr/local/bin/start-target.sh

RUN chmod +x /usr/local/bin/start-target.sh

EXPOSE 88/tcp 88/udp

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-target.sh"]
