-- Crear la base de datos principal
CREATE DATABASE ecommerce_lab;

-- 1.1 CREACIÓN DE TABLAS

-- Almacena información del catálogo de productos con control de inventario
CREATE TABLE productos (
    codigo VARCHAR(20) PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    stock_disponible INTEGER NOT NULL DEFAULT 0 CHECK (stock_disponible >= 0),
    stock_minimo INTEGER NOT NULL DEFAULT 5 CHECK (stock_minimo >= 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Información de clientes registrados en el sistema
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre_completo VARCHAR(200) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    direccion_envio TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Registro maestro de todos los pedidos realizados
CREATE TABLE pedidos (
    id_pedido SERIAL PRIMARY KEY,
    id_cliente INTEGER NOT NULL REFERENCES clientes(id_cliente),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' 
        CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENVIADO', 'CANCELADO')),
    monto_total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (monto_total >= 0),
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Líneas de detalle de cada pedido con productos y cantidades
CREATE TABLE detalle_pedido (
    id_detalle SERIAL PRIMARY KEY,
    id_pedido INTEGER NOT NULL REFERENCES pedidos(id_pedido),
    codigo_producto VARCHAR(20) NOT NULL REFERENCES productos(codigo),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0)
);

-- Registro de transacciones de pago vinculadas a pedidos
CREATE TABLE pagos (
    id_pago SERIAL PRIMARY KEY,
    id_pedido INTEGER NOT NULL REFERENCES pedidos(id_pedido),
    metodo_pago VARCHAR(50) NOT NULL,
    monto_pagado NUMERIC(12,2) NOT NULL CHECK (monto_pagado > 0),
    fecha_pago TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado_pago VARCHAR(20) NOT NULL DEFAULT 'PROCESANDO' 
        CHECK (estado_pago IN ('PROCESANDO', 'APROBADO', 'RECHAZADO')),
    referencia_transaccion VARCHAR(100) UNIQUE
);

-- Auditoría de todos los movimientos de inventario
CREATE TABLE historial_stock (
    id_registro SERIAL PRIMARY KEY,
    codigo_producto VARCHAR(20) NOT NULL REFERENCES productos(codigo),
    tipo_movimiento VARCHAR(20) NOT NULL 
        CHECK (tipo_movimiento IN ('ENTRADA', 'SALIDA', 'AJUSTE', 'DEVOLUCION')),
    cantidad INTEGER NOT NULL,
    stock_anterior INTEGER NOT NULL,
    stock_nuevo INTEGER NOT NULL,
    id_pedido_relacionado INTEGER REFERENCES pedidos(id_pedido),
    fecha_movimiento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(100) DEFAULT CURRENT_USER,
    observaciones TEXT
);

-- 1.2 CREACIÓN DE ÍNDICES PARA OPTIMIZACIÓN

-- Índices B-tree para búsquedas por rangos y ordenamiento
CREATE INDEX idx_productos_stock ON productos(stock_disponible);
CREATE INDEX idx_productos_nombre ON productos(nombre);
CREATE INDEX idx_pedidos_cliente ON pedidos(id_cliente);
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido DESC);
CREATE INDEX idx_detalle_pedido ON detalle_pedido(id_pedido);
CREATE INDEX idx_historial_producto ON historial_stock(codigo_producto);
CREATE INDEX idx_historial_fecha ON historial_stock(fecha_movimiento DESC);

-- Índices Hash para búsquedas exactas (Lab 2)
CREATE INDEX idx_productos_estado_hash ON productos USING HASH(estado);
CREATE INDEX idx_pedidos_estado_hash ON pedidos USING HASH(estado);
CREATE INDEX idx_pagos_estado_hash ON pagos USING HASH(estado_pago);

-- Índice compuesto para consultas frecuentes (Lab 3)
CREATE INDEX idx_productos_estado_stock ON productos(estado, stock_disponible) 
    WHERE estado = 'ACTIVO';

-- Índice parcial para pedidos activos (Lab 3)
CREATE INDEX idx_pedidos_activos ON pedidos(estado, fecha_pedido) 
    WHERE estado IN ('PENDIENTE', 'CONFIRMADO');

-- 1.3 INSERCIÓN DE DATOS DE PRUEBA

-- Insertar productos con diferentes niveles de stock
INSERT INTO productos (codigo, nombre, descripcion, precio_unitario, stock_disponible, stock_minimo) VALUES
('PROD-001', 'Laptop HP Pavilion', 'Laptop 15.6" Intel i5 8GB RAM 256GB SSD', 2500.00, 15, 5),
('PROD-002', 'Mouse Inalámbrico Logitech', 'Mouse óptico inalámbrico ergonómico', 45.00, 50, 10),
('PROD-003', 'Teclado Mecánico Razer', 'Teclado mecánico RGB switches blue', 180.00, 8, 5),
('PROD-004', 'Monitor Samsung 24"', 'Monitor Full HD IPS 75Hz', 450.00, 2, 3),  -- Stock muy bajo
('PROD-005', 'Auriculares Bluetooth Sony', 'Auriculares over-ear con cancelación de ruido', 320.00, 1, 5),  -- Stock crítico
('PROD-006', 'Webcam Logitech C920', 'Cámara web Full HD 1080p', 150.00, 25, 8),
('PROD-007', 'SSD Kingston 1TB', 'Disco sólido NVMe M.2 1TB', 280.00, 30, 10),
('PROD-008', 'Router TP-Link AC1750', 'Router WiFi dual band AC1750', 95.00, 12, 5),
('PROD-009', 'Memoria RAM Corsair 16GB', 'Memoria DDR4 3200MHz 16GB', 180.00, 1, 5),  -- Stock crítico
('PROD-010', 'Fuente de Poder Corsair 650W', 'Fuente modular 80+ Gold', 220.00, 6, 4);

-- Insertar clientes
INSERT INTO clientes (nombre_completo, email, telefono, direccion_envio) VALUES
('Juan Pérez García', 'juan.perez@email.com', '987654321', 'Av. Arequipa 123, Lima'),
('María González López', 'maria.gonzalez@email.com', '987654322', 'Jr. Puno 456, Arequipa'),
('Carlos Rodríguez Silva', 'carlos.rodriguez@email.com', '987654323', 'Calle Lima 789, Cusco'),
('Ana Martínez Torres', 'ana.martinez@email.com', '987654324', 'Av. Bolognesi 321, Tacna'),
('Luis Fernández Ruiz', 'luis.fernandez@email.com', '987654325', 'Jr. Moquegua 654, Puno');

