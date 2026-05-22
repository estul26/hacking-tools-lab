FROM alpine:3.20

RUN apk add --no-cache \
        file \
        gcc \
        jq \
        musl-dev \
        python3 \
        radare2

COPY generate_fixture.py /usr/local/bin/generate_fixture.py

WORKDIR /work

CMD ["sleep", "infinity"]
