FROM kalilinux/kali-rolling

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && echo "macchanger macchanger/automatically_run boolean false" | debconf-set-selections \
    && apt-get install -y --no-install-recommends \
        iproute2 \
        jq \
        macchanger \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["sleep", "infinity"]
