"""
Nexus AI Coordinator API
Routes tasks to agents and manages rewards
"""
from fastapi import FastAPI, HTTPException, Depends, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import Optional, List
import uvicorn
import sqlite3
import json
import time
import uuid
import os

app = FastAPI(
    title="Nexus AI Coordinator",
    description="Community-Owned AGI Task Router",
    version="1.0.0"
)

# Database setup
DB_PATH = os.getenv("DB_PATH", "nexus_coordinator.db")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    # Agents table
    c.execute('''CREATE TABLE IF NOT EXISTS agents (
        id TEXT PRIMARY KEY,
        wallet_address VARCHAR(42),
        cpu_cores INTEGER,
        memory_gb REAL,
        gpu_info TEXT,
        status TEXT DEFAULT 'offline',
        total_tasks INTEGER DEFAULT 0,
        total_rewards REAL DEFAULT 0,
        last_seen INTEGER
    )''')
    
    # Tasks table
    c.execute('''CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        agent_id TEXT,
        task_type VARCHAR(50),
        status VARCHAR(20),
        input_data TEXT,
        output_data TEXT,
        reward REAL DEFAULT 0,
        created_at INTEGER,
        completed_at INTEGER,
        FOREIGN KEY (agent_id) REFERENCES agents(id)
    )''')
    
    # Rewards table
    c.execute('''CREATE TABLE IF NOT EXISTS rewards (
        id TEXT PRIMARY KEY,
        wallet_address VARCHAR(42),
        pending_rewards REAL DEFAULT 0,
        claimed_rewards REAL DEFAULT 0,
        last_claim INTEGER
    )''')
    
    conn.commit()
    return conn

conn = init_db()

# ============== MODELS ==============

class RegisterPayload(BaseModel):
    id: str
    wallet_address: str
    cpu_cores: int
    memory_gb: float
    gpu_info: Optional[dict] = None
    status: str = "online"

class HeartbeatPayload(BaseModel):
    id: str
    status: Optional[str] = "online"

class TaskRequest(BaseModel):
    task_type: str
    input_data: dict
    priority: int = 1

class TaskCompletePayload(BaseModel):
    output_data: dict
    reward: float

# ============== AGENT ENDPOINTS ==============

@app.post("/register")
async def register_agent(payload: RegisterPayload):
    """Register a new agent with the coordinator"""
    c = conn.cursor()
    ts = int(time.time())
    
    gpu_info_json = json.dumps(payload.gpu_info) if payload.gpu_info else None
    
    c.execute('''INSERT OR REPLACE INTO agents 
        (id, wallet_address, cpu_cores, memory_gb, gpu_info, status, last_seen)
        VALUES (?, ?, ?, ?, ?, ?, ?)''',
        (payload.id, payload.wallet_address, payload.cpu_cores, 
         payload.memory_gb, gpu_info_json, payload.status, ts))
    
    conn.commit()
    
    return {
        "status": "registered",
        "agent_id": payload.id,
        "message": "Welcome to Nexus AI! Start earning $NEXUS"
    }

@app.post("/heartbeat")
async def heartbeat(payload: HeartbeatPayload):
    """Agent heartbeat to show liveness"""
    c = conn.cursor()
    ts = int(time.time())
    
    c.execute('UPDATE agents SET last_seen = ?, status = ? WHERE id = ?',
               (ts, payload.status, payload.id))
    conn.commit()
    
    return {"status": "alive", "timestamp": ts}

@app.get("/agents")
async def list_agents(status: Optional[str] = None):
    """List all registered agents"""
    c = conn.cursor()
    
    if status:
        c.execute('SELECT * FROM agents WHERE status = ?', (status,))
    else:
        c.execute('SELECT * FROM agents')
    
    agents = c.fetchall()
    
    return {
        "count": len(agents),
        "agents": [
            {
                "id": a[0],
                "wallet": a[1],
                "cpu_cores": a[2],
                "memory_gb": a[3],
                "gpu_info": json.loads(a[4]) if a[4] else None,
                "status": a[5],
                "total_tasks": a[6],
                "total_rewards": a[7]
            } for a in agents
        ]
    }

@app.get("/agents/{agent_id}")
async def get_agent(agent_id: str):
    """Get agent details"""
    c = conn.cursor()
    c.execute('SELECT * FROM agents WHERE id = ?', (agent_id,))
    a = c.fetchone()
    
    if not a:
        raise HTTPException(status_code=404, detail="Agent not found")
    
    return {
        "id": a[0],
        "wallet": a[1],
        "cpu_cores": a[2],
        "memory_gb": a[3],
        "gpu_info": json.loads(a[4]) if a[4] else None,
        "status": a[5],
        "total_tasks": a[6],
        "total_rewards": a[7],
        "last_seen": a[8]
    }

# ============== AGENT TASK POLLING ==============

@app.get("/tasks/{agent_id}")
async def get_agent_task(agent_id: str):
    """Agent polls for available tasks"""
    c = conn.cursor()
    
    # Check if agent exists
    c.execute('SELECT id, status FROM agents WHERE id = ?', (agent_id,))
    agent = c.fetchone()
    
    if not agent:
        return {"task": None, "message": "Agent not registered"}
    
    # Get pending task assigned to this agent
    c.execute('''SELECT id, task_type, input_data, reward, created_at 
                 FROM tasks 
                 WHERE agent_id = ? AND status = 'pending'
                 ORDER BY created_at ASC LIMIT 1''', (agent_id,))
    task = c.fetchone()
    
    if not agent:
        return {"task": None}
    
    return {
        "task": {
            "id": task[0],
            "task_type": task[1],
            "payload": json.loads(task[2]) if task[2] else {},
            "reward": task[3],
            "created_at": task[4]
        } if task else None
    }

