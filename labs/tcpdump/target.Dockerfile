FROM python:3.12-alpine

COPY tcpdump_target.py /opt/lab/tcpdump_target.py

CMD ["python", "/opt/lab/tcpdump_target.py"]
