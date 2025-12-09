/**
 * Tests unitaires pour metricsExporter
 * Verification du format Prometheus
 */

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const {
  updateFarmMetrics,
  updateAllMetrics,
  getMetrics,
  getContentType,
  resetMetrics
} = require('../src/services/metricsExporter');

describe('metricsExporter', () => {

  beforeEach(() => {
    resetMetrics();
  });

  describe('getContentType', () => {
    it('doit retourner le content-type Prometheus', () => {
      const contentType = getContentType();
      assert.ok(contentType.includes('text/plain'), 'Content-type doit contenir text/plain');
    });
  });

  describe('updateFarmMetrics', () => {
    it('doit mettre a jour les metriques pour une ferme', async () => {
      const testData = {
        farm_name: 'provence',
        power_production_kw: 1500,
        theoretical_power_kw: 1700,
        irradiance_wm2: 850,
        panel_temp_c: 45,
        ambient_temp_c: 28,
        efficiency_percent: 88.2,
        daily_revenue_eur: 1250.50,
        hour: 14,
        day_of_year: 165,
        inverter_1_status: 1,
        inverter_2_status: 1,
        inverter_3_status: 0,
        inverter_4_status: 1,
        anomaly_type: 'INVERTER_DOWN',
        anomaly_severity: 'high'
      };

      updateFarmMetrics('provence', testData);

      const metrics = await getMetrics();

      // Verifier que les metriques sont presentes
      assert.ok(metrics.includes('solar_power_production_kw'), 'Metrique production manquante');
      assert.ok(metrics.includes('farm="provence"'), 'Label farm manquant');
      assert.ok(metrics.includes('1500'), 'Valeur production incorrecte');
    });

    it('doit gerer les donnees manquantes gracieusement', async () => {
      const incompleteData = {
        farm_name: 'occitanie',
        power_production_kw: 1000
        // Autres champs manquants
      };

      // Ne doit pas lever d'erreur
      updateFarmMetrics('occitanie', incompleteData);

      const metrics = await getMetrics();
      assert.ok(metrics.includes('solar_power_production_kw'), 'Metrique doit etre presente');
    });
  });

  describe('updateAllMetrics', () => {
    it('doit mettre a jour les metriques pour toutes les fermes', async () => {
      const allData = {
        provence: {
          power_production_kw: 1500,
          irradiance_wm2: 900,
          panel_temp_c: 42,
          ambient_temp_c: 25,
          inverter_1_status: 1,
          inverter_2_status: 1,
          inverter_3_status: 1,
          inverter_4_status: 1,
          anomaly_type: 'NORMAL',
          anomaly_severity: 'low'
        },
        occitanie: {
          power_production_kw: 1100,
          irradiance_wm2: 880,
          panel_temp_c: 40,
          ambient_temp_c: 24,
          inverter_1_status: 1,
          inverter_2_status: 1,
          inverter_3_status: 1,
          anomaly_type: 'NORMAL',
          anomaly_severity: 'low'
        },
        aquitaine: {
          power_production_kw: 1300,
          irradiance_wm2: 820,
          panel_temp_c: 38,
          ambient_temp_c: 22,
          inverter_1_status: 1,
          inverter_2_status: 1,
          inverter_3_status: 1,
          inverter_4_status: 1,
          anomaly_type: 'NORMAL',
          anomaly_severity: 'low'
        }
      };

      updateAllMetrics(allData);

      const metrics = await getMetrics();

      // Verifier les 3 fermes
      assert.ok(metrics.includes('farm="provence"'), 'Provence manquante');
      assert.ok(metrics.includes('farm="occitanie"'), 'Occitanie manquante');
      assert.ok(metrics.includes('farm="aquitaine"'), 'Aquitaine manquante');
    });
  });

  describe('getMetrics', () => {
    it('doit retourner un format Prometheus valide', async () => {
      updateFarmMetrics('provence', {
        power_production_kw: 1500,
        inverter_1_status: 1,
        inverter_2_status: 1,
        inverter_3_status: 1,
        inverter_4_status: 1,
        anomaly_type: 'NORMAL',
        anomaly_severity: 'low'
      });

      const metrics = await getMetrics();

      // Verifier la structure basique Prometheus
      // Les metriques commencent par # HELP ou # TYPE ou nom_metrique
      const lines = metrics.split('\n');

      let hasHelp = false;
      let hasType = false;
      let hasMetric = false;

      for (const line of lines) {
        if (line.startsWith('# HELP')) hasHelp = true;
        if (line.startsWith('# TYPE')) hasType = true;
        if (line.startsWith('solar_')) hasMetric = true;
      }

      assert.ok(hasHelp, 'Doit contenir des lignes HELP');
      assert.ok(hasType, 'Doit contenir des lignes TYPE');
      assert.ok(hasMetric, 'Doit contenir des metriques solar_');
    });

    it('doit inclure les metriques par defaut Node.js', async () => {
      const metrics = await getMetrics();

      // prom-client ajoute des metriques process par defaut
      assert.ok(
        metrics.includes('nodejs_') || metrics.includes('process_'),
        'Metriques Node.js par defaut manquantes'
      );
    });
  });

  describe('Format des labels', () => {
    it('doit formater correctement les labels d\'onduleurs', async () => {
      updateFarmMetrics('provence', {
        inverter_1_status: 1,
        inverter_2_status: 0,
        inverter_3_status: 1,
        inverter_4_status: 1,
        anomaly_type: 'NORMAL',
        anomaly_severity: 'low'
      });

      const metrics = await getMetrics();

      // Verifier le format des labels
      assert.ok(
        metrics.includes('inverter_id="1"') || metrics.includes("inverter_id='1'"),
        'Label inverter_id incorrect'
      );
    });

    it('doit formater correctement les labels d\'anomalies', async () => {
      updateFarmMetrics('provence', {
        inverter_1_status: 1,
        inverter_2_status: 1,
        inverter_3_status: 1,
        inverter_4_status: 1,
        anomaly_type: 'OVERHEAT',
        anomaly_severity: 'high'
      });

      const metrics = await getMetrics();

      assert.ok(
        metrics.includes('type="OVERHEAT"'),
        'Label anomaly type incorrect'
      );
    });
  });

});
