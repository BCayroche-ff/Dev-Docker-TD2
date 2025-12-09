#!/bin/bash
# ===========================================
# GreenWatt Stack - Helm Stop Script
# ===========================================
# Usage: ./stop-helm.sh [--delete] [--stop-minikube]
# ===========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DELETE_RELEASE=false
STOP_MINIKUBE=false
RELEASE_NAME="greenwatt"

# Find helm binary
HELM_BIN=""
if command -v helm &> /dev/null; then
    HELM_BIN="helm"
elif [ -f "$HOME/bin/helm" ]; then
    HELM_BIN="$HOME/bin/helm"
fi

for arg in "$@"; do
    case $arg in
        --delete)
            DELETE_RELEASE=true
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
            echo "  --delete         Uninstall the Helm release completely"
            echo "  --stop-minikube  Stop Minikube after cleanup"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
    esac
done

echo -e "${YELLOW}Stopping GreenWatt Helm Stack...${NC}"

# Kill any running port-forwards
echo "Stopping port-forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || true

if [ "$DELETE_RELEASE" = true ] && [ -n "$HELM_BIN" ]; then
    echo -e "${YELLOW}Uninstalling Helm release...${NC}"
    $HELM_BIN uninstall $RELEASE_NAME -n greenwatt 2>/dev/null || true

    # Delete PVCs (data will be lost)
    echo -e "${YELLOW}Deleting PVCs...${NC}"
    kubectl delete pvc --all -n greenwatt 2>/dev/null || true

    # Delete namespace
    echo -e "${YELLOW}Deleting namespace...${NC}"
    kubectl delete namespace greenwatt 2>/dev/null || true

    echo -e "${GREEN}Helm release uninstalled${NC}"
fi

if [ "$STOP_MINIKUBE" = true ]; then
    echo -e "${YELLOW}Stopping Minikube...${NC}"
    minikube stop
    echo -e "${GREEN}Minikube stopped${NC}"
fi

echo -e "${GREEN}Done!${NC}"
echo ""
echo "To restart: ./start-helm.sh --env=dev --windows"
