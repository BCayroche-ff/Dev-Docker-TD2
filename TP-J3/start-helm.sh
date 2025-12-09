#!/bin/bash
# ===========================================
# GreenWatt Stack - Helm Deployment Script
# ===========================================
# Ce script déploie la stack via Helm et configure l'accès
#
# Usage: ./start-helm.sh [--env dev|staging|prod] [--windows]
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHART="$SCRIPT_DIR/helm/greenwatt"

# Options
ENVIRONMENT="dev"
WINDOWS_MODE=false
RELEASE_NAME="greenwatt"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --env=*)
            ENVIRONMENT="${arg#*=}"
            shift
            ;;
        --windows)
            WINDOWS_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --env=ENV    Environment: dev, staging, prod (default: dev)"
            echo "  --windows    Use port-forward mode for Windows access"
            echo "  --help, -h   Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --env=dev --windows   # Dev environment, Windows access"
            echo "  $0 --env=prod            # Production environment"
            exit 0
            ;;
    esac
done

VALUES_FILE="$HELM_CHART/values-${ENVIRONMENT}.yaml"

if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}ERROR: Values file not found: $VALUES_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   GreenWatt Platform - Helm Deploy     ${NC}"
echo -e "${BLUE}   Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# ===========================================
# 1. Check Prerequisites
# ===========================================
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

# Find helm binary
HELM_BIN=""
if command -v helm &> /dev/null; then
    HELM_BIN="helm"
elif [ -f "$HOME/bin/helm" ]; then
    HELM_BIN="$HOME/bin/helm"
else
    echo -e "${RED}ERROR: helm not found. Please install it first.${NC}"
    echo "Run: curl -fsSL https://get.helm.sh/helm-v3.19.2-linux-amd64.tar.gz | tar -xzf - -C /tmp && mkdir -p ~/bin && mv /tmp/linux-amd64/helm ~/bin/"
    exit 1
fi
echo -e "${GREEN}Using helm: $HELM_BIN${NC}"

if ! command -v minikube &> /dev/null; then
    echo -e "${RED}ERROR: minikube not found. Please install it first.${NC}"
    exit 1
fi

MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")
if [ "$MINIKUBE_STATUS" != "Running" ]; then
    echo -e "${YELLOW}Starting Minikube...${NC}"
    minikube start --driver=docker
else
    echo -e "${GREEN}Minikube is already running${NC}"
fi

# ===========================================
# 2. Enable Addons
# ===========================================
echo ""
echo -e "${YELLOW}[2/6] Enabling Minikube addons...${NC}"

minikube addons enable ingress 2>/dev/null || true
minikube addons enable metrics-server 2>/dev/null || true

echo -e "${GREEN}Addons enabled${NC}"

# ===========================================
# 3. Build Images
# ===========================================
echo ""
echo -e "${YELLOW}[3/6] Building Docker images in Minikube...${NC}"

eval $(minikube docker-env)

# Build backend
if ! docker images | grep -q "greenwatt-backend.*v1"; then
    echo "Building backend..."
    docker build -t greenwatt-backend:v1 "$SCRIPT_DIR/backend" -q 2>/dev/null || \
    docker build -t greenwatt-backend:v1 "$SCRIPT_DIR/backend"
fi

# Build frontend
if ! docker images | grep -q "greenwatt-frontend.*v1"; then
    echo "Building frontend..."
    docker build -t greenwatt-frontend:v1 "$SCRIPT_DIR/frontend" -q 2>/dev/null || \
    docker build -t greenwatt-frontend:v1 "$SCRIPT_DIR/frontend"
fi

# Also tag as dev for dev environment
docker tag greenwatt-backend:v1 greenwatt-backend:dev 2>/dev/null || true
docker tag greenwatt-frontend:v1 greenwatt-frontend:dev 2>/dev/null || true

eval $(minikube docker-env -u)

echo -e "${GREEN}Images ready${NC}"

# ===========================================
# 4. Deploy with Helm
# ===========================================
echo ""
echo -e "${YELLOW}[4/6] Deploying with Helm...${NC}"

# Check if release exists
if $HELM_BIN status $RELEASE_NAME -n greenwatt &>/dev/null; then
    echo "Upgrading existing release..."
    $HELM_BIN upgrade $RELEASE_NAME "$HELM_CHART" \
        -f "$VALUES_FILE" \
        -n greenwatt \
        --wait \
        --timeout 5m
else
    echo "Installing new release..."
    $HELM_BIN install $RELEASE_NAME "$HELM_CHART" \
        -f "$VALUES_FILE" \
        -n greenwatt \
        --create-namespace \
        --wait \
        --timeout 5m
fi

echo -e "${GREEN}Helm deployment complete${NC}"

# ===========================================
# 5. Wait for Pods
# ===========================================
echo ""
echo -e "${YELLOW}[5/6] Waiting for pods...${NC}"

kubectl wait --for=condition=available --timeout=120s deployment/postgres -n greenwatt 2>/dev/null || true
kubectl wait --for=condition=available --timeout=120s deployment/redis -n greenwatt 2>/dev/null || true
kubectl wait --for=condition=available --timeout=120s deployment/backend -n greenwatt 2>/dev/null || true
kubectl wait --for=condition=available --timeout=120s deployment/frontend -n greenwatt 2>/dev/null || true

echo ""
echo -e "${GREEN}Pods status:${NC}"
kubectl get pods -n greenwatt --no-headers 2>/dev/null | awk '{printf "  %-40s %s\n", $1, $3}'

# ===========================================
# 6. Configure Access
# ===========================================
echo ""
echo -e "${YELLOW}[6/6] Configuring access...${NC}"

MINIKUBE_IP=$(minikube ip)

# Update /etc/hosts
if ! grep -q "greenwatt.local" /etc/hosts 2>/dev/null; then
    echo "$MINIKUBE_IP greenwatt.local" | sudo tee -a /etc/hosts > /dev/null
else
    sudo sed -i "s/.*greenwatt.local/$MINIKUBE_IP greenwatt.local/" /etc/hosts
fi

echo -e "${GREEN}/etc/hosts updated${NC}"

# ===========================================
# 7. Start Access
# ===========================================
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Helm deployment successful!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "Release: ${GREEN}$RELEASE_NAME${NC}"
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo ""

if [ "$WINDOWS_MODE" = true ]; then
    echo -e "Access URLs (Windows mode):"
    echo -e "  ${GREEN}Frontend:${NC} http://localhost:8080"
    echo -e "  ${GREEN}API:${NC}      http://localhost:5000/api/health"
    echo ""
    echo -e "${YELLOW}Starting port-forwards...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 1

    kubectl port-forward svc/frontend-service 8080:80 -n greenwatt --address 0.0.0.0 &
    kubectl port-forward svc/backend-service 5000:5000 -n greenwatt --address 0.0.0.0 &

    wait
else
    echo -e "Access URLs:"
    echo -e "  ${GREEN}Frontend:${NC} http://greenwatt.local"
    echo -e "  ${GREEN}API:${NC}      http://greenwatt.local/api/health"
    echo ""
    echo -e "${YELLOW}Starting minikube tunnel...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    minikube tunnel
fi
