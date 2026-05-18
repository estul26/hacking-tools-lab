FROM rust:1.91-slim AS builder

ENV PATH="/usr/local/cargo/bin:${PATH}"

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        perl \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN cargo install feroxbuster --locked --root /opt/ferox

FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/ferox/bin/feroxbuster /usr/local/bin/feroxbuster

WORKDIR /work

CMD ["sleep", "infinity"]
