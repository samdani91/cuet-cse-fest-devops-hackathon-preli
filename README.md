# Hackathon Challenge

Your challenge is to take this simple e-commerce backend and turn it into a fully containerized microservices setup using Docker and solid DevOps practices.

## Problem Statement

The backend setup consisting of:

- A service for managing products
- A gateway that forwards API requests

The system must be containerized, secure, optimized, and maintain data persistence across container restarts.

## Architecture

```
                    ┌─────────────────┐
                    │   Client/User   │
                    └────────┬────────┘
                             │
                             │ HTTP (port 5921)
                             │
                    ┌────────▼────────┐
                    │    Gateway      │
                    │  (port 5921)    │å
                    │   [Exposed]     │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
         ┌──────────▼──────────┐      │
         │   Private Network   │      │
         │  (Docker Network)   │      │
         └──────────┬──────────┘      │
                    │                 │
         ┌──────────┴──────────┐      │
         │                     │      │
    ┌────▼────┐         ┌──────▼──────┐
    │ Backend │         │   MongoDB   │
    │(port    │◄────────┤  (port      │
    │ 3847)   │         │  27017)     │
    │[Not     │         │ [Not        │
    │Exposed] │         │ Exposed]    │
    └─────────┘         └─────────────┘
```

**Key Points:**
- Gateway is the only service exposed to external clients (port 5921)
## CUET CSE Fest — DevOps Hackathon (repository)

This repository contains a small e-commerce backend and a gateway. The goal of this README is to give clear, practical instructions to run the project in development and production (via Docker), explain why commands are used, and provide quick tests to run locally.

## What's in this repo

- `backend/` — TypeScript backend service (ports: 3847, not exposed directly in Docker compose)
- `gateway/` — Simple gateway that forwards requests to backend (ports: 5921, exposed)
- `docker/` — `compose.development.yaml` and `compose.production.yaml`
- `Makefile` — convenience wrapper around docker compose and common tasks

Why this setup: the gateway is the only externally exposed service. Backend and MongoDB run on a private Docker network to limit direct exposure.

## Prerequisites

- Docker Engine and Docker Compose (Docker Compose V2 CLI: `docker compose`) installed
- Node.js (only required if you want to run services locally without Docker)
- A `.env` file in the repo root (see sample below)

Why: Docker provides an isolated environment and reproducible builds; the Makefile simplifies common workflows.

## Quick `.env` (sample)

Create a `.env` file at the repository root with at least:

MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=changeme
MONGO_URI=mongodb://dev-mongo:27017
MONGO_DATABASE=devdb
BACKEND_PORT=3847
GATEWAY_PORT=5921
NODE_ENV=development

Do NOT commit credentials to source control.

## Run (Development)

The repo includes a Makefile with convenient targets. The recommended dev flow is:

- Start development environment (uses `docker/compose.development.yaml`):

  make dev-up

  Why: this brings up the database, backend, and gateway in dev mode. The Makefile sets appropriate compose file and environment file.

- Stop development environment:

  make dev-down

- See logs for a particular service (example: gateway):

  make dev-logs SERVICE=gateway


Direct docker-compose equivalent:

  docker compose -f docker/compose.development.yaml --env-file .env up -d --build

## Run (Production)

Build and start production services (uses `docker/compose.production.yaml`):

  make prod-build
  make prod-up

Or directly:

  docker compose -f docker/compose.production.yaml --env-file .env up -d --build

Why: production compose is intended to use optimized Dockerfiles (no bind-mounts), different volumes and networking suited for a real deployment.


## Health checks & quick API tests

After bringing the stack up (dev or prod), verify the services with simple curl checks:

- Gateway health (gateway should be reachable on host port configured in `.env` — default 5921):

  curl http://localhost:5921/health

- Backend health via gateway:

  curl http://localhost:5921/api/health

- Create a product (example):

  curl -X POST http://localhost:5921/api/products \
    -H 'Content-Type: application/json' \
    -d '{"name":"Test Product","price":99.99}'

- List products:

  curl http://localhost:5921/api/products

- Security check (backend should not be exposed directly — this should fail when using provided compose):

  curl http://localhost:3847/api/products

Why: these commands validate that the gateway is handling external traffic and the backend is only accessible through internal networking.

## Useful Makefile targets (summary)

- `make dev-up` / `make prod-up` — start environment
- `make dev-down` / `make prod-down` — stop environment
- `make dev-build` / `make prod-build` — build images
- `make dev-logs SERVICE=backend` — follow logs
- `make backend-shell` / `make gateway-shell` — open a shell in a container
- `make db-backup` / `make db-reset` — DB maintenance (dangerous operations prompt you)

Use `make help` to list all targets and short descriptions.

## Test scripts in repo

- `test-api.sh` — a small script included to run a series of curl checks against the gateway. Use after starting the stack to do a quick verification.
- `validate-setup.sh` — convenience script to check for required tools and environment variables on your machine before running the stack.

Run them like:

  ./validate-setup.sh
  ./test-api.sh

Why: automated quick-tests save time when you want to confirm the stack is responding correctly.

## Data persistence notes

- The compose files mount volumes for MongoDB to preserve data across restarts. 