-- PARTE 1: CONFIGURACIÓN INICIAL Y PREPARACIÓN DEL ENTORNO

-- Paso 1.1: Crear la base de datos de prueba
CREATE DATABASE lab_recuperacion;
-- Paso 1.2: Crear esquema de base de datos bancario
CREATE TABLE cuentas_bancarias (
	id SERIAL PRIMARY KEY,
	numero_cuenta VARCHAR(20) UNIQUE NOT NULL,
	titular VARCHAR(100) NOT NULL,
	saldo DECIMAL(12,2) NOT NULL CHECK (saldo >= 0),
	fecha_apertura DATE DEFAULT CURRENT_DATE,
	estado VARCHAR(20) DEFAULT 'ACTIVA' CHECK (estado IN('ACTIVA', 'SUSPENDIDA', 'CERRADA'))
);

CREATE TABLE transacciones (
	id SERIAL PRIMARY KEY,
	cuenta_origen_id INTEGER REFERENCES cuentas_bancarias(id),
	cuenta_destino_id INTEGER REFERENCES cuentas_bancarias(id),
	tipo_transaccion VARCHAR(20) NOT NULL CHECK (tipo_transaccion in ('DEPOSITO', 'RETIRO', 'TRANSFERENCIA')),
	monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
	fecha_transaccion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	descripcion TEXT,
	estado VARCHAR(20) DEFAULT 'COMPLETADA' CHECK (estado IN ('COMPLETADA', 'RECHAZADA', 'PENDIENTE'))
);

CREATE TABLE auditoria_sistema (
	id SERIAL PRIMARY KEY,
	operacion VARCHAR(100),
	usuario VARCHAR(50),
	timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	detalle TEXT
);

CREATE INDEX idx_transacciones_fecha ON transacciones(fecha_transaccion);
CREATE INDEX idx_cuentas_titular ON cuentas_bancarias(titular);

-- Paso 1.3: Insertar datos iniciales

INSERT INTO cuentas_bancarias (numero_cuenta, titular, saldo, estado) VALUES
('CTA-001', 'Juan Pérez', 5000.00, 'ACTIVA'),
('CTA-002', 'María García', 8500.00, 'ACTIVA'),
('CTA-003', 'Carlos López', 3200.00, 'ACTIVA'),
('CTA-004', 'Ana Martínez', 12000.00, 'ACTIVA'),
('CTA-005', 'Pedro Rodríguez', 6700.00, 'ACTIVA'),
('CTA-006', 'Laura Fernández', 9200.00, 'ACTIVA'),
('CTA-007', 'Miguel Torres', 4500.00, 'ACTIVA'),
('CTA-008', 'Sofia Ramírez', 15000.00, 'ACTIVA');

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('INICIO_LABORATORIO', 'SYSTEM', 'Inicialización de base de datos de prueba');

-- Paso 1.4: Verificar configuración actual de WAL
SHOW wal_level;
SHOW fsync;
SHOW synchronous_commit;
SHOW wal_buffers;
SHOW checkpoint_timeout;
SHOW max_wal_size;
SHOW min_wal_size;

SHOW data_directory;
SELECT pg_current_wal_lsn();

-- paso 2.1

BEGIN;

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('TRANSACCION_TEST_1', 'ADMIN', 'Prueba de transacción exitosa');

UPDATE cuentas_bancarias
SET saldo = saldo - 1000.00
WHERE numero_cuenta = 'CTA-001';

UPDATE cuentas_bancarias
SET saldo = saldo + 1000.00
WHERE numero_cuenta = 'CTA-002';

INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
VALUES (1, 2, 'TRANSFERENCIA', 1000.00, 'Transferencia de prueba 1');

SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

COMMIT;

SELECT pg_current_wal_lsn();

-- paso 2.2

BEGIN;

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('TRANSACCION_TEST_2', 'ADMIN', 'Prueba de transacción compleja');

UPDATE cuentas_bancarias
SET saldo = saldo - 500.00
WHERE numero_cuenta = 'CTA-003';

INSERT INTO transacciones (cuenta_origen_id, tipo_transaccion, monto, descripcion)
VALUES (3, 'RETIRO', 500.00, 'Retiro en efectivo');

UPDATE cuentas_bancarias
SET saldo = saldo - 2000.00
WHERE numero_cuenta = 'CTA-004';

UPDATE cuentas_bancarias
SET saldo = saldo + 2000.00
WHERE numero_cuenta = 'CTA-005';

INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
VALUES (4, 5, 'TRANSFERENCIA', 2000.00, 'Transferencia múltiple');

