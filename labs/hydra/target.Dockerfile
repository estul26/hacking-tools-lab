FROM python:3.13-slim

WORKDIR /app
COPY hydra_target.py /app/hydra_target.py

EXPOSE 8080
CMD ["python", "/app/hydra_target.py"]
