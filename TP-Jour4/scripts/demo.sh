#!/bin/bash
# =====================================================
# Script de demonstration - Solar Monitoring GitOps
# Lance les port-forwards et affiche les URLs
# =====================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

NAMESPACE="solar-prod"

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Arret des port-forwards...${NC}"
    pkill -f "kubectl port-forward.*solar-prod" 2>/dev/null || true
    pkill -f "kubectl port-forward.*argocd" 2>/dev/null || true
    echo -e "${GREEN}Termine.${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Header
clear
echo ""
echo -e "${GREEN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║     DEMO - Solar Monitoring avec GitOps           ║"
echo "  ║     TP Master 2 DevOps - Observabilite            ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verification des pods
echo -e "${BLUE}Verification des pods...${NC}"
kubectl get pods -n $NAMESPACE --no-headers | while read line; do
    name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $3}')
    if [ "$status" == "Running" ]; then
        echo -e "  ${GREEN}✓${NC} $name"
    else
        echo -e "  ${RED}✗${NC} $name ($status)"
    fi
done

echo ""

# Kill existing port-forwards
echo -e "${BLUE}Nettoyage des anciens port-forwards...${NC}"
pkill -f "kubectl port-forward.*solar-prod" 2>/dev/null || true
pkill -f "kubectl port-forward.*argocd" 2>/dev/null || true
sleep 1

# Launch port-forwards in background
echo -e "${BLUE}Lancement des port-forwards...${NC}"

kubectl port-forward svc/grafana -n $NAMESPACE 3000:3000 > /dev/null 2>&1 &
echo -e "  ${GREEN}✓${NC} Grafana       → localhost:3000"

kubectl port-forward svc/prometheus -n $NAMESPACE 9090:9090 > /dev/null 2>&1 &
echo -e "  ${GREEN}✓${NC} Prometheus    → localhost:9090"

kubectl port-forward svc/solar-simulator -n $NAMESPACE 3001:3000 > /dev/null 2>&1 &
echo -e "  ${GREEN}✓${NC} Simulateur    → localhost:3001"

kubectl port-forward svc/alertmanager -n $NAMESPACE 9093:9093 > /dev/null 2>&1 &
echo -e "  ${GREEN}✓${NC} AlertManager  → localhost:9093"

kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
echo -e "  ${GREEN}✓${NC} ArgoCD        → localhost:8080"

sleep 2

# URLs
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                   URLS D'ACCES                     ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Dashboard Grafana (données temps réel):${NC}"
echo -e "  ${YELLOW}http://localhost:3000/d/solar-monitoring/solar-monitoring-dashboard${NC}"
echo -e "  Login: admin / admin"
echo ""
echo -e "${GREEN}Alertes Prometheus (incidents en cours):${NC}"
echo -e "  ${YELLOW}http://localhost:9090/alerts${NC}"
echo ""
echo -e "${GREEN}Métriques brutes du simulateur:${NC}"
echo -e "  ${YELLOW}http://localhost:3001/metrics${NC}"
echo ""
echo -e "${GREEN}AlertManager (notifications):${NC}"
echo -e "  ${YELLOW}http://localhost:9093${NC}"
echo ""
echo -e "${GREEN}ArgoCD (GitOps):${NC}"
echo -e "  ${YELLOW}https://localhost:8080${NC}"
echo ""

# Current status
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}               ETAT ACTUEL DU SIMULATEUR            ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""

# Get current metrics
METRICS=$(curl -s http://localhost:3001/metrics 2>/dev/null)

if [ -n "$METRICS" ]; then
    HOUR=$(echo "$METRICS" | grep 'solar_simulated_hour{farm="provence"}' | awk '{print $2}' | cut -d. -f1)
    DAY=$(echo "$METRICS" | grep 'solar_simulated_day{farm="provence"}' | awk '{print $2}' | cut -d. -f1)

    echo -e "  Jour simulé: ${YELLOW}$DAY${NC} | Heure: ${YELLOW}${HOUR}h${NC}"
    echo ""
    echo -e "  ${BLUE}Production actuelle (kW):${NC}"
    echo "$METRICS" | grep "^solar_power_production_kw" | while read line; do
        farm=$(echo $line | sed 's/.*farm="\([^"]*\)".*/\1/')
        value=$(echo $line | awk '{print $2}')
        printf "    %-12s: %s kW\n" "$farm" "$value"
    done
    echo ""
    echo -e "  ${BLUE}Températures panneaux (°C):${NC}"
    echo "$METRICS" | grep "^solar_panel_temperature_celsius" | while read line; do
        farm=$(echo $line | sed 's/.*farm="\([^"]*\)".*/\1/')
        value=$(echo $line | awk '{print $2}')
        printf "    %-12s: %s °C\n" "$farm" "$value"
    done
else
    echo -e "  ${RED}Impossible de récupérer les métriques${NC}"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Cycle: 5 sec = 1 heure simulée (24h = 2 min)${NC}"
echo -e "${YELLOW}Production solaire: 6h-20h | Nuit: 0 kW${NC}"
echo ""
echo -e "${GREEN}Les alertes se déclenchent automatiquement selon les données CSV:${NC}"
echo "  • SolarPanelOverheating  → Température > 65°C"
echo "  • InverterDown           → Onduleur en panne"
echo "  • LowProductionEfficiency→ Production < 50%"
echo ""
echo -e "${YELLOW}Ctrl+C pour arrêter les port-forwards${NC}"
echo ""

# Keep script running
while true; do
    sleep 10
    # Refresh metrics display
    METRICS=$(curl -s http://localhost:3001/metrics 2>/dev/null)
    if [ -n "$METRICS" ]; then
        HOUR=$(echo "$METRICS" | grep 'solar_simulated_hour{farm="provence"}' | awk '{print $2}' | cut -d. -f1)
        DAY=$(echo "$METRICS" | grep 'solar_simulated_day{farm="provence"}' | awk '{print $2}' | cut -d. -f1)
        PROD=$(echo "$METRICS" | grep 'solar_power_production_kw{farm="provence"}' | awk '{print $2}')
        TEMP=$(echo "$METRICS" | grep 'solar_panel_temperature_celsius{farm="provence"}' | awk '{print $2}')
        echo -ne "\r${CYAN}[Jour $DAY - ${HOUR}h]${NC} Provence: ${PROD} kW | ${TEMP}°C     "
    fi
done
