FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        samba \
        tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash labuser \
    && useradd -m -s /bin/bash auditor \
    && groupadd smb-lab-admins \
    && usermod -aG smb-lab-admins labuser \
    && printf 'labuser:labpass!\n' | chpasswd \
    && printf 'auditor:auditpass!\n' | chpasswd \
    && mkdir -p /run/samba /srv/samba/labshare /srv/samba/reports \
    && printf 'enum4linux-ng local lab share\n' > /srv/samba/labshare/readme.txt \
    && printf 'quarter,systems\nQ1,2\n' > /srv/samba/reports/q1.csv \
    && chown -R labuser:smb-lab-admins /srv/samba \
    && chmod -R 0770 /srv/samba \
    && printf 'labpass!\nlabpass!\n' | smbpasswd -s -a labuser \
    && printf 'auditpass!\nauditpass!\n' | smbpasswd -s -a auditor

COPY smb.conf /etc/samba/smb.conf
COPY start-target.sh /usr/local/bin/start-target.sh

RUN chmod +x /usr/local/bin/start-target.sh

EXPOSE 445

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-target.sh"]
