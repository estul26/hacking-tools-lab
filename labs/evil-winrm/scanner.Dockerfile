FROM kalilinux/kali-rolling

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        evil-winrm \
        jq \
        netcat-openbsd \
        util-linux-extra \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["sleep", "infinity"]