UPDATE cuentas_bancarias
SET saldo = saldo + 1500.00
WHERE numero_cuenta = 'CTA-006';

COMMIT;

SELECT pg_current_wal_lsn();

-- 2.3

BEGIN;

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('TRANSACCION_TEST_3', 'ADMIN', 'Prueba de transacción abortada');

UPDATE cuentas_bancarias
SET saldo = saldo - 800.00
WHERE numero_cuenta = 'CTA-007';

UPDATE cuentas_bancarias
SET saldo = saldo + 800.00
WHERE numero_cuenta = 'CTA-008';

INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
VALUES (7, 8, 'TRANSFERENCIA', 800.00, 'Transferencia que será cancelada');

SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-007', 'CTA-008');

ROLLBACK;

SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-007', 'CTA-008');

SELECT * FROM auditoria_sistema WHERE operacion = 'TRANSACCION_TEXT_3';

-- Paso 2.4

BEGIN;

UPDATE cuentas_bancarias
SET saldo = saldo - 10000.00
WHERE numero_cuenta = 'CTA-007';

COMMIT;

-- Paso 2.5

SELECT 
	pid,
	usename,
	application_name,
	state,
	query_start,
	state_change,
	query
FROM pg_stat_activity
WHERE datname = 'lab_recuperacion';

-- Paso 2.6

CREATE OR REPLACE FUNCTION transferir_fondos(
	p_cuenta_origen VARCHAR,
	p_cuenta_destino VARCHAR,
	p_monto DECIMAL
) RETURNS BOOLEAN AS $$
DECLARE
	v_id_origen INTEGER;
	v_id_destino INTEGER;
	v_saldo_origen DECIMAL;
BEGIN
	SELECT id, saldo INTO v_id_origen, v_saldo_origen
	FROM cuentas_bancarias
	WHERE numero_cuenta = p_cuenta_origen AND estado = 'ACTIVA';

	SELECT id INTO v_id_destino
	FROM cuentas_bancarias
	WHERE numero_cuenta = p_cuenta_destino AND estado = 'ACTIVA';

	IF v_id_origen IS NULL OR v_id_Destino IS NULL THEN
		RAISE EXCEPTION 'Una o ambas cuentas no existen o no están activas';
	END IF;

	IF v_saldo_origen < p_monto THEN
		RAISE EXCEPTION 'Saldo insuficiente';
	END IF;

	UPDATE cuentas_bancarias SET saldo = saldo - p_monto WHERE id = v_id_origen;
	UPDATE cuentas_bancarias SET saldo = saldo + p_monto WHERE id = v_id_destino;

	INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
	VALUES (v_id_origen, v_id_destino, 'TRANSFERENCIA', p_monto, 'Transferencia automática');

	INSERT INTO auditoria_sistema (operacion, usuario, detalle)
	VALUES ('TRANSFERENCIA', CURRENT_USER, 'Transferencia de ' || p_cuenta_origen || ' a ' || p_cuenta_destino);

	RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 2.7

SELECT transferir_fondos('CTA-001', 'CTA-002', 500.00);

SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

SELECT transferir_fondos('CTA-003', 'CTA-004', 50000.00);

--SELECT numero_cuenta, saldo FROM cuentas_bancarias
--WHERE numero_cuenta IN ('CTA-003', 'CTA-004');

-- Paso 3.1

CREATE TABLE metricas_rendimiento  (
	id SERIAL PRIMARY KEY,
	operacion VARCHAR(50),
	tiempo_inicio TIMESTAMP,
	tiempo_fin TIMESTAMP,
	duracion_ms NUMERIC,
	lsn_inicio TEXT,
	lsn_fin TEXT,
	observaciones TEXT
);

-- 3.2

DO $$
DECLARE
	v_inicio TIMESTAMP;
	v_fin TIMESTAMP;
	v_lsn_inicio TEXT;
	v_lsn_fin TEXT;
	v_i INTEGER;
BEGIN
	v_inicio := clock_timestamp();
	v_lsn_inicio := pg_current_wal_lsn()::TEXT;

	FOR v_i IN 1..1000 LOOP
		INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
		VALUES (1, 2, 'TRANSFERENCIA', 10.00, 'Transacción de prueba ' || v_i);
	END LOOP;

	v_fin := clock_timestamp();
	v_lsn_fin := pg_current_wal_lsn()::TEXT;

	INSERT INTO metricas_rendimiento (operacion, tiempo_inicio, tiempo_fin, duracion_ms, lsn_inicio, lsn_fin, observaciones)
	VALUES ('INSERT_1000_ANTES_CHECKPOINT', v_inicio, v_fin,
			EXTRACT(EPOCH FROM (v_fin - v_inicio)) * 1000,
			v_lsn_inicio, v_lsn_fin, 'Prueba antes de checkpoint');
