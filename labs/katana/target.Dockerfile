FROM python:3.13-slim

WORKDIR /app
COPY katana_target.py /app/katana_target.py

EXPOSE 8080
CMD ["python", "/app/katana_target.py"]
