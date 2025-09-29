-- PARTE 1: CONFIGURACIÓN DEL ENTORNO

-- Paso 1.1: Crear base de datos para el laboratorio

-- Como usuario postgres
CREATE DATABASE lab_particionamiento;
\c lab_particionamiento;

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Paso 1.2: Configurar logging para análisis

-- Habilitar logging de consultas lentas
ALTER SYSTEM SET log_min_duration_statement = 1000; -- 1 segundo
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();

-- PARTE 2: CREACIÓN DE DATOS DE PRUEBA

-- Paso 2.1: Crear tabla sin particionamiento

-- Tabla de ventas sin particiones (para comparación)
CREATE TABLE ventas_sin_particion (
    id SERIAL PRIMARY KEY,
    fecha_venta DATE NOT NULL,
    cliente_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    sucursal_id INTEGER NOT NULL,
    vendedor_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices básicos
CREATE INDEX idx_ventas_fecha ON ventas_sin_particion(fecha_venta);
CREATE INDEX idx_ventas_cliente ON ventas_sin_particion(cliente_id);

-- Paso 2.2: Generar datos de prueba masivos

-- Función para generar datos aleatorios
CREATE OR REPLACE FUNCTION generar_ventas_masivas(num_registros INTEGER)
RETURNS VOID AS $$
DECLARE
    i INTEGER;
    fecha_aleatoria DATE;
    precio DECIMAL(10,2);
BEGIN
    FOR i IN 1..num_registros LOOP
    -- Fecha entre 2020 y 2024
    fecha_aleatoria := '2020-01-01'::DATE +
    (RANDOM() * (DATE '2024-12-31' - DATE '2020-01-01'))::INTEGER;

    precio := ROUND((RANDOM() * 1000 + 10)::NUMERIC, 2);

    INSERT INTO ventas_sin_particion (
    fecha_venta, cliente_id, producto_id, cantidad,
    precio_unitario, total, sucursal_id, vendedor_id
) VALUES (
    fecha_aleatoria,
    (RANDOM() * 10000 + 1)::INTEGER,
    (RANDOM() * 5000 + 1)::INTEGER,
    (RANDOM() * 10 + 1)::INTEGER,
    precio,
    precio * (RANDOM() * 10 + 1),
    (RANDOM() * 50 + 1)::INTEGER,
    (RANDOM() * 200 + 1)::INTEGER
));
    
-- Mostrar progreso cada 100,000 registros
IF i % 100000 = 0 THEN
    RAISE NOTICE 'Insertados % registros', i;
    END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Ejecutar inserción de 2 millones de registros
SELECT generar_ventas_masivas(2000000);

-- Paso 2.3: Análisis de rendimiento inicial

-- Estadísticas de la tabla
SELECT
    schemaname,
    tablename,
    n_tup_ins as inserciones,
    n_tup_del as eliminaciones,
    n_tup_upd as actualizaciones,
    seq_scan as escaneos_secuencial,
    seq_tup_read as tuplas_leidas_secuencial,
    idx_scan as escaneos_indice
FROM pg_stat_user_tables
WHERE tablename = 'ventas_sin_particion';

-- Tamaño de la tabla
SELECT
    pg_size_pretty(pg_total_relation_size('ventas_sin_particion')) as tamaño_total,
    pg_size_pretty(pg_relation_size('ventas_sin_particion')) as tamaño_table,
    pg_size_pretty(pg_total_relation_size('ventas_sin_particion') - 
    pg_relation_size('ventas_sin_particion')) as tamaño_indices;

-- PARTE 3: IMPLEMENTACIÓN DE PARTICIONAMIENTO POR RANGO

-- Paso 3.1: Crear tabla particionada por fecha

-- Tabla principal con particionamiento por rango de fechas
CREATE TABLE ventas_particionada (
    id SERIAL,
    fecha_venta DATE NOT NULL,
    cliente_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    sucursal_id INTEGER NOT NULL,
    vendedor_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
) PARTITION BY RANGE (fecha_venta);

-- Crear particiones por año
CREATE TABLE ventas_2020 PARTITION OF ventas_particionada
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');

CREATE TABLE ventas_2021 PARTITION OF ventas_particionada
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');

