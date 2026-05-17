FROM python:3.12-alpine

COPY dirsearch_target.py /opt/lab/dirsearch_target.py

CMD ["python", "/opt/lab/dirsearch_target.py"]
