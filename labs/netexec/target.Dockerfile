FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        samba \
        tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash labuser \
    && printf 'labuser:labpass!\n' | chpasswd \
    && mkdir -p /run/sshd /srv/samba/labshare \
    && chown -R labuser:labuser /srv/samba/labshare \
    && printf 'local lab share\n' > /srv/samba/labshare/readme.txt \
    && chown labuser:labuser /srv/samba/labshare/readme.txt \
    && printf 'labpass!\nlabpass!\n' | smbpasswd -s -a labuser

COPY smb.conf /etc/samba/smb.conf
COPY start-target.sh /usr/local/bin/start-target.sh

RUN chmod +x /usr/local/bin/start-target.sh

EXPOSE 22 445

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-target.sh"]
