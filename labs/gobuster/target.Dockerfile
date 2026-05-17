FROM python:3.12-alpine

COPY gobuster_target.py /opt/lab/gobuster_target.py

CMD ["python", "/opt/lab/gobuster_target.py"]
