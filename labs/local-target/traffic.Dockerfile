FROM python:3.12-alpine

COPY traffic_generator.py /opt/lab/traffic_generator.py

CMD ["python", "/opt/lab/traffic_generator.py"]
