FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        samba \
        tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash labuser \
    && printf 'labuser:labpass!\n' | chpasswd \
    && mkdir -p /run/samba /srv/samba/labshare/docs /srv/samba/dropbox \
    && chown -R labuser:labuser /srv/samba \
    && printf 'Packetlab SMB readme\n' > /srv/samba/labshare/readme.txt \
    && printf 'Quarterly local lab notes\n' > /srv/samba/labshare/docs/notes.txt \
    && printf 'backup-target=ws1.packetlab.local\n' > /srv/samba/labshare/docs/inventory.txt \
    && chown -R labuser:labuser /srv/samba \
    && printf 'labpass!\nlabpass!\n' | smbpasswd -s -a labuser

COPY smb.conf /etc/samba/smb.conf
COPY start-target.sh /usr/local/bin/start-target.sh

RUN chmod +x /usr/local/bin/start-target.sh

EXPOSE 445

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-target.sh"]
