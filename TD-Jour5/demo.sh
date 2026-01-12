#!/bin/bash
#
# Script de Démonstration - TP Platform Engineering & SRE
# TechMarket Internal Developer Platform
#
# Usage: ./demo.sh
#

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Fonction pour afficher un titre de section
section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Fonction pour afficher une étape
step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

# Fonction pour afficher une explication
explain() {
    echo -e "${NC}  $1${NC}"
}

# Fonction pour afficher un succès
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Fonction pour afficher une erreur
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Fonction pour afficher une commande
show_cmd() {
    echo -e "${BOLD}  \$ $1${NC}"
}

# Fonction pour attendre l'utilisateur
pause() {
    echo ""
    echo -e "${CYAN}Appuyez sur Entrée pour continuer...${NC}"
    read -r
}

# Fonction pour exécuter une commande avec affichage
run_cmd() {
    show_cmd "$1"
    echo ""
    eval "$1"
    echo ""
}

# Vérifier que kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    error "kubectl n'est pas installé ou pas dans le PATH"
    exit 1
fi

# Vérifier la connexion au cluster
if ! kubectl cluster-info &> /dev/null; then
    error "Impossible de se connecter au cluster Kubernetes"
    echo "Assurez-vous que le cluster Kind 'techmarket' est démarré:"
    echo "  kind get clusters"
    echo "  kind create cluster --name techmarket --config kind-config.yaml"
    exit 1
fi

clear

echo -e "${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║     DÉMONSTRATION - Platform Engineering & SRE                    ║"
echo "║     TechMarket Internal Developer Platform (IDP)                  ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Ce script va vous guider à travers les 4 blocs du TP :"
echo ""
echo "  BLOC 1 - Backstage : Portail développeur et catalogue de services"
echo "  BLOC 2 - Kyverno   : Policy as Code (validation des déploiements)"
echo "  BLOC 3 - SRE       : SLOs, métriques et Chaos Engineering"
echo "  BLOC 4 - Tekton    : Pipelines CI/CD cloud-native"
echo ""

pause

# ============================================================================
# BLOC 0 - État du Cluster
# ============================================================================

section "BLOC 0 - État du Cluster Kubernetes"

step "Vérification des nodes du cluster"
explain "Le cluster Kind 'techmarket' doit avoir 3 nodes (1 control-plane + 2 workers)"
echo ""
run_cmd "kubectl get nodes"

step "Vérification des namespaces"
explain "Chaque composant a son propre namespace pour l'isolation"
echo ""
run_cmd "kubectl get namespaces"

pause

# ============================================================================
# BLOC 1 - Backstage
# ============================================================================

section "BLOC 1 - Backstage (Internal Developer Platform)"

step "Qu'est-ce que Backstage ?"
explain "Backstage est un portail développeur open-source créé par Spotify."
explain "Il centralise :"
explain "  - Le catalogue de tous les services (qui possède quoi)"
explain "  - La documentation technique"
explain "  - Les templates pour créer de nouveaux services (Golden Paths)"
explain "  - Les outils et plugins de l'écosystème"
echo ""

step "Vérification des pods Backstage"
run_cmd "kubectl get pods -n backstage 2>/dev/null || echo 'Namespace backstage non trouvé'"

step "Accès à l'interface Backstage"
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  URL Backstage : ${BOLD}http://localhost:30000${NC}${CYAN}                        │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  Ce que vous devez observer :                                   │${NC}"
echo -e "${CYAN}│  1. Le catalogue avec les 3 services TechMarket                 │${NC}"
echo -e "${CYAN}│  2. Les relations entre services (dépendances)                  │${NC}"
echo -e "${CYAN}│  3. Les templates disponibles pour créer un nouveau service     │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
echo ""

step "Fichiers catalog-info.yaml créés"
explain "Chaque microservice a un fichier catalog-info.yaml qui le déclare dans Backstage"
echo ""
for svc in frontend backend payment-service; do
    if [ -f "microservices/$svc/catalog-info.yaml" ]; then
        success "microservices/$svc/catalog-info.yaml existe"
    else
        error "microservices/$svc/catalog-info.yaml manquant"
    fi
done

pause

# ============================================================================
# BLOC 2 - Kyverno
# ============================================================================

section "BLOC 2 - Kyverno (Policy as Code)"

