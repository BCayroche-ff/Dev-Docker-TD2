/**
 * Service d'export des metriques au format Prometheus
 * Utilise prom-client pour generer les metriques
 */

const client = require('prom-client');
const { FARMS_CONFIG, CONSTANTS, ANOMALY_TYPES } = require('../config/farms');

// Creer un registre personnalise
const register = new client.Registry();

// Ajouter les metriques par defaut (process, nodejs)
client.collectDefaultMetrics({ register });

// === DEFINITION DES METRIQUES ===

// Production electrique instantanee (kW)
const powerProductionGauge = new client.Gauge({
  name: 'solar_power_production_kw',
  help: 'Production electrique instantanee en kW',
  labelNames: ['farm'],
  registers: [register]
});

// Production theorique (kW)
const theoreticalPowerGauge = new client.Gauge({
  name: 'solar_power_theoretical_kw',
  help: 'Production theorique calculee en kW',
  labelNames: ['farm'],
  registers: [register]
});

// Irradiance solaire (W/m2)
const irradianceGauge = new client.Gauge({
  name: 'solar_irradiance_wm2',
  help: 'Irradiance solaire mesuree en W/m2',
  labelNames: ['farm'],
  registers: [register]
});

// Temperature des panneaux (C)
const panelTempGauge = new client.Gauge({
  name: 'solar_panel_temperature_celsius',
  help: 'Temperature moyenne des panneaux en Celsius',
  labelNames: ['farm'],
  registers: [register]
});

// Temperature ambiante (C)
const ambientTempGauge = new client.Gauge({
  name: 'solar_ambient_temperature_celsius',
  help: 'Temperature ambiante en Celsius',
  labelNames: ['farm'],
  registers: [register]
});

// Etat des onduleurs (1=OK, 0=KO)
const inverterStatusGauge = new client.Gauge({
  name: 'solar_inverter_status',
  help: 'Etat de l\'onduleur (1=OK, 0=KO)',
  labelNames: ['farm', 'inverter_id'],
  registers: [register]
});

// Rendement (%)
const efficiencyGauge = new client.Gauge({
  name: 'solar_efficiency_percent',
  help: 'Rendement global en pourcentage',
  labelNames: ['farm'],
  registers: [register]
});

// Revenus journaliers cumules (EUR)
const dailyRevenueGauge = new client.Gauge({
  name: 'solar_daily_revenue_euros',
  help: 'Revenus journaliers cumules en euros',
  labelNames: ['farm'],
  registers: [register]
});

// Disponibilite (%)
const availabilityGauge = new client.Gauge({
  name: 'solar_availability_percent',
  help: 'Taux de disponibilite en pourcentage',
  labelNames: ['farm'],
  registers: [register]
});

// Type d'anomalie active
const anomalyGauge = new client.Gauge({
  name: 'solar_anomaly_active',
  help: 'Indicateur d\'anomalie active (1=active, 0=inactive)',
  labelNames: ['farm', 'type'],
  registers: [register]
});

// Severite de l'anomalie
const anomalySeverityGauge = new client.Gauge({
  name: 'solar_anomaly_severity',
  help: 'Severite de l\'anomalie (0=low, 1=medium, 2=high)',
  labelNames: ['farm'],
  registers: [register]
});

// Nombre de panneaux
const panelCountGauge = new client.Gauge({
  name: 'solar_panel_count',
  help: 'Nombre total de panneaux dans la ferme',
  labelNames: ['farm'],
  registers: [register]
});

// Capacite installee (MW)
const capacityGauge = new client.Gauge({
  name: 'solar_capacity_mw',
  help: 'Capacite installee en MW',
  labelNames: ['farm'],
  registers: [register]
});

// Timestamp de derniere mise a jour
const lastUpdateGauge = new client.Gauge({
  name: 'solar_last_update_timestamp',
  help: 'Timestamp de la derniere mise a jour des donnees',
  labelNames: ['farm'],
  registers: [register]
});

