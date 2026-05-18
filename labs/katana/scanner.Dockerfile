FROM golang:1.25.7-bookworm AS builder

ARG KATANA_VERSION=v1.5.0

RUN CGO_ENABLED=1 go install "github.com/projectdiscovery/katana/cmd/katana@${KATANA_VERSION}"

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        python3-minimal \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/katana /usr/local/bin/katana

WORKDIR /work

CMD ["sleep", "infinity"]
