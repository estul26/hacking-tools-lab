FROM rustscan/rustscan:latest

USER root

RUN apk add --no-cache \
    curl \
    iproute2 \
    iputils \
    jq

WORKDIR /work

ENTRYPOINT []
CMD ["sleep", "infinity"]
