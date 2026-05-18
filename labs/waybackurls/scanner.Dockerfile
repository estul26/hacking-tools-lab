FROM golang:1.25.7-bookworm AS builder

ARG WAYBACKURLS_VERSION=v0.1.0

RUN go install "github.com/tomnomnom/waybackurls@${WAYBACKURLS_VERSION}"

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        python3-minimal \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/waybackurls /usr/local/bin/waybackurls

WORKDIR /work

CMD ["sleep", "infinity"]
