#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DevOps Setup Validation Script                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

ERRORS=0
WARNINGS=0

# Function to check if a file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is missing"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if a directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 directory exists"
        return 0
    else
        echo -e "${RED}✗${NC} $1 directory is missing"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if a command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        ((ERRORS++))
        return 1
    fi
}

echo -e "${YELLOW}=== Checking Prerequisites ===${NC}\n"

check_command "docker"
check_command "docker-compose" || check_command "docker compose"
check_command "make"
check_command "curl"

echo -e "\n${YELLOW}=== Checking Project Structure ===${NC}\n"

# Check directories
check_dir "backend"
check_dir "backend/src"
check_dir "gateway"
check_dir "gateway/src"
check_dir "docker"

echo ""

# Check Dockerfiles
check_file "backend/Dockerfile"
check_file "backend/Dockerfile.dev"
check_file "gateway/Dockerfile"
check_file "gateway/Dockerfile.dev"

echo ""

# Check Docker Compose files
check_file "docker/compose.development.yaml"
check_file "docker/compose.production.yaml"

echo ""

# Check configuration files
check_file "Makefile"
check_file ".env"
check_file ".env.example"
check_file ".gitignore"

echo ""

# Check documentation
check_file "README.md"
check_file "SETUP.md"
check_file "IMPLEMENTATION.md"

echo ""

# Check .dockerignore files
check_file "backend/.dockerignore"
check_file "gateway/.dockerignore"

echo -e "\n${YELLOW}=== Checking File Contents ===${NC}\n"

# Check if .env has required variables
if [ -f ".env" ]; then
    required_vars=("MONGO_INITDB_ROOT_USERNAME" "MONGO_INITDB_ROOT_PASSWORD" "MONGO_URI" "MONGO_DATABASE" "BACKEND_PORT" "GATEWAY_PORT" "NODE_ENV")
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env; then
            echo -e "${GREEN}✓${NC} .env contains $var"
        else
            echo -e "${RED}✗${NC} .env is missing $var"
            ((ERRORS++))
        fi
    done
fi

echo ""

# Check if ports are correct
if [ -f ".env" ]; then
    backend_port=$(grep "^BACKEND_PORT=" .env | cut -d'=' -f2)
    gateway_port=$(grep "^GATEWAY_PORT=" .env | cut -d'=' -f2)
    
    if [ "$backend_port" = "3847" ]; then
        echo -e "${GREEN}✓${NC} BACKEND_PORT is correctly set to 3847"
    else
        echo -e "${RED}✗${NC} BACKEND_PORT should be 3847, found: $backend_port"
        ((ERRORS++))
    fi
    
    if [ "$gateway_port" = "5921" ]; then
        echo -e "${GREEN}✓${NC} GATEWAY_PORT is correctly set to 5921"
    else
        echo -e "${RED}✗${NC} GATEWAY_PORT should be 5921, found: $gateway_port"
        ((ERRORS++))
    fi
fi

echo -e "\n${YELLOW}=== Checking Docker Configuration ===${NC}\n"

# Check if Docker is running
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
else
    echo -e "${RED}✗${NC} Docker daemon is not running"
    ((ERRORS++))
fi

# Check if ports are available
if lsof -Pi :5921 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Port 5921 is already in use"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Port 5921 is available"
fi

if lsof -Pi :3847 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Port 3847 is already in use (this is OK if backend is running)"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Port 3847 is available"
fi

echo -e "\n${YELLOW}=== Checking Makefile Targets ===${NC}\n"

# Check if Makefile has required targets
required_targets=("help" "up" "down" "build" "logs" "dev-up" "prod-up" "clean" "health")
for target in "${required_targets[@]}"; do
    if grep -q "^${target}:" Makefile; then
        echo -e "${GREEN}✓${NC} Makefile has '$target' target"
    else
        echo -e "${RED}✗${NC} Makefile is missing '$target' target"
        ((ERRORS++))
    fi
done

echo -e "\n${YELLOW}=== Security Checks ===${NC}\n"

# Check if .env is in .gitignore
if grep -q "^\.env$" .gitignore || grep -q "^\.env" .gitignore; then
    echo -e "${GREEN}✓${NC} .env is in .gitignore"
else
    echo -e "${RED}✗${NC} .env should be in .gitignore"
    ((ERRORS++))
fi

# Check if node_modules is in .gitignore
if grep -q "node_modules" .gitignore; then
    echo -e "${GREEN}✓${NC} node_modules is in .gitignore"
else
    echo -e "${RED}✗${NC} node_modules should be in .gitignore"
    ((ERRORS++))
fi

# Check if Dockerfiles use non-root user
if grep -q "USER nodejs" backend/Dockerfile; then
    echo -e "${GREEN}✓${NC} Backend Dockerfile uses non-root user"
else
    echo -e "${YELLOW}⚠${NC} Backend Dockerfile should use non-root user"
    ((WARNINGS++))
fi

if grep -q "USER nodejs" gateway/Dockerfile; then
    echo -e "${GREEN}✓${NC} Gateway Dockerfile uses non-root user"
else
    echo -e "${YELLOW}⚠${NC} Gateway Dockerfile should use non-root user"
    ((WARNINGS++))
fi

echo -e "\n${YELLOW}=== Optimization Checks ===${NC}\n"

# Check for multi-stage builds
if grep -q "FROM.*AS builder" backend/Dockerfile; then
    echo -e "${GREEN}✓${NC} Backend uses multi-stage build"
else
    echo -e "${YELLOW}⚠${NC} Backend should use multi-stage build for optimization"
    ((WARNINGS++))
fi

# Check for .dockerignore
if [ -f "backend/.dockerignore" ] && [ -s "backend/.dockerignore" ]; then
    echo -e "${GREEN}✓${NC} Backend has .dockerignore file"
else
    echo -e "${YELLOW}⚠${NC} Backend should have .dockerignore file"
    ((WARNINGS++))
fi

if [ -f "gateway/.dockerignore" ] && [ -s "gateway/.dockerignore" ]; then
    echo -e "${GREEN}✓${NC} Gateway has .dockerignore file"
else
    echo -e "${YELLOW}⚠${NC} Gateway should have .dockerignore file"
    ((WARNINGS++))
fi

# Check for health checks in Dockerfiles
if grep -q "HEALTHCHECK" backend/Dockerfile; then
    echo -e "${GREEN}✓${NC} Backend Dockerfile has health check"
else
    echo -e "${YELLOW}⚠${NC} Backend Dockerfile should have health check"
    ((WARNINGS++))
fi

if grep -q "HEALTHCHECK" gateway/Dockerfile; then
    echo -e "${GREEN}✓${NC} Gateway Dockerfile has health check"
else
    echo -e "${YELLOW}⚠${NC} Gateway Dockerfile should have health check"
    ((WARNINGS++))
fi

echo -e "\n${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Validation Summary                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Your setup is ready.${NC}\n"
    echo -e "Next steps:"
    echo -e "  1. Review and update .env file with your credentials"
    echo -e "  2. Run: ${YELLOW}make dev-up${NC} to start development environment"
    echo -e "  3. Run: ${YELLOW}./test-api.sh${NC} to test the API"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warning(s)${NC}\n"
    echo -e "Your setup should work, but consider addressing the warnings."
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}\n"
    echo -e "Please fix the errors before proceeding."
    exit 1
fi
