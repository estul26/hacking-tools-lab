FROM kalilinux/kali-rolling

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        exploitdb \
        file \
        jq \
    && printf '%s\n' '#!/usr/bin/env sh' 'awk '\''{ for (i = length($0); i > 0; i--) printf "%s", substr($0, i, 1); print "" }'\''' > /usr/local/bin/rev \
    && chmod +x /usr/local/bin/rev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["sleep", "infinity"]
