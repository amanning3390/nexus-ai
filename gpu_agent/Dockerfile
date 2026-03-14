FROM nvidia/cuda:12.1.0-base-ubuntu22.04

WORKDIR /app

# Install Python and dependencies
RUN apt-get update && apt-get install -y python3 python3-pip curl && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cuda121
RUN pip3 install --no-cache-dir transformers accelerate flask

COPY inference_agent.py .
ENV COORDINATOR_URL=http://coordinator:8000
ENV AGENT_TYPE=gpu
ENV PORT=8000

EXPOSE 8000
CMD ["python3", "inference_agent.py"]
