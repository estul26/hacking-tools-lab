FROM golang:1.25.7-bookworm AS builder

ARG NUCLEI_VERSION=v3.8.0

RUN go install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@${NUCLEI_VERSION}"

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/nuclei /usr/local/bin/nuclei

WORKDIR /work

CMD ["sleep", "infinity"]
