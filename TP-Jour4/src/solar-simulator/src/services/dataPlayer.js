/**
 * Service de replay des donnees CSV
 * Rejoue les donnees temporelles en boucle avec acceleration
 */

const { FARMS_CONFIG, CONSTANTS } = require('../config/farms');

class DataPlayer {
  constructor(farmsData, options = {}) {
    this.farmsData = farmsData;
    this.currentIndex = {};
    this.currentData = {};

    // Options de configuration
    this.options = {
      // Intervalle de mise a jour en ms (30s par defaut = 1h simulee)
      updateInterval: options.updateInterval || CONSTANTS.SCRAPE_INTERVAL_MS,
      // Facteur d'acceleration (1 = temps reel, 120 = 30s = 1h)
      speedFactor: options.speedFactor || 120,
      // Mode de replay: 'sequential' ou 'time-based'
      mode: options.mode || 'sequential'
    };

    // Initialiser les index pour chaque ferme
    for (const farmName of Object.keys(FARMS_CONFIG)) {
      this.currentIndex[farmName] = 0;
      this.currentData[farmName] = null;
    }

    this.isPlaying = false;
    this.timer = null;
    this.lastUpdate = Date.now();
  }

  /**
   * Demarre le replay des donnees
   */
  start() {
    if (this.isPlaying) return;

    this.isPlaying = true;
    this.updateCurrentData();

    // Mise a jour periodique
    this.timer = setInterval(() => {
      this.advanceToNext();
    }, this.options.updateInterval);

    console.log(`[DataPlayer] Replay demarre (interval: ${this.options.updateInterval}ms)`);
  }

  /**
   * Arrete le replay
   */
  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this.isPlaying = false;
    console.log('[DataPlayer] Replay arrete');
  }

  /**
   * Avance a la prochaine ligne de donnees
   */
  advanceToNext() {
    for (const farmName of Object.keys(this.farmsData)) {
      const data = this.farmsData[farmName];
      if (!data || data.length === 0) continue;

      // Avancer l'index (boucle sur le dataset)
      this.currentIndex[farmName] = (this.currentIndex[farmName] + 1) % data.length;
    }

    this.updateCurrentData();
    this.lastUpdate = Date.now();
  }

  /**
   * Met a jour les donnees courantes pour chaque ferme
   */
  updateCurrentData() {
    for (const farmName of Object.keys(this.farmsData)) {
      const data = this.farmsData[farmName];
      if (!data || data.length === 0) {
        this.currentData[farmName] = this.getDefaultData(farmName);
        continue;
      }

      const index = this.currentIndex[farmName];
      this.currentData[farmName] = data[index];
    }
  }

  /**
   * Retourne les donnees par defaut pour une ferme (en cas d'erreur)
   */
  getDefaultData(farmName) {
    const config = FARMS_CONFIG[farmName];
    return {
      farm_name: farmName,
      timestamp: new Date(),
      hour: new Date().getHours(),
      day_of_year: Math.floor((Date.now() - new Date(new Date().getFullYear(), 0, 0)) / 86400000),
      irradiance_wm2: 0,
      ambient_temp_c: 20,
      panel_temp_c: 20,
      power_production_kw: 0,
      theoretical_power_kw: 0,
      efficiency_percent: 0,
      inverter_1_status: 1,
      inverter_2_status: 1,
      inverter_3_status: 1,
      inverter_4_status: config?.inverters >= 4 ? 1 : undefined,
      daily_revenue_eur: 0,
      anomaly_type: 'NORMAL',
      anomaly_severity: 'low'
    };
  }

  /**
   * Obtient les donnees actuelles pour une ferme
   * @param {string} farmName - Nom de la ferme
   * @returns {Object} Donnees actuelles
   */
  getCurrentData(farmName) {
    return this.currentData[farmName] || this.getDefaultData(farmName);
  }

  /**
   * Obtient les donnees actuelles pour toutes les fermes
   * @returns {Object} Donnees par ferme
   */
  getAllCurrentData() {
    const result = {};
    for (const farmName of Object.keys(FARMS_CONFIG)) {
      result[farmName] = this.getCurrentData(farmName);
    }
    return result;
  }

  /**
   * Obtient l'etat du replay
   * @returns {Object} Etat actuel
   */
  getStatus() {
    return {
      isPlaying: this.isPlaying,
      lastUpdate: this.lastUpdate,
      indices: { ...this.currentIndex },
      totalRecords: Object.fromEntries(
        Object.entries(this.farmsData).map(([k, v]) => [k, v?.length || 0])
      )
    };
  }

  /**
   * Saute a un index specifique
   * @param {number} index - Index cible
   */
  jumpToIndex(index) {
    for (const farmName of Object.keys(this.farmsData)) {
      const data = this.farmsData[farmName];
      if (data && data.length > 0) {
        this.currentIndex[farmName] = Math.max(0, Math.min(index, data.length - 1));
      }
    }
    this.updateCurrentData();
  }
}

module.exports = DataPlayer;
