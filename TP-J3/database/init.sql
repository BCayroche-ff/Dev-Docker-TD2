-- ===========================================
-- GreenWatt Database Schema & Data
-- ===========================================

-- Create installations table
CREATE TABLE IF NOT EXISTS installations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('solar', 'wind', 'hybrid')),
    location VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    capacity_kw DECIMAL(10, 2) NOT NULL,
    installation_date DATE,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create production_metrics table
CREATE TABLE IF NOT EXISTS production_metrics (
    id SERIAL PRIMARY KEY,
    installation_id INTEGER REFERENCES installations(id) ON DELETE CASCADE,
    timestamp TIMESTAMP NOT NULL,
    power_output_kw DECIMAL(10, 2),
    energy_produced_kwh DECIMAL(10, 2),
    efficiency_percent DECIMAL(5, 2),
    temperature_celsius DECIMAL(5, 2),
    solar_irradiance_wm2 DECIMAL(10, 2),
    wind_speed_ms DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_production_timestamp ON production_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_production_installation ON production_metrics(installation_id);

-- Create alerts table
CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    installation_id INTEGER REFERENCES installations(id) ON DELETE CASCADE,
    alert_type VARCHAR(50) NOT NULL CHECK (alert_type IN ('info', 'warning', 'critical', 'maintenance')),
    message TEXT NOT NULL,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP
);

-- Create index for alerts
CREATE INDEX IF NOT EXISTS idx_alerts_installation ON alerts(installation_id);
CREATE INDEX IF NOT EXISTS idx_alerts_created ON alerts(created_at);

-- Insert sample installations (10 installations in Occitanie)
INSERT INTO installations (name, type, location, latitude, longitude, capacity_kw, installation_date, status) VALUES
('Parc Solaire Montpellier', 'solar', 'Montpellier, Hérault', 43.6108, 3.8767, 250.00, '2020-05-15', 'active'),
('Éolienne Toulouse Sud', 'wind', 'Toulouse, Haute-Garonne', 43.6047, 1.4442, 150.00, '2019-03-22', 'active'),
('Installation Hybride Nîmes', 'hybrid', 'Nîmes, Gard', 43.8367, 4.3601, 300.00, '2021-01-10', 'active'),
('Ferme Solaire Carcassonne', 'solar', 'Carcassonne, Aude', 43.2132, 2.3508, 180.00, '2020-09-01', 'active'),
('Parc Éolien Perpignan', 'wind', 'Perpignan, Pyrénées-Orientales', 42.6886, 2.8948, 200.00, '2018-11-15', 'active'),
('Centrale Solaire Béziers', 'solar', 'Béziers, Hérault', 43.3442, 3.2150, 220.00, '2021-06-20', 'active'),
('Turbine Éolienne Albi', 'wind', 'Albi, Tarn', 43.9298, 2.1480, 120.00, '2019-08-05', 'active'),
('Parc Hybride Rodez', 'hybrid', 'Rodez, Aveyron', 44.3508, 2.5750, 280.00, '2020-12-01', 'active'),
('Ferme Solaire Cahors', 'solar', 'Cahors, Lot', 44.4485, 1.4415, 190.00, '2021-03-15', 'active'),
('Installation Éolienne Mende', 'wind', 'Mende, Lozère', 44.5185, 3.4995, 160.00, '2019-07-10', 'active');

-- Create views

-- View: current_production (latest metrics for each installation)
CREATE OR REPLACE VIEW current_production AS
SELECT DISTINCT ON (installation_id)
    installation_id,
    timestamp,
    power_output_kw,
    energy_produced_kwh,
    efficiency_percent,
    temperature_celsius,
    solar_irradiance_wm2,
    wind_speed_ms
FROM production_metrics
ORDER BY installation_id, timestamp DESC;

-- View: global_statistics
CREATE OR REPLACE VIEW global_statistics AS
SELECT
    COUNT(DISTINCT i.id) AS total_installations,
    SUM(i.capacity_kw) AS total_capacity_kw,
    COUNT(CASE WHEN i.type = 'solar' THEN 1 END) AS solar_count,
    COUNT(CASE WHEN i.type = 'wind' THEN 1 END) AS wind_count,
    COUNT(CASE WHEN i.type = 'hybrid' THEN 1 END) AS hybrid_count,
    COUNT(CASE WHEN i.status = 'active' THEN 1 END) AS active_count
