FROM python:3.12-alpine

COPY whois_target.py /opt/lab/whois_target.py

CMD ["python", "/opt/lab/whois_target.py"]
