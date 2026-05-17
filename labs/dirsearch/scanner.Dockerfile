FROM python:3.12-slim

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --disable-pip-version-check --root-user-action=ignore \
    "setuptools<81" \
    dirsearch

ENV PYTHONWARNINGS=ignore::UserWarning

WORKDIR /work

RUN mkdir -p reports

CMD ["sleep", "infinity"]
