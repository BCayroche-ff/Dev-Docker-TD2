# Postmortem - Chaos Experiment Pod Delete

**Date de l'incident** : 2026-01-12
**Auteur** : Platform Team
**Réviseurs** : SRE Team, Payments Team
**Statut** : Final

---

## Résumé Exécutif

Le 12 janvier 2026, un chaos experiment "pod-delete" a été exécuté sur le payment-service pour valider sa résilience. L'experiment a supprimé 1 pod sur 3 toutes les 10 secondes pendant 30 secondes. Le service est resté disponible avec un taux de succès de 100% grâce aux replicas restants et au PodDisruptionBudget.

---

## Impact

| Métrique | Valeur |
|----------|--------|
| **Durée de l'experiment** | 30 secondes |
| **Pods supprimés** | 3 pods (recréés automatiquement) |
| **Utilisateurs impactés** | 0 |
| **Transactions échouées** | 0 |
| **Success Rate minimum** | 100% (SLO: 99.9%) |
| **Error Budget consommé** | 0% |

**Services affectés** :
- ⚠️ payment-service (pods redémarrés)
- ✅ backend-api (non impacté)
- ✅ frontend-app (non impacté)

---

## Chronologie

| Heure | Événement | Acteur/Système |
|-------|-----------|----------------|
| 15:50:00 | Début du chaos experiment | Litmus ChaosEngine |
| 15:50:00 | Premier pod payment-service-xxx supprimé | Litmus |
| 15:50:02 | Kubernetes détecte le pod manquant | ReplicaSet Controller |
| 15:50:03 | Nouveau pod créé pour remplacer celui supprimé | ReplicaSet Controller |
| 15:50:08 | Nouveau pod Ready, reçoit du trafic | Kubernetes Service |
| 15:50:10 | Deuxième pod supprimé | Litmus |
| 15:50:12 | Remplacement du deuxième pod initié | ReplicaSet Controller |
| 15:50:17 | Deuxième pod Ready | Kubernetes Service |
| 15:50:20 | Troisième pod supprimé | Litmus |
| 15:50:30 | Fin du chaos experiment | Litmus |
| 15:50:35 | Tous les pods à nouveau Running | Kubernetes |

---

## Analyse

### Ce qui a bien fonctionné

1. **Kubernetes ReplicaSet** : Les pods ont été recréés automatiquement en quelques secondes
2. **PodDisruptionBudget** : Garantit qu'au moins 2 pods restent disponibles
3. **Service Load Balancing** : Le trafic a été automatiquement redirigé vers les pods sains
4. **ReadinessProbe** : Les nouveaux pods n'ont reçu du trafic qu'une fois prêts
5. **Replicas = 3** : Suffisant pour absorber la perte d'un pod sans impact utilisateur

### Points d'amélioration identifiés

1. **Monitoring** : Ajouter des alertes spécifiques pour les restarts de pods
2. **Logs** : Améliorer la corrélation entre les événements Kubernetes et les métriques applicatives
3. **Documentation** : Créer un runbook pour les incidents de type "pod crash"

---

## Méthode des 5 Pourquoi

1. **Pourquoi les pods ont-ils été supprimés ?**
   - Parce qu'un chaos experiment a été déclenché volontairement.

2. **Pourquoi avons-nous déclenché cet experiment ?**
   - Pour valider la résilience du payment-service avant un incident réel.

3. **Pourquoi est-ce important de valider la résilience ?**
   - Parce que le payment-service est critique et qu'un downtime impacte directement les revenus.

4. **Pourquoi le service est-il resté disponible malgré les suppressions ?**
   - Grâce aux bonnes pratiques : 3 replicas, PDB, readinessProbe, HPA.

5. **Pourquoi avons-nous ces bonnes pratiques en place ?**
   - Parce que le Golden Path template les inclut par défaut.

---

## Actions Correctives

| Action | Responsable | Deadline | Statut |
|--------|-------------|----------|--------|
| Ajouter alerte "High Pod Restart Rate" | SRE Team | 2026-01-19 | ⏳ Todo |
| Créer runbook "Payment Service Pod Failures" | Platform Team | 2026-01-22 | ⏳ Todo |
| Documenter les résultats du chaos experiment | Platform Team | 2026-01-12 | ✅ Done |
| Planifier un experiment network-latency | SRE Team | 2026-01-26 | ⏳ Todo |
| Revoir les SLOs avec l'équipe Payments | SRE + Payments | 2026-01-30 | ⏳ Todo |

---

## Leçons Apprises

### Pour les Développeurs
- **Les replicas ne sont pas optionnels** : Un seul pod = single point of failure
- **Les probes sont critiques** : Sans readinessProbe, les nouveaux pods recevraient du trafic avant d'être prêts

### Pour la Platform Team
- **Le chaos engineering fonctionne** : Il a validé nos hypothèses de résilience
- **Les Golden Paths portent leurs fruits** : Les bonnes pratiques intégrées par défaut ont protégé le service

### Pour l'Organisation
- **Tester en production (contrôlée)** : Le chaos engineering permet de découvrir les faiblesses avant les vrais incidents
- **La résilience est un investissement** : 3 replicas coûtent plus cher que 1, mais évitent les incidents coûteux

---

## Annexes

### Configuration du Payment Service

```yaml
# Extraits de payment-service.yaml
spec:
  replicas: 3                    # Haute disponibilité

  # PodDisruptionBudget
  minAvailable: 2                # Au moins 2 pods pendant les perturbations

  # Probes
  readinessProbe:
    httpGet:
      path: /ready
      port: 8081
    initialDelaySeconds: 5       # Attend que le pod soit vraiment prêt

  livenessProbe:
    httpGet:
      path: /healthz
      port: 8081
    failureThreshold: 3          # 3 échecs avant restart
```

### Métriques pendant l'experiment

```
# Success Rate (stable à 100%)
payment_service:success_rate:ratio = 1.0

# Latency P95 (légère augmentation due aux cold starts)
payment_service:latency:p95 = 0.15s → 0.22s → 0.16s

# Error Budget (non impacté)
payment_service:error_budget:remaining_percent = 100%
```

---

## Conclusion

Ce chaos experiment a validé que le payment-service est résilient aux pannes de pods. Les mécanismes de Kubernetes (ReplicaSet, Service, PDB) fonctionnent comme prévu. Aucune action corrective urgente n'est requise, mais des améliorations de monitoring sont recommandées.

**Note** : Ce postmortem est blameless. L'objectif est d'apprendre et d'améliorer nos systèmes.

---

*Rédigé selon le template SRE TechMarket*
