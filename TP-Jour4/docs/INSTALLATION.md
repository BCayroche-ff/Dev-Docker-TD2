# Guide d'Installation - Solar Monitoring GitOps

## Prerequis

### Logiciels requis

| Logiciel | Version minimale | Verification |
|----------|-----------------|--------------|
| Docker | 20.10+ | `docker --version` |
| kubectl | 1.25+ | `kubectl version --client` |
| Minikube | 1.30+ | `minikube version` |
| Node.js | 18+ (optionnel) | `node --version` |
| Git | 2.30+ | `git --version` |

### Ressources systeme

- **CPU**: 2 cores minimum (4 recommandes)
- **RAM**: 4 GB minimum (8 GB recommandes)
- **Disque**: 10 GB disponibles

## Installation rapide

### Option 1: Script automatise (recommande)

```bash
# Cloner le repository
git clone https://github.com/YOUR_USERNAME/solar-monitoring-gitops.git
cd solar-monitoring-gitops

# Executer le script d'installation
./scripts/setup.sh
```

Le script effectue automatiquement:
1. Verification des prerequis
2. Creation du cluster Minikube
3. Installation d'ArgoCD
4. Build de l'image Docker
5. Deploiement des composants

### Option 2: Installation manuelle

#### Etape 1: Creer le cluster Minikube

```bash
# Creer le cluster
minikube start -p solar-monitoring \
    --cpus=2 \
    --memory=4096 \
    --driver=docker \
    --kubernetes-version=v1.28.0

# Verifier le cluster
kubectl get nodes
```

#### Etape 2: Installer ArgoCD

```bash
# Creer le namespace
kubectl create namespace argocd

# Installer ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Attendre le demarrage
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Recuperer le mot de passe admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### Etape 3: Creer le namespace de l'application

```bash
kubectl apply -f k8s/base/namespace.yaml
```

#### Etape 4: Build de l'image Docker

```bash
# Configurer Docker pour Minikube
eval $(minikube -p solar-monitoring docker-env)

# Copier les donnees CSV
cd src/solar-simulator
mkdir -p data
cp ../../data/*.csv data/

# Builder l'image
docker build -t solar-simulator:latest .
```

#### Etape 5: Deployer les composants

```bash
# Deployer le simulateur
kubectl apply -k k8s/apps/solar-simulator

# Deployer Prometheus
kubectl apply -k k8s/monitoring/prometheus

# Deployer Grafana
kubectl apply -k k8s/monitoring/grafana

# Deployer AlertManager
kubectl apply -k k8s/monitoring/alertmanager

# Verifier les deployments
kubectl get pods -n solar-prod
```

## Configuration GitOps avec ArgoCD

### Configurer les applications ArgoCD

1. **Modifier les URLs du repository** dans les fichiers:
   - `k8s/argocd/application-solar.yaml`
   - `k8s/argocd/application-monitoring.yaml`

   Remplacer `YOUR_USERNAME` par votre username GitHub.

2. **Appliquer les applications**:

```bash
kubectl apply -f k8s/argocd/application-solar.yaml
kubectl apply -f k8s/argocd/application-monitoring.yaml
```

3. **Verifier la synchronisation**:

```bash
kubectl get applications -n argocd
```

## Acces aux services

### Port-forwarding

Ouvrir plusieurs terminaux et executer:

```bash
# Terminal 1: ArgoCD (https://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Terminal 2: Grafana (http://localhost:3000)
kubectl port-forward svc/grafana -n solar-prod 3000:3000

# Terminal 3: Prometheus (http://localhost:9090)
kubectl port-forward svc/prometheus -n solar-prod 9090:9090

# Terminal 4: Simulateur (http://localhost:3001)
kubectl port-forward svc/solar-simulator -n solar-prod 3001:3000
```

### URLs et credentials

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | https://localhost:8080 | admin / (voir commande) |
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| Simulateur | http://localhost:3001 | - |

## Verification de l'installation

### Verifier les pods

```bash
kubectl get pods -n solar-prod
```

Tous les pods doivent etre en status `Running`:

```
NAME                               READY   STATUS    RESTARTS   AGE
solar-simulator-xxx                1/1     Running   0          5m
prometheus-xxx                     1/1     Running   0          5m
grafana-xxx                        1/1     Running   0          5m
alertmanager-xxx                   1/1     Running   0          5m
```

### Verifier les metriques

```bash
# Port-forward le simulateur
kubectl port-forward svc/solar-simulator -n solar-prod 3001:3000 &

# Tester l'endpoint metrics
curl http://localhost:3001/metrics | head -20

# Tester le health check
curl http://localhost:3001/health
```

### Verifier Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus -n solar-prod 9090:9090 &

# Tester une requete
curl 'http://localhost:9090/api/v1/query?query=solar_power_production_kw'
```

## Troubleshooting

### Probleme: Pods en CrashLoopBackOff

```bash
# Voir les logs du pod
kubectl logs -f deploy/solar-simulator -n solar-prod

# Voir les events
kubectl describe pod -l app=solar-simulator -n solar-prod
```

### Probleme: Metriques non collectees

1. Verifier que le ServiceMonitor existe:
```bash
kubectl get servicemonitor -n solar-prod
```

2. Verifier les labels du Service:
```bash
kubectl get svc solar-simulator -n solar-prod -o yaml | grep -A5 labels
```

3. Verifier les targets Prometheus:
   - Aller sur http://localhost:9090/targets
   - Verifier que `solar-simulator` est UP

### Probleme: ArgoCD ne synchronise pas

1. Verifier la connectivite au repository:
```bash
kubectl logs -f deploy/argocd-repo-server -n argocd
```

2. Verifier l'application:
```bash
kubectl get application solar-simulator -n argocd -o yaml
```

### Probleme: Minikube ne demarre pas

```bash
# Supprimer et recreer
minikube delete -p solar-monitoring
minikube start -p solar-monitoring --driver=docker
```

## Desinstallation

### Supprimer les composants

```bash
# Supprimer les deployments
kubectl delete -k k8s/monitoring/
kubectl delete -k k8s/apps/solar-simulator/
kubectl delete -k k8s/base/

# Supprimer ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

### Supprimer le cluster

```bash
minikube delete -p solar-monitoring
```

## Developpement local

### Lancer le simulateur en local

```bash
cd src/solar-simulator

# Installer les dependances
npm install

# Copier les donnees CSV
mkdir -p data
cp ../../data/*.csv data/

# Demarrer le simulateur
npm start

# Ou en mode watch
npm run dev
```

### Lancer les tests

```bash
cd src/solar-simulator
npm test
```

### Reconstruire l'image

```bash
# Configurer Docker pour Minikube
eval $(minikube -p solar-monitoring docker-env)

# Rebuild
cd src/solar-simulator
docker build -t solar-simulator:latest .

# Restart le deployment pour utiliser la nouvelle image
kubectl rollout restart deploy/solar-simulator -n solar-prod
```
