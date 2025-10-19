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

