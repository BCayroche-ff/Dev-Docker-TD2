# Architecture - Solar Monitoring GitOps

## Vue d'ensemble

Cette plateforme de monitoring temps reel pour fermes solaires utilise une architecture GitOps avec ArgoCD pour le deploiement continu et une stack d'observabilite Prometheus/Grafana.

## Schema d'architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Git Repository                              │
│              (Source de verite - manifests K8s)                     │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 │ Pull-based sync (ArgoCD)
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster (Minikube)                   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Namespace: argocd                          │   │
│  │  ┌──────────────┐                                             │   │
│  │  │   ArgoCD     │ ◄─── Synchronise les manifests Git         │   │
│  │  │   Server     │                                             │   │
│  │  └──────────────┘                                             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Namespace: solar-prod                      │   │
│  │                                                               │   │
│  │  ┌─────────────────────────────────────────────────────────┐ │   │
│  │  │              Application Layer                           │ │   │
│  │  │                                                          │ │   │
│  │  │  ┌──────────────────┐      ┌──────────────────┐         │ │   │
│  │  │  │  Solar Simulator │      │  ConfigMap       │         │ │   │
│  │  │  │  (Node.js)       │◄─────│  (CSV Data)      │         │ │   │
│  │  │  │                  │      └──────────────────┘         │ │   │
│  │  │  │  Port: 3000      │                                   │ │   │
│  │  │  │  /metrics        │──────────────────────────┐        │ │   │
│  │  │  │  /health         │                          │        │ │   │
│  │  │  └──────────────────┘                          │        │ │   │
│  │  └────────────────────────────────────────────────│────────┘ │   │
│  │                                                   │          │   │
│  │  ┌────────────────────────────────────────────────│────────┐ │   │
│  │  │              Observability Stack               │        │ │   │
│  │  │                                                ▼        │ │   │
│  │  │  ┌──────────────────┐      ┌──────────────────┐        │ │   │
│  │  │  │   Prometheus     │◄─────│  AlertManager    │        │ │   │
│  │  │  │   Port: 9090     │      │  Port: 9093      │        │ │   │
│  │  │  │                  │      │                  │        │ │   │
│  │  │  │  - Scrape /30s   │      │  - Routing       │        │ │   │
│  │  │  │  - 5 Alert Rules │      │  - Notifications │        │ │   │
│  │  │  │  - Recording     │      │                  │        │ │   │
│  │  │  └────────┬─────────┘      └──────────────────┘        │ │   │
│  │  │           │                                             │ │   │
│  │  │           │ Datasource                                  │ │   │
│  │  │           ▼                                             │ │   │
│  │  │  ┌──────────────────┐                                   │ │   │
│  │  │  │    Grafana       │                                   │ │   │
│  │  │  │    Port: 3000    │                                   │ │   │
│  │  │  │                  │                                   │ │   │
│  │  │  │  - 6 Dashboards  │                                   │ │   │
│  │  │  │  - Variables     │                                   │ │   │
│  │  │  │  - Alertes       │                                   │ │   │
│  │  │  └──────────────────┘                                   │ │   │
│  │  └─────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Composants

### 1. Solar Simulator (Node.js)

**Role**: Simule les donnees des 3 fermes solaires en rejouant les fichiers CSV.

**Technologies**:
- Node.js 20 Alpine
- Express.js (serveur HTTP)
- prom-client (metriques Prometheus)
- csv-parse (lecture CSV)

**Endpoints**:
| Endpoint | Description |
|----------|-------------|
| `GET /metrics` | Metriques au format Prometheus |
| `GET /health` | Liveness probe |
| `GET /ready` | Readiness probe |
| `GET /status` | Etat du simulateur |
| `GET /data` | Donnees actuelles toutes fermes |
| `GET /data/:farm` | Donnees d'une ferme |

**Ressources**:
- CPU: 100m request / 200m limit
- Memory: 128Mi request / 256Mi limit

### 2. Prometheus

**Role**: Collecte et stockage des metriques, evaluation des alertes.

**Configuration**:
- Scrape interval: 30s
- Retention: 7 jours
- 5 regles d'alerting
- Recording rules pour agregations

