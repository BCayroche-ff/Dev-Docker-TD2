/**
 * Configuration des 3 fermes solaires
 * Donnees basees sur les specifications du TP
 */

const FARMS_CONFIG = {
  provence: {
    name: 'provence',
    location: 'Marseille',
    latitude: 43.3,
    panels: 5000,
    capacity_mw: 2.0,
    inverters: 4,
    panel_power_w: 400,
    csvFile: 'provence_data.csv'
  },
  occitanie: {
    name: 'occitanie',
    location: 'Montpellier',
    latitude: 43.6,
    panels: 3500,
    capacity_mw: 1.4,
    inverters: 3,
    panel_power_w: 400,
    csvFile: 'occitanie_data.csv'
  },
  aquitaine: {
    name: 'aquitaine',
    location: 'Bordeaux',
    latitude: 44.8,
    panels: 4200,
    capacity_mw: 1.68,
    inverters: 4,
    panel_power_w: 400,
    csvFile: 'aquitaine_data.csv'
  }
};

// Constantes physiques du TP
const CONSTANTS = {
  SYSTEM_EFFICIENCY: 0.85,           // Pertes cablage, onduleur, poussiere
  TEMP_COEFFICIENT: -0.0035,         // -0.35%/C
  REFERENCE_TEMP: 25,                // STC temperature de reference
  TARIF_RACHAT: 0.18,                // EUR/kWh (contrat EDF OA)
  CRITICAL_TEMP: 65,                 // Seuil critique temperature panneau
  SCRAPE_INTERVAL_MS: 30000          // Intervalle de mise a jour (30s)
};

// Mapping des types d'anomalies
const ANOMALY_TYPES = {
  NORMAL: 0,
  OVERHEAT: 1,
  INVERTER_DOWN: 2,
  DEGRADATION: 3,
  SHADING: 4,
  SENSOR_FAIL: 5
};

module.exports = {
  FARMS_CONFIG,
  CONSTANTS,
  ANOMALY_TYPES
};
