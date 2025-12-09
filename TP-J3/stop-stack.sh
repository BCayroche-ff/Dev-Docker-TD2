#!/bin/bash
# ===========================================
# GreenWatt Stack - Kubernetes Stop Script
# ===========================================
# Usage: ./stop-stack.sh [--delete-all] [--stop-minikube]
# ===========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DELETE_ALL=false
STOP_MINIKUBE=false

for arg in "$@"; do
    case $arg in
        --delete-all)
            DELETE_ALL=true
            shift
            ;;
        --stop-minikube)
            STOP_MINIKUBE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --delete-all     Delete all K8s resources (keeps Minikube running)"
            echo "  --stop-minikube  Stop Minikube completely"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
    esac
done

echo -e "${YELLOW}Stopping GreenWatt Stack...${NC}"

# Kill any running port-forwards
pkill -f "kubectl port-forward" 2>/dev/null || true

if [ "$DELETE_ALL" = true ]; then
    echo -e "${YELLOW}Deleting all resources...${NC}"
    kubectl delete -f "$SCRIPT_DIR/k8s/security/" 2>/dev/null || true
    kubectl delete -f "$SCRIPT_DIR/k8s/monitoring/" 2>/dev/null || true
    kubectl delete -f "$SCRIPT_DIR/k8s/" 2>/dev/null || true
    echo -e "${GREEN}All resources deleted${NC}"
fi

if [ "$STOP_MINIKUBE" = true ]; then
    echo -e "${YELLOW}Stopping Minikube...${NC}"
    minikube stop
    echo -e "${GREEN}Minikube stopped${NC}"
fi

echo -e "${GREEN}Done!${NC}"
