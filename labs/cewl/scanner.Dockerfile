FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cewl \
        curl \
        jq \
        python3-minimal \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["sleep", "infinity"]
