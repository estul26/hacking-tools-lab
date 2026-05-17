FROM alpine:3.20

RUN apk add --no-cache \
    bind-tools

WORKDIR /work

CMD ["sleep", "infinity"]
