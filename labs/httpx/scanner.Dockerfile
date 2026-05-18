FROM golang:1.25.7-bookworm AS builder

ARG HTTPX_VERSION=v1.9.0

RUN go install "github.com/projectdiscovery/httpx/cmd/httpx@${HTTPX_VERSION}"

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/httpx /usr/local/bin/httpx

WORKDIR /work

CMD ["sleep", "infinity"]
