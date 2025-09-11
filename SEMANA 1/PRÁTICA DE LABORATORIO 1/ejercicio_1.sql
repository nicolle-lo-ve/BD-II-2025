-- Crear base de datos
CREATE DATABASE practica_almacenamiento;

-- Conectarse a la base de datos
\c practica_almacenamiento;

-- Crear tabla estudiantes 
CREATE TABLE estudiantes (
	id_estudiante INTEGER PRIMARY KEY,
	nombres VARCHAR(50) NOT NULL,
	apellido VARCHAR(50) NOT NULL,
	carrera VARCHAR(30),
	semestre INTEGER,
	promedio DECIMAL(4,2)
);

INSERT INTO estudiantes VALUES
(1001, 'Ana', 'García López', 'Ingenieria de Software', 6, 16.5),
(1015, 'Carlos', 'Mendoza Silva', 'Ingenieria de Software', 5, 15.8),
(1028, 'Maria', 'Torres Vega', 'Ingenieria de Sistemas', 7, 17.2),
(1035, 'José', 'Ramirez Cruz', 'Ingenieria de Software', 4, 14.9),
(1042, 'Lucía', 'Herrea Díaz', 'Ingenieria de Industrial', 8, 18.1),
(1056, 'Diego', 'Castillo Ruíz', 'Ingenieria de Software', 6, 16.8),
(1063, 'Patricia', 'Morales Soto', 'Ingenieria de Sisitemas', 3, 15.4),
(1077, 'Roberto', 'Jiménez Paz', 'Ingenieria de Software', 5, 17.0),
(1084, 'Carmen', 'Vargas León', 'Ingenieria de Industrial', 7, 16.3),
(1098, 'Miguel', 'Santos Ríos', 'Ingenieria de Sistemas', 4, 15.1);


CREATE TABLE estudiantes_heap AS
SELECT * FROM estudiantes;

-- Verificar que no tiene indices
SELECT * FROM pg_indexes WHERE tablename = 'estudiantes_heap';

-- Activar medición de tiempo
\timing on

-- Busqueda secuecnial completa 
SELECT * FROM estudiantes_heap WHERE id_estudiante = 1077;

-- Contar cuántos registros se examinaron
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM estudiantes_heap WHERE id_estudiante = 1077;

-- Búsqueda en tabla ordenada
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM estudiantes_ordenados WHERE id_estudiante = 1077;

-- Búsqueda por rango (ventaja de estructura ordenada)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM estudiantes_ordenados
WHERE id_estudiante BETWEEN 1030 AND 1080;

CREATE TABLE estudiantes_ordenados AS
SELECT * FROM estudiantes ORDER BY id_estudiante;

-- Crear índice para simular orden físico
CREATE INDEX idx_estudiantes_ordenados_id
ON estudiantes_ordenados(id_estudiante);

-- Crear función hash simple
CREATE OR REPLACE FUNCTION hash_estudiante(id INTEGER )
RETURNS INTEGER AS $$
BEGIN
	RETURN id % 7;
END;
$$ LANGUAGE plpgsql;

-- Ver distribución hash
SELECT
	id_estudiante,
	nombres,
	apellido,
	hash_estudiante(id_estudiante)as posicion_hash
FROM estudiantes
ORDER BY hash_estudiante(id_estudiante),id_estudiante;

-- Identificar colisiones
SELECT 
	hash_estudiante(id_estudiante) as posicion_hash,
	COUNT(*) as cantidad_registros,
	ARRAY_AGG(id_estudiante ORDER BY id_estudiante) as ids_en_posicion
FROM estudiantes
GROUP BY hash_estudiante(id_estudiante)
ORDER BY posicion_hash;

-- Crear tabla principal particionada
CREATE TABLE estudiantes_hash (
	id_estudiante INTEGER,
	nombres VARCHAR(50) NOT NULL,
	apellidos VARCHAR(50) NOT NULL,
	carrera VARCHAR(30),
	semestre INTEGER,
	promedio DECIMAL(4,2)
) PARTITION BY HASH (id_estudiante);

-- Crear particiones
CREATE TABLE estudiantes_hash_p0 PARTITION OF estudiantes_hash 
	FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE estudiantes_hash_p1 PARTITION OF estudiantes_hash 
	FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE estudiantes_hash_p2 PARTITION OF estudiantes_hash 
	FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE estudiantes_hash_p3 PARTITION OF estudiantes_hash 
	FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Insertar datos
INSERT INTO estudiantes_hash SELECT * FROM estudiantes;

-- Ver distribución por partición
SELECT
	schemaname,
	tablename,
	n_tup_ins as registros_insertados
FROM pg_stat_user_tables
WHERE tablename LIKE 'estudiantes_hash_%'
ORDER BY tablename;
