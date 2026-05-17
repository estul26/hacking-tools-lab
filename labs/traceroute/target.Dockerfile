FROM python:3.12-alpine

RUN apk add --no-cache iproute2

COPY target_app.py /opt/lab/target_app.py
COPY target_entrypoint.sh /opt/lab/target_entrypoint.sh

ENTRYPOINT ["/opt/lab/target_entrypoint.sh"]
CMD ["python", "/opt/lab/target_app.py"]
