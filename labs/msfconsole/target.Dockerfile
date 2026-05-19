FROM python:3.13-slim

WORKDIR /app
COPY msfconsole_target.py /app/msfconsole_target.py

EXPOSE 8080
CMD ["python", "/app/msfconsole_target.py"]
