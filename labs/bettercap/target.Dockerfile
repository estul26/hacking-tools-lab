FROM python:3.13-slim

COPY target_services.py /opt/lab/target_services.py

WORKDIR /opt/lab

CMD ["python3", "/opt/lab/target_services.py", "web"]
