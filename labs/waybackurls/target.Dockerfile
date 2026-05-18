FROM python:3.13-slim

WORKDIR /app
COPY waybackurls_target.py /app/waybackurls_target.py

EXPOSE 8080
CMD ["python", "/app/waybackurls_target.py"]
