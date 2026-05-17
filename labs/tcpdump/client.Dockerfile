FROM python:3.12-alpine

COPY traffic_client.py /opt/lab/traffic_client.py

CMD ["sleep", "infinity"]
