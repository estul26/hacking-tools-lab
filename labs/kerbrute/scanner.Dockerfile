FROM golang:1.24-bookworm AS builder

RUN go install github.com/ropnop/kerbrute@v1.0.3

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        jq \
        krb5-user \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/kerbrute /usr/local/bin/kerbrute
COPY krb5.conf /etc/krb5.conf

WORKDIR /work

CMD ["sleep", "infinity"]