step "Qu'est-ce que Kyverno ?"
explain "Kyverno est un admission controller qui intercepte les requêtes API Kubernetes."
explain "Il peut :"
explain "  - VALIDER : Bloquer les ressources non conformes"
explain "  - MUTER : Modifier automatiquement les ressources"
explain "  - GÉNÉRER : Créer des ressources complémentaires"
echo ""

step "Vérification des pods Kyverno"
run_cmd "kubectl get pods -n kyverno"

step "Liste des policies actives"
run_cmd "kubectl get clusterpolicies"

echo ""
step "Détail des policies :"
echo ""
echo -e "  ${BOLD}1. deny-latest-tag${NC}"
echo "     Bloque les pods utilisant une image avec le tag :latest"
echo "     Pourquoi ? Le tag :latest est non-déterministe et empêche les rollbacks"
echo ""
echo -e "  ${BOLD}2. require-resource-limits${NC}"
echo "     Exige des limits CPU et mémoire sur tous les containers"
echo "     Pourquoi ? Sans limits, un pod peut consommer toutes les ressources du node"
echo ""
echo -e "  ${BOLD}3. require-probes${NC}"
echo "     Exige readinessProbe et livenessProbe sur les Deployments"
echo "     Pourquoi ? Sans probes, le trafic est routé vers des pods non prêts"
echo ""
echo -e "  ${BOLD}4. add-standard-labels${NC}"
echo "     Ajoute automatiquement des labels (managed-by, created-at)"
echo "     Pourquoi ? Facilite le tracking et le debugging"
echo ""

pause

step "TEST 1 : Tentative de déploiement avec tag :latest (doit échouer)"
explain "On essaie de créer un pod avec nginx:latest - Kyverno doit le bloquer"
echo ""
show_cmd "kubectl run test-latest --image=nginx:latest --dry-run=server"
echo ""

if kubectl run test-latest --image=nginx:latest --dry-run=server 2>&1 | grep -q "denied"; then
    kubectl run test-latest --image=nginx:latest --dry-run=server 2>&1 || true
    echo ""
    success "La policy fonctionne ! Le déploiement avec :latest est bloqué"
else
    kubectl run test-latest --image=nginx:latest --dry-run=server 2>&1 || true
    echo ""
    error "Le déploiement n'a pas été bloqué (policy peut-être en mode Audit)"
fi

pause

step "TEST 2 : Tentative de déploiement sans resource limits (doit échouer)"
explain "On essaie de créer un Deployment sans limits CPU/mémoire"
echo ""

cat << 'EOF' > /tmp/test-no-limits.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-no-limits
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.0
        # Pas de resources.limits !
EOF

show_cmd "kubectl apply -f /tmp/test-no-limits.yaml --dry-run=server"
echo ""

if kubectl apply -f /tmp/test-no-limits.yaml --dry-run=server 2>&1 | grep -q "denied\|validation"; then
    kubectl apply -f /tmp/test-no-limits.yaml --dry-run=server 2>&1 || true
    echo ""
    success "La policy fonctionne ! Le déploiement sans limits est bloqué"
else
    kubectl apply -f /tmp/test-no-limits.yaml --dry-run=server 2>&1 || true
    echo ""
    error "Le déploiement n'a pas été bloqué"
fi

rm -f /tmp/test-no-limits.yaml

pause

step "TEST 3 : Déploiement conforme (doit réussir)"
explain "Un déploiement avec tag versionné, limits, et probes doit passer"
echo ""

cat << 'EOF' > /tmp/test-compliant.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-compliant
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-compliant
  template:
    metadata:
      labels:
        app: test-compliant
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.0
        resources:
          limits:
            cpu: "100m"
            memory: "128Mi"
          requests:
            cpu: "50m"
            memory: "64Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
EOF

show_cmd "kubectl apply -f /tmp/test-compliant.yaml --dry-run=server"
echo ""

if kubectl apply -f /tmp/test-compliant.yaml --dry-run=server 2>&1 | grep -q "created\|configured"; then
    kubectl apply -f /tmp/test-compliant.yaml --dry-run=server 2>&1
    echo ""
    success "Le déploiement conforme est accepté"
else
    kubectl apply -f /tmp/test-compliant.yaml --dry-run=server 2>&1 || true
fi

rm -f /tmp/test-compliant.yaml

pause

# ============================================================================
# BLOC 3 - SRE
# ============================================================================

section "BLOC 3 - SRE (Site Reliability Engineering)"

