FROM python:3.13-slim

WORKDIR /app
COPY httpx_target.py /app/httpx_target.py

EXPOSE 8080
CMD ["python", "/app/httpx_target.py"]
