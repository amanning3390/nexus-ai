# Nexus AI Coordinator Service

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
python main.py

# Or with Docker
docker-compose up -d
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| DATABASE_URL | postgresql://localhost/nexus | PostgreSQL connection |
| REDIS_URL | redis://localhost:6379 | Redis for caching |
| PORT | 8000 | Server port |
| SECRET_KEY | - | JWT secret |

## API Endpoints

### Agents
- `POST /register` - Register new agent
- `POST /heartbeat` - Agent heartbeat
- `GET /agents` - List all agents
- `GET /agents/{id}` - Get agent details

### Tasks
- `POST /task` - Submit new task
- `GET /task/{id}` - Get task status
- `POST /task/{id}/complete` - Complete task

### Rewards
- `GET /rewards/{wallet}` - Get user rewards
- `POST /rewards/claim` - Claim pending rewards

### Health
- `GET /health` - Health check

## WebSocket

Connect to `/ws` for real-time task updates.