**Metriques collectees**:
- `solar_power_production_kw` - Production instantanee
- `solar_panel_temperature_celsius` - Temperature panneaux
- `solar_inverter_status` - Etat onduleurs
- `solar_availability_percent` - Disponibilite
- `solar_daily_revenue_euros` - Revenus

### 3. Grafana

**Role**: Visualisation des metriques et alertes.

**Configuration**:
- Datasource Prometheus auto-configure
- Dashboard "Solar Monitoring" provisionne
- 6 panneaux (Gauge, TimeSeries, Heatmap, Stat, BarChart, Table)

**Acces**: admin / admin

### 4. AlertManager

**Role**: Routage et notification des alertes.

**Configuration**:
- Groupement par alertname, farm, severity
- Receivers differencies (critical vs warning)
- Inhibit rules pour eviter les doublons

### 5. ArgoCD

**Role**: Deploiement GitOps automatise.

**Applications**:
- `solar-simulator` - Deploie l'application
- `solar-monitoring` - Deploie la stack d'observabilite

**Sync Policy**:
- Automated sync
- Self-heal active
- Prune active

## Flux de donnees

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐     ┌──────────┐
│  CSV Data   │────▶│  Simulator   │────▶│ Prometheus │────▶│  Grafana │
│  (30 jours) │     │  (Node.js)   │     │  (scrape)  │     │ (display)│
└─────────────┘     └──────────────┘     └────────────┘     └──────────┘
                           │                    │
                           │                    ▼
                           │              ┌────────────┐
                           │              │ AlertMgr   │
                           │              │ (routing)  │
                           │              └────────────┘
                           ▼
                    ┌──────────────┐
                    │   /metrics   │
                    │   endpoint   │
                    └──────────────┘
```

## Fermes solaires simulees

| Ferme | Localisation | Panneaux | Capacite | Onduleurs |
|-------|--------------|----------|----------|-----------|
| Provence | Marseille | 5000 | 2.0 MW | 4 |
| Occitanie | Montpellier | 3500 | 1.4 MW | 3 |
| Aquitaine | Bordeaux | 4200 | 1.68 MW | 4 |

**Capacite totale**: 5.08 MW

## Alertes configurees

| Alerte | Condition | Severite | For |
|--------|-----------|----------|-----|
| SolarPanelOverheating | temp > 65C | critical | 10m |
| InverterDown | status = 0 | critical | 1m |
| LowProductionEfficiency | production < 50% theorique | warning | 15m |
| SensorDataLoss | pas de donnees > 5min | warning | 5m |
| SLOAvailabilityBreach | disponibilite < 99.5% | critical | 5m |

## SLO/SLI

| SLI | Objectif (SLO) | Mesure |
|-----|----------------|--------|
| Disponibilite | 99.5% | Ratio onduleurs actifs |
| Detection anomalie | < 2 min | Temps entre anomalie et alerte |
| Temps de scrape | < 30s | Intervalle Prometheus |

## Structure des fichiers

```
TP-Jour4/
├── src/solar-simulator/       # Application Node.js
│   ├── src/
│   │   ├── index.js           # Point d'entree Express
│   │   ├── config/farms.js    # Configuration fermes
│   │   └── services/          # Services metier
│   ├── tests/                 # Tests unitaires
│   ├── Dockerfile             # Image Docker
│   └── package.json
├── k8s/                       # Manifests Kubernetes
│   ├── base/                  # Namespace
│   ├── apps/solar-simulator/  # Deployment simulateur
│   ├── monitoring/            # Prometheus, Grafana, AlertManager
│   └── argocd/                # Applications ArgoCD
├── data/                      # Dataset CSV
├── docs/                      # Documentation
└── scripts/                   # Scripts setup/demo
```

## Considerations de securite

1. **Pods non-root**: Tous les pods tournent avec un utilisateur non-root
2. **Network policies**: Isolation namespace (a ajouter en production)
3. **RBAC**: ServiceAccount Prometheus avec permissions minimales
4. **Secrets**: Credentials Grafana/ArgoCD (a externaliser en production)

## Scalabilite

Pour passer en production:

1. **Haute disponibilite**: Replicas > 1 pour chaque composant
2. **Stockage persistant**: PVC pour Prometheus et Grafana
3. **Ingress**: Exposition via Ingress Controller
4. **TLS**: Certificats pour tous les endpoints
5. **Multi-cluster**: Federation Prometheus pour plusieurs sites
