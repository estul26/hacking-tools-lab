FROM python:3.12-alpine

COPY nikto_target.py /opt/lab/nikto_target.py

CMD ["python", "/opt/lab/nikto_target.py"]
