FROM python:3.13-slim

WORKDIR /opt/lab
COPY query_client.py /opt/lab/query_client.py

CMD ["sleep", "infinity"]
