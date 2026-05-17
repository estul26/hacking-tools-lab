FROM python:3.12-alpine

COPY curl_target.py /opt/lab/curl_target.py

CMD ["python", "/opt/lab/curl_target.py"]
