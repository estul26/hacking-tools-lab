FROM alpine:3.20

RUN apk add --no-cache \
    ca-certificates \
    curl \
    ffuf \
    jq

WORKDIR /work

CMD ["sleep", "infinity"]
