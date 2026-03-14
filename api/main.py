#!/usr/bin/env python3
"""
Nexus AI Payment API with x402 Support
Handles payments for LLM responses
"""

from flask import Flask, request, jsonify
import os
import time
import hashlib

app = Flask(__name__)

# Configuration
USDC_DECIMALS = 6  # USDC has 6 decimals
PAYMENT_ADDRESS = os.getenv("PAYMENT_ADDRESS", "0x289383F655940B800E82749863DC4bE925CbddD4")
NETWORK = os.getenv("NETWORK", "base-sepolia")  # base or base-sepolia

# Price tiers (in USDC, with 6 decimals)
PRICES = {
    "free": 0,
    "basic": 1_000,  # $0.001
    "priority": 5_000,  # $0.005
}

# In-memory storage (use Redis/DB in production)
payments = {}
chat_history = {}

# x402 Payment Required response
def payment_required(resource, payment_details):
    """Return 402 Payment Required with x402 headers"""
    return jsonify({
        "error": "Payment Required",
        "payment": {
            "resource": resource,
            "network": NETWORK,
            "scheme": "exact",
            "accepts": [
                f"{NETWORK}:USDC",
                f"{NETWORK}:0x4ED4eC4bD0767E7C7d198Ad8772243C5A9B941"
            ],
            "price": payment_details["price"],
            "description": payment_details["description"],
            "deadline": int(time.time()) + 300  # 5 min deadline
        }
    }), 402, {"X-Payment-Required": "true"}

# Health check
@app.route("/health")
def health():
    return jsonify({"status": "ok", "network": NETWORK})

# Get payment requirements for a resource
@app.route("/.well-known/x402")
def x402_wellknown():
    """Return accepted payment methods"""
    return jsonify({
        "/api/chat": {
            "price": PRICES["basic"],
            "network": NETWORK,
            "scheme": "exact",
            "description": "Chat with Nexus AI",
            "accepts": [f"{NETWORK}:USDC"]
        }
    })

# Chat endpoint (x402 protected)
@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.get_json() or {}
    message = data.get("message", "")
    user_address = data.get("address", "")
    
    # Check for x402 payment header
    payment_header = request.headers.get("X-Payment")
    
    # Free tier (no payment)
    if not payment_header and not user_address:
        return process_chat(message, tier="free")
    
    # Verify payment
    if payment_header:
        verified = verify_payment(payment_header, user_address)
        if not verified:
            return payment_required("/api/chat", {
                "price": PRICES["basic"],
                "description": "Chat with Nexus AI"
            })
        tier = "paid"
    else:
        # Check staking for discount
        tier = check_staking(user_address) if user_address else "free"
    
    # Process chat
    response = process_chat(message, tier)
    
    # Record payment for analytics
    if tier == "paid":
        record_payment(user_address, PRICES["basic"])
    
    return response

def verify_payment(payment_header, user_address):
    """Verify x402 payment"""
    # In production, verify the payment signature and transaction
    # For now, accept test payments
    if NETWORK == "base-sepolia":
        return True  # Skip verification on testnet
    return False

def check_staking(user_address):
    """Check if user has staked for discount"""
    # In production, query the staking contract
    return "basic"  # Default tier

def process_chat(message, tier):
    """Process chat message and return response"""
    # In production, call the LLM via coordinator
    response_text = generate_response(message)
    
    return jsonify({
        "reply": response_text,
        "tier": tier,
        "price": "free" if tier == "free" else "paid",
        "message_id": hashlib.sha256(f"{message}{time.time()}".encode()).hexdigest()[:16]
    })

def generate_response(prompt):
    """Generate AI response - connect to coordinator in production"""
    # Simple responses for demo
    prompt_lower = prompt.lower()
    
    if "hello" in prompt_lower or "hi" in prompt_lower:
        return "Hello! I'm Nexus AI. How can I help you today?"
    
    if "who are you" in prompt_lower:
        return "I'm Nexus AI, a community-owned AI assistant. I run on decentralized compute and learn from conversations."
    
    if "decentralized" in prompt_lower or "how do you work" in prompt_lower:
        return "I run on a network of computers provided by community contributors. They earn $NEXUS tokens for their compute, and you get an AI assistant that's owned by the community."
    
    if "token" in prompt_lower or "nexus" in prompt_lower:
        return "$NEXUS is the token that powers this network. Contributors earn it by providing compute. Stakers get reduced fees and governance rights."
    
    if "price" in prompt_lower or "cost" in prompt_lower:
        return "This demo is free! In production, basic chat costs $0.001 per message, paid in USDC. Stakers get 50% discount."
    
    return f"I understand: '{prompt}'. This is a demo response. In production, I'd connect to the full agent network for intelligent responses."

def record_payment(user_address, amount):
    """Record payment for analytics"""
    if user_address not in payments:
        payments[user_address] = []
    payments[user_address].append({
        "amount": amount,
        "time": int(time.time())
    })

# Staking endpoint
@app.route("/api/stake", methods=["POST"])
def stake():
    data = request.get_json() or {}
    address = data.get("address", "")
    amount = data.get("amount", 0)
    
    # In production, call the staking contract
    return jsonify({
        "status": "success",
        "address": address,
        "amount": amount,
        "tx": "0x" + hashlib.sha256(f"{address}{amount}{time.time()}".encode()).hexdigest()[:64]
    })

# Get user stats
@app.route("/api/user/<address>")
def get_user(address):
    user_payments = payments.get(address, [])
    total_paid = sum(p["amount"] for p in user_payments)
    
    return jsonify({
        "address": address,
        "total_messages": len(user_payments),
        "total_paid_usdc": total_paid / (10**USDC_DECIMALS),
        "tier": "free"
    })

# Root
@app.route("/")
def root():
    return jsonify({
        "name": "Nexus AI API",
        "version": "1.0.0",
        "endpoints": {
            "chat": "/api/chat",
            "stake": "/api/stake",
            "user": "/api/user/{address}",
            "health": "/health",
            "x402": "/.well-known/x402"
        },
        "network": NETWORK
    })

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
