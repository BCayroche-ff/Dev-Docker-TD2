/**
 * Tests unitaires pour les calculs physiques
 * Validation des formules de production solaire
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');

const { CONSTANTS, FARMS_CONFIG } = require('../src/config/farms');

/**
 * Calcul de la production theorique
 * P(t) = Nb_panneaux x Puissance_crete x (Irradiance/1000) x eta_systeme x Facteur_temp
 */
function calculateTheoreticalPower(farmName, irradiance, panelTemp) {
  const config = FARMS_CONFIG[farmName];
  if (!config) return 0;

  const tempFactor = 1 + (panelTemp - CONSTANTS.REFERENCE_TEMP) * CONSTANTS.TEMP_COEFFICIENT;
  const power = config.panels * config.panel_power_w * (irradiance / 1000) * CONSTANTS.SYSTEM_EFFICIENCY * tempFactor;

  return power / 1000; // Convertir en kW
}

/**
 * Calcul de la temperature des panneaux
 * T_panneau = T_ambiante + (irradiance/1000) x 25
 */
function calculatePanelTemperature(ambientTemp, irradiance) {
  return ambientTemp + (irradiance / 1000) * 25;
}

/**
 * Calcul de l'irradiance selon l'heure
 * Irradiance(h) = Irradiance_max x sin(PI x (h-6) / 12) pour h in [6, 18]
 */
function calculateIrradiance(hour, maxIrradiance) {
  if (hour < 6 || hour >= 18) {
    return 0;
  }
  return maxIrradiance * Math.sin(Math.PI * (hour - 6) / 12);
}

/**
 * Calcul des revenus journaliers
 */
function calculateRevenue(energyKwh) {
  return energyKwh * CONSTANTS.TARIF_RACHAT;
}

describe('Calculs Physiques Solaires', () => {

  describe('calculateTheoreticalPower', () => {
    it('doit retourner 0 quand irradiance est 0 (nuit)', () => {
      const power = calculateTheoreticalPower('provence', 0, 20);
      assert.strictEqual(power, 0, 'Puissance doit etre 0 la nuit');
    });

    it('doit calculer la puissance correctement pour Provence a midi', () => {
      // Provence: 5000 panneaux x 400W = 2MW
      // Irradiance 1000 W/m2, temp 25C (STC)
      // P = 5000 x 400 x 1 x 0.85 x 1 = 1,700,000 W = 1700 kW
      const power = calculateTheoreticalPower('provence', 1000, 25);

      assert.ok(power > 1600 && power < 1800, `Puissance ${power} hors plage attendue`);
    });

    it('doit reduire la puissance quand temperature augmente', () => {
      const powerNormal = calculateTheoreticalPower('provence', 1000, 25);
      const powerHot = calculateTheoreticalPower('provence', 1000, 65);

      assert.ok(powerHot < powerNormal, 'Puissance doit diminuer avec la chaleur');

      // Coefficient: -0.35%/C x 40C = -14%
      const expectedReduction = 0.86; // 1 - 0.14
      const actualRatio = powerHot / powerNormal;
      assert.ok(actualRatio > 0.80 && actualRatio < 0.90, `Ratio ${actualRatio} incorrect`);
    });

    it('doit retourner 0 pour une ferme inconnue', () => {
      const power = calculateTheoreticalPower('unknown', 1000, 25);
      assert.strictEqual(power, 0);
    });
  });

  describe('calculatePanelTemperature', () => {
    it('doit etre egale a ambiante quand irradiance est 0', () => {
      const panelTemp = calculatePanelTemperature(20, 0);
      assert.strictEqual(panelTemp, 20);
    });

    it('doit augmenter avec l\'irradiance', () => {
      // T_panneau = 25 + (1000/1000) x 25 = 50C
      const panelTemp = calculatePanelTemperature(25, 1000);
      assert.strictEqual(panelTemp, 50);
    });

    it('doit depasser le seuil critique en canicule', () => {
      // Canicule: T_amb = 40C, irradiance = 1000 W/m2
      // T_panneau = 40 + 25 = 65C (seuil critique!)
      const panelTemp = calculatePanelTemperature(40, 1000);
      assert.ok(panelTemp >= CONSTANTS.CRITICAL_TEMP, 'Doit atteindre le seuil critique');
    });
  });

  describe('calculateIrradiance', () => {
    it('doit retourner 0 avant 6h et apres 18h', () => {
      assert.strictEqual(calculateIrradiance(0, 1000), 0);
      assert.strictEqual(calculateIrradiance(5, 1000), 0);
      assert.strictEqual(calculateIrradiance(18, 1000), 0);
      assert.strictEqual(calculateIrradiance(23, 1000), 0);
    });

    it('doit atteindre le maximum a midi', () => {
      const irradianceNoon = calculateIrradiance(12, 1000);
      assert.ok(irradianceNoon > 999, 'Irradiance max a midi');
    });

    it('doit suivre un profil sinusoidal', () => {
      const irradiance6h = calculateIrradiance(6, 1000);
      const irradiance9h = calculateIrradiance(9, 1000);
      const irradiance12h = calculateIrradiance(12, 1000);
      const irradiance15h = calculateIrradiance(15, 1000);

      // 6h < 9h < 12h (matin)
      assert.ok(irradiance6h < irradiance9h, '6h < 9h');
      assert.ok(irradiance9h < irradiance12h, '9h < 12h');

      // Symetrie: 9h ~ 15h
      assert.ok(Math.abs(irradiance9h - irradiance15h) < 1, 'Symetrie 9h/15h');
    });
  });

  describe('calculateRevenue', () => {
    it('doit calculer les revenus correctement', () => {
      // 1000 kWh x 0.18 EUR/kWh = 180 EUR
      const revenue = calculateRevenue(1000);
      assert.strictEqual(revenue, 180);
    });

    it('doit retourner 0 pour 0 kWh', () => {
      const revenue = calculateRevenue(0);
      assert.strictEqual(revenue, 0);
    });
  });

  describe('Configuration des fermes', () => {
    it('doit avoir 3 fermes configurees', () => {
      const farms = Object.keys(FARMS_CONFIG);
      assert.strictEqual(farms.length, 3);
      assert.ok(farms.includes('provence'));
      assert.ok(farms.includes('occitanie'));
      assert.ok(farms.includes('aquitaine'));
    });

    it('doit avoir des capacites coherentes', () => {
      for (const [name, config] of Object.entries(FARMS_CONFIG)) {
        const expectedCapacity = (config.panels * config.panel_power_w) / 1_000_000;
        assert.strictEqual(
          config.capacity_mw,
          expectedCapacity,
          `Capacite incorrecte pour ${name}`
        );
      }
    });
  });

});
