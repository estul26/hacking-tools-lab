FROM python:3.13-slim

WORKDIR /app
COPY cewl_target.py /app/cewl_target.py

EXPOSE 8080
CMD ["python", "/app/cewl_target.py"]
