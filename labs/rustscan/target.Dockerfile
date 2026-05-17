FROM python:3.12-alpine

COPY rustscan_target.py /opt/lab/rustscan_target.py

CMD ["python", "/opt/lab/rustscan_target.py"]
