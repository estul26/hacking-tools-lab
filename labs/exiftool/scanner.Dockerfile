FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        file \
        jq \
        libimage-exiftool-perl \
        python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY generate_fixture.py /usr/local/bin/generate_fixture.py

WORKDIR /work

CMD ["sleep", "infinity"]
