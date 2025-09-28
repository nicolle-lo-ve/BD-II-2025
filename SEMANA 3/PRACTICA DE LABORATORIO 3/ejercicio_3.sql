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