CREATE TABLE ventas_2022 PARTITION OF ventas_particionada
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');

CREATE TABLE ventas_2023 PARTITION OF ventas_particionada
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE ventas_2024 PARTITION OF ventas_particionada
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- Paso 3.2: Crear índices en particiones

-- Índices automáticos en todas las particiones
CREATE INDEX idx_ventas_part_cliente ON ventas_particionada(cliente_id);
CREATE INDEX idx_ventas_part_producto ON ventas_particionada(producto_id);
CREATE INDEX idx_ventas_part_sucursal ON ventas_particionada(sucursal_id);

-- Verificar que los índices se crearon en cada partición
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE tablename LIKE 'ventas_%'
ORDER BY tablename, indexname;

-- Paso 3.3: Migrar datos existentes

-- Insertar datos desde tabla sin particiones
INSERT INTO ventas_particionada
SELECT * FROM ventas_sin_particion;

-- Verificar distribución de datos por partición
SELECT
    schemaname,
    tablename,
    n_tup_ins as registros
FROM pg_stat_user_tables
WHERE tablename LIKE 'ventas_2%'
ORDER BY tablename;

-- PARTE 4: PARTICIONAMIENTO HÍBRIDO

-- Paso 4.1: Crear subparticionamiento por hash

-- Tabla con particionamiento por fecha y subparticionamiento por hash
CREATE TABLE ventas_hibrida (
    id SERIAL,
    fecha_venta DATE NOT NULL,
    cliente_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    sucursal_id INTEGER NOT NULL,
    vendedor_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
) PARTITION BY RANGE (fecha_venta);

-- Partición principal 2024 con subparticiones por cliente_id
CREATE TABLE ventas_2024_base PARTITION OF ventas_hibrida
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01')
    PARTITION BY HASH (cliente_id);

-- Crear 4 subparticiones hash para 2024
CREATE TABLE ventas_2024_h0 PARTITION OF ventas_2024_base
    FOR VALUES WITH (modulus 4, remainder 0);

CREATE TABLE ventas_2024_h1 PARTITION OF ventas_2024_base
    FOR VALUES WITH (modulus 4, remainder 1);

CREATE TABLE ventas_2024_h2 PARTITION OF ventas_2024_base
    FOR VALUES WITH (modulus 4, remainder 2);

CREATE TABLE ventas_2024_h3 PARTITION OF ventas_2024_base
    FOR VALUES WITH (modulus 4, remainder 3);

-- Paso 4.2: Insertar datos de prueba específicos

-- Insertar datos específicos para 2024
INSERT INTO ventas_hibrida
SELECT * FROM ventas_sin_particion
WHERE fecha_venta >= '2024-01-01' AND fecha_venta < '2025-01-01';

-- Verificar distribución en subparticiones
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(tablename::regclass)) as tamaño,
    (SELECT COUNT(*) FROM information_schema.tables
    WHERE table_name = t.tablename) as existe
FROM (
    VALUES
    ('ventas_2024_h0'::text),
    ('ventas_2024_h1'::text),
    ('ventas_2024_h2'::text),
    ('ventas_2024_h3'::text)
) t(tablename);

-- PARTE 5: ANÁLISIS COMPARATIVO DE RENDIMIENTO

-- Paso 5.1: Pruebas de consulta por rango de fechas

-- Limpiar estadísticas
SELECT pg_stat_reset();

-- Consulta en tabla sin particionamiento
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
FROM ventas_sin_particion
WHERE fecha_venta BETWEEN '2023-06-01' AND '2023-08-31';

-- Misma consulta en tabla particionada
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
FROM ventas_particionada
WHERE fecha_venta BETWEEN '2023-06-01' AND '2023-08-31';

-- Paso 5.2: Pruebas de consulta específica por cliente

-- Consulta por cliente específico - tabla sin particiones
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT * FROM ventas_sin_particion
WHERE cliente_id = 5000
AND fecha_venta >= '2024-01-01'
ORDER BY fecha_venta DESC
LIMIT 100;

-- Misma consulta - tabla con subparticiones hash
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT * FROM ventas_hibrida
WHERE cliente_id = 5000
AND fecha_venta >= '2024-01-01'
ORDER BY fecha_venta DESC
LIMIT 100;

