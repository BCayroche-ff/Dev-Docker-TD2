#!/bin/bash
# ===========================================
# GreenWatt Stack - Kubernetes Startup Script
# ===========================================
# Ce script démarre la stack complète et configure
# l'accès via greenwatt.local
#
# Usage: ./start-stack.sh [--with-monitoring] [--with-security]
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Options
WITH_MONITORING=false
WITH_SECURITY=false
WINDOWS_MODE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --with-monitoring)
            WITH_MONITORING=true
            shift
            ;;
        --with-security)
            WITH_SECURITY=true
            shift
            ;;
        --full)
            WITH_MONITORING=true
            WITH_SECURITY=true
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
            echo "  --with-monitoring  Deploy Prometheus + Grafana"
            echo "  --with-security    Deploy Network Policies"
            echo "  --full             Deploy everything (monitoring + security)"
            echo "  --windows          Use port-forward mode for Windows access"
            echo "  --help, -h         Show this help"
            exit 0
            ;;
    esac
done

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   GreenWatt Platform - K8s Startup     ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# ===========================================
# 1. Check Minikube
# ===========================================
echo -e "${YELLOW}[1/6] Checking Minikube...${NC}"

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

echo -e "${GREEN}Addons enabled: ingress, metrics-server${NC}"

# ===========================================
# 3. Build Images (if needed)
# ===========================================
echo ""
echo -e "${YELLOW}[3/6] Checking Docker images...${NC}"

# Check if images exist in Minikube
BACKEND_EXISTS=$(minikube image ls | grep -c "greenwatt-backend:v1" || echo "0")
FRONTEND_EXISTS=$(minikube image ls | grep -c "greenwatt-frontend:v1" || echo "0")

if [ "$BACKEND_EXISTS" -eq "0" ] || [ "$FRONTEND_EXISTS" -eq "0" ]; then
    echo -e "${YELLOW}Building images in Minikube Docker...${NC}"
    eval $(minikube docker-env)

    if [ "$BACKEND_EXISTS" -eq "0" ]; then
        echo "Building backend..."
        docker build -t greenwatt-backend:v1 "$SCRIPT_DIR/backend" -q
    fi

    if [ "$FRONTEND_EXISTS" -eq "0" ]; then
        echo "Building frontend..."
        docker build -t greenwatt-frontend:v1 "$SCRIPT_DIR/frontend" -q
    fi

    eval $(minikube docker-env -u)
    echo -e "${GREEN}Images built${NC}"
else
    echo -e "${GREEN}Images already exist${NC}"
fi

# ===========================================
# 4. Deploy Kubernetes Manifests
# ===========================================
echo ""
echo -e "${YELLOW}[4/6] Deploying Kubernetes manifests...${NC}"

# Core stack
kubectl apply -f "$SCRIPT_DIR/k8s/" 2>/dev/null | grep -v "unchanged" || true

# Monitoring (optional)
if [ "$WITH_MONITORING" = true ]; then
    echo -e "${YELLOW}Deploying monitoring stack...${NC}"
    kubectl apply -f "$SCRIPT_DIR/k8s/monitoring/" 2>/dev/null | grep -v "unchanged" || true
fi

# Security (optional)
if [ "$WITH_SECURITY" = true ]; then
    echo -e "${YELLOW}Deploying network policies...${NC}"
    kubectl apply -f "$SCRIPT_DIR/k8s/security/" 2>/dev/null | grep -v "unchanged" || true
fi

echo -e "${GREEN}Manifests deployed${NC}"

# ===========================================
# 5. Wait for Pods
# ===========================================
echo ""
echo -e "${YELLOW}[5/6] Waiting for pods to be ready...${NC}"

# Wait for deployments
kubectl wait --for=condition=available --timeout=120s deployment/postgres -n greenwatt 2>/dev/null || true
kubectl wait --for=condition=available --timeout=120s deployment/redis -n greenwatt 2>/dev/null || true
kubectl wait --for=condition=available --timeout=120s deployment/backend -n greenwatt 2>/dev/null || true
kubectl wait --for=condition=available --timeout=120s deployment/frontend -n greenwatt 2>/dev/null || true

echo ""
echo -e "${GREEN}Pods status:${NC}"
kubectl get pods -n greenwatt --no-headers | awk '{printf "  %-35s %s\n", $1, $3}'

# ===========================================
# 6. Configure Access
# ===========================================
echo ""
echo -e "${YELLOW}[6/6] Configuring access...${NC}"

MINIKUBE_IP=$(minikube ip)

# Check /etc/hosts
if ! grep -q "greenwatt.local" /etc/hosts 2>/dev/null; then
    echo -e "${YELLOW}Adding greenwatt.local to /etc/hosts (requires sudo)...${NC}"
    echo "$MINIKUBE_IP greenwatt.local" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GREEN}Added: $MINIKUBE_IP greenwatt.local${NC}"
else
    # Update existing entry
    sudo sed -i "s/.*greenwatt.local/$MINIKUBE_IP greenwatt.local/" /etc/hosts
    echo -e "${GREEN}/etc/hosts updated: $MINIKUBE_IP greenwatt.local${NC}"
fi

# ===========================================
# 7. Start Tunnel or Port-Forward
# ===========================================
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Stack deployed successfully!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [ "$WINDOWS_MODE" = true ]; then
    # Windows mode: use port-forward
    echo -e "Access URLs (Windows mode):"
    echo -e "  ${GREEN}Frontend:${NC} http://localhost:8080"
    echo -e "  ${GREEN}API:${NC}      http://localhost:5000/api/health"
    if [ "$WITH_MONITORING" = true ]; then
        echo -e "  ${GREEN}Grafana:${NC}  http://localhost:3000 (admin/greenwatt2025)"
    fi
    echo ""
    echo -e "${YELLOW}Starting port-forwards (keep this terminal open)...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    # Kill existing port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 1

    # Start port-forwards in background
    kubectl port-forward svc/frontend-service 8080:80 -n greenwatt --address 0.0.0.0 &
    kubectl port-forward svc/backend-service 5000:5000 -n greenwatt --address 0.0.0.0 &

    if [ "$WITH_MONITORING" = true ]; then
        kubectl port-forward svc/grafana-service 3000:3000 -n monitoring --address 0.0.0.0 &
        kubectl port-forward svc/prometheus-service 9090:9090 -n monitoring --address 0.0.0.0 &
    fi

    echo -e "${GREEN}Port-forwards started${NC}"
    echo ""

    # Wait for all background jobs
    wait
else
    # Linux/WSL mode: use minikube tunnel
    echo -e "Access URLs:"
    echo -e "  ${GREEN}Frontend:${NC} http://greenwatt.local"
    echo -e "  ${GREEN}API:${NC}      http://greenwatt.local/api/health"
    if [ "$WITH_MONITORING" = true ]; then
        echo -e "  ${GREEN}Grafana:${NC}  kubectl port-forward -n monitoring svc/grafana-service 3000:3000"
        echo -e "            → http://localhost:3000 (admin/greenwatt2025)"
    fi
    echo ""
    echo -e "${YELLOW}Starting minikube tunnel (keep this terminal open)...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    # Start tunnel (this will block)
    minikube tunnel
fi
