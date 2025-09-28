-- PASO 1.3: CREAR TABLAS DE PRUEBA

-- tabla clientes
CREATE TABLE clientes(
	cliente_id SERIAL PRIMARY KEY,
	nombre VARCHAR(100),
	email VARCHAR(100),
	ciudad VARCHAR(50),
	fecha_registro DATE,
	activo BOOLEAN DEFAULT true
);

-- tabla de productos
CREATE TABLE productos(
	producto_id SERIAL PRIMARY KEY,
	nombre_producto VARCHAR(100),
	categoria VARCHAR(50),
	precio DECIMAL(10,2),
	stock INTEGER
);

-- tabla de pedidos
CREATE TABLE pedidos(
	pedido_id SERIAL PRIMARY KEY,
	cliente_id INTEGER REFERENCES clientes(cliente_id),
	fecha_pedido DATE,
	total DECIMAL(10,2),
	estado VARCHAR(20)
);

-- tabla de detalle de pedidos
CREATE TABLE detalle_pedidos(
	detalle_id SERIAL PRIMARY KEY,
	pedido_id INTEGER REFERENCES pedidos(pedido_id),
	producto_id INTEGER REFERENCES productos(producto_id),
	cantidad INTEGER,
	precio_unitario DECIMAL(10,2)
);

-- PASO 1.4: INSERTAR DATOS DE PREUBA

-- insertar clientes (10,000 registros)
INSERT INTO clientes (nombres, email, ciudad, fecha_registro, activo)
SELECT
  'Cliente_' || generate_series,
  'Cliente' || generate_series || '@email.com',
  CASE (generate_series % 5)
    WHEN 0 THEN 'Lima'
    WHEN 1 THEN 'Arequipa'
    WHEN 2 THEN 'Trujillo'
    WHEN 3 THEN 'Cusco'
    ELSE 'Piura'
  END
  CURRENT_DATE - (generate_series % 365),
  (generate_series % 10) != 0
FROM generate_series(1,10000);

-- insertar productos (1,000 registros)
INSERT INTO clientes (nombre_prodcuto, categoria, precio, stock)
SELECT
  'Producto_' || generate_series,
  CASE (generate_series % 4)
    WHEN 0 THEN 'Electronicos'
    WHEN 1 THEN 'Ropa'
    WHEN 2 THEN 'Hogar'
    ELSE 'Deportes'
  END
  (generate_series % 500) + 10.99,
  (generate_series % 100) + 1
FROM generate_series(1,1000);

-- insertar pedidos (50,000 registros)
INSERT INTO pedidos (cliente_id, fecha_pedido, total, estado)
SELECT
  (generate_series % 10000) + 1,
  CURRENT_DATE - (generate_series % 180),
  ((generate_series % 500) + 50) * 1.19,
  CASE (generate_series % 4) 
    WHEN 0 THEN 'Completado'
    WHEN 1 THEN 'Pendiente'
    WHEN 2 THEN 'Enviado'
    ELSE 'Cancelado'
  END
FROM generate_series(1, 50000);

-- insertar detalle de pedidos (150,000 registros)
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario)
SELECT
  (generate_series % 50000) + 1,
  (generate_series % 1000) + 1,
  (generate_series % 5) + 1,
  ((generate_series % 200) + 10) + 0.99
FROM generate_series(1, 150000);

-- PARTE 2: ANÁLISIS DE PLANES DE EJECUCIÓN

-- PAso2.1: Consulta Básica sin Optimización

-- Consulta: Clientes de Lima con sus pedidos
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
goup by c.cliente_id, c.nombre
ORDER BY total_pedidos DESC;

-- EJERCICIO 2.1
-- Paso 2.2: Análisis del Plan de Ejecución

-- Solo mostrar el plan (sin ejecutar)
EXPLAIN (FORMAT JSON)
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre
ORDER BY total_pedidos DESC;

-- PARTE 3: OPTIMIZACIÓN CON ÍNDICES 
-- Paso 3.1:Crear índices estrategicos

-- índice en ciudad (alta selectividad para nuestra consulta)
CREATE INDEX idx_clientes_ciudad ON clientes(ciudad);

-- índice en fecha_pedido
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido);

-- índice compuesto
CREATE INDEX idx_pedidos_cliente_fecha ON pedidos(cliente_id, fecha_pedido);

-- Paso 3.2: Comparar Rendimiento con índices
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre
ORDER BY total_pedidos DESC;

-- Paso 3.3: índices parciales
-- índice parcial para clientes activos de Lima
CREATE INDEX idx_clientes_lima_activos
ON clientes(cliente_id)
WHERE ciudad = 'Lima' AND activo = true;

-- Consulta que puede usar el índice parcial
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, c.email
FROM clientes c
WHERE c.ciudad = 'Lima' AND c.activo = true
AND c.fecha_registro > '2024-01-01';

-- PARTE 4: ALGORITMOS DE JOIN
-- Paso 4.1: Forzar Different Join AL¿lgorithms

-- Deshabilitar hash joins temporalmente
SET enable_hashjoin = off;

