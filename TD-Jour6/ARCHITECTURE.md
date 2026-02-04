# ARCHITECTURE.md - CloudShop Platform

## Vue d'ensemble

CloudShop est une plateforme e-commerce Cloud Native composee de 5 microservices, deployee sur Kubernetes avec GitOps (ArgoCD), monitored par Prometheus/Grafana, et securisee par Kyverno et Falco.

## Architecture microservices

```
                    +------------------+
                    |   Navigateur     |
                    +--------+---------+
                             |
                    +--------v---------+
                    |  Frontend React  |  Port 3000 (Compose) / 80 (K8s)
                    |  Nginx + Vite    |
                    +--------+---------+
                             |
                    +--------v---------+
                    |   API Gateway    |  Port 8080
                    |  Node.js Express |
                    +--+-----+-----+--+
                       |     |     |
          +------------+     |     +------------+
          |                  |                  |
+---------v------+  +--------v-------+  +-------v--------+
|  Auth Service  |  |  Products API  |  |  Orders API    |
|  Node.js JWT   |  |  Python FastAPI|  |  Go HTTP       |
|  Port 8081     |  |  Port 8082     |  |  Port 8083     |
+--------+-------+  +--------+------+  +--------+-------+
         |                   |                   |
         +-------------------+-------------------+
                             |
                    +--------v---------+
                    |   PostgreSQL 17  |
                    |   StatefulSet    |
                    +------------------+
```

## Services

| Service | Technologie | Role | Port |
|---------|------------|------|------|
| Frontend | React 18 + Vite 5 + Nginx 1.27 | Interface utilisateur SPA | 80 |
| API Gateway | Node.js 22 + Express | Point d'entree unique, proxy, CORS | 8080 |
| Auth Service | Node.js 22 + JWT + bcryptjs | Authentification, gestion utilisateurs | 8081 |
| Products API | Python 3.13 + FastAPI | CRUD produits, catalogue | 8082 |
| Orders API | Go 1.23 | CRUD commandes | 8083 |
| PostgreSQL | PostgreSQL 17 Alpine | Base de donnees relationnelle | 5432 |

Tous les services backend exposent `/health` (healthcheck) et `/metrics` (Prometheus).

## Choix Docker (Partie 1)

### Multi-stage builds

Chaque Dockerfile utilise un pattern multi-stage pour minimiser la taille des images de production :

| Service | Stage build | Stage runtime | Taille cible |
|---------|-----------|---------------|-------------|
| Frontend | node:22-alpine | nginx:1.27-alpine | < 50 MB |
| API Gateway | - | node:22-alpine | < 150 MB |
| Auth Service | - | node:22-alpine | < 150 MB |
| Products API | python:3.13-slim (gcc) | python:3.13-slim | < 180 MB |
| Orders API | golang:1.23-alpine | alpine:3.20 | < 20 MB |

### Securite des images

- **Utilisateur non-root** : `USER appuser` (UID 1001) sur tous les services, `USER nginx` (UID 101) pour le frontend
- **HEALTHCHECK** Docker natif sur chaque service
- **`.dockerignore`** pour exclure node_modules, .env, .git du contexte de build
- **Production only** : `npm ci --only=production`, `--no-cache-dir` pour pip

### Docker Compose

- Fichier `compose.yaml` (standard Compose V2)
- Reseau dedie `cloudshop-net` (bridge)
- Volume nomme `postgres-data` pour la persistance PostgreSQL
- `depends_on` avec `condition: service_healthy` pour l'ordonnancement
- Variables sensibles via `.env` (non commite)

## Choix Kubernetes (Partie 2)

### Organisation

- **Namespace** `cloudshop-prod` avec label `environment: production`
- **ConfigMap** `app-config` : URLs internes, LOG_LEVEL, NODE_ENV
- **Secrets** `db-credentials` et `jwt-secret` : credentials base64

### StatefulSet PostgreSQL

- StatefulSet (pas Deployment) car PostgreSQL est stateful
- Headless Service (`clusterIP: None`) pour DNS stable
- VolumeClaimTemplate pour PVC automatique
- PGDATA configure dans un sous-repertoire pour eviter les conflits
- Probes avec `pg_isready`

### Deployments

- Replicas : 3 pour API Gateway (point critique), 2 pour les autres
- Resources requests/limits sur CPU et memoire
- Probes liveness + readiness HTTP sur `/health`
- SecurityContext : `runAsNonRoot: true`, `allowPrivilegeEscalation: false`
- Tags versionnees (`v1.0.0`) au lieu de `latest`

### Networking

