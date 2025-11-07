
-- Paso 1: Conexión a la Base de Datos
-- CREATE DATABASE Laboratorio_indices;

-- DROP de tablas y eliminación de datos existentes
DROP TABLE IF EXISTS ventas CASCADE;
DROP TABLE IF EXISTS empleados CASCADE;

-- Paso 2: Creación de Tablas Base
CREATE TABLE empleados (
	id SERIAL PRIMARY KEY,
	nombre VARCHAR(100),
	email VARCHAR(100) UNIQUE,
	departamento VARCHAR(50),
	salario DECIMAL(10,2),
	fecha_ingreso DATE,
	activo BOOLEAN DEFAULT true
);

/* EJERCICIO 1: ANÁLISIS SIN ÍNDICES
Instrucciones
1. Poblar las tablas con datos de prueba
2. Ejecutar consultas sin índices
3. Medir tiempos de ejecución
*/


-- Tabla de ventas (tabla grande para pruebas)
CREATE TABLE ventas (
	id SERIAL PRIMARY KEY,
	empleado_id INTEGER REFERENCES empleados(id),
	fecha_venta TIMESTAMP,
	producto VARCHAR(100),
	categoria VARCHAR(50),
	precio DECIMAL(10,2),
	cantidad INTEGER,
	total DECIMAL(12,2)
);


-- Insertar datos de empleados (1000 registros)
INSERT INTO empleados (nombre, email, departamento, salario, fecha_ingreso)
SELECT
	'Empleado_'|| i,
	'emp' || i || '@empresa.com',
	CASE (i % 5)
		WHEN 0 THEN 'Ventas'
		WHEN 1 THEN 'Marketing'
		WHEN 2 THEN 'TI'
		WHEN 3 THEN 'RRHH'
		ELSE 'Finanzas'
	END,
	30000 + (RANDOM() * 50000):: INTEGER,
	'2020-01-01'::DATE + (RANDOM() * 1400):: INTEGER
FROM generate_series(1, 1000) AS i;



-- Insertar datos de ventas (100,000 registros)
INSERT INTO ventas (empleado_id, fecha_venta, producto, categoria, precio, cantidad, total)
SELECT
	(FLOOR(RANDOM() * 1000) + 1):: INTEGER,          
	'2023-01-01'::TIMESTAMP + (RANDOM() * 365 || 'days')::INTERVAL +
	(RANDOM() * 24 || 'hours')::INTERVAL,
	'Producto_' || (FLOOR(RANDOM() * 500) + 1):: INTEGER,
	CASE (FLOOR(RANDOM() * 4)):: INTEGER
		WHEN 0 THEN 'Electrónicos'
		WHEN 1 THEN 'Ropa'
		WHEN 2 THEN 'Hogar'
		ELSE 'Deportes'
	END,
	(RANDOM() * 1000 + 10)::DECIMAL(10,2),
	(FLOOR(RANDOM() * 10) + 1):: INTEGER,
	0 -- Se calculará después
FROM generate_series(1, 100000);


-- Actualizar el total
UPDATE ventas SET total = precio * cantidad;


-- CONSULTAS DE PRUEBA (SIN ÍNDICES)

-- Consulta 1: Búsqueda por ID de empleado
EXPLAIN ANALYZE
SELECT * FROM empleados WHERE id = 500;

-- Consulta 2: Búsqueda por departamento
EXPLAIN ANALYZE
SELECT * FROM empleados WHERE departamento = 'Ventas'; 

-- Consulta 3: Búsqueda por rango de salarios
EXPLAIN ANALYZE
SELECT * FROM empleados
WHERE salario BETWEEN 40000 AND 50000; 

-- Conusulta 4: JOIN entre tablas
EXPLAIN ANALYZE
SELECT e.nombre, COUNT(*) as total_ventas
FROM empleados e
JOIN ventas v ON e.id = v.empleado_id
WHERE v.fecha_venta >= '2023-06-01'
GROUP BY e.id, e.nombre
ORDER BY total_ventas DESC
LIMIT 10; 


/* EJERCICIO 2: CREACIÓN DE ÍNDICES BÁSICOS
Instrucciones
1. Crear índices apropiados
2. Re-ejecutar las mismas consultas
3. Comparar rendimiento
*/


