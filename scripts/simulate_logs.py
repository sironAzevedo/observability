#!/usr/bin/env python3
"""
Simulador de Logs de Microserviços para Elastic Stack (EFK/ELK)
---------------------------------------------------------------
Uso:
    python simulate_logs.py --mode normal --rate 2 --duration 30
    python simulate_logs.py --mode burst --rate 50 --duration 10
    python simulate_logs.py --mode error-spike --rate 10 --duration 15
"""

import argparse
import json
import random
import sys
import time
from datetime import datetime, timezone

SERVICES = [
    "caderneta-user-services",
    "fatura-service",
    "caderneta-dashboard-services",
    "notification-service",
    "automacao-resgate-fatura",
    "auth-api"
]
USERS = ["usr_101", "usr_202", "usr_303", "usr_404", "usr_505"]
ENDPOINTS = ["/api/v1/checkout", "/api/v1/login", "/api/v1/orders", "/api/v1/faturas", "/api/v1/caderneta", "/api/v1/notifications"]

INFO_MESSAGES = [
    "User authentication successful",
    "Order created successfully",
    "Payment processed",
    "Inventory updated",
    "Notification sent via email",
    "Cache hit for product catalog"
]

WARN_MESSAGES = [
    "High latency detected in DB query",
    "Rate limit threshold reached (80%)",
    "Payment gateway timeout, retrying...",
    "Deprecated API endpoint accessed",
    "Connection pool reaching capacity"
]

ERROR_MESSAGES = [
    "Database connection refused",
    "Payment processing failed: Insufficient funds",
    "Unhandled NullPointerException in OrderController",
    "Failed to reach Inventory service: Connection Timeout",
    "JWT token validation failed: Expired signature"
]

def generate_log(mode: str, service_override: str = None) -> dict:
    if mode == "error-spike":
        level = random.choices(["error", "warn", "fatal"], weights=[0.75, 0.15, 0.10])[0]
    elif mode == "burst":
        level = random.choices(["info", "warn", "error"], weights=[0.85, 0.10, 0.05])[0]
    else:  # normal
        level = random.choices(["info", "warn", "error"], weights=[0.80, 0.15, 0.05])[0]

    service = service_override if service_override else random.choice(SERVICES)
    user_id = random.choice(USERS)
    endpoint = random.choice(ENDPOINTS)
    
    if level in ["error", "fatal"]:
        message = random.choice(ERROR_MESSAGES)
        status_code = random.choice([500, 502, 503, 504])
    elif level == "warn":
        message = random.choice(WARN_MESSAGES)
        status_code = random.choice([400, 429, 408])
    else:
        message = random.choice(INFO_MESSAGES)
        status_code = random.choice([200, 201, 204])

    log_entry = {
        "@timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "service": service,
        "environment": "production",
        "message": message,
        "http": {
            "endpoint": endpoint,
            "status_code": status_code,
            "latency_ms": random.randint(15, 3500)
        },
        "user_id": user_id,
        "trace_id": f"trc_{random.randint(100000, 999999)}"
    }

    if level in ["error", "fatal"]:
        log_entry["exception"] = {
            "type": "SystemException",
            "stacktrace": f"Error at {service}.Controller (line {random.randint(10, 250)}): {message}"
        }

    return log_entry

def main():
    parser = argparse.ArgumentParser(description="Simulador de Logs para Elastic Stack")
    parser.add_argument("--mode", choices=["normal", "burst", "error-spike", "all"], default="normal", help="Modo de simulação")
    parser.add_argument("--service", default="", help="Forçar nome de serviço específico (opcional)")
    parser.add_argument("--rate", type=float, default=2.0, help="Logs por segundo")
    parser.add_argument("--duration", type=int, default=30, help="Duração total em segundos (0 para infinito)")
    
    args = parser.parse_args()
    
    interval = 1.0 / args.rate if args.rate > 0 else 0.5
    start_time = time.time()
    count = 0
    service_override = args.service.strip() if args.service else None

    print(f"--- Iniciando simulação de logs [Modo: {args.mode.upper()} | Rate: {args.rate}/s | Duração: {args.duration}s | Serviço: {service_override or 'Todos'}] ---", file=sys.stderr)

    modes = ["normal", "burst", "error-spike"] if args.mode == "all" else [args.mode]
    phase_duration = (args.duration / len(modes)) if args.duration > 0 else 0

    try:
        while True:
            elapsed = time.time() - start_time
            if args.duration > 0 and elapsed >= args.duration:
                break
            
            if args.mode == "all" and phase_duration > 0:
                current_mode_idx = min(int(elapsed / phase_duration), len(modes) - 1)
                active_mode = modes[current_mode_idx]
            else:
                active_mode = args.mode

            log_data = generate_log(active_mode, service_override=service_override)
            print(json.dumps(log_data), flush=True)
            count += 1
            time.sleep(interval)
    except KeyboardInterrupt:
        pass
    
    print(f"--- Simulação concluída. Total de logs gerados: {count} ---", file=sys.stderr)

if __name__ == "__main__":
    main()
