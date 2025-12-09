#!/bin/bash
# =====================================================
# Script d'installation - Solar Monitoring GitOps
# TP Master 2 - DevOps
# =====================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="solar-monitoring"
NAMESPACE="solar-prod"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
    echo ""
}

# Verification des prerequis
check_prerequisites() {
    print_header "Verification des prerequis"

    local missing=0

    # Docker
    if command -v docker &> /dev/null; then
        log_success "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    else
        log_error "Docker non installe"
        missing=1
    fi

    # kubectl
    if command -v kubectl &> /dev/null; then
        log_success "kubectl: $(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": "[^"]*"' | cut -d'"' -f4)"
    else
        log_error "kubectl non installe"
        missing=1
    fi

    # minikube
    if command -v minikube &> /dev/null; then
        log_success "minikube: $(minikube version --short 2>/dev/null || echo 'installed')"
    else
        log_error "minikube non installe"
        missing=1
    fi

    # Node.js (optionnel pour dev local)
    if command -v node &> /dev/null; then
        log_success "Node.js: $(node --version)"
    else
        log_warning "Node.js non installe (optionnel pour dev local)"
    fi

    if [ $missing -eq 1 ]; then
        log_error "Prerequis manquants. Veuillez les installer avant de continuer."
        exit 1
    fi
}

# Creation du cluster Minikube
setup_cluster() {
    print_header "Configuration du cluster Kubernetes"

    # Verifier si le cluster existe deja
    if minikube status -p $CLUSTER_NAME &> /dev/null; then
        log_warning "Le cluster '$CLUSTER_NAME' existe deja"
        read -p "Voulez-vous le supprimer et recreer? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Suppression du cluster existant..."
            minikube delete -p $CLUSTER_NAME
        else
            log_info "Utilisation du cluster existant"
            minikube start -p $CLUSTER_NAME
            return
        fi
    fi

    log_info "Creation du cluster Minikube '$CLUSTER_NAME'..."
    minikube start -p $CLUSTER_NAME \
        --cpus=2 \
        --memory=4096 \
        --driver=docker \
        --kubernetes-version=v1.28.0

    log_success "Cluster '$CLUSTER_NAME' cree avec succes"

    # Configurer kubectl pour utiliser ce cluster
    kubectl config use-context $CLUSTER_NAME
    log_success "kubectl configure pour le cluster '$CLUSTER_NAME'"
}

# Installation d'ArgoCD
install_argocd() {
    print_header "Installation d'ArgoCD"

    # Creer le namespace ArgoCD
    log_info "Creation du namespace argocd..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

    # Installer ArgoCD
    log_info "Installation des composants ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    # Attendre que les pods soient prets
    log_info "Attente du demarrage des pods ArgoCD..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

    log_success "ArgoCD installe avec succes"

    # Recuperer le mot de passe admin
    log_info "Recuperation du mot de passe admin initial..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo ""
    echo -e "${GREEN}=== Credentials ArgoCD ===${NC}"
    echo -e "URL:      https://localhost:8080"
    echo -e "Username: admin"
    echo -e "Password: ${ARGOCD_PASSWORD}"
    echo ""
}

# Creation du namespace de l'application
setup_namespace() {
    print_header "Configuration du namespace $NAMESPACE"

    kubectl apply -f "$PROJECT_DIR/k8s/base/namespace.yaml"
    log_success "Namespace '$NAMESPACE' cree"
}

# Build de l'image Docker du simulateur
build_simulator() {
    print_header "Build de l'image Docker du simulateur"

    # Se positionner dans le repertoire du simulateur
    cd "$PROJECT_DIR/src/solar-simulator"

    # Copier les donnees CSV si pas deja fait
    if [ ! -d "data" ]; then
        log_info "Copie des donnees CSV..."
        mkdir -p data
        cp "$PROJECT_DIR/data/"*.csv data/ 2>/dev/null || log_warning "Fichiers CSV non trouves dans $PROJECT_DIR/data/"
    fi

    # Configurer Docker pour utiliser le daemon Minikube
    log_info "Configuration de Docker pour Minikube..."
    eval $(minikube -p $CLUSTER_NAME docker-env)

    # Builder l'image
    log_info "Build de l'image solar-simulator:latest..."
    docker build -t solar-simulator:latest .

    log_success "Image Docker construite avec succes"

    # Retour au repertoire projet
    cd "$PROJECT_DIR"
}

# Deploiement des composants
deploy_components() {
    print_header "Deploiement des composants"

    # Deployer le simulateur
    log_info "Deploiement du simulateur solaire..."
    kubectl apply -k "$PROJECT_DIR/k8s/apps/solar-simulator"

    # Deployer la stack de monitoring
    log_info "Deploiement de Prometheus..."
    kubectl apply -k "$PROJECT_DIR/k8s/monitoring/prometheus"

    log_info "Deploiement de Grafana..."
    kubectl apply -k "$PROJECT_DIR/k8s/monitoring/grafana"

    log_info "Deploiement d'AlertManager..."
    kubectl apply -k "$PROJECT_DIR/k8s/monitoring/alertmanager"

    # Attendre que les pods soient prets
    log_info "Attente du demarrage des pods..."
    kubectl wait --for=condition=available --timeout=300s deployment/solar-simulator -n $NAMESPACE || true
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $NAMESPACE || true
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n $NAMESPACE || true

    log_success "Composants deployes avec succes"
}

# Affichage des informations d'acces
print_access_info() {
    print_header "Informations d'acces"

    echo -e "${BLUE}Pour acceder aux services, executez ces commandes dans des terminaux separes:${NC}"
    echo ""
    echo "# ArgoCD (https://localhost:8080)"
    echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo ""
    echo "# Grafana (http://localhost:3000) - admin/admin"
    echo "kubectl port-forward svc/grafana -n $NAMESPACE 3000:3000"
    echo ""
    echo "# Prometheus (http://localhost:9090)"
    echo "kubectl port-forward svc/prometheus -n $NAMESPACE 9090:9090"
    echo ""
    echo "# Simulateur (http://localhost:3001/metrics)"
    echo "kubectl port-forward svc/solar-simulator -n $NAMESPACE 3001:3000"
    echo ""
    echo -e "${GREEN}Installation terminee avec succes!${NC}"
}

# Fonction principale
main() {
    print_header "Installation Solar Monitoring GitOps"

    check_prerequisites
    setup_cluster
    install_argocd
    setup_namespace
    build_simulator
    deploy_components
    print_access_info
}

# Execution
main "$@"
