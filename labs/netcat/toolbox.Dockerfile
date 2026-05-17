FROM alpine:3.20

RUN apk add --no-cache \
    bind-tools \
    curl \
    iproute2 \
    iputils \
    netcat-openbsd \
    tcpdump

WORKDIR /work

CMD ["sleep", "infinity"]
