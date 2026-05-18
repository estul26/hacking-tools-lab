FROM python:3.13-slim

WORKDIR /app
COPY gau_target.py /app/gau_target.py

EXPOSE 8080
CMD ["python", "/app/gau_target.py"]