-- Consulta que forzará nested loop o merge join
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, p.total, pr.nombre_producto
FROM clientes c
JOIN pedidos p ON c.cliente_id = p.cliente_id
JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
JOIN productos pr ON dp.producto_id = pr.producto_id
WHERE c.ciudad ='Lima'
AND p.fecha_pedido >= '2025-01-01';

-- Paso 4.2: Comparar ALgoritmos de Join

-- Habilitar solo hash joins
SET enable_hashjoin = on;
SET enable_mergejoin = off;
SET enable_nestloop = off;

-- Ejecutar la misma consulta
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, p.total, pr.nombre_producto
FROM clientes c
JOIN pedidos p ON c.cliente_id = p.cliente_id
JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
JOIN productos pr ON dp.producto_id = pr.producto_id
WHERE c.ciudad = 'Lima'
AND p.fecha_pedido >= '2025-01-01';

-- Restaurar configuración por defecto
RESET enable_hashjoin;
RESET enable_mergejoin;
RESET enable_nestloop;

-- PARTE 5: OPTIMIZACIÓN BASADA EN ESTADÍSTICAS
-- Paso 5.1: Actualizar Estadísticas

-- Ver estadísticas actuales
SELECT
	schemaname,
	tablename,
	n_tup_ins,
	n_tup_upd,
	n_tup_del,
	last_vacuum,
	last_analyze
FROM pg_stat_user_tables;

-- Actualizar estadísticas
ANALYZE clientes;
ANALYZE pedidos;
ANALYZE productos;
ANALYZE detalle_pedidos;

-- Paso 5.2: Impacto de las Estadísticas

-- Insertar más datos
INSERT INTO clientes (nombre, email, ciudad, fecha_registro, activo)
SELECT 
	'NuevoCliente_' || generate_series,
	'nuevo' || generate_series || '@email.com',
	'Lima',
	CURRENT_DATE,
	true
FROM generate_series(1, 5000);

-- Consulta sin actualizar estadísticas
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM clientes WHERE ciudad = 'Lima';

-- Actualizar estadísticas y repetir
ANALYZE clientes;

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM clientes WHERE ciudad = 'Lima';

-- PARTE 6: REESCRITURA DE CONSULTAS
-- Paso 6.1: Optimización con EXISTS vs IN

-- Versión con IN (potencialmente menos eficiente)
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre
FROM clientes c
WHERE c.clientes_id IN (
	SELECT p.cliente_id
	FROM pedidos p
	WHERE p.total > 500
	);

-- Versión con EXISTS (generalmente más eficiente)
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre
FROM clientes c
WHERE EXISTS (
	SELECT 1
	FROM pedidos p
	WHERE p.cliente_id = c.cliente_id
	AND p.total > 500
	);

-- Paso 6.2: Subconsultas vs JOINs
-- Versión con subconsulta
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre,
	(SELECT COUNT (*)
	 FROM pedidos p
	 WHERE p.cliente_id = c.cliente_id) as total_pedidos
FROM clientes c
WHERE c.ciudad = 'Lima';

-- Versión con JOIN
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre;

-- Paso 6.3: Uso de Window Functions
-- Ranking de clientes por total de compras
EXPLAIN (ANALYZE, BUFFERS)
SELECT
	c.nombre,
	SUM(p.total) as total_compras,
	RANK() OVER (ORDER BY SUM(p.total)DESC) as ranking
FROM clientes c
JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre
ORDER BY ranking;

--	PASO 7: CONSULTAS COMPLEJAS Y OPTIMIZACIÓN
-- Paso 7.1: Consulta de análisis de ventas

-- Análisis complejo: Top productos por ciudad y mes
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_mensuales AS (
	SELECT 
		c.ciudad,
		pr.nombre_producto,
		DATE_TRUNC('month', p.fecha_pedido) as mes,
		SUM(dp.cantidad * dp.precio_unitario) as total_ventas,
		COUNT(DISTINCT c.cliente_id) as clientes_unicos
	FROM clientes c
	JOIN pedidos p ON c.cliente_id = p.cliente_id
	JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
	JOIN productos pr ON dp.producto_id = pr.producto_id
	WHERE p.fecha_pedido >= '2024-01-01'
	AND p.estado = 'Completado'
	GROUP BY c.ciudad, pr.nombre_producto, DATE_TRUNC('month', p.fecha_pedido)
	),
	ranking_productos AS (
		SELECT *,
			ROW_NUMBER() OVER (
				PARTITION BY ciudad, mes
				ORDER BY total_ventas DESC
			) as rank_ventas
		FROM ventas_mensuales
	)
SELECT *
FROM ranking_productos 
WHERE rank_ventas <= 3
ORDER BY ciudad. mes, rank_ventas;

-- Paso 7.2: Índices para Consultas Complejas
-- índices adicionales para controlar la consulta anterior
CREATE INDEX idx_pedidos_fecha_estado ON pedidos(fecha_pedido, estado);
CREATE INDEX idx_detalle_pedido_producto ON detalle_pedidos(pedido_id, producto_id)

-- Ejecutar nuevamente la consulta
-- Repetir la consulta del paso 7.1
