FROM python:3.12-alpine

COPY ffuf_target.py /opt/lab/ffuf_target.py

CMD ["python", "/opt/lab/ffuf_target.py"]
