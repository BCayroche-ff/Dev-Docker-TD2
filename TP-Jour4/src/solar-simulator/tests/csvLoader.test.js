/**
 * Tests unitaires pour csvLoader
 * Verification du parsing des fichiers CSV
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const path = require('path');
const fs = require('fs');

const { loadCSV, loadAllFarms, indexByHour, getDatasetStats } = require('../src/services/csvLoader');

const DATA_DIR = path.join(__dirname, '../../data');
const SAMPLE_CSV = path.join(DATA_DIR, 'provence_data.csv');

describe('csvLoader', () => {

  describe('loadCSV', () => {
    it('doit charger un fichier CSV existant', () => {
      // Skip si le fichier n'existe pas
      if (!fs.existsSync(SAMPLE_CSV)) {
        console.log('  [SKIP] Fichier CSV non disponible');
        return;
      }

      const data = loadCSV(SAMPLE_CSV);

      assert.ok(Array.isArray(data), 'Le resultat doit etre un tableau');
      assert.ok(data.length > 0, 'Le tableau ne doit pas etre vide');
    });

    it('doit parser correctement les colonnes', () => {
      if (!fs.existsSync(SAMPLE_CSV)) {
        console.log('  [SKIP] Fichier CSV non disponible');
        return;
      }

      const data = loadCSV(SAMPLE_CSV);
      const firstRow = data[0];

      // Verifier les colonnes attendues
      assert.ok('farm_name' in firstRow, 'Colonne farm_name manquante');
      assert.ok('hour' in firstRow, 'Colonne hour manquante');
      assert.ok('irradiance_wm2' in firstRow, 'Colonne irradiance_wm2 manquante');
      assert.ok('power_production_kw' in firstRow, 'Colonne power_production_kw manquante');
      assert.ok('anomaly_type' in firstRow, 'Colonne anomaly_type manquante');
    });

    it('doit caster les types correctement', () => {
      if (!fs.existsSync(SAMPLE_CSV)) {
        console.log('  [SKIP] Fichier CSV non disponible');
        return;
      }

      const data = loadCSV(SAMPLE_CSV);
      const row = data[0];

      assert.strictEqual(typeof row.hour, 'number', 'hour doit etre un nombre');
      assert.strictEqual(typeof row.irradiance_wm2, 'number', 'irradiance doit etre un nombre');
      assert.strictEqual(typeof row.farm_name, 'string', 'farm_name doit etre une string');
      assert.strictEqual(typeof row.anomaly_type, 'string', 'anomaly_type doit etre une string');
    });

    it('doit lancer une erreur pour un fichier inexistant', () => {
      assert.throws(() => {
        loadCSV('/chemin/inexistant.csv');
      }, /non trouve/);
    });
  });

  describe('loadAllFarms', () => {
    it('doit charger les 3 fermes', () => {
      if (!fs.existsSync(DATA_DIR)) {
        console.log('  [SKIP] Repertoire data non disponible');
        return;
      }

      const farms = loadAllFarms(DATA_DIR);

      assert.ok('provence' in farms, 'Ferme provence manquante');
      assert.ok('occitanie' in farms, 'Ferme occitanie manquante');
      assert.ok('aquitaine' in farms, 'Ferme aquitaine manquante');
    });

    it('chaque ferme doit avoir 720 lignes (30 jours x 24h)', () => {
      if (!fs.existsSync(DATA_DIR)) {
        console.log('  [SKIP] Repertoire data non disponible');
        return;
      }

      const farms = loadAllFarms(DATA_DIR);

      for (const [farmName, data] of Object.entries(farms)) {
        if (data.length > 0) {
          assert.strictEqual(data.length, 720, `${farmName} doit avoir 720 lignes`);
        }
      }
    });
  });

  describe('indexByHour', () => {
    it('doit creer un index par jour-heure', () => {
      const sampleData = [
        { day_of_year: 152, hour: 10, value: 100 },
        { day_of_year: 152, hour: 11, value: 200 },
        { day_of_year: 153, hour: 10, value: 150 }
      ];

      const index = indexByHour(sampleData);

      assert.ok(index instanceof Map, 'Le resultat doit etre une Map');
      assert.strictEqual(index.size, 3, 'L\'index doit avoir 3 entrees');
      assert.strictEqual(index.get('152-10').value, 100);
      assert.strictEqual(index.get('152-11').value, 200);
      assert.strictEqual(index.get('153-10').value, 150);
    });
  });

  describe('getDatasetStats', () => {
    it('doit calculer les statistiques correctement', () => {
      const mockData = {
        provence: [
          { anomaly_type: 'NORMAL', timestamp: new Date('2025-06-01') },
          { anomaly_type: 'OVERHEAT', timestamp: new Date('2025-06-15') },
          { anomaly_type: 'NORMAL', timestamp: new Date('2025-06-30') }
        ],
        occitanie: [
          { anomaly_type: 'NORMAL', timestamp: new Date('2025-06-10') }
        ]
      };

      const stats = getDatasetStats(mockData);

      assert.strictEqual(stats.totalRecords, 4, 'Total records incorrect');
      assert.strictEqual(stats.recordsPerFarm.provence, 3);
      assert.strictEqual(stats.recordsPerFarm.occitanie, 1);
      assert.strictEqual(stats.anomalyCounts.NORMAL, 3);
      assert.strictEqual(stats.anomalyCounts.OVERHEAT, 1);
    });
  });

});