END $$;

SELECT * FROM metricas_rendimiento;

-- Paso 3.3

CHECKPOINT;

-- 3.4

SELECT
	checkpoints_timed AS "Checkpoints por tiempo",
	checkpoints_req AS "Checkpoints solicitados",
	checkpoint_write_time AS "Tiempo escritura (ms)",
	checkpoint_sync_time AS "Tiempo sync (ms)",
	buffers_checkpoint AS "Buffers escritos en checkpoint",
	buffers_clean AS "Buffers limpiados por bgwriter",
	maxwritten_clean AS "Veces que bgwriter se detuvo",
	buffers_backend AS "Buffers escritos por backends",
	buffers_backend_fsync AS "Veces que backend ejecutó fsync"
FROM pg_stat_bgwriter;

-- 3.5

DO $$
DECLARE
	v_inicio TIMESTAMP;
	v_fin TIMESTAMP;
	v_lsn_inicio TEXT;
	v_lsn_fin TEXT;
	v_i INTEGER;
BEGIN
	v_inicio := clock_timestamp();
	v_lsn_inicio := pg_current_wal_lsn()::TEXT;

	FOR v_i IN 1001..2000 LOOP
		INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
		VALUES (1, 2, 'TRANSFERENCIA', 10.00, 'Transacción de prueba ' || v_i);
	END LOOP;

	v_fin := clock_timestamp();
	v_lsn_fin := pg_current_wal_lsn()::TEXT;

	INSERT INTO metricas_rendimiento (operacion, tiempo_inicio, tiempo_fin, duracion_ms, lsn_inicio, lsn_fin, observaciones)
	VALUES ('INSERT_1000_DESPUES_CHECKPOINT', v_inicio, v_fin,
			EXTRACT(EPOCH FROM (v_fin - v_inicio)) * 1000,
			v_lsn_inicio, v_lsn_fin, 'Prueba despues de checkpoint');
END $$;

-- 3.6
-- sesion 1

BEGIN;
UPDATE cuentas_bancarias SET saldo = saldo + 100 WHERE numero_cuenta = 'CTA-001';
SELECT pg_sleep(10);

/*
sesion 2
BEGIN;
UPDATE cuentas_bancarias SET saldo = saldo + 200 WHERE numero_cuenta = 'CTA-002';
SELECT pg_sleep(5);
COMMIT;
*/

/*
sesion 3
BEGIN;
UPDATE cuentas_bancarias SET saldo = saldo + 300 WHERE numero_cuenta = 'CTA-003';
COMMIT;
*/

COMMIT;

-- SHOW data_directory;

-- Paso 4.1

