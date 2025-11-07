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
    estado VARCHAR(20) DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'SUSPENDIDA', 'CERRADA'))
);

CREATE TABLE transacciones (
    id SERIAL PRIMARY KEY,
    cuenta_origen_id INTEGER REFERENCES cuentas_bancarias(id),
    cuenta_destino_id INTEGER REFERENCES cuentas_bancarias(id),
    tipo_transaccion VARCHAR(20) NOT NULL CHECK (tipo_transaccion IN ('DEPOSITO', 'RETIRO', 'TRANSFERENCIA')),
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
('CTA-008', 'Sofía Ramírez', 15000.00, 'ACTIVA');

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

-- Paso 1.5: Obtener información del directorio de datos
SHOW data_directory;
SELECT pg_current_wal_lsn();

-- PARTE 2: TRANSACCIONES Y ANÁLISIS DEL COMPORTAMIENTO DEL LOG

-- Paso 2.1: Transacción exitosa simple
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

-- Verificar cambios antes de confirmar
SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

COMMIT;

-- Verificar LSN después del commit
SELECT pg_current_wal_lsn();

-- Paso 2.2: Transacción con múltiples operaciones
BEGIN;

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('TRANSACCION_TEST_2', 'ADMIN', 'Prueba de transacción compleja');

-- Operación 1: Retiro de CTA-003
UPDATE cuentas_bancarias
SET saldo = saldo - 500.00
WHERE numero_cuenta = 'CTA-003';

INSERT INTO transacciones (cuenta_origen_id, tipo_transaccion, monto, descripcion)
VALUES (3, 'RETIRO', 500.00, 'Retiro en efectivo');

-- Operación 2: Transferencia entre CTA-004 y CTA-005
UPDATE cuentas_bancarias
SET saldo = saldo - 2000.00
WHERE numero_cuenta = 'CTA-004';

UPDATE cuentas_bancarias
SET saldo = saldo + 2000.00
WHERE numero_cuenta = 'CTA-005';

INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
VALUES (4, 5, 'TRANSFERENCIA', 2000.00, 'Transferencia múltiple');

-- Operación 3: Depósito en CTA-006
UPDATE cuentas_bancarias
SET saldo = saldo + 1500.00
WHERE numero_cuenta = 'CTA-006';

-- Paso 2.3: Transacción que será abortada
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

-- Verificar cambios
SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-007', 'CTA-008');

ROLLBACK;

-- Verificar que los cambios no persisten
SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-007', 'CTA-008');

-- Verificar si se registró en auditoría
SELECT * FROM auditoria_sistema WHERE operacion = 'TRANSACCION_TEST_3';

-- Paso 2.4: Transacción con violación de restricción
BEGIN;

-- Intentar dejar saldo negativo
UPDATE cuentas_bancarias
SET saldo = saldo - 10000.00
WHERE numero_cuenta = 'CTA-007';

COMMIT;

-- Paso 2.5: Ver información de transacciones activas
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

-- Paso 2.6: Crear procedimiento almacenado para transferencias
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
    -- Obtener IDs y saldo
    SELECT id, saldo INTO v_id_origen, v_saldo_origen
    FROM cuentas_bancarias
    WHERE numero_cuenta = p_cuenta_origen AND estado = 'ACTIVA';

    SELECT id INTO v_id_destino
    FROM cuentas_bancarias
    WHERE numero_cuenta = p_cuenta_destino AND estado = 'ACTIVA';

    -- Validaciones
    IF v_id_origen IS NULL OR v_id_destino IS NULL THEN
        RAISE EXCEPTION 'Una o ambas cuentas no existen o no están activas';
    END IF;

    IF v_saldo_origen < p_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente';
    END IF;

    -- Realizar transferencia
    UPDATE cuentas_bancarias SET saldo = saldo - p_monto WHERE id = v_id_origen;
    UPDATE cuentas_bancarias SET saldo = saldo + p_monto WHERE id = v_id_destino;

    INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
    VALUES (v_id_origen, v_id_destino, 'TRANSFERENCIA', p_monto, 'Transferencia automática');

    INSERT INTO auditoria_sistema (operacion, usuario, detalle)
    VALUES ('TRANSFERENCIA', CURRENT_USER, 'Transferencia de ' || p_cuenta_origen || ' a ' || p_cuenta_destino);

    RETURN TRUE;

END;
$$ LANGUAGE plpgsql;

-- Paso 2.7: Probar el procedimiento almacenado
-- Transferencia exitosa
SELECT transferir_fondos('CTA-001', 'CTA-002', 500.00);

-- Verificar resultado
SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

-- Intentar transferencia con saldo insuficiente
SELECT transferir_fondos('CTA-003', 'CTA-004', 50000.00);

-- PARTE 3: CHECKPOINT Y ANÁLISIS DE RENDIMIENTO

-- Paso 3.1: Crear tabla para medir rendimiento
CREATE TABLE metricas_rendimiento (
    id SERIAL PRIMARY KEY,
    operacion VARCHAR(50),
    tiempo_inicio TIMESTAMP,
    tiempo_fin TIMESTAMP,
    duracion_ms NUMERIC,
    lsn_inicio TEXT,
    lsn_fin TEXT,
    observaciones TEXT
);

-- Paso 3.2: Medir rendimiento antes de checkpoint
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

    -- Insertar 1000 transacciones
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

-- Paso 3.3: Forzar un checkpoint manual
CHECKPOINT;

-- Paso 3.4: Ver estadísticas del checkpoint
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

-- Paso 3.5: Medir rendimiento después de checkpoint
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

    -- Insertar otras 1000 transacciones
    FOR v_i IN 1001..2000 LOOP
        INSERT INTO transacciones (cuenta_origen_id, cuenta_destino_id, tipo_transaccion, monto, descripcion)
        VALUES (1, 2, 'TRANSFERENCIA', 10.00, 'Transacción de prueba ' || v_i);
    END LOOP;

    v_fin := clock_timestamp();
    v_lsn_fin := pg_current_wal_lsn()::TEXT;

    INSERT INTO metricas_rendimiento (operacion, tiempo_inicio, tiempo_fin, duracion_ms, lsn_inicio, lsn_fin, observaciones)
    VALUES ('INSERT_1000_DESPUES_CHECKPOINT', v_inicio, v_fin,
    EXTRACT(EPOCH FROM (v_fin - v_inicio)) * 1000,
    v_lsn_inicio, v_lsn_fin, 'Prueba después de checkpoint');

END $$;

SELECT operacion, duracion_ms, observaciones FROM metricas_rendimiento ORDER BY id;

-- PARTE 4: SIMULACIÓN DE DIFERENTES TIPOS DE FALLOS

-- Paso 4.1: Preparar escenario con datos críticos
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

-- Insertar registro de inicio
INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('PREPARACION_PRUEBA_FALLO', 'SYSTEM', 'Sistema preparado para prueba de fallo');

-- Paso 4.2: Ejecutar transacciones críticas antes del fallo
BEGIN;
INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('OPERACION_CRITICA_1', 'ADMIN', 'Operación crítica antes de fallo - DEBE PERSISTIR');

UPDATE cuentas_bancarias SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-001';
UPDATE cuentas_bancarias SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-002';
UPDATE cuentas_bancarias SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-003';

INSERT INTO transacciones (cuenta_destino_id, tipo_transaccion, monto, descripcion, estado)
VALUES (1, 'DEPOSITO', 1000.00, 'Depósito crítico 1', 'COMPLETADA'),
       (2, 'DEPOSITO', 1000.00, 'Depósito crítico 2', 'COMPLETADA'),
       (3, 'DEPOSITO', 1000.00, 'Depósito crítico 3', 'COMPLETADA');
COMMIT;

-- Esperar un momento
SELECT pg_sleep(2);

BEGIN;
INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('OPERACION_CRITICA_2', 'ADMIN', 'Operación crítica antes de fallo - DEBE PERSISTIR');

UPDATE configuracion_sistema SET valor = '0.06' WHERE parametro = 'TASA_INTERES';
COMMIT;

-- Anotar estado antes del fallo
SELECT 'SALDOS_ANTES_FALLO' AS momento, numero_cuenta, saldo
FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002', 'CTA-003')
ORDER BY numero_cuenta;

SELECT 'CONFIG_ANTES_FALLO' AS momento, parametro, valor
FROM configuracion_sistema
WHERE parametro = 'TASA_INTERES';

-- Paso 4.7: Verificar integridad de datos después de recuperación
\c lab_recuperacion

-- Verificar auditoría
SELECT * FROM auditoria_sistema
WHERE operacion LIKE 'OPERACION_CRITICA%'
ORDER BY id;

-- Verificar saldos
SELECT 'SALDOS_DESPUES_FALLO' AS momento, numero_cuenta, saldo
FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-001', 'CTA-002', 'CTA-003')
ORDER BY numero_cuenta;

-- Verificar configuración
SELECT 'CONFIG_DESPUES_FALLO' AS momento, parametro, valor
FROM configuracion_sistema
WHERE parametro = 'TASA_INTERES';

-- Verificar transacciones
SELECT COUNT(*) AS total_transacciones FROM transacciones;

-- Paso 4.8: Simular fallo tipo 2 - Transacción interrumpida
-- Sesión 1
BEGIN;
INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('OPERACION_INTERRUMPIDA', 'ADMIN', 'Esta operación será interrumpida - NO DEBE PERSISTIR');

UPDATE cuentas_bancarias SET saldo = saldo + 5000 WHERE numero_cuenta = 'CTA-004';
UPDATE cuentas_bancarias SET saldo = saldo + 5000 WHERE numero_cuenta = 'CTA-005';

-- NO HACER COMMIT, dejar la transacción abierta
SELECT pg_sleep(30); -- Esperar 30 segundos

-- Verificar si la operación interrumpida persistió
SELECT * FROM auditoria_sistema WHERE operacion = 'OPERACION_INTERRUMPIDA';

-- Verificar saldos (NO deben haber cambiado)
SELECT numero_cuenta, saldo FROM cuentas_bancarias
WHERE numero_cuenta IN ('CTA-004', 'CTA-005');

-- PARTE 5: ANÁLISIS DETALLADO DE ARCHIVOS WAL

-- Paso 5.1: Identificar archivos WAL activos
SELECT
    pg_walfile_name(pg_current_wal_lsn()) AS archivo_wal_actual,
    pg_current_wal_lsn() AS lsn_actual,
    pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') AS bytes_desde_inicio;

-- Paso 5.3: Generar carga de trabajo y analizar crecimiento de WAL
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

-- Ejecutar con diferentes cargas
SELECT * FROM generar_carga_wal(100);
SELECT * FROM generar_carga_wal(500);
SELECT * FROM generar_carga_wal(1000);

-- Paso 5.4: Monitorear el tamaño del WAL en tiempo real
SELECT
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS wal_generado_total,
    pg_walfile_name(pg_current_wal_lsn()) AS archivo_actual,
    pg_current_wal_lsn() AS lsn_actual;

-- PARTE 6: RESPALDOS Y RESTAURACIÓN

-- Paso 6.2: Realizar cambios después del backup
\c lab_recuperacion

INSERT INTO auditoria_sistema (operacion, usuario, detalle)
VALUES ('POST_BACKUP_1', 'ADMIN', 'Operación después del backup 1');

-- Realizar varias operaciones
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

-- Anotar estado actual
SELECT 'ESTADO_POST_BACKUP' AS momento, COUNT(*) AS total_registros
FROM transacciones;

SELECT 'ESTADO_POST_BACKUP' AS momento, COUNT(*) AS total_auditoria
FROM auditoria_sistema;

-- Paso 6.3: Simular pérdida catastrófica de datos
-- Conectarse a otra base de datos
\c postgres

-- Eliminar la base de datos
DROP DATABASE lab_recuperacion;

-- Verificar que ya no existe
\l

-- Paso 6.5: Verificar restauración
\c lab_recuperacion

-- Verificar auditoría (NO deben existir las operaciones POST_BACKUP)
SELECT * FROM auditoria_sistema
WHERE operacion LIKE 'POST_BACKUP%';

-- Verificar totales
SELECT 'ESTADO_POST_RESTAURACION' AS momento, COUNT(*) AS total_registros
FROM transacciones;

SELECT 'ESTADO_POST_RESTAURACION' AS momento, COUNT(*) AS total_auditoria
FROM auditoria_sistema;