FROM installations i;

-- ===========================================
-- Data Generation Functions
-- ===========================================

-- Function: generate_solar_metrics
CREATE OR REPLACE FUNCTION generate_solar_metrics(
    p_installation_id INTEGER,
    p_capacity_kw DECIMAL,
    p_days_back INTEGER
) RETURNS void AS $$
DECLARE
    v_date TIMESTAMP;
    v_hour INTEGER;
    v_power_output DECIMAL;
    v_efficiency DECIMAL;
    v_temperature DECIMAL;
    v_irradiance DECIMAL;
    v_base_efficiency DECIMAL := 0.88;
BEGIN
    FOR day_offset IN 0..p_days_back LOOP
        v_date := NOW() - (day_offset || ' days')::INTERVAL;

        FOR v_hour IN 0..23 LOOP
            IF v_hour >= 6 AND v_hour <= 20 THEN
                v_irradiance := 1000 * EXP(-POWER((v_hour - 13), 2) / 18.0) * (0.8 + RANDOM() * 0.4);
                v_temperature := 15 + (v_hour - 6) * 1.5 + RANDOM() * 5;
                v_efficiency := v_base_efficiency - (v_temperature - 25) * 0.004 + RANDOM() * 0.05;
                v_efficiency := GREATEST(0.70, LEAST(0.95, v_efficiency));
                v_power_output := p_capacity_kw * (v_irradiance / 1000.0) * v_efficiency;
                v_power_output := v_power_output * (0.7 + 0.3 * SIN((EXTRACT(DOY FROM v_date) - 172) * PI() / 182.5));

                IF RANDOM() < 0.2 THEN
                    v_power_output := v_power_output * (0.3 + RANDOM() * 0.4);
                    v_irradiance := v_irradiance * (0.3 + RANDOM() * 0.4);
                END IF;

                INSERT INTO production_metrics (
                    installation_id, timestamp, power_output_kw, energy_produced_kwh,
                    efficiency_percent, temperature_celsius, solar_irradiance_wm2
                ) VALUES (
                    p_installation_id,
                    v_date + (v_hour || ' hours')::INTERVAL,
                    ROUND(v_power_output, 2),
                    ROUND(v_power_output, 2),
                    ROUND(v_efficiency * 100, 2),
                    ROUND(v_temperature, 1),
                    ROUND(v_irradiance, 2)
                );
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function: generate_wind_metrics
CREATE OR REPLACE FUNCTION generate_wind_metrics(
    p_installation_id INTEGER,
    p_capacity_kw DECIMAL,
    p_days_back INTEGER
) RETURNS void AS $$
DECLARE
    v_date TIMESTAMP;
    v_hour INTEGER;
    v_power_output DECIMAL;
    v_efficiency DECIMAL;
    v_temperature DECIMAL;
    v_wind_speed DECIMAL;
    v_wind_base DECIMAL;
BEGIN
    FOR day_offset IN 0..p_days_back LOOP
        v_date := NOW() - (day_offset || ' days')::INTERVAL;
        v_wind_base := 8 + RANDOM() * 8;

        FOR v_hour IN 0..23 LOOP
            v_wind_speed := v_wind_base + SIN(v_hour * PI() / 12) * 3 + RANDOM() * 4;
            v_wind_speed := GREATEST(0, v_wind_speed);
            v_temperature := 12 + RANDOM() * 10;

            IF v_wind_speed < 3 THEN
                v_power_output := 0;
                v_efficiency := 0;
            ELSIF v_wind_speed > 25 THEN
                v_power_output := 0;
                v_efficiency := 0;
            ELSIF v_wind_speed < 12 THEN
                v_power_output := p_capacity_kw * POWER(v_wind_speed / 12, 3);
                v_efficiency := 70 + RANDOM() * 15;
            ELSE
                v_power_output := p_capacity_kw * (0.85 + RANDOM() * 0.15);
                v_efficiency := 85 + RANDOM() * 10;
            END IF;

            v_power_output := v_power_output * (0.8 + 0.4 * COS((EXTRACT(DOY FROM v_date) - 1) * PI() / 182.5));

            INSERT INTO production_metrics (
                installation_id, timestamp, power_output_kw, energy_produced_kwh,
                efficiency_percent, temperature_celsius, wind_speed_ms
            ) VALUES (
                p_installation_id,
                v_date + (v_hour || ' hours')::INTERVAL,
                ROUND(v_power_output, 2),
                ROUND(v_power_output, 2),
                ROUND(v_efficiency, 2),
                ROUND(v_temperature, 1),
                ROUND(v_wind_speed, 2)
            );
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function: generate_realistic_alerts
CREATE OR REPLACE FUNCTION generate_realistic_alerts(
    p_days_back INTEGER
) RETURNS void AS $$
DECLARE
    v_installation_id INTEGER;
    v_date TIMESTAMP;
    v_alert_type TEXT;
    v_messages TEXT[] := ARRAY[
        'Efficacité en baisse de 5% - Nettoyage recommandé',
        'Température élevée détectée sur onduleur',
        'Baisse de rendement de 3% - Vérification recommandée',
        'Maintenance préventive programmée',
        'Remplacement de composant nécessaire',
        'Turbine hors ligne - Intervention technique requise',
        'Production optimale atteinte',
        'Mise à jour firmware effectuée avec succès',
        'Connexion réseau instable',
        'Capteur de température défaillant'
    ];