step "Qu'est-ce que le SRE ?"
explain "SRE est une discipline qui applique les principes du génie logiciel à l'exploitation."
explain "Concepts clés :"
explain "  - SLI (Service Level Indicator) : Métrique mesurable (ex: latency P95)"
explain "  - SLO (Service Level Objective) : Cible pour le SLI (ex: P95 < 500ms)"
explain "  - Error Budget : Temps de panne 'autorisé' (ex: 99.9% = 43min/mois de downtime)"
echo ""

step "Microservices déployés"
run_cmd "kubectl get pods -n techmarket 2>/dev/null || kubectl get pods -n default -l app"

step "SLOs définis pour payment-service"
explain "Fichier: prometheus/payment-service-slo.yaml"
echo ""
if [ -f "prometheus/payment-service-slo.yaml" ]; then
    echo -e "${CYAN}SLIs configurés :${NC}"
    echo "  - payment_service:success_rate    (ratio requêtes OK / total)"
    echo "  - payment_service:latency_p95     (95% des requêtes < seuil)"
    echo "  - payment_service:latency_p99     (99% des requêtes < seuil)"
    echo ""
    echo -e "${CYAN}SLOs cibles :${NC}"
    echo "  - Success Rate : 99.9%"
    echo "  - Latency P95  : < 500ms"
    echo "  - Latency P99  : < 1000ms"
    echo ""
    success "Fichier SLO présent"
else
    error "Fichier SLO manquant"
fi

pause

step "Chaos Engineering avec Litmus"
explain "Le Chaos Engineering consiste à provoquer des pannes contrôlées"
explain "pour valider la résilience du système AVANT qu'une vraie panne survienne."
echo ""

step "Vérification de Litmus Operator"
if kubectl get deployment chaos-operator-ce -n litmus &>/dev/null; then
    success "Litmus Operator installé"
    kubectl get pods -n litmus -l name=chaos-operator 2>/dev/null
else
    echo -e "${YELLOW}⚠ Litmus Operator non installé${NC}"
    echo "  Installation avec: kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v2.14.0.yaml"
fi
echo ""

step "État actuel du payment-service"
echo ""
echo -e "${CYAN}Pods payment-service AVANT le chaos :${NC}"
kubectl get pods -n techmarket -l app=payment-service 2>/dev/null || echo "Namespace techmarket non trouvé"
echo ""

if [ -f "litmus/pod-delete-experiment.yaml" ]; then
    read -p "Voulez-vous lancer le Chaos Experiment maintenant ? (o/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Oo]$ ]]; then
        echo ""
        step "Lancement du Chaos Experiment : pod-delete"
        explain "L'experiment va supprimer des pods du payment-service pendant 30 secondes"
        echo ""

        # Nettoyer les anciennes ressources
        kubectl delete chaosengine payment-service-chaos -n techmarket 2>/dev/null || true
        kubectl delete chaosresult -n techmarket --all 2>/dev/null || true
        sleep 2

        # Lancer l'experiment
        show_cmd "kubectl apply -f litmus/pod-delete-experiment.yaml"
        kubectl apply -f litmus/pod-delete-experiment.yaml
        echo ""

        # Attendre le démarrage
        echo -e "${YELLOW}Attente du démarrage du chaos runner...${NC}"
        sleep 8

        # Observer les pods pendant le chaos
        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  OBSERVATION DU CHAOS EN TEMPS RÉEL (40 secondes)             ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        for i in $(seq 1 8); do
            timestamp=$(date +%H:%M:%S)
            echo -e "${YELLOW}[$timestamp] Observation T+$((i*5))s${NC}"
            kubectl get pods -n techmarket -l app=payment-service --no-headers 2>/dev/null | while read line; do
                name=$(echo $line | awk '{print $1}')
                status=$(echo $line | awk '{print $3}')
                age=$(echo $line | awk '{print $5}')
                if [[ "$status" == "Terminating" ]]; then
                    echo -e "  ${RED}✗ $name - $status ($age)${NC}"
                elif [[ "$status" == "Running" ]]; then
                    ready=$(echo $line | awk '{print $2}')
                    if [[ "$ready" == "1/1" ]]; then
                        echo -e "  ${GREEN}✓ $name - $status ($age)${NC}"
                    else
                        echo -e "  ${YELLOW}◐ $name - $status $ready ($age)${NC}"
                    fi
                else
                    echo -e "  ${YELLOW}? $name - $status ($age)${NC}"
                fi
            done
            echo ""
            sleep 5
        done

        # Afficher le résultat
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  RÉSULTAT DU CHAOS EXPERIMENT                                 ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Attendre le résultat
        sleep 5

        result=$(kubectl get chaosresult -n techmarket -o jsonpath='{.items[0].status.experimentStatus.verdict}' 2>/dev/null || echo "Pending")
        phase=$(kubectl get chaosresult -n techmarket -o jsonpath='{.items[0].status.experimentStatus.phase}' 2>/dev/null || echo "Running")

        echo -e "  Phase   : ${BOLD}$phase${NC}"
        echo -e "  Verdict : ${BOLD}$result${NC}"
        echo ""

        if [[ "$result" == "Pass" ]]; then
            success "CHAOS EXPERIMENT RÉUSSI !"
            echo ""
            echo -e "  ${GREEN}✓ Les pods ont été supprimés par Litmus${NC}"
            echo -e "  ${GREEN}✓ Kubernetes a recréé les pods automatiquement${NC}"
            echo -e "  ${GREEN}✓ Le service payment-service est resté disponible${NC}"
        elif [[ "$result" == "Fail" ]]; then
            error "CHAOS EXPERIMENT ÉCHOUÉ"
            echo "  Le système n'a pas répondu correctement à la panne simulée"
        else
            echo -e "${YELLOW}⚠ Experiment en cours ou résultat non disponible${NC}"
            echo "  Vérifiez avec: kubectl get chaosresult -n techmarket"
        fi

        echo ""
        step "État final du payment-service"
        kubectl get pods -n techmarket -l app=payment-service
        echo ""

        # Afficher les détails du résultat
        step "Détails du ChaosResult"
        kubectl describe chaosresult -n techmarket 2>/dev/null | grep -A15 "Status:" | head -20 || echo "Pas de résultat disponible"

    else
        echo ""
        echo -e "${CYAN}Experiment non lancé. Pour le lancer manuellement :${NC}"
        show_cmd "kubectl apply -f litmus/pod-delete-experiment.yaml"
        echo ""
        echo -e "${CYAN}Pour observer les pods pendant le chaos :${NC}"
        show_cmd "watch kubectl get pods -n techmarket -l app=payment-service"
    fi
