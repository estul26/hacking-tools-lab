FROM alpine:3.20

RUN apk add --no-cache \
    ca-certificates \
    curl \
    iproute2 \
    iputils \
    jq \
    libpcap-dev \
    masscan \
    nmap \
    nmap-scripts

WORKDIR /work

CMD ["sleep", "infinity"]
