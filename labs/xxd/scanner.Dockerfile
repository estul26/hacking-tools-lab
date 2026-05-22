FROM debian:trixie-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        file \
        jq \
        python3 \
        xxd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY generate_fixture.py /usr/local/bin/generate_fixture.py

WORKDIR /work

CMD ["sleep", "infinity"]
