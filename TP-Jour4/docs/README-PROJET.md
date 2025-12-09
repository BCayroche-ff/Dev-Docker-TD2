# Solar Monitoring GitOps

Plateforme de monitoring temps reel pour 3 fermes solaires photovoltaiques, deployee via GitOps avec ArgoCD et une stack d'observabilite Prometheus/Grafana.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Git Repository                          │
│              (Source de verite GitOps)                      │
└────────────────────────┬────────────────────────────────────┘
                         │ Pull-based sync
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                Kubernetes Cluster                           │
│  ┌─────────────┐  ┌───────────────────────────────────────┐ │
│  │   ArgoCD    │  │        Namespace: solar-prod          │ │
│  └─────────────┘  │  ┌─────────────┐  ┌──────────────┐    │ │
│                   │  │  Simulator  │─▶│  Prometheus  │    │ │
│                   │  │  (Node.js)  │  │  (Metrics)   │    │ │
│                   │  └─────────────┘  └──────┬───────┘    │ │
│                   │                          │            │ │
│                   │  ┌─────────────┐  ┌──────▼───────┐    │ │
│                   │  │ AlertManager│  │   Grafana    │    │ │
│                   │  │  (Alertes)  │  │ (Dashboard)  │    │ │
│                   │  └─────────────┘  └──────────────┘    │ │
│                   └───────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Fonctionnalites

- **Simulation temps reel** de 3 fermes solaires (Provence, Occitanie, Aquitaine)
- **Replay des donnees CSV** reelles (30 jours de production)
- **Metriques Prometheus** exposees au format standard
- **5 alertes** configurees (surchauffe, panne onduleur, production basse, perte capteur, SLO)
- **Dashboard Grafana** avec 6 panneaux (production, temperature, SLO, revenus, alertes)
- **Deploiement GitOps** avec ArgoCD

## Installation rapide

```bash
# Prerequis: Docker, kubectl, minikube

# 1. Cloner le repository
https://github.com/BCayroche-ff/Dev-Docker-TD2.git
cd TP-Jour4

# 2. Lancer l'installation automatique
./scripts/setup.sh

# 3. Acceder aux services (dans des terminaux separes)
kubectl port-forward svc/grafana -n solar-prod 3000:3000
kubectl port-forward svc/prometheus -n solar-prod 9090:9090
kubectl port-forward svc/argocd-server -n argocd 8080:443

Ou bien démarrer le script demo:
./scripts/demo.sh
```

## Acces aux services

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| ArgoCD | https://localhost:8080 | admin / (voir setup) |
| Simulateur | http://localhost:3001 | - |

## Metriques exposees

```prometheus
# Production
solar_power_production_kw{farm="provence"} 1850.5
solar_power_theoretical_kw{farm="provence"} 2000.0

# Temperature
solar_panel_temperature_celsius{farm="provence"} 42.3

# Onduleurs
solar_inverter_status{farm="provence",inverter_id="1"} 1

# SLO
solar_availability_percent{farm="provence"} 99.8

# Revenus
solar_daily_revenue_euros{farm="provence"} 1250.80
```

## Alertes

| Alerte | Condition | Severite |
|--------|-----------|----------|
| SolarPanelOverheating | temp > 65C pendant 10min | critical |
| InverterDown | status = 0 | critical |
| LowProductionEfficiency | < 50% theorique | warning |
| SensorDataLoss | pas de donnees > 5min | warning |
| SLOAvailabilityBreach | < 99.5% | critical |

## Structure du projet

```
solar-monitoring-gitops/
├── src/solar-simulator/    # Application Node.js
│   ├── src/               # Code source
│   ├── tests/             # Tests unitaires
│   └── Dockerfile         # Image Docker
├── k8s/                   # Manifests Kubernetes
│   ├── apps/              # Deployment simulateur
│   ├── monitoring/        # Prometheus, Grafana, AlertManager
│   └── argocd/            # Applications ArgoCD
├── data/                  # Dataset CSV (30 jours)
├── docs/                  # Documentation
└── scripts/               # Scripts setup/demo
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Installation](docs/INSTALLATION.md)
- [Dataset](data/README_DATASET.md)

## Troubleshooting

### Metriques non collectees

```bash
# Verifier les targets Prometheus
curl http://localhost:9090/api/v1/targets
```

### Pods en erreur

```bash
kubectl logs -f deploy/solar-simulator -n solar-prod
kubectl describe pod -l app=solar-simulator -n solar-prod
```

### ArgoCD out of sync

```bash
kubectl get applications -n argocd
argocd app sync solar-simulator
```

## Ameliorations futures

1. **Haute disponibilite**: Replicas > 1
2. **Stockage persistant**: PVC pour Prometheus
3. **Alertes Slack/Email**: Webhooks AlertManager
4. **ML predictions**: Prediction de pannes
5. **Multi-cluster**: Federation Prometheus

## FinOps - Estimation des couts

| Composant | CPU | Memory | Stockage | Cout/mois |
|-----------|-----|--------|----------|-----------|
| Simulator | 100-200m | 128-256Mi | 0 | ~5 EUR |
| Prometheus | 200-500m | 512Mi-1Gi | 10GB | ~19 EUR |
| Grafana | 100-200m | 256-512Mi | 2GB | ~8 EUR |
| AlertManager | 50-100m | 64-128Mi | 1GB | ~3 EUR |
| **TOTAL** | | | | **~35 EUR** |

*Hypotheses: Cloud provider standard, 0.05 EUR/CPU-hour, 0.01 EUR/GB-hour*

### Optimisations proposees

1. **Reduction de la retention Prometheus** (Economie: ~4 EUR/mois)
   - Avant: retention 15 jours par defaut
   - Apres: retention 7 jours (`--storage.tsdb.retention.time=7d`)
   - Justification: Les donnees historiques peuvent etre archivees dans un stockage objet moins couteux

2. **Right-sizing des ressources simulateur** (Economie: ~2 EUR/mois)
   - Avant: `requests.cpu: 200m`, `limits.cpu: 400m`
   - Apres: `requests.cpu: 100m`, `limits.cpu: 200m`
   - Justification: Apres analyse des metriques, le simulateur utilise en moyenne 50m CPU

3. **Activation de la compression TSDB** (Economie: ~1.50 EUR/mois)
   - Configuration: `--storage.tsdb.wal-compression`
   - Justification: Reduction de 30-40% du stockage sans impact sur les performances de lecture
