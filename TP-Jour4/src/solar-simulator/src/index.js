/**
 * Solar Simulator - Point d'entree principal
 * Simulateur de donnees pour fermes solaires photovoltaiques
 *
 * Endpoints:
 * - GET /metrics : Metriques Prometheus
 * - GET /health : Health check
 * - GET /status : Etat du replay
 * - GET /data/:farm : Donnees actuelles d'une ferme
 */

const express = require('express');
const path = require('path');

const { loadAllFarms, getDatasetStats } = require('./services/csvLoader');
const DataPlayer = require('./services/dataPlayer');
const { updateAllMetrics, getMetrics, getContentType } = require('./services/metricsExporter');
const { FARMS_CONFIG, CONSTANTS } = require('./config/farms');

// Configuration
const PORT = process.env.PORT || 3000;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '../../data');
const UPDATE_INTERVAL = parseInt(process.env.UPDATE_INTERVAL) || CONSTANTS.SCRAPE_INTERVAL_MS;

// Initialisation Express
const app = express();
app.use(express.json());

// Variables globales
let dataPlayer = null;
let startTime = Date.now();

/**
 * Initialise le simulateur
 */
async function initialize() {
  console.log('='.repeat(60));
  console.log('  SOLAR SIMULATOR - TP GitOps & Observabilite');
  console.log('='.repeat(60));
  console.log(`[INIT] Demarrage du simulateur...`);
  console.log(`[INIT] Repertoire donnees: ${DATA_DIR}`);

  // Charger les donnees CSV
  console.log('[INIT] Chargement des fichiers CSV...');
  const farmsData = loadAllFarms(DATA_DIR);

  // Afficher les statistiques
  const stats = getDatasetStats(farmsData);
  console.log(`[INIT] Dataset charge: ${stats.totalRecords} enregistrements`);
  console.log(`[INIT] Fermes: ${Object.keys(stats.recordsPerFarm).join(', ')}`);
  console.log(`[INIT] Anomalies: ${JSON.stringify(stats.anomalyCounts)}`);

  // Initialiser le lecteur de donnees
  dataPlayer = new DataPlayer(farmsData, {
    updateInterval: UPDATE_INTERVAL
  });

  // Demarrer le replay
  dataPlayer.start();

  // Mettre a jour les metriques immediatement
  updateMetrics();

  // Mise a jour periodique des metriques
  setInterval(updateMetrics, UPDATE_INTERVAL);

  console.log(`[INIT] Simulateur pret sur le port ${PORT}`);
  console.log('='.repeat(60));
}

/**
 * Met a jour les metriques Prometheus
 */
function updateMetrics() {
  if (!dataPlayer) return;

  const allData = dataPlayer.getAllCurrentData();
  updateAllMetrics(allData);
}

// === ROUTES ===

/**
 * GET /metrics - Endpoint Prometheus
 */
app.get('/metrics', async (req, res) => {
  try {
    const metrics = await getMetrics();
    res.set('Content-Type', getContentType());
    res.send(metrics);
  } catch (error) {
    console.error('[ERROR] /metrics:', error.message);
    res.status(500).send('Erreur generation metriques');
  }
});

/**
 * GET /health - Health check pour Kubernetes
 */
app.get('/health', (req, res) => {
  const healthy = dataPlayer !== null && dataPlayer.isPlaying;
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'healthy' : 'unhealthy',
    uptime: Math.floor((Date.now() - startTime) / 1000),
    timestamp: new Date().toISOString()
  });
});

/**
 * GET /ready - Readiness probe
 */
app.get('/ready', (req, res) => {
  const ready = dataPlayer !== null;
  res.status(ready ? 200 : 503).json({
    status: ready ? 'ready' : 'not_ready',
    timestamp: new Date().toISOString()
  });
});

/**
 * GET /status - Etat du simulateur
 */
app.get('/status', (req, res) => {
  if (!dataPlayer) {
    return res.status(503).json({ error: 'Simulateur non initialise' });
  }

  const status = dataPlayer.getStatus();
  res.json({
    ...status,
    uptime: Math.floor((Date.now() - startTime) / 1000),
    config: {
      updateInterval: UPDATE_INTERVAL,
      farms: Object.keys(FARMS_CONFIG)
    }
  });
});

