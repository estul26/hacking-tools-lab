FROM python:3.12-alpine

COPY masscan_target.py /opt/lab/masscan_target.py

CMD ["python", "/opt/lab/masscan_target.py"]
