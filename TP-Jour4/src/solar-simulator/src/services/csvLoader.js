/**
 * Service de chargement des fichiers CSV
 * Parse les donnees des fermes solaires
 */

const fs = require('fs');
const path = require('path');
const { parse } = require('csv-parse/sync');

/**
 * Charge et parse un fichier CSV de ferme solaire
 * @param {string} filePath - Chemin vers le fichier CSV
 * @returns {Array} Tableau d'objets avec les donnees parsees
 */
function loadCSV(filePath) {
  const absolutePath = path.resolve(filePath);

  if (!fs.existsSync(absolutePath)) {
    throw new Error(`Fichier CSV non trouve: ${absolutePath}`);
  }

  const fileContent = fs.readFileSync(absolutePath, 'utf-8');

  const records = parse(fileContent, {
    columns: true,
    skip_empty_lines: true,
    cast: (value, context) => {
      const column = context.column || '';

      // Cast automatique des types
      if (column === 'timestamp') {
        return new Date(value);
      }
      if (column === 'hour' || column === 'day_of_year') {
        return parseInt(value, 10);
      }
      if (typeof column === 'string' && column.includes('status')) {
        return parseInt(value, 10);
      }
      if (column === 'anomaly_type' || column === 'anomaly_severity' || column === 'farm_name') {
        return value;
      }
      // Valeurs numeriques flottantes
      const num = parseFloat(value);
      return isNaN(num) ? value : num;
    }
  });

  return records;
}

/**
 * Charge les donnees de toutes les fermes
 * @param {string} dataDir - Repertoire contenant les fichiers CSV
 * @returns {Object} Donnees par ferme
 */
function loadAllFarms(dataDir) {
  const farms = {
    provence: [],
    occitanie: [],
    aquitaine: []
  };

  const files = {
    provence: 'provence_data.csv',
    occitanie: 'occitanie_data.csv',
    aquitaine: 'aquitaine_data.csv'
  };

  for (const [farmName, fileName] of Object.entries(files)) {
    const filePath = path.join(dataDir, fileName);
    try {
      farms[farmName] = loadCSV(filePath);
      console.log(`[CSV] Charge ${farms[farmName].length} lignes pour ${farmName}`);
    } catch (error) {
      console.error(`[CSV] Erreur chargement ${farmName}: ${error.message}`);
      farms[farmName] = [];
    }
  }

  return farms;
}

/**
 * Indexe les donnees par heure pour acces rapide
 * @param {Array} data - Donnees d'une ferme
 * @returns {Map} Index hour -> donnees
 */
function indexByHour(data) {
  const index = new Map();

  for (const record of data) {
    // Cle composite: jour + heure
    const key = `${record.day_of_year}-${record.hour}`;
    index.set(key, record);
  }

  return index;
}

/**
 * Obtient les statistiques du dataset
 * @param {Object} farmsData - Donnees de toutes les fermes
 * @returns {Object} Statistiques
 */
function getDatasetStats(farmsData) {
  const stats = {
    totalRecords: 0,
    recordsPerFarm: {},
    anomalyCounts: {},
    dateRange: { start: null, end: null }
  };

  for (const [farmName, data] of Object.entries(farmsData)) {
    stats.recordsPerFarm[farmName] = data.length;
    stats.totalRecords += data.length;

    for (const record of data) {
      const type = record.anomaly_type || 'UNKNOWN';
      stats.anomalyCounts[type] = (stats.anomalyCounts[type] || 0) + 1;

      if (record.timestamp) {
        if (!stats.dateRange.start || record.timestamp < stats.dateRange.start) {
          stats.dateRange.start = record.timestamp;
        }
        if (!stats.dateRange.end || record.timestamp > stats.dateRange.end) {
          stats.dateRange.end = record.timestamp;
        }
      }
    }
  }

  return stats;
}

module.exports = {
  loadCSV,
  loadAllFarms,
  indexByHour,
  getDatasetStats
};
