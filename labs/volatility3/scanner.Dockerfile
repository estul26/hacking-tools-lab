FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils \
        jq \
    && python -m venv /opt/volatility3 \
    && /opt/volatility3/bin/pip install --no-cache-dir volatility3 \
    && ln -s /opt/volatility3/bin/vol /usr/local/bin/vol \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY generate_fixture.py /usr/local/bin/generate_fixture.py

WORKDIR /work

CMD ["sleep", "infinity"]