- 5 Services ClusterIP (pas d'exposition directe)
- Ingress Traefik : `shop.local` (frontend) et `api.local` (API Gateway)

## Choix GitOps - ArgoCD (Partie 3)

### Pattern App-of-Apps

4 applications separees par domaine fonctionnel, gerees par une application racine :

1. `cloudshop-infrastructure` : namespace, configmaps, secrets
2. `cloudshop-database` : StatefulSet PostgreSQL
3. `cloudshop-backend` : deployments et services backend
4. `cloudshop-frontend` : deployment frontend + ingress

### Sync Policies

- **Auto-sync** : synchronisation automatique depuis Git
- **Prune** : suppression auto des ressources retirees de Git
- **Self-heal** : reconciliation auto si modification manuelle
- **Retry** : 5 tentatives avec backoff exponentiel (5s a 3min)

## Choix Observabilite (Partie 4)

### Stack

- **Prometheus Operator** (kube-prometheus-stack) pour les metriques
- **Grafana** pour la visualisation
- **Alertmanager** pour le routage des alertes

### ServiceMonitors

Un ServiceMonitor par service backend (4 au total), scraping `/metrics` toutes les 30s.

### Dashboards Grafana

1. **CloudShop Overview** : Request Rate, Error Rate, P95 Latency, Pods Status
2. **SLO Monitoring** : Availability gauge, Error Budget, Burn Rate, Downtime Budget

### Alertes (6 regles)

| Alerte | Condition | Severite |
|--------|-----------|----------|
| HighErrorRate | Taux 5xx > 5% sur 5min | warning |
| HighLatencyP95 | P95 > 1s sur 10min | warning |
| PodCrashLooping | Restarts > 0 sur 15min | critical |
| PodNotReady | Phase != Running > 5min | warning |
| HighMemoryUsage | > 80% limits sur 10min | warning |
| SLOBreach | Availability < 99.9% sur 30min | critical |

### SLO / Error Budget

- **SLO** : 99.9% disponibilite sur 30 jours glissants
- **Error Budget** : 43.2 minutes de downtime autorise par mois
- **SLI Availability** : ratio requetes reussies (status != 5xx)
- **SLI Latency** : P95 < 500ms

## Choix Securite & SRE (Partie 5)

### Kyverno - Policy as Code

3 ClusterPolicies en mode **Enforce** :

1. `disallow-latest-tag` : interdit le tag `latest` dans cloudshop-prod
2. `require-resources` : exige requests et limits CPU/memoire
3. `disallow-privileged` : interdit les conteneurs privilegies

+ 1 policy `verify-image-signature` (mode Audit) pour la verification Cosign

### Falco - Runtime Security

4 regles de detection :
- Shell dans les conteneurs CloudShop
- Ecriture dans /root
- Acces aux fichiers sensibles (/etc/shadow, /etc/passwd)
- Connexions reseau inattendues

### CI/CD - GitHub Actions

Pipeline complet (`.github/workflows/docker-ci.yml`) :
1. Build Docker avec Buildx et cache GHA
2. Push vers ghcr.io
3. Signature Cosign
4. SBOM avec Syft (SPDX-JSON)
5. Attestation SBOM avec Cosign
6. Scan Trivy avec upload SARIF

### Chaos Engineering - Litmus

- Experience `pod-delete` sur le frontend
- Suppression de 50% des pods pendant 30 secondes
- Probe HTTP continue pour verifier la disponibilite
- RBAC dedie avec permissions minimales

## Structure du projet

```
TD-Jour6/
  src/                          # Code source des microservices
    frontend/                   # React + Vite -> Nginx
    api-gateway/                # Node.js Express (proxy)
    auth-service/               # Node.js JWT auth
    products-api/               # Python FastAPI CRUD
    orders-api/                 # Go HTTP server CRUD
  k8s/                          # Manifests Kubernetes
    namespaces/                 # Namespace cloudshop-prod
    configs/configmaps/         # Configuration applicative
    configs/secrets/            # Credentials (base64)
    deployments/                # 5 Deployments
    services/                   # 5 Services ClusterIP
    statefulsets/               # PostgreSQL StatefulSet + PVC
    ingress/                    # Traefik Ingress
  argocd/apps/                  # Applications ArgoCD (GitOps)
  monitoring/                   # Observabilite
    servicemonitors/            # Prometheus scraping
    alerts/                     # PrometheusRules
    dashboards/                 # Grafana JSON dashboards
    error-budget/               # Queries PromQL SLO
  policies/                     # Securite
    kyverno/                    # ClusterPolicies
    falco/                      # Regles runtime security
  chaos/                        # Chaos Engineering
    experiments/                # ChaosEngine pod-delete
    rbac/                       # ServiceAccount Litmus
  .github/workflows/            # CI/CD pipeline
  compose.yaml                  # Docker Compose V2 (dev local)
  .env                          # Variables d'environnement (gitignore)
```
