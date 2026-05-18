FROM golang:1.25.7-bookworm AS builder

ARG GAU_VERSION=v2.2.4

RUN go install "github.com/lc/gau/v2/cmd/gau@${GAU_VERSION}"

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        python3-minimal \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/gau /usr/local/bin/gau

WORKDIR /work

CMD ["sleep", "infinity"]
