#!/usr/bin/env python3
"""
GPU Inference Agent
Runs Qwen2.5-2B and serves inference requests from the coordinator
"""

import os
import json
import time
import uuid
import hashlib
import base64
import requests
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, pipeline
from flask import Flask, request, jsonify
import threading

COORDINATOR = os.getenv("COORDINATOR_URL", "http://localhost:8000")
AGENT_TYPE = os.getenv("AGENT_TYPE", "gpu")
PORT = int(os.getenv("PORT", "8000"))

app = Flask(__name__)

# Global model and tokenizer
model = None
tokenizer = None
pipe = None

def generate_keypair():
    secret = str(uuid.uuid4()).encode()
    pubkey = hashlib.sha256(secret).hexdigest()[:16]
    return base64.b64encode(secret).decode(), pubkey

# Load or create keypair
key_file = "/tmp/gpu_agent_key.json"
import os
if os.path.exists(key_file):
    with open(key_file) as f:
        data = json.load(f)
        secret = data["secret"]
        pubkey = data["pubkey"]
else:
    secret, pubkey = generate_keypair()
    with open(key_file, "w") as f:
        json.dump({"secret": secret, "pubkey": pubkey}, f)

agent_id = pubkey
print(f"[*] GPU Inference Agent starting with ID: {agent_id}")

def load_model():
    global model, tokenizer, pipe
    print("[*] Loading Qwen2.5-2B model...")
    try:
        MODEL_NAME = "Qwen/Qwen2.5-2B-Instruct"
        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
        model = AutoModelForCausalLM.from_pretrained(
            MODEL_NAME,
            torch_dtype=torch.float16,
            device_map="auto",
            trust_remote_code=True
        )
        pipe = pipeline(
            "text-generation",
            model=model,
            tokenizer=tokenizer,
            max_new_tokens=256,
            temperature=0.7,
        )
        print("[+] Model loaded successfully!")
        return True
    except Exception as e:
        print(f"[!] Failed to load model: {e}")
        return False

# Health check
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy" if model else "loading",
        "model_loaded": model is not None,
        "agent_id": agent_id,
        "agent_type": AGENT_TYPE
    })

# Inference endpoint
@app.route("/infer", methods=["POST"])
def infer():
    if not model:
        return jsonify({"error": "Model not loaded"}), 503
    
    data = request.json
    prompt = data.get("prompt", "")
    max_tokens = data.get("max_tokens", 256)
    temperature = data.get("temperature", 0.7)
    
    try:
        output = pipe(
            prompt,
            max_new_tokens=max_tokens,
            temperature=temperature,
            do_sample=True
        )
        generated_text = output[0]["generated_text"]
        
        return jsonify({
            "text": generated_text,
            "tokens": len(generated_text.split()),
            "agent_id": agent_id
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def register_with_coordinator():
    """Register this agent with the main coordinator"""
    try:
        resp = requests.post(f"{COORDINATOR}/register", json={
            "id": agent_id,
            "pubkey": pubkey,
            "price_per_hour": 0.05,
            "capacity": "gpu=1,cpu=2,ram=8",
            "agent_type": AGENT_TYPE,
            "status": "online"
        })
        print(f"[+] Registered with coordinator: {resp.json()}")
    except Exception as e:
        print(f"[!] Failed to register: {e}")

def heartbeat_loop():
    """Send periodic heartbeats to coordinator"""
    while True:
        try:
            requests.post(f"{COORDINATOR}/heartbeat", json={
                "id": agent_id,
                "capacity": "gpu=1,cpu=2,ram=8",
                "status": "online" if model else "loading"
            }, timeout=5)
        except Exception as e:
            print(f"[!] Heartbeat failed: {e}")
        time.sleep(30)

if __name__ == "__main__":
    # Load model in background
    model_loaded = load_model()
    
    # Start heartbeat thread
    heartbeat_thread = threading.Thread(target=heartbeat_loop, daemon=True)
    heartbeat_thread.start()
    
    # Register
    time.sleep(2)  # Wait for coordinator
    register_with_coordinator()
    
    # Start Flask server
    print(f"[+] Starting inference server on port {PORT}")
    app.run(host="0.0.0.0", port=PORT)
