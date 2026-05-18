FROM python:3.13-slim

WORKDIR /app
COPY amass_target.py /app/amass_target.py

EXPOSE 53/udp 53/tcp 8080
CMD ["python", "/app/amass_target.py"]
