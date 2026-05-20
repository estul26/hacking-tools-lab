FROM kalilinux/kali-rolling

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bloodhound.py \
        ca-certificates \
        curl \
        jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["sleep", "infinity"]
