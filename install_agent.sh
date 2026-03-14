#!/bin/bash
# Nexus AI Agent Installer
# Run this on your machine to start contributing

set -e

echo "🤖 Nexus AI Agent Installer"
echo "=============================="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    exit 1
fi

# Check pip
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed."
    exit 1
fi

# Check for GPU
echo "🔍 Detecting hardware..."
HAS_GPU=false
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        HAS_GPU=true
        GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader)
        echo "   ✅ NVIDIA GPU detected: $GPU_INFO"
    fi
fi

if [ "$HAS_GPU" = false ]; then
    echo "   ℹ️  No NVIDIA GPU detected - will run in CPU mode"
fi

# Create virtual environment
echo ""
echo "📦 Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install requests psutil torch transformers

# Get coordinator URL
echo ""
echo "🌐 Configuration"
read -p "   Coordinator URL [http://localhost:8000]: " COORDINATOR_URL
COORDINATOR_URL=${COORDINATOR_URL:-http://localhost:8000}

# Register agent
echo ""
echo "📝 Registering agent..."
python3 << EOF
import requests
import socket
import psutil
import json

# Detect hardware
cpu_count = psutil.cpu_count()
memory_gb = psutil.virtual_memory().total / (1024**3)

# Try to detect GPU
has_gpu = False
gpu_info = {}
try:
    import torch
    has_gpu = torch.cuda.is_available()
    if has_gpu:
        gpu_info = {
            "name": torch.cuda.get_device_name(0),
            "memory_gb": torch.cuda.get_device_properties(0).total_memory / (1024**3)
        }
except:
    pass

# Registration payload
payload = {
    "hostname": socket.gethostname(),
    "cpu_count": cpu_count,
    "memory_gb": round(memory_gb, 2),
    "has_gpu": has_gpu,
    "gpu_info": gpu_info,
    "coordinator_url": "$COORDINATOR_URL"
}

try:
    response = requests.post(f"$COORDINATOR_URL/register", json=payload, timeout=10)
    if response.status_code == 200:
        data = response.json()
        print(f"   ✅ Agent registered successfully!")
        print(f"   🆔 Agent ID: {data.get('agent_id', 'N/A')}")
    else:
        print(f"   ⚠️  Registration failed: {response.status_code}")
        print("   ℹ️  You can still run locally")
except Exception as e:
    print(f"   ⚠️  Could not reach coordinator: {e}")
    print("   ℹ️  Running in standalone mode")
EOF

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "1. Get $NEXUS tokens from the faucet"
echo "2. Run: python agent.py"
echo ""
echo "For help: https://github.com/nexus-ai/agent-hub"