else
    error "Fichier litmus/pod-delete-experiment.yaml manquant"
fi

pause

step "Postmortem Blameless"
explain "Un postmortem est un document qui analyse un incident SANS blâmer les individus."
explain "Il se concentre sur les causes systémiques et les améliorations à apporter."
echo ""
if [ -f "sre/postmortem-chaos-experiment.md" ]; then
    success "Template postmortem présent : sre/postmortem-chaos-experiment.md"
else
    error "Template postmortem manquant"
fi

pause

# ============================================================================
# BLOC 4 - Tekton
# ============================================================================

section "BLOC 4 - Tekton (CI/CD Cloud-Native)"

step "Qu'est-ce que Tekton ?"
explain "Tekton est un framework CI/CD qui s'exécute nativement dans Kubernetes."
explain "Avantages par rapport à Jenkins :"
explain "  - Chaque pipeline run est un pod isolé"
explain "  - Pas de serveur central à maintenir"
explain "  - Définition en YAML (GitOps-friendly)"
echo ""

step "Vérification des pods Tekton"
run_cmd "kubectl get pods -n tekton-pipelines"

step "Tasks disponibles"
explain "Une Task est une unité de travail réutilisable (comme une fonction)"
echo ""
run_cmd "kubectl get tasks -n tekton-pipelines"

echo ""
echo -e "${CYAN}Description des Tasks :${NC}"
echo "  - git-clone    : Clone un repository Git"
echo "  - kaniko-build : Build une image Docker (sans daemon Docker)"
echo "  - trivy-scan   : Scanne l'image pour les vulnérabilités (CVE)"
echo "  - cosign-sign  : Signe l'image avec Sigstore/Cosign"
echo ""

pause

step "Pipeline build-and-push"
explain "Le Pipeline orchestre les Tasks dans l'ordre : clone → build → scan → sign"
echo ""
run_cmd "kubectl get pipelines -n tekton-pipelines"

step "Visualisation du workflow"
echo ""
echo -e "${CYAN}┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐${NC}"
echo -e "${CYAN}│ git-clone│───▶│  kaniko  │───▶│  trivy   │───▶│  cosign  │${NC}"
echo -e "${CYAN}│          │    │  build   │    │  scan    │    │  sign    │${NC}"
echo -e "${CYAN}└──────────┘    └──────────┘    └──────────┘    └──────────┘${NC}"
echo ""

