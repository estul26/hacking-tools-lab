FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2 \
        iputils-ping \
        python3 \
        tcpdump \
        tshark \
    && rm -rf /var/lib/apt/lists/*

COPY mini_wireshark.py /opt/lab/mini_wireshark.py

WORKDIR /work

CMD ["sleep", "infinity"]
