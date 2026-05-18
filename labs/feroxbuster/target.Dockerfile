FROM python:3.12-alpine

COPY feroxbuster_target.py /opt/lab/feroxbuster_target.py

CMD ["python", "/opt/lab/feroxbuster_target.py"]
