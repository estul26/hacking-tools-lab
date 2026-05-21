FROM kalilinux/kali-rolling

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        aircrack-ng \
        jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY generate_frames.py /usr/local/bin/generate_frames.py

WORKDIR /work

CMD ["sleep", "infinity"]
