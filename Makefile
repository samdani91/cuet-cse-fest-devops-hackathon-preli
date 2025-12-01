.PHONY: help up down build logs restart shell ps clean clean-all clean-volumes
.PHONY: dev-up dev-down dev-build dev-logs dev-restart dev-shell dev-ps
.PHONY: prod-up prod-down prod-build prod-logs prod-restart prod-shell prod-ps
.PHONY: backend-build backend-install backend-type-check backend-dev backend-shell gateway-shell mongo-shell
.PHONY: db-reset db-backup status health

# Default mode is development
MODE ?= dev
SERVICE ?= backend
ARGS ?=

# Compose file selection
ifeq ($(MODE),prod)
	COMPOSE_FILE = docker/compose.production.yaml
	PROJECT_NAME = prod
	ENV_FILE = $(CURDIR)/.env
else
	COMPOSE_FILE = docker/compose.development.yaml
	PROJECT_NAME = dev
	ENV_FILE = $(CURDIR)/.env
endif

# Docker compose command
DOCKER_COMPOSE = docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) --env-file $(ENV_FILE)

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

##@ Help

help: ## Display this help message
	@echo "$(GREEN)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(GREEN)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Docker Services

up: ## Start services (use: make up [service...] or make up MODE=prod ARGS="--build")
	@echo "$(GREEN)Starting $(MODE) environment...$(NC)"
	$(DOCKER_COMPOSE) up -d $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

down: ## Stop services (use: make down [service...] or make down MODE=prod ARGS="--volumes")
	@echo "$(YELLOW)Stopping $(MODE) environment...$(NC)"
	$(DOCKER_COMPOSE) down $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

build: ## Build containers (use: make build [service...] or make build MODE=prod)
	@echo "$(GREEN)Building $(MODE) containers...$(NC)"
	$(DOCKER_COMPOSE) build $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

logs: ## View logs (use: make logs [service] or make logs SERVICE=backend MODE=prod)
	@echo "$(GREEN)Viewing logs for $(MODE) environment...$(NC)"
	$(DOCKER_COMPOSE) logs -f $(if $(filter-out $@,$(MAKECMDGOALS)),$(filter-out $@,$(MAKECMDGOALS)),$(SERVICE))

restart: ## Restart services (use: make restart [service...] or make restart MODE=prod)
	@echo "$(YELLOW)Restarting $(MODE) services...$(NC)"
	$(DOCKER_COMPOSE) restart $(filter-out $@,$(MAKECMDGOALS))

shell: ## Open shell in container (use: make shell [service] or make shell SERVICE=gateway MODE=prod)
	@echo "$(GREEN)Opening shell in $(if $(filter-out $@,$(MAKECMDGOALS)),$(filter-out $@,$(MAKECMDGOALS)),$(SERVICE))...$(NC)"
	$(DOCKER_COMPOSE) exec $(if $(filter-out $@,$(MAKECMDGOALS)),$(filter-out $@,$(MAKECMDGOALS)),$(SERVICE)) sh

ps: ## Show running containers (use: make ps or make ps MODE=prod)
	@echo "$(GREEN)Running containers in $(MODE) environment:$(NC)"
	$(DOCKER_COMPOSE) ps

##@ Development Aliases

dev-up: ## Start development environment
	@$(MAKE) up MODE=dev

dev-down: ## Stop development environment
	@$(MAKE) down MODE=dev

dev-build: ## Build development containers
	@$(MAKE) build MODE=dev

dev-logs: ## View development logs
	@$(MAKE) logs MODE=dev

dev-restart: ## Restart development services
	@$(MAKE) restart MODE=dev

dev-shell: ## Open shell in backend container (development)
	@$(MAKE) shell SERVICE=backend MODE=dev

dev-ps: ## Show running development containers
	@$(MAKE) ps MODE=dev

##@ Production Aliases

prod-up: ## Start production environment
	@$(MAKE) up MODE=prod

prod-down: ## Stop production environment
	@$(MAKE) down MODE=prod

prod-build: ## Build production containers
	@$(MAKE) build MODE=prod

prod-logs: ## View production logs
	@$(MAKE) logs MODE=prod

prod-restart: ## Restart production services
	@$(MAKE) restart MODE=prod

prod-shell: ## Open shell in backend container (production)
	@$(MAKE) shell SERVICE=backend MODE=prod

prod-ps: ## Show running production containers
	@$(MAKE) ps MODE=prod

##@ Service Shells

backend-shell: ## Open shell in backend container
	@$(MAKE) shell SERVICE=backend

