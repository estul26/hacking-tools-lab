FROM python:3.12-alpine

COPY wget_target.py /opt/lab/wget_target.py

CMD ["python", "/opt/lab/wget_target.py"]
