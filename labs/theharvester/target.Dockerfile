FROM python:3.13-slim

WORKDIR /app
COPY theharvester_target.py /app/theharvester_target.py

EXPOSE 8080
CMD ["python", "/app/theharvester_target.py"]
