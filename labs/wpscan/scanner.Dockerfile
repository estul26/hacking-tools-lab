FROM ruby:3.3-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        jq \
        libcurl4-openssl-dev \
        libxml2-dev \
        libxslt1-dev \
        make \
        pkg-config \
        zlib1g-dev \
    && gem install wpscan -v 3.8.28 --no-document \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["sleep", "infinity"]
