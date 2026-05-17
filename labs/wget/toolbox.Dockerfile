FROM alpine:3.20

RUN apk add --no-cache \
    ca-certificates \
    wget

WORKDIR /work

CMD ["sleep", "infinity"]