-- DROP de índices existentes antes de crear nuevos
DROP INDEX IF EXISTS idx_empleados_departamento;
DROP INDEX IF EXISTS idx_empleados_salario;
DROP INDEX IF EXISTS idx_ventas_empleado_id;
DROP INDEX IF EXISTS idx_ventas_fecha;
DROP INDEX IF EXISTS idx_ventas_categoria;
DROP INDEX IF EXISTS idx_ventas_fecha_empleado;


-- Índice en departamento (B-tree por defecto)
CREATE INDEX idx_empleados_departamento
ON empleados (departamento) ; 

-- Índice en salario para búsquedas por rango
CREATE INDEX idx_empleados_salario
ON empleados (salario); 

-- Índice en email (único ya existe, pero lo mencionamos)
-- El índice único ya fue creado automáticamente

-- Índices en tabla de ventas
CREATE INDEX idx_ventas_empleado_id
ON ventas(empleado_id); 

CREATE INDEX idx_ventas_fecha
ON ventas (fecha_venta);

CREATE INDEX idx_ventas_categoria
ON ventas (categoria);


-- Índice compuesto para consultas especificas
CREATE INDEX idx_ventas_fecha_empleado
ON ventas (fecha_venta, empleado_id); 

-- Verificar Índices Creados
-- Ver todos los índices de una tabla
SELECT
	indexname,
	indexdef
FROM pg_indexes
WHERE tablename = 'empleados';


-- Ver tamaño de índices
SELECT
	schemaname,
	relname as tablename,
    indexrelname as indexname,
	pg_size_pretty(pg_total_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_total_relation_size(indexrelid) DESC; 

-- Re-ejecutar CONSULTAS DE PRUEBA (CON ÍNDICES)

-- Consulta 1: Búsqueda por ID de empleado
EXPLAIN ANALYZE
SELECT * FROM empleados WHERE id = 500;

-- Consulta 2: Búsqueda por departamento
EXPLAIN ANALYZE
SELECT * FROM empleados WHERE departamento = 'Ventas'; 

-- Consulta 3: Búsqueda por rango de salarios
EXPLAIN ANALYZE
SELECT * FROM empleados
WHERE salario BETWEEN 40000 AND 50000; 

-- Conusulta 4: JOIN entre tablas
EXPLAIN ANALYZE
SELECT e.nombre, COUNT(*) as total_ventas
FROM empleados e
JOIN ventas v ON e.id = v.empleado_id
WHERE v.fecha_venta >= '2023-06-01'
GROUP BY e.id, e.nombre
ORDER BY total_ventas DESC
LIMIT 10; 

/* 
EJERCICIO 3: ÍNDICES HASH
Instrucciones
1. Crear índices Hash para comparar
2. Evaluar diferencias con B-tree
*/

-- DROP de índices hash existentes
DROP INDEX IF EXISTS idx_empleados_dept_hash;
DROP INDEX IF EXISTS idx_ventas_categoria_hash;

-- Crear indice Hash para busqueda por igualdad exacta
CREATE INDEX idx_empleados_dept_hash
ON empleados USING HASH(departamento);

-- Crear indice Hash en categoria de ventas
CREATE INDEX idx_ventas_categoria_hash
ON ventas USING HASH(categoria); 

-- Consultas de Comparación

-- Comparar B-tree vs Hash para búsquedas por igualdad
SET enable_seqscan = OFF; 

-- Con índice B-tree
DROP INDEX IF EXISTS idx_empleados_dept_hash;
EXPLAIN ANALYZE
SELECT * FROM empleados WHERE departamento = 'Ventas';

-- Con índice Hash
DROP INDEX IF EXISTS idx_empleados_departamento;
CREATE INDEX idx_empleados_dept_hash ON empleados USING HASH(departamento);
EXPLAIN ANALYZE
SELECT * FROM empleados WHERE departamento = 'Ventas';

-- Probar búsqueda por rango (Hash NO funciona eficientemente)
EXPLAIN ANALYZE
SELECT * FROM empleados WHERE departamento > 'Marketing';

SET enable_seqscan = ON; 







