FROM golang:1.25.7-bookworm AS builder

ARG SUBFINDER_VERSION=v2.14.0

RUN go install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@${SUBFINDER_VERSION}"

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/subfinder /usr/local/bin/subfinder

WORKDIR /work

CMD ["sleep", "infinity"]
