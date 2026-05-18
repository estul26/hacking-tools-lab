FROM python:3.12-alpine

COPY sqlmap_target.py /opt/lab/sqlmap_target.py

CMD ["python", "/opt/lab/sqlmap_target.py"]