/**
 * GET /data - Donnees actuelles de toutes les fermes
 */
app.get('/data', (req, res) => {
  if (!dataPlayer) {
    return res.status(503).json({ error: 'Simulateur non initialise' });
  }

  const allData = dataPlayer.getAllCurrentData();
  res.json(allData);
});

/**
 * GET /data/:farm - Donnees actuelles d'une ferme specifique
 */
app.get('/data/:farm', (req, res) => {
  const { farm } = req.params;

  if (!FARMS_CONFIG[farm]) {
    return res.status(404).json({
      error: 'Ferme non trouvee',
      availableFarms: Object.keys(FARMS_CONFIG)
    });
  }

  if (!dataPlayer) {
    return res.status(503).json({ error: 'Simulateur non initialise' });
  }

  const data = dataPlayer.getCurrentData(farm);
  res.json(data);
});

/**
 * GET /farms - Liste des fermes configurees
 */
app.get('/farms', (req, res) => {
  res.json(FARMS_CONFIG);
});

/**
 * POST /control/jump - Sauter a un index specifique
 */
app.post('/control/jump', (req, res) => {
  const { index } = req.body;

  if (typeof index !== 'number' || index < 0) {
    return res.status(400).json({ error: 'Index invalide' });
  }

  if (!dataPlayer) {
    return res.status(503).json({ error: 'Simulateur non initialise' });
  }

  dataPlayer.jumpToIndex(index);
  updateMetrics();

  res.json({
    message: 'Index mis a jour',
    newIndex: index,
    currentData: dataPlayer.getAllCurrentData()
  });
});

/**
 * POST /control/pause - Mettre en pause le replay
 */
app.post('/control/pause', (req, res) => {
  if (!dataPlayer) {
    return res.status(503).json({ error: 'Simulateur non initialise' });
  }

  dataPlayer.stop();
  res.json({ message: 'Replay en pause', status: dataPlayer.getStatus() });
});

/**
 * POST /control/resume - Reprendre le replay
 */
app.post('/control/resume', (req, res) => {
  if (!dataPlayer) {
    return res.status(503).json({ error: 'Simulateur non initialise' });
  }

  dataPlayer.start();
  res.json({ message: 'Replay repris', status: dataPlayer.getStatus() });
});

/**
 * GET / - Page d'accueil
 */
app.get('/', (req, res) => {
  res.json({
    name: 'Solar Simulator',
    version: '1.0.0',
    description: 'Simulateur de donnees pour fermes solaires - TP GitOps',
    endpoints: {
      metrics: 'GET /metrics - Metriques Prometheus',
      health: 'GET /health - Health check',
      ready: 'GET /ready - Readiness probe',
      status: 'GET /status - Etat du simulateur',
      data: 'GET /data - Donnees toutes fermes',
      dataFarm: 'GET /data/:farm - Donnees une ferme',
      farms: 'GET /farms - Configuration des fermes',
      jump: 'POST /control/jump - Sauter a un index',
      pause: 'POST /control/pause - Pause replay',
      resume: 'POST /control/resume - Reprendre replay'
    },
    farms: Object.keys(FARMS_CONFIG)
  });
});

// === DEMARRAGE ===

// Gestion des erreurs non capturees
process.on('uncaughtException', (error) => {
  console.error('[FATAL] Exception non capturee:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[ERROR] Promise rejetee:', reason);
});

// Arret propre
process.on('SIGTERM', () => {
  console.log('[SHUTDOWN] Signal SIGTERM recu');
  if (dataPlayer) dataPlayer.stop();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('[SHUTDOWN] Signal SIGINT recu');
  if (dataPlayer) dataPlayer.stop();
  process.exit(0);
});

// Demarrer le serveur
initialize().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[SERVER] Ecoute sur http://0.0.0.0:${PORT}`);
    console.log(`[SERVER] Metriques: http://localhost:${PORT}/metrics`);
  });
}).catch((error) => {
  console.error('[FATAL] Erreur initialisation:', error);
  process.exit(1);
});

module.exports = app;
