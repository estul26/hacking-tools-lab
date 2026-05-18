FROM golang:1.25.7-bookworm AS builder

ARG AMASS_VERSION=v4.2.0

RUN go install "github.com/owasp-amass/amass/v4/cmd/amass@${AMASS_VERSION}"

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/bin/amass /usr/local/bin/amass

WORKDIR /work

CMD ["sleep", "infinity"]