BEGIN
    FOR day_offset IN 0..p_days_back LOOP
        v_date := NOW() - (day_offset || ' days')::INTERVAL;

        FOR i IN 1..(1 + FLOOR(RANDOM() * 3))::INTEGER LOOP
            SELECT id INTO v_installation_id FROM installations ORDER BY RANDOM() LIMIT 1;

            IF RANDOM() < 0.5 THEN v_alert_type := 'warning';
            ELSIF RANDOM() < 0.75 THEN v_alert_type := 'info';
            ELSIF RANDOM() < 0.9 THEN v_alert_type := 'maintenance';
            ELSE v_alert_type := 'critical';
            END IF;

            INSERT INTO alerts (installation_id, alert_type, message, is_resolved, created_at, resolved_at)
            VALUES (
                v_installation_id,
                v_alert_type,
                v_messages[1 + FLOOR(RANDOM() * array_length(v_messages, 1))],
                RANDOM() < 0.7,
                v_date + (FLOOR(RANDOM() * 24) || ' hours')::INTERVAL,
                CASE WHEN RANDOM() < 0.7
                    THEN v_date + (FLOOR(RANDOM() * 48) || ' hours')::INTERVAL
                    ELSE NULL
                END
            );
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- Generate Data
-- ===========================================

DO $$
DECLARE
    v_installation RECORD;
    v_days_back INTEGER := 90;
BEGIN
    RAISE NOTICE 'Début de la génération de données réalistes...';
    RAISE NOTICE 'Période : % jours', v_days_back;

    FOR v_installation IN
        SELECT id, type, capacity_kw, name
        FROM installations
        WHERE status = 'active'
    LOOP
        RAISE NOTICE 'Génération pour : % (%, % kW)',
            v_installation.name,
            v_installation.type,
            v_installation.capacity_kw;

        IF v_installation.type = 'solar' THEN
            PERFORM generate_solar_metrics(v_installation.id, v_installation.capacity_kw, v_days_back);
        ELSIF v_installation.type = 'wind' THEN
            PERFORM generate_wind_metrics(v_installation.id, v_installation.capacity_kw, v_days_back);
        ELSIF v_installation.type = 'hybrid' THEN
            PERFORM generate_solar_metrics(v_installation.id, v_installation.capacity_kw * 0.6, v_days_back);
            PERFORM generate_wind_metrics(v_installation.id, v_installation.capacity_kw * 0.4, v_days_back);
        END IF;
    END LOOP;

    RAISE NOTICE 'Génération des alertes...';
    PERFORM generate_realistic_alerts(v_days_back);

    RAISE NOTICE '✅ Génération terminée !';
    RAISE NOTICE '  - Installations : %', (SELECT COUNT(*) FROM installations);
    RAISE NOTICE '  - Métriques : %', (SELECT COUNT(*) FROM production_metrics);
    RAISE NOTICE '  - Alertes : %', (SELECT COUNT(*) FROM alerts);
END $$;

-- Cleanup functions
DROP FUNCTION IF EXISTS generate_solar_metrics(INTEGER, DECIMAL, INTEGER);
DROP FUNCTION IF EXISTS generate_wind_metrics(INTEGER, DECIMAL, INTEGER);
DROP FUNCTION IF EXISTS generate_realistic_alerts(INTEGER);