@app.post("/result")
async def submit_result(payload: dict):
    """Agent submits task result"""
    task_id = payload.get("task_id")
    agent_id = payload.get("agent_id")
    result = payload.get("result")
    
    c = conn.cursor()
    ts = int(time.time())
    
    # Update task
    c.execute('''UPDATE tasks 
                 SET status = 'completed', output_data = ?, completed_at = ?
                 WHERE id = ?''',
               (json.dumps(result), ts, task_id))
    
    # Update agent stats
    c.execute('''UPDATE agents 
                 SET total_tasks = total_tasks + 1
                 WHERE id = ?''', (agent_id,))
    
    conn.commit()
    
    return {"status": "completed", "task_id": task_id}

# ============== TASK ENDPOINTS ==============

@app.post("/task")
async def create_task(payload: TaskRequest):
    """Submit a new task"""
    c = conn.cursor()
    ts = int(time.time())
    task_id = str(uuid.uuid4())[:8]
    
    # Find available agent
    c.execute('''SELECT id FROM agents 
                 WHERE status = 'online' 
                 ORDER BY total_tasks ASC LIMIT 1''')
    agent = c.fetchone()
    
    agent_id = agent[0] if agent else None
    
    # Calculate reward based on task type
    reward_rates = {
        "inference": 0.1,
        "training": 1.0,
        "data_processing": 0.05
    }
    reward = reward_rates.get(payload.task_type, 0.1)
    
    c.execute('''INSERT INTO tasks 
        (id, agent_id, task_type, status, input_data, reward, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)''',
        (task_id, agent_id, payload.task_type, "pending", 
         json.dumps(payload.input_data), reward, ts))
    
    conn.commit()
    
    return {
        "task_id": task_id,
        "agent_id": agent_id,
        "reward": reward,
        "status": "pending"
    }

@app.get("/task/{task_id}")
async def get_task(task_id: str):
    """Get task status"""
    c = conn.cursor()
    c.execute('SELECT * FROM tasks WHERE id = ?', (task_id,))
    t = c.fetchone()
    
    if not t:
        raise HTTPException(status_code=404, detail="Task not found")
    
    return {
        "id": t[0],
        "agent_id": t[1],
        "task_type": t[2],
        "status": t[3],
        "input_data": json.loads(t[4]) if t[4] else None,
        "output_data": json.loads(t[5]) if t[5] else None,
        "reward": t[6],
        "created_at": t[7],
        "completed_at": t[8]
    }

@app.post("/task/{task_id}/complete")
async def complete_task(task_id: str, payload: TaskCompletePayload):
    """Mark task as complete and distribute rewards"""
    c = conn.cursor()
    ts = int(time.time())
    
    # Update task
    c.execute('''UPDATE tasks 
                 SET status = 'completed', output_data = ?, completed_at = ?
                 WHERE id = ?''',
               (json.dumps(payload.output_data), ts, task_id))
    
    # Get agent
    c.execute('SELECT agent_id FROM tasks WHERE id = ?', (task_id,))
    result = c.fetchone()
    
    if result and result[0]:
        agent_id = result[0]
        
        # Update agent stats
        c.execute('''UPDATE agents 
                     SET total_tasks = total_tasks + 1,
                         total_rewards = total_rewards + ?
                     WHERE id = ?''',
                  (payload.reward, agent_id))
        
        # Update rewards table
        c.execute('''INSERT OR REPLACE INTO rewards 
                     (wallet_address, pending_rewards, last_claim)
                     SELECT wallet_address, ?, ? FROM agents WHERE id = ?''',
                  (payload.reward, ts, agent_id))
    
    conn.commit()
    
    return {
        "status": "completed",
        "reward": payload.reward
    }

# ============== REWARD ENDPOINTS ==============

@app.get("/rewards/{wallet_address}")
async def get_rewards(wallet_address: str):
    """Get rewards for a wallet"""
    c = conn.cursor()
    c.execute('SELECT * FROM rewards WHERE wallet_address = ?', (wallet_address,))
    r = c.fetchone()
    
    if not r:
        return {
            "wallet": wallet_address,
            "pending": 0,
            "claimed": 0
        }
    
    return {
        "wallet": r[1],
        "pending": r[2],
        "claimed": r[3],
        "last_claim": r[4]
    }

@app.post("/rewards/claim")
async def claim_rewards(wallet_address: str):
    """Claim pending rewards (would interact with blockchain)"""
    c = conn.cursor()
    ts = int(time.time())
    
    c.execute('''UPDATE rewards 
                 SET pending_rewards = 0, 
                     claimed_rewards = claimed_rewards + pending_realties,
                     last_claim = ?
                 WHERE wallet_address = ?''',
              (ts, wallet_address))
    conn.commit()
    
    return {
        "status": "claimed",
        "wallet": wallet_address
    }

# ============== HEALTH ==============

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    c = conn.cursor()
    c.execute('SELECT COUNT(*) FROM agents')
    agent_count = c.fetchone()[0]
    
    c.execute('SELECT COUNT(*) FROM tasks')
    task_count = c.fetchone()[0]
    
    return {
        "status": "healthy",
        "agents": agent_count,
        "tasks": task_count,
        "timestamp": int(time.time())
    }

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "Nexus AI Coordinator",
        "version": "1.0.0",
        "docs": "/docs"
    }

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
