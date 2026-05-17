FROM python:3.12-alpine

COPY dig_target.py /opt/lab/dig_target.py

CMD ["python", "/opt/lab/dig_target.py"]