CREATE TABLE configuracion_sistema (
	id SERIAL PRIMARY KEY,
	parametro VARCHAR(50) UNIQUE NOT NULL,
	valor TEXT NOT NULL,
	fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO configuracion_sistema (parametro, valor) VALUES
('TASA_INTERES', '0.05'),
('LIMITE_TRANSFERENCIA_DIARIA', '50000.00'),
('COMISION_RETIRO', '2.50'),
('ESTADO_SISTEMA', 'OPERATIVO');

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('PREPARACION_PRUEBA_FALLO', 'SYSTEM', 'Sistema preparado para prueba de fallo');

-- Paso 4.2

BEGIN;
INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('OPERACION_CRITICA_1', 'ADMIN', 'Operación crítica antes de fallo - DEBE PERSISTIR');

UPDATE cuentas_bancarias SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-001';
UPDATE cuentas_bancarias SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-002';
UPDATE cuentas_bancarias SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-003';

INSERT INTO transacciones (cuenta_destino_id, tipo_transaccion, monto, descripcion, estado)
VALUES
	(1, 'DEPOSITO', 1000.00, 'Depósito crítico 1', 'COMPLETADA'),
	(2, 'DEPOSITO', 1000.00, 'Depósito crítico 2', 'COMPLETADA'),
	(3, 'DEPOSITO', 1000.00, 'Depósito crítico 3', 'COMPLETADA');
COMMIT;

SELECT pg_sleep(2);

BEGIN;
INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('OPERACION_CRITICA_2', 'ADMIN', 'Operación crítica antes de fallo - DEBE PERSISTIR');

UPDATE configuracion_sistema SET valor = '0.06' WHERE parametro = 'TASA_INTERES';
COMMIT;

SELECT 'SALDOS_ANTES_FALLO' AS momento, numero_cuenta, saldo
FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002', 'CTA-003')
ORDER BY numero_cuenta;

SELECT 'CONFIG_ANTES_FALLO' AS momento, parametro, valor
FROM configuracion_sistema
WHERE parametro = 'TASA_INTERES';

-- Paso 4.7

SELECT * FROM auditoria_sistema
WHERE operacion LIKE 'OPERACION_CRITICA%'
ORDER BY id;

SELECT 'SALDOS_DESPUES_FALLO' AS momento, numero_cuenta, saldo
FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002', 'CTA-003')
ORDER BY numero_cuenta;

SELECT 'CONFIG_DESPUES_FALLO' AS momento, parametro, valor
FROM configuracion_sistema
WHERE parametro = 'TASA_INTERES';

SELECT COUNT(*) AS total_transacciones FROM transacciones;

-- 4.8

BEGIN;
INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('OPERACION_INTERRUMPIDA', 'ADMIN', 'Esta operación será interrumpida - NO DEBE PERSISTIR');

UPDATE cuentas_bancarias SET saldo = saldo + 5000 WHERE numero_cuenta = 'CTA-004';
UPDATE cuentas_bancarias SET saldo = saldo + 5000 WHERE numero_cuenta = 'CTA-005';

SELECT pg_sleep(30);

/*
Sesion 2
SELECT pid, state, query
FROM pg_stat_activity
WHERE datname = 'lab_recuperacion' AND state = 'active';
*/

SELECT * FROM auditoria_sistema WHERE operacion = 'OPERACION_INTERRUMPIDA';

SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-004', 'CTA-005');

-- 5.1

SELECT
	pg_walfile_name(pg_current_wal_lsn()) AS archivo_wal_actual,
	pg_current_wal_lsn() AS lsn_actual,
	pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') AS bytes_desde_inicio;

-- 5.3

CREATE OR REPLACE FUNCTION generar_carga_wal(p_iteraciones INTEGER)
RETURNS TABLE(lsn_inicial TEXT, lsn_final TEXT, bytes_generados NUMERIC) AS $$
DECLARE
	v_lsn_inicial TEXT;
	v_lsn_final TEXT;
	v_i INTEGER;
BEGIN
	v_lsn_inicial := pg_current_wal_lsn()::TEXT;

	FOR v_i IN 1..p_iteraciones LOOP
		INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
		VALUES (
			(RANDOM() * 7 + 1)::INTEGER,
			(RANDOM() * 7 + 1)::INTEGER,
			'TRANSFERENCIA',
			(RANDOM() * 1000 + 10)::NUMERIC(12,2),
			'Carga de trabajo ' || v_i
		);
	END LOOP;

	v_lsn_final := pg_current_wal_lsn()::TEXT;

	RETURN QUERY
	SELECT
		v_lsn_inicial,
		v_lsn_final,
		pg_wal_lsn_diff(v_lsn_final::pg_lsn, v_lsn_inicial::pg_lsn);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM generar_carga_wal(100);
SELECT * FROM generar_carga_wal(500);
SELECT * FROM generar_carga_wal(1000);

SELECT 
	pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS wal_generado_total,
	pg_walfile_name(pg_current_wal_lsn()) AS archivo_actual,
	pg_current_wal_lsn() AS lsn_actual;

-- 6.2

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('POST_BACKUP_1', 'ADMIN', 'Operación después del backup 1');

UPDATE cuentas_bancarias SET saldo = saldo + 100 WHERE id BETWEEN 1 AND 4;
UPDATE cuentas_bancarias SET saldo = saldo + 200 WHERE id BETWEEN 5 AND 8;

INSERT INTO transacciones (cuenta_origen_id, tipo_transaccion, monto, descripcion)
SELECT
	id,
	'DEPOSITO',
	100.00,
	'Depósito post-backup'
FROM cuentas_bancarias
WHERE id <= 8;

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('POST_BACKUP_2', 'ADMIN', 'Operación después del backup 2');

SELECT 'ESTADO_POST_BACKUP' AS momento, COUNT(*) AS total_registros
FROM transacciones;

SELECT 'ESTADO_POST_BACKUP' AS momento, COUNT(*) AS total_registros
FROM auditoria_sistema;

-- 6.5

SELECT * FROM auditoria_sistema
WHERE operacion LIKE 'POST_BACKUP%'

SELECT 'ESTADO_POST_BACKUP' AS momento, COUNT(*) AS total_registros
FROM transacciones;

SELECT 'ESTADO_POST_BACKUP' AS momento, COUNT(*) AS total_registros
FROM auditoria_sistema;