// Heure simulee
const simulatedHourGauge = new client.Gauge({
  name: 'solar_simulated_hour',
  help: 'Heure simulee (0-23)',
  labelNames: ['farm'],
  registers: [register]
});

// Jour simule
const simulatedDayGauge = new client.Gauge({
  name: 'solar_simulated_day',
  help: 'Jour de l\'annee simule (1-365)',
  labelNames: ['farm'],
  registers: [register]
});

/**
 * Met a jour les metriques pour une ferme donnee
 * @param {string} farmName - Nom de la ferme
 * @param {Object} data - Donnees de la ferme
 */
function updateFarmMetrics(farmName, data) {
  const config = FARMS_CONFIG[farmName];
  if (!config || !data) return;

  // Metriques de production
  powerProductionGauge.set({ farm: farmName }, data.power_production_kw || 0);
  theoreticalPowerGauge.set({ farm: farmName }, data.theoretical_power_kw || 0);
  irradianceGauge.set({ farm: farmName }, data.irradiance_wm2 || 0);

  // Temperatures
  panelTempGauge.set({ farm: farmName }, data.panel_temp_c || 0);
  ambientTempGauge.set({ farm: farmName }, data.ambient_temp_c || 0);

  // Rendement et revenus
  efficiencyGauge.set({ farm: farmName }, data.efficiency_percent || 0);
  dailyRevenueGauge.set({ farm: farmName }, data.daily_revenue_eur || 0);

  // Etats des onduleurs
  for (let i = 1; i <= config.inverters; i++) {
    const statusKey = `inverter_${i}_status`;
    const status = data[statusKey] !== undefined ? data[statusKey] : 1;
    inverterStatusGauge.set({ farm: farmName, inverter_id: String(i) }, status);
  }

  // Calcul de la disponibilite basee sur les onduleurs
  let activeInverters = 0;
  for (let i = 1; i <= config.inverters; i++) {
    const statusKey = `inverter_${i}_status`;
    if (data[statusKey] !== 0) activeInverters++;
  }
  const availability = (activeInverters / config.inverters) * 100;
  availabilityGauge.set({ farm: farmName }, availability);

  // Anomalies
  const anomalyType = data.anomaly_type || 'NORMAL';

  // Reset toutes les anomalies puis activer celle en cours
  for (const type of Object.keys(ANOMALY_TYPES)) {
    anomalyGauge.set({ farm: farmName, type }, type === anomalyType ? 1 : 0);
  }

  // Severite (0=low, 1=medium, 2=high)
  const severityMap = { low: 0, medium: 1, high: 2 };
  const severity = severityMap[data.anomaly_severity] || 0;
  anomalySeverityGauge.set({ farm: farmName }, severity);

  // Metriques statiques
  panelCountGauge.set({ farm: farmName }, config.panels);
  capacityGauge.set({ farm: farmName }, config.capacity_mw);

  // Timestamps
  lastUpdateGauge.set({ farm: farmName }, Date.now() / 1000);
  simulatedHourGauge.set({ farm: farmName }, data.hour || 0);
  simulatedDayGauge.set({ farm: farmName }, data.day_of_year || 0);
}

/**
 * Met a jour les metriques pour toutes les fermes
 * @param {Object} allData - Donnees de toutes les fermes
 */
function updateAllMetrics(allData) {
  for (const [farmName, data] of Object.entries(allData)) {
    updateFarmMetrics(farmName, data);
  }
}

/**
 * Retourne les metriques au format Prometheus
 * @returns {Promise<string>} Metriques formatees
 */
async function getMetrics() {
  return register.metrics();
}

/**
 * Retourne le content-type pour Prometheus
 * @returns {string} Content-type
 */
function getContentType() {
  return register.contentType;
}

/**
 * Reset toutes les metriques
 */
function resetMetrics() {
  register.resetMetrics();
}

module.exports = {
  updateFarmMetrics,
  updateAllMetrics,
  getMetrics,
  getContentType,
  resetMetrics,
  register
};
