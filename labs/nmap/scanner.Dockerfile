FROM alpine:3.20

RUN apk add --no-cache \
    bind-tools \
    curl \
    iproute2 \
    iputils \
    nmap \
    nmap-scripts

WORKDIR /work

CMD ["sleep", "infinity"]
