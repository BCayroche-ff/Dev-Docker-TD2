/**
 * ${{ values.serviceName }}
 * ${{ values.description }}
 *
 * Généré par le Golden Path Template TechMarket
 * Owner: ${{ values.owner }}
 */

const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');

const app = express();
const PORT = process.env.PORT || ${{ values.port }};

// Configuration du logging structuré
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: '${{ values.serviceName }}' },
  transports: [new winston.transports.Console()]
});

// Métriques Prometheus
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total des requêtes HTTP',
  labelNames: ['method', 'path', 'status'],
  registers: [register]
});

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Durée des requêtes HTTP en secondes',
  labelNames: ['method', 'path'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register]
});

// Middleware pour les métriques
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestsTotal.inc({ method: req.method, path: req.path, status: res.statusCode });
    httpRequestDuration.observe({ method: req.method, path: req.path }, duration);
  });
  next();
});

app.use(express.json());

// Health checks
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: '${{ values.serviceName }}' });
});

app.get('/ready', (req, res) => {
  // Ajouter ici les vérifications de readiness (DB, dépendances, etc.)
  res.json({ status: 'ready', service: '${{ values.serviceName }}' });
});

app.get('/healthz', (req, res) => {
  res.json({ status: 'alive' });
});

// Métriques Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Route principale - À personnaliser
app.get('/', (req, res) => {
  logger.info('Request received on /');
  res.json({
    service: '${{ values.serviceName }}',
    version: '1.0.0',
    message: 'Service opérationnel'
  });
});

// Démarrage du serveur
app.listen(PORT, () => {
  logger.info(`${{ values.serviceName }} démarré sur le port ${PORT}`);
});
