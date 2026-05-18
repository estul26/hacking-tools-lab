FROM debian:trixie-slim

ARG NIKTO_REF=2.6.0
ARG NIKTO_COMMIT=69681e2e4213c15b85a90c53b2169ecb2a88fb01

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        libjson-perl \
        libnet-ssleay-perl \
        libwww-perl \
        libxml-writer-perl \
        perl \
    && git -c advice.detachedHead=false clone --depth 1 --branch "$NIKTO_REF" https://github.com/sullo/nikto.git /opt/nikto \
    && cd /opt/nikto \
    && test "$(git rev-parse HEAD)" = "$NIKTO_COMMIT" \
    && rm -rf /opt/nikto/.git /var/lib/apt/lists/* \
    && printf '%s\n' '#!/usr/bin/env sh' 'exec perl /opt/nikto/program/nikto.pl "$@"' > /usr/local/bin/nikto \
    && chmod +x /usr/local/bin/nikto

WORKDIR /work

CMD ["sleep", "infinity"]
