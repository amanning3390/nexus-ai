#!/bin/bash
# Nexus AI - Quick Connect Script
# Run this on your computer to join the network
#
# Usage:
#   ./connect.sh                    # Use default localhost
#   ./connect.sh http://your-server:8001  # Connect to remote coordinator

set -e

COORDINATOR_URL=${1:-"http://localhost:8001"}

echo "🤖 Nexus AI Agent Connector"
echo "=============================="
echo ""
echo "📡 Coordinator: $COORDINATOR_URL"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 required"
    echo "   Install: https://python.org/downloads"
    exit 1
fi

# Create temp directory
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

echo "📦 Getting Nexus AI..."
git clone --depth 1 https://github.com/amanning3390/nexus-ai.git .

# Install dependencies
echo "📦 Installing dependencies..."
pip install -q requests psutil 2>/dev/null || pip3 install -q requests psutil

# Set coordinator
export COORDINATOR_URL="$COORDINATOR_URL"

echo ""
echo "🚀 Starting agent..."
echo ""
python3 agent/agent.py
