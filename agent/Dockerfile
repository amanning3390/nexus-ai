FROM python:3.11-slim

WORKDIR /app
COPY agent.py .

# Install dependencies
RUN pip install --no-cache-dir requests

ENV COORDINATOR_URL=http://coordinator:8000

CMD ["python", "agent.py"]
