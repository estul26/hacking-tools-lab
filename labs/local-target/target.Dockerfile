FROM python:3.12-alpine

COPY target_app.py /opt/lab/target_app.py

CMD ["python", "/opt/lab/target_app.py"]