gateway-shell: ## Open shell in gateway container
	@$(MAKE) shell SERVICE=gateway

mongo-shell: ## Open MongoDB shell
	@echo "$(GREEN)Opening MongoDB shell...$(NC)"
	@if [ "$(MODE)" = "prod" ]; then \
		docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec mongo mongosh -u $(MONGO_INITDB_ROOT_USERNAME) -p $(MONGO_INITDB_ROOT_PASSWORD); \
	else \
		docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec mongo mongosh -u $(MONGO_INITDB_ROOT_USERNAME) -p $(MONGO_INITDB_ROOT_PASSWORD); \
	fi

##@ Backend Commands

backend-build: ## Build backend TypeScript
	@echo "$(GREEN)Building backend...$(NC)"
	cd backend && npm run build

backend-install: ## Install backend dependencies
	@echo "$(GREEN)Installing backend dependencies...$(NC)"
	cd backend && npm install

backend-type-check: ## Type check backend code
	@echo "$(GREEN)Type checking backend...$(NC)"
	cd backend && npm run type-check

backend-dev: ## Run backend in development mode (local, not Docker)
	@echo "$(GREEN)Starting backend in development mode...$(NC)"
	cd backend && npm run dev

##@ Database Commands

db-reset: ## Reset MongoDB database (WARNING: deletes all data)
	@echo "$(RED)WARNING: This will delete all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(YELLOW)Resetting database...$(NC)"; \
		$(DOCKER_COMPOSE) exec mongo mongosh -u $(MONGO_INITDB_ROOT_USERNAME) -p $(MONGO_INITDB_ROOT_PASSWORD) --eval "db.getSiblingDB('$(MONGO_DATABASE)').dropDatabase()"; \
		echo "$(GREEN)Database reset complete!$(NC)"; \
	else \
		echo "$(GREEN)Cancelled.$(NC)"; \
	fi

db-backup: ## Backup MongoDB database
	@echo "$(GREEN)Backing up database...$(NC)"
	@mkdir -p backups
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	$(DOCKER_COMPOSE) exec -T mongo mongodump \
		--username=$(MONGO_INITDB_ROOT_USERNAME) \
		--password=$(MONGO_INITDB_ROOT_PASSWORD) \
		--db=$(MONGO_DATABASE) \
		--archive > backups/backup_$$TIMESTAMP.archive
	@echo "$(GREEN)Backup complete! Saved to backups/backup_$$TIMESTAMP.archive$(NC)"

##@ Cleanup Commands

clean: ## Remove containers and networks (both dev and prod)
	@echo "$(YELLOW)Cleaning up containers and networks...$(NC)"
	@docker compose -f docker/compose.development.yaml -p dev down 2>/dev/null || true
	@docker compose -f docker/compose.production.yaml -p prod down 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete!$(NC)"

clean-all: ## Remove containers, networks, volumes, and images
	@echo "$(RED)WARNING: This will remove all containers, networks, volumes, and images!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(YELLOW)Removing everything...$(NC)"; \
		docker compose -f docker/compose.development.yaml -p dev down -v --rmi all 2>/dev/null || true; \
		docker compose -f docker/compose.production.yaml -p prod down -v --rmi all 2>/dev/null || true; \
		echo "$(GREEN)Complete cleanup done!$(NC)"; \
	else \
		echo "$(GREEN)Cancelled.$(NC)"; \
	fi

clean-volumes: ## Remove all volumes
	@echo "$(RED)WARNING: This will delete all persistent data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(YELLOW)Removing volumes...$(NC)"; \
		docker compose -f docker/compose.development.yaml -p dev down -v 2>/dev/null || true; \
		docker compose -f docker/compose.production.yaml -p prod down -v 2>/dev/null || true; \
		echo "$(GREEN)Volumes removed!$(NC)"; \
	else \
		echo "$(GREEN)Cancelled.$(NC)"; \
	fi

##@ Utilities

status: ps ## Alias for ps

health: ## Check service health
	@echo "$(GREEN)Checking service health...$(NC)"
	@echo "\n$(YELLOW)Gateway Health:$(NC)"
	@curl -s http://localhost:5921/health | jq '.' || echo "$(RED)Gateway not responding$(NC)"
	@echo "\n$(YELLOW)Backend Health (via Gateway):$(NC)"
	@curl -s http://localhost:5921/api/health | jq '.' || echo "$(RED)Backend not responding$(NC)"
	@echo "\n$(YELLOW)Docker Container Status:$(NC)"
	@$(DOCKER_COMPOSE) ps

# Catch-all target to allow passing service names as arguments
%:
	@:
