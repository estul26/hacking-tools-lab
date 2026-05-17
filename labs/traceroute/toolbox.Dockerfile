FROM alpine:3.20

RUN apk add --no-cache \
    ca-certificates \
    curl \
    iproute2 \
    iputils \
    tcpdump \
    traceroute

COPY toolbox_entrypoint.sh /opt/lab/toolbox_entrypoint.sh

WORKDIR /work

ENTRYPOINT ["/opt/lab/toolbox_entrypoint.sh"]
CMD ["sleep", "infinity"]