-- Paso 5.3: Análisis de partition pruning

-- Verificar eliminación de particiones
SET enable_partition_pruning = on;
SET constraint_exclusion = partition;

EXPLAIN (ANALYZE, BUFFERS)
SELECT sucursal_id, SUM(total) as ventas_totales
FROM ventas_particionada
WHERE fecha_venta = '2023-12-25'
GROUP BY sucursal_id
ORDER BY ventas_totales DESC;

-- Paso 5.4: Crear tabla de métricas comparativas

-- Tabla para almacenar resultados de pruebas
CREATE TABLE metricas_rendimiento (
    id SERIAL PRIMARY KEY,
    tipo_tabla VARCHAR(50),
    tipo_consulta VARCHAR(100),
    tiempo_ejecucion_ms DECIMAL(10,2),
    buffers_hit INTEGER,
    buffers_read INTEGER,
    filas_procesadas BIGINT,
    fecha_prueba TIMESTAMP DEFAULT NOW()
);

-- Función para ejecutar y medir consultas
CREATE OR REPLACE FUNCTION medir_consulta(
    nombre_prueba TEXT,
    consulta TEXT
) RETURNS VOID AS $$
DECLARE
    inicio TIMESTAMP;
    fin TIMESTAMP;
    duracion DECIMAL(10,2);
BEGIN
    inicio := clock_timestamp();
    EXECUTE consulta;
    fin := clock_timestamp();
    duracion := EXTRACT(MILLISECONDS FROM (fin - inicio));

    RAISE NOTICE 'Prueba: %, Duración: % ms', nombre_prueba, duracion;

    INSERT INTO metricas_rendimiento (tipo_tabla, tipo_consulta, tiempo_ejecucion_ms)
    VALUES (nombre_prueba, consulta, duracion);
END;
$$ LANGUAGE plpgsql;

-- PARTE 6: MANTENIMIENTO AUTOMATIZADO

-- Paso 6.1: Crear función para mantener particiones

-- Función para crear particiones automáticamente
CREATE OR REPLACE FUNCTION crear_particion_mensual(
    tabla_principal TEXT,
    año INTEGER,
    mes INTEGER
) RETURNS TEXT AS $$
DECLARE
    fecha_inicio DATE;
    fecha_fin DATE;
    nombre_particion TEXT;
    comando_sql TEXT;

BEGIN
    fecha_inicio := make_date(año, mes, 1);
    fecha_fin := fecha_inicio + INTERVAL '1 month';
    nombre_particion := tabla_principal || '_' || año || '_' ||
    LPAD(mes::TEXT, 2, '0');

    comando_sql := format(
    'CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
    nombre_particion, tabla_principal, fecha_inicio, fecha_fin
);

    EXECUTE comando_sql;

    RETURN 'Partición creada: ' || nombre_particion;

END;
$$ LANGUAGE plpgsql;

-- Probar la función
SELECT crear_particion_mensual('ventas_particionada', 2025, 1);

-- Paso 6.2: Procedimiento de limpieza de particiones antiguas

-- Función para eliminar particiones antiguas
CREATE OR REPLACE FUNCTION limpiar_particiones_antiguas(
    tabla_principal TEXT,
    meses_retener INTEGER DEFAULT 24
) RETURNS TEXT AS $$
DECLARE
    rec RECORD;
    fecha_limite DATE;
    resultado TEXT := '';
BEGIN
    fecha_limite := CURRENT_DATE - (meses_retener || ' months')::INTERVAL;

FOR rec IN
    SELECT tablename
    FROM pg_tables
    WHERE tablename LIKE tabla_principal || '_%'
    AND schemaname = 'public'
LOOP
-- Lógica simplificada - en producción sería más robusta
IF rec.tablename < tabla_principal || '_' ||
    EXTRACT(YEAR FROM fecha_limite)::TEXT THEN

    EXECUTE 'DROP TABLE ' || rec.tablename;
    resultado := resultado || 'Eliminada: ' || rec.tablename || '; ';
    END IF;
END LOOP;

    RETURN COALESCE(resultado, 'No se eliminaron particiones');
END;
$$ LANGUAGE plpgsql;
