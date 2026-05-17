FROM python:3.12-alpine

COPY lab_target.py /opt/lab/lab_target.py

CMD ["python", "/opt/lab/lab_target.py"]
