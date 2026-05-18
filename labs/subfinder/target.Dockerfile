FROM python:3.13-slim

WORKDIR /app
COPY subfinder_target.py /app/subfinder_target.py

EXPOSE 8080
CMD ["python", "/app/subfinder_target.py"]
