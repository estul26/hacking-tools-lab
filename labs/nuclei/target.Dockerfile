FROM python:3.13-slim

WORKDIR /app
COPY nuclei_target.py /app/nuclei_target.py

EXPOSE 8080
CMD ["python", "/app/nuclei_target.py"]
