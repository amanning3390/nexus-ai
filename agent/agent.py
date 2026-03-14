#!/usr/bin/env python3
"""
Auto-Detecting Agent
Automatically detects hardware and registers with coordinator
"""

import os
import json
import time
import uuid
import hashlib
import base64
import random
import platform
import subprocess
import requests
import sys

COORDINATOR = os.getenv("COORDINATOR_URL", "http://localhost:8000")

def get_system_info():
    """Auto-detect system capabilities"""
    info = {
        "platform": platform.system(),
        "cpu_count": os.cpu_count(),
        "ram_gb": 0,
        "gpu": None,
        "gpu_count": 0,
    }
    
    # Detect RAM
    try:
        if platform.system() == "Linux":
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if line.startswith('MemTotal:'):
                        kb = int(line.split()[1])
                        info["ram_gb"] = kb // (1024 * 1024)
        elif platform.system() == "Darwin":
            result = subprocess.run(['sysctl', '-n', 'hw.memsize'], capture_output=True, text=True)
            info["ram_gb"] = int(result.stdout.strip()) // (1024**3)
    except:
        info["ram_gb"] = 8  # Default
    
    # Detect GPU
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=name', '--format=csv,noheader'], 
                            capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            gpus = [g.strip() for g in result.stdout.strip().split('\n') if g.strip()]
            info["gpu"] = gpus[0] if gpus else None
            info["gpu_count"] = len(gpus)
    except:
        info["gpu"] = None
        info["gpu_count"] = 0
    
    # Determine agent type
    if info["gpu"]:
        info["agent_type"] = "gpu"
        info["capacity"] = f"gpu={info['gpu_count']},cpu={info['cpu_count']},ram={info['ram_gb']}"
    else:
        info["agent_type"] = "cpu"
        info["capacity"] = f"cpu={info['cpu_count']},ram={info['ram_gb']}"
    
    return info

def generate_keypair():
    secret = str(uuid.uuid4()).encode()
    pubkey = hashlib.sha256(secret).hexdigest()[:16]
    return base64.b64encode(secret).decode(), pubkey

# Load or create keypair
key_file = "/tmp/auto_agent_key.json"
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

print("=" * 50)
print("🤖 AUTO-DETECTING AGENT")
print("=" * 50)

# Detect system
sys_info = get_system_info()
print(f"\n📊 System Detected:")
print(f"   Platform: {sys_info['platform']}")
print(f"   CPU Cores: {sys_info['cpu_count']}")
print(f"   RAM: {sys_info['ram_gb']} GB")
print(f"   GPU: {sys_info['gpu'] or 'None (CPU only)'}")
print(f"   Agent Type: {sys_info['agent_type'].upper()}")
print(f"   Capacity: {sys_info['capacity']}")
print()

# Wait for coordinator
print(f"[*] Connecting to coordinator at {COORDINATOR}...")
for i in range(10):
    try:
        resp = requests.get(f"{COORDINATOR}/", timeout=5)
        print("[+] Coordinator connected!")
        break
    except:
        print(f"[*] Waiting for coordinator... ({i+1}/10)")
        time.sleep(2)
else:
    print("[!] Could not connect to coordinator")
    print(f"   Make sure coordinator is running at {COORDINATOR}")
    sys.exit(1)

# Register
reward_tier = "high" if sys_info["agent_type"] == "gpu" else "low"
print(f"\n[*] Registering as {sys_info['agent_type']} agent...")

resp = requests.post(f"{COORDINATOR}/register", json={
    "id": agent_id,
    "pubkey": pubkey,
    "price_per_hour": 0.05 if sys_info["agent_type"] == "gpu" else 0.01,
    "capacity": sys_info["capacity"],
    "agent_type": sys_info["agent_type"],
    "status": "online"
})
print(f"[+] Registered: {resp.json()}")

print(f"\n💰 Reward Tier: {reward_tier.upper()}")
if sys_info["agent_type"] == "gpu":
    print("   Higher rewards for GPU compute!")
else:
    print("   Standard rewards for CPU compute.")

print("\n" + "=" * 50)
print("🎉 AGENT READY!")
print("=" * 50)
print(f"   Agent ID: {agent_id[:16]}...")
print(f"   Tasks will be assigned automatically")
print("   Press Ctrl+C to stop")
print("=" * 50)

# Main loop
while True:
    try:
        # Heartbeat
        requests.post(f"{COORDINATOR}/heartbeat", json={
            "id": agent_id,
            "capacity": sys_info["capacity"],
            "status": "online"
        }, timeout=5)
        
        # Pull task
        resp = requests.get(f"{COORDINATOR}/tasks/{agent_id}", timeout=5)
        data = resp.json()
        
        if data.get("task"):
            task = data["task"]
            task_id = task["id"]
            payload = task["payload"]
            
            task_type = payload.get("task_type", "inference")
            print(f"\n[*] Got {task_type} task: {task_id[:8]}...")
            
            # Simulate work
            time.sleep(random.uniform(1, 3))
            
            if task_type == "fine_tune":
                result = {
                    "loss": random.uniform(0.3, 1.0),
                    "checkpoint_hash": hashlib.sha256(f"{agent_id}{time.time()}".encode()).hexdigest()[:12],
                    "task_type": "fine_tune"
                }
            else:
                result = {
                    "generated_text": f"Response to: {payload.get('prompt', 'query')[:50]}..."
                }
            
            # Submit result
            sig_input = f"{secret}{task_id}"
            signature = base64.b64encode(sig_input.encode()).decode()
            
            requests.post(f"{COORDINATOR}/result", json={
                "task_id": task_id,
                "agent_id": agent_id,
                "result": result,
                "signature": signature
            })
            print(f"[+] Task completed!")
        else:
            print(".", end="", flush=True)
            
    except Exception as e:
        print(f"\n[!] Error: {e}")
    
    time.sleep(5)
