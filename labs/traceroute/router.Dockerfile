FROM alpine:3.20

RUN apk add --no-cache \
    iproute2 \
    iputils \
    tcpdump

COPY router_entrypoint.sh /opt/lab/router_entrypoint.sh

ENTRYPOINT ["/opt/lab/router_entrypoint.sh"]
CMD ["sleep", "infinity"]
