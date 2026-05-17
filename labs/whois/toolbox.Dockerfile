FROM alpine:3.20

RUN apk add --no-cache \
    netcat-openbsd \
    whois

WORKDIR /work

CMD ["sleep", "infinity"]