step "Accès au Dashboard Tekton"
echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  Pour accéder au Dashboard Tekton :                             │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  ${BOLD}kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097${NC}${CYAN} │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  Puis ouvrir : ${BOLD}http://localhost:9097${NC}${CYAN}                            │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
echo ""

pause

step "Lancer un PipelineRun"
explain "Un PipelineRun est une instance d'exécution du Pipeline"
echo ""

echo -e "${CYAN}Pour lancer le pipeline pour payment-service :${NC}"
show_cmd "kubectl create -f tekton/pipelineruns/payment-service-run.yaml"
echo ""
echo -e "${CYAN}Pour suivre les logs :${NC}"
show_cmd "tkn pipelinerun logs -f -n tekton-pipelines"
echo ""

read -p "Voulez-vous lancer le pipeline maintenant ? (o/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Oo]$ ]]; then
    echo ""
    kubectl create -f tekton/pipelineruns/payment-service-run.yaml 2>/dev/null || echo "Pipeline déjà en cours ou erreur"
    echo ""
    echo "Pipeline lancé ! Utilisez 'tkn pipelinerun logs -f -n tekton-pipelines' pour suivre"
fi

pause

# ============================================================================
# Résumé Final
# ============================================================================

section "RÉSUMÉ - Vérification Finale"

echo -e "${BOLD}Checklist du TP :${NC}"
echo ""

# Vérifications
check_backstage=$(kubectl get pods -n backstage 2>/dev/null | grep -c Running || echo "0")
check_kyverno=$(kubectl get pods -n kyverno 2>/dev/null | grep -c Running || echo "0")
check_tekton=$(kubectl get pods -n tekton-pipelines 2>/dev/null | grep -c Running || echo "0")
check_litmus=$(kubectl get pods -n litmus 2>/dev/null | grep -c Running || echo "0")
check_policies=$(kubectl get clusterpolicies 2>/dev/null | grep -c -v NAME || echo "0")
check_tasks=$(kubectl get tasks -n tekton-pipelines 2>/dev/null | grep -c -v NAME || echo "0")

if [ "$check_backstage" -gt 0 ]; then
    success "BLOC 1 - Backstage : $check_backstage pods running"
else
    error "BLOC 1 - Backstage : Non déployé"
fi

if [ "$check_kyverno" -gt 0 ] && [ "$check_policies" -gt 0 ]; then
    success "BLOC 2 - Kyverno : $check_kyverno pods, $check_policies policies"
else
    error "BLOC 2 - Kyverno : Non fonctionnel"
fi

if [ "$check_litmus" -gt 0 ]; then
    success "BLOC 3 - Litmus : $check_litmus pods running"
else
    echo -e "${YELLOW}⚠ BLOC 3 - Litmus : Non déployé (optionnel)${NC}"
fi

if [ "$check_tekton" -gt 0 ] && [ "$check_tasks" -gt 0 ]; then
    success "BLOC 4 - Tekton : $check_tekton pods, $check_tasks tasks"
else
    error "BLOC 4 - Tekton : Non fonctionnel"
fi

echo ""
echo -e "${BOLD}Fichiers créés :${NC}"
echo ""

files=(
    "microservices/frontend/catalog-info.yaml"
    "microservices/backend/catalog-info.yaml"
    "microservices/payment-service/catalog-info.yaml"
    "backstage/template-nodejs-service.yaml"
    "kyverno/policy-deny-latest.yaml"
    "kyverno/policy-require-limits.yaml"
    "kyverno/policy-require-probes.yaml"
    "kyverno/policy-add-labels.yaml"
    "prometheus/payment-service-slo.yaml"
    "litmus/pod-delete-experiment.yaml"
    "sre/postmortem-chaos-experiment.md"
    "tekton/tasks/git-clone.yaml"
    "tekton/tasks/kaniko-build.yaml"
    "tekton/tasks/trivy-scan.yaml"
    "tekton/tasks/cosign-sign.yaml"
    "tekton/pipelines/build-and-push.yaml"
    "tekton/pipelineruns/payment-service-run.yaml"
)

for f in "${files[@]}"; do
    if [ -f "$f" ]; then
        success "$f"
    else
        error "$f (manquant)"
    fi
done

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Démonstration terminée !${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Prochaines étapes suggérées :"
echo "  1. Explorer l'interface Backstage (http://localhost:30000)"
echo "  2. Tester d'autres policies Kyverno"
echo "  3. Lancer un chaos experiment Litmus"
echo "  4. Observer un PipelineRun dans le Dashboard Tekton"
echo ""
