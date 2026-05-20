FROM python:3.13-slim

WORKDIR /app
COPY target_server.py /app/target_server.py
COPY fixtures /app/fixtures

EXPOSE 8080
CMD ["python", "/app/target_server.py"]
