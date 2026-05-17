FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        tcpdump \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["sleep", "infinity"]
