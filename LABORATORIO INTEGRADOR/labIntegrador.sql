-- SECCIÓN 1: CREACIÓN Y CONFIGURACIÓN DE LA BASE DE DATOS

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

-- SECCIÓN 2: IMPLEMENTACIÓN DE PROCEDIMIENTOS DE NEGOCIO

-- 2.1 FUNCIÓN: crear_pedido
-- Crea un nuevo pedido validando stock y reservando productos
-- Utiliza técnicas de Lab 5 (transacciones) y Lab 6 (SELECT FOR UPDATE)

CREATE OR REPLACE FUNCTION crear_pedido(
    p_id_cliente INTEGER,
    p_productos JSON  -- Array de objetos codigo y cantidad
)
RETURNS INTEGER AS $$
DECLARE
    v_id_pedido INTEGER;
    v_producto JSON;
    v_codigo_producto VARCHAR(20);
    v_cantidad INTEGER;
    v_precio NUMERIC(10,2);
    v_stock_actual INTEGER;
    v_stock_anterior INTEGER;
    v_subtotal NUMERIC(12,2);
    v_monto_total NUMERIC(12,2) := 0;
    v_producto_nombre VARCHAR(200);
    v_estado VARCHAR(20);
BEGIN
    -- Iniciar transacción explícita (Lab 5)
    BEGIN
        -- Validar que el cliente existe
        IF NOT EXISTS (SELECT 1 FROM clientes WHERE id_cliente = p_id_cliente) THEN
            RAISE EXCEPTION 'El cliente con ID % no existe', p_id_cliente;
        END IF;

        -- Crear el registro del pedido en estado pendiente
        INSERT INTO pedidos (id_cliente, estado, monto_total)
        VALUES (p_id_cliente, 'PENDIENTE', 0)
        RETURNING id_pedido INTO v_id_pedido;

        -- Procesar cada producto del pedido
        FOR v_producto IN SELECT * FROM json_array_elements(p_productos)
        LOOP
            -- Extraer datos del producto
            v_codigo_producto := v_producto->>'codigo';
            v_cantidad := (v_producto->>'cantidad')::INTEGER;

            -- Validar cantidad positiva
            IF v_cantidad <= 0 THEN
                RAISE EXCEPTION 'La cantidad debe ser mayor a cero para el producto %', v_codigo_producto;
            END IF;

            -- Obtener información del producto con bloqueo exclusivo (Lab 6)
            -- Esto previene condiciones de carrera en ambiente concurrente
            SELECT precio_unitario, stock_disponible, nombre, estado
            INTO v_precio, v_stock_actual, v_producto_nombre, v_estado
            FROM productos
            WHERE codigo = v_codigo_producto
            FOR UPDATE;  -- Bloqueo explícito para concurrencia

            -- Validar que el producto existe
            IF NOT FOUND THEN
                RAISE EXCEPTION 'El producto % no existe', v_codigo_producto;
            END IF;

            -- Validar que el producto está activo
            IF v_estado != 'ACTIVO' THEN
                RAISE EXCEPTION 'El producto % no está disponible para venta', v_producto_nombre;
            END IF;

            -- Validar stock suficiente
            IF v_stock_actual < v_cantidad THEN
                RAISE EXCEPTION 'Stock insuficiente para %: disponible %, solicitado %', 
                    v_producto_nombre, v_stock_actual, v_cantidad;
            END IF;

            -- Guardar stock anterior para auditoría
            v_stock_anterior := v_stock_actual;

            -- Reservar el stock (reducir inventario)
            UPDATE productos
            SET stock_disponible = stock_disponible - v_cantidad,
                fecha_actualizacion = CURRENT_TIMESTAMP
            WHERE codigo = v_codigo_producto;

            -- Calcular subtotal
            v_subtotal := v_precio * v_cantidad;
            v_monto_total := v_monto_total + v_subtotal;

            -- Insertar detalle del pedido
            INSERT INTO detalle_pedido (id_pedido, codigo_producto, cantidad, precio_unitario, subtotal)
            VALUES (v_id_pedido, v_codigo_producto, v_cantidad, v_precio, v_subtotal);

            -- Registrar movimiento en historial de stock (auditoría completa)
            INSERT INTO historial_stock (
                codigo_producto, tipo_movimiento, cantidad, 
                stock_anterior, stock_nuevo, id_pedido_relacionado, observaciones
            )
            VALUES (
                v_codigo_producto, 'SALIDA', v_cantidad,
                v_stock_anterior, v_stock_anterior - v_cantidad, v_id_pedido,
                'Reserva de stock para pedido #' || v_id_pedido
            );
        END LOOP;

        -- Actualizar monto total del pedido
        UPDATE pedidos
        SET monto_total = v_monto_total,
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id_pedido = v_id_pedido;

        -- Retornar ID del pedido creado exitosamente
        RETURN v_id_pedido;

    EXCEPTION
        WHEN OTHERS THEN
            -- Manejo de errores con rollback automático (Lab 5)
            RAISE NOTICE 'Error al crear pedido: %', SQLERRM;
            RETURN NULL;
    END;
END;
$$ LANGUAGE plpgsql;

-- 2.2 FUNCIÓN: procesar_pago
-- Procesa el pago de un pedido con simulación de aprobación/rechazo
-- Implementa rollback condicional basado en Lab 5 y Lab 6


CREATE OR REPLACE FUNCTION procesar_pago(
    p_id_pedido INTEGER,
    p_metodo_pago VARCHAR(50),
    p_referencia VARCHAR(100)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_estado_pedido VARCHAR(20);
    v_monto_pedido NUMERIC(12,2);
    v_id_pago INTEGER;
    v_pago_aprobado BOOLEAN;
    v_numero_aleatorio INTEGER;
BEGIN
    BEGIN
        -- Validar que el pedido existe y obtener su estado con bloqueo (Lab 6)
        SELECT estado, monto_total
        INTO v_estado_pedido, v_monto_pedido
        FROM pedidos
        WHERE id_pedido = p_id_pedido
        FOR UPDATE;  -- Bloqueo para evitar pagos duplicados

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El pedido % no existe', p_id_pedido;
        END IF;

        -- Validar que el pedido está en estado pendiente
        IF v_estado_pedido != 'PENDIENTE' THEN
            RAISE EXCEPTION 'El pedido % no puede ser pagado (estado actual: %)', 
                p_id_pedido, v_estado_pedido;
        END IF;

        -- Registrar intento de pago en estado "procesando"
        INSERT INTO pagos (id_pedido, metodo_pago, monto_pagado, estado_pago, referencia_transaccion)
        VALUES (p_id_pedido, p_metodo_pago, v_monto_pedido, 'PROCESANDO', p_referencia)
        RETURNING id_pago INTO v_id_pago;

        -- Simular validación del pago (80% de aprobación)
        -- Genera número aleatorio entre 1 y 10
        v_numero_aleatorio := floor(random() * 10 + 1)::INTEGER;
        v_pago_aprobado := FALSE; -- FORZADO A FALLO , para evitarlo poner (v_numero_aleatorio <= 8)

        IF v_pago_aprobado THEN
            -- PAGO APROBADO: Confirmar transacción
            
            -- Actualizar estado del pago
            UPDATE pagos
            SET estado_pago = 'APROBADO'
            WHERE id_pago = v_id_pago;

            -- Actualizar estado del pedido
            UPDATE pedidos
            SET estado = 'CONFIRMADO',
                fecha_actualizacion = CURRENT_TIMESTAMP
            WHERE id_pedido = p_id_pedido;

            RAISE NOTICE 'Pago aprobado para pedido %. Transacción confirmada.', p_id_pedido;
            RETURN TRUE;

        ELSE
            -- PAGO RECHAZADO: Revertir reserva de stock (Lab 5 - Rollback)
            
            -- Actualizar estado del pago
            UPDATE pagos
            SET estado_pago = 'RECHAZADO'
            WHERE id_pago = v_id_pago;

            -- Restaurar stock de todos los productos del pedido
            UPDATE productos p
            SET stock_disponible = stock_disponible + d.cantidad,
                fecha_actualizacion = CURRENT_TIMESTAMP
            FROM detalle_pedido d
            WHERE p.codigo = d.codigo_producto
              AND d.id_pedido = p_id_pedido;

            -- Registrar devolución en historial de stock
            INSERT INTO historial_stock (
                codigo_producto, tipo_movimiento, cantidad,
                stock_anterior, stock_nuevo, id_pedido_relacionado, observaciones
            )
            SELECT 
                d.codigo_producto, 
                'DEVOLUCION',
                d.cantidad,
                p.stock_disponible - d.cantidad,
                p.stock_disponible,
                p_id_pedido,
                'Devolución por pago rechazado - Pedido #' || p_id_pedido
            FROM detalle_pedido d
            JOIN productos p ON p.codigo = d.codigo_producto
            WHERE d.id_pedido = p_id_pedido;

            -- Actualizar estado del pedido a cancelado
            UPDATE pedidos
            SET estado = 'CANCELADO',
                fecha_actualizacion = CURRENT_TIMESTAMP
            WHERE id_pedido = p_id_pedido;

            RAISE NOTICE 'Pago rechazado para pedido %. Stock restaurado.', p_id_pedido;
            RETURN FALSE;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error al procesar pago: %', SQLERRM;
            RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql;


-- 2.3 FUNCIÓN: cancelar_pedido
-- Cancela un pedido y restaura el stock
-- Implementa validaciones y rollback basado en Lab 5


CREATE OR REPLACE FUNCTION cancelar_pedido(
    p_id_pedido INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
    v_estado_pedido VARCHAR(20);
    v_producto RECORD;
BEGIN
    BEGIN
        -- Obtener estado del pedido con bloqueo (Lab 6)
        SELECT estado
        INTO v_estado_pedido
        FROM pedidos
        WHERE id_pedido = p_id_pedido
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El pedido % no existe', p_id_pedido;
        END IF;

        -- Validar que el pedido puede ser cancelado
        IF v_estado_pedido NOT IN ('PENDIENTE', 'CONFIRMADO') THEN
            RAISE EXCEPTION 'El pedido % no puede ser cancelado (estado: %)', 
                p_id_pedido, v_estado_pedido;
        END IF;

        -- Restaurar stock de todos los productos del pedido
        FOR v_producto IN 
            SELECT d.codigo_producto, d.cantidad, p.stock_disponible
            FROM detalle_pedido d
            JOIN productos p ON p.codigo = d.codigo_producto
            WHERE d.id_pedido = p_id_pedido
        LOOP
            -- Incrementar stock
            UPDATE productos
            SET stock_disponible = stock_disponible + v_producto.cantidad,
                fecha_actualizacion = CURRENT_TIMESTAMP
            WHERE codigo = v_producto.codigo_producto;

            -- Registrar devolución en historial
            INSERT INTO historial_stock (
                codigo_producto, tipo_movimiento, cantidad,
                stock_anterior, stock_nuevo, id_pedido_relacionado, observaciones
            )
            VALUES (
                v_producto.codigo_producto,
                'devolucion',
                v_producto.cantidad,
                v_producto.stock_disponible,
                v_producto.stock_disponible + v_producto.cantidad,
                p_id_pedido,
                'Cancelación de pedido #' || p_id_pedido
            );
        END LOOP;

        -- Actualizar estado del pedido
        UPDATE pedidos
        SET estado = 'CANCELADO',
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id_pedido = p_id_pedido;

        RAISE NOTICE 'Pedido % cancelado exitosamente. Stock restaurado.', p_id_pedido;
        RETURN TRUE;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error al cancelar pedido: %', SQLERRM;
            RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql;


-- SECCIÓN 3: SCRIPTS DE PRUEBA DE CONCURRENCIA
-- Basado en Lab 5 (Transacciones) y Lab 6 (Control de Concurrencia)

-- 3.1 PRUEBA DE COMPETENCIA POR STOCK LIMITADO
/*
INSTRUCCIONES PARA EJECUTAR PRUEBA DE CONCURRENCIA:

1. Abrir DOS terminales de psql conectadas a ecommerce_lab
2. Ejecutar los siguientes comandos EN PARALELO

*/

-- TERMINAL A (Conexión 1):
-- Configurar nivel de aislamiento (Lab 5)
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Intentar comprar el último Monitor Samsung (PROD-004 con stock=2)
SELECT crear_pedido(
    1,  -- ID Cliente
    '[{"codigo": "PROD-004", "cantidad": 2}]'::JSON
);

-- ESPERAR 10 segundos antes de confirmar
SELECT pg_sleep(10);

COMMIT;

-- TERMINAL B (Conexión 2 - ejecutar mientras A está en espera):
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Intentar comprar el mismo producto simultáneamente
SELECT crear_pedido(
    2,  -- ID Cliente diferente
    '[{"codigo": "PROD-004", "cantidad": 1}]'::JSON
);

COMMIT;

-- VERIFICAR RESULTADO
SELECT 
    p.id_pedido,
    p.id_cliente,
    p.estado,
    c.nombre_completo,
    d.codigo_producto,
    d.cantidad
FROM pedidos p
JOIN clientes c ON c.id_cliente = p.id_cliente
JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE d.codigo_producto = 'PROD-004'
ORDER BY p.fecha_pedido DESC
LIMIT 2;

-- Verificar stock final
SELECT codigo, nombre, stock_disponible 
FROM productos 
WHERE codigo = 'PROD-004';

-- 3.2 PRUEBA DE PAGO FALLIDO CON ROLLBACK

-- PASO 1: VERIFICAR DATOS INICIALES
SELECT 'DATOS INICIALES ' as info;
SELECT codigo, nombre, stock_disponible as stock_inicial
FROM productos 
WHERE codigo IN ('PROD-005', 'PROD-009');

-- PASO 2: CREAR PEDIDO
SELECT 'CREANDO PEDIDO' as info;
SELECT crear_pedido(
    3,
    '[{"codigo": "PROD-005", "cantidad": 1}, {"codigo": "PROD-009", "cantidad": 1}]'::JSON
) as id_pedido_creado;

-- PASO 3: VER STOCK DESPUÉS DE CREAR PEDIDO (debe haber disminuido)
SELECT 'STOCK DESPUÉS DE CREAR PEDIDO' as info;
SELECT codigo, nombre, stock_disponible as stock_despues_pedido
FROM productos 
WHERE codigo IN ('PROD-005', 'PROD-009');

-- PASO 4: PROCESAR PAGO (FALLIDO - forzado)
SELECT 'PROCESANDO PAGO (FORZANDO RECHAZO)' as info;
SELECT procesar_pago(
    (SELECT MAX(id_pedido) FROM pedidos),
    'Tarjeta de Crédito',
    'REF-TEST-FALLIDO'
) as pago_exitoso;

-- PASO 5: VERIFICAR RESULTADOS FINALES
SELECT 'RESULTADOS FINALES' as info;

-- Stock final (debe estar restaurado)
SELECT 'STOCK FINAL' as estado, codigo, nombre, stock_disponible as stock_final
FROM productos 
WHERE codigo IN ('PROD-005', 'PROD-009');

-- Estado del pedido (debe estar cancelado)
SELECT 'ESTADO PEDIDO' as info, id_pedido, estado, monto_total
FROM pedidos 
WHERE id_pedido = (SELECT MAX(id_pedido) FROM pedidos);

-- Historial de movimientos (debe mostrar la devolución)
SELECT 'HISTORIAL MOVIMIENTOS' as info, 
       codigo_producto, 
       tipo_movimiento, 
       cantidad,
       stock_anterior,
       stock_nuevo,
       observaciones
FROM historial_stock 
WHERE id_pedido_relacionado = (SELECT MAX(id_pedido) FROM pedidos)
ORDER BY fecha_movimiento DESC;

-- 3.3 SIMULACIÓN DE DEADLOCK
-- Basado en Lab 6 (Control de Concurrencia Distribuida)

/*
ESCENARIO DE DEADLOCK:
- Transacción A: Actualiza PROD-001, luego PROD-002
- Transacción B: Actualiza PROD-002, luego PROD-001
- Orden inverso causa deadlock

INSTRUCCIONES: Abrir DOS terminales y ejecutar EN PARALELO
*/

-- TERMINAL A:
BEGIN;
-- Bloquear PROD-001 primero
UPDATE productos SET stock_disponible = stock_disponible - 1
WHERE codigo = 'PROD-001';

-- Esperar 7 segundos para permitir que Terminal B bloquee PROD-002
SELECT pg_sleep(7);

-- Intentar bloquear PROD-002 (causará deadlock)
UPDATE productos SET stock_disponible = stock_disponible - 1
WHERE codigo = 'PROD-002';

COMMIT;


-- TERMINAL B (ejecutar inmediatamente después de iniciar Terminal A):

BEGIN;
-- Bloquear PROD-002 primero
UPDATE productos SET stock_disponible = stock_disponible - 1
WHERE codigo = 'PROD-002';

-- Esperar 2 segundos
SELECT pg_sleep(2);

-- Intentar bloquear PROD-001 (causará deadlock)
UPDATE productos SET stock_disponible = stock_disponible - 1
WHERE codigo = 'PROD-001';

COMMIT;


-- SECCIÓN 4: CONSULTAS DE ANÁLISIS Y MONITOREO
-- Basado en Lab 3 (Optimización de Consultas)


-- 4.1 CONSULTAS DE MONITOREO DEL SISTEMA
-- Consulta 1: Reporte completo de pedidos con información relacionada
-- Utiliza múltiples JOINs optimizados (Lab 3)
SELECT 
    p.id_pedido,
    p.fecha_pedido,
    p.estado AS estado_pedido,
    c.nombre_completo AS cliente,
    c.email,
    c.telefono,
    d.codigo_producto,
    pr.nombre AS producto,
    d.cantidad,
    d.precio_unitario,
    d.subtotal,
    p.monto_total,
    pg.metodo_pago,
    pg.estado_pago,
    pg.fecha_pago
FROM pedidos p
JOIN clientes c ON c.id_cliente = p.id_cliente
JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
JOIN productos pr ON pr.codigo = d.codigo_producto
LEFT JOIN pagos pg ON pg.id_pedido = p.id_pedido
ORDER BY p.fecha_pedido DESC, p.id_pedido, d.id_detalle;

-- Consulta 2: Productos con stock por debajo del mínimo (alerta crítica)
SELECT 
    codigo,
    nombre,
    stock_disponible,
    stock_minimo,
    (stock_minimo - stock_disponible) AS unidades_faltantes,
    precio_unitario,
    estado,
    CASE 
        WHEN stock_disponible = 0 THEN 'SIN STOCK'
        WHEN stock_disponible < stock_minimo / 2 THEN 'CRITICO'
        ELSE 'BAJO'
    END AS nivel_alerta
FROM productos
WHERE stock_disponible < stock_minimo
  AND estado = 'ACTIVO'
ORDER BY stock_disponible ASC, codigo;

-- Consulta 3: Reporte de ventas por producto (agregación)
SELECT 
    pr.codigo,
    pr.nombre AS producto,
    pr.precio_unitario AS precio_actual,
    COUNT(DISTINCT d.id_pedido) AS total_pedidos,
    SUM(d.cantidad) AS unidades_vendidas,
    SUM(d.subtotal) AS ingreso_total,
    AVG(d.precio_unitario) AS precio_promedio_venta,
    MIN(d.precio_unitario) AS precio_minimo,
    MAX(d.precio_unitario) AS precio_maximo
FROM productos pr
LEFT JOIN detalle_pedido d ON d.codigo_producto = pr.codigo
LEFT JOIN pedidos p ON p.id_pedido = d.id_pedido AND p.estado IN ('confirmado', 'enviado')
GROUP BY pr.codigo, pr.nombre, pr.precio_unitario
ORDER BY ingreso_total DESC NULLS LAST;

-- Consulta 4: Pedidos cancelados con análisis de causas
SELECT 
    p.id_pedido,
    p.fecha_pedido,
    c.nombre_completo AS cliente,
    p.monto_total,
    pg.estado_pago,
    pg.metodo_pago,
    CASE 
        WHEN pg.estado_pago = 'RECHAZADO' THEN 'Pago rechazado'
        WHEN pg.id_pago IS NULL THEN 'Sin intento de pago'
        ELSE 'Cancelación manual'
    END AS motivo_cancelacion,
    p.fecha_actualizacion AS fecha_cancelacion,
    STRING_AGG(pr.nombre || ' (x' || d.cantidad || ')', ', ') AS productos
FROM pedidos p
JOIN clientes c ON c.id_cliente = p.id_cliente
LEFT JOIN pagos pg ON pg.id_pedido = p.id_pedido
LEFT JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
LEFT JOIN productos pr ON pr.codigo = d.codigo_producto
WHERE p.estado = 'CANCELADO'
GROUP BY p.id_pedido, p.fecha_pedido, c.nombre_completo, p.monto_total, 
         pg.estado_pago, pg.metodo_pago, pg.id_pago, p.fecha_actualizacion
ORDER BY p.fecha_actualizacion DESC;

-- Consulta 5: Historial completo de movimientos de stock por producto
CREATE OR REPLACE FUNCTION obtener_historial_producto(p_codigo VARCHAR)
RETURNS TABLE (
    fecha TIMESTAMP,
    tipo VARCHAR,
    cantidad INTEGER,
    stock_previo INTEGER,
    stock_posterior INTEGER,
    pedido INTEGER,
    usuario VARCHAR,
    observaciones TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.fecha_movimiento,
        h.tipo_movimiento,
        h.cantidad,
        h.stock_anterior,
        h.stock_nuevo,
        h.id_pedido_relacionado,
        h.usuario,
        h.observaciones
    FROM historial_stock h
    WHERE h.codigo_producto = p_codigo
    ORDER BY h.fecha_movimiento DESC;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM obtener_historial_producto('PROD-004');

-- Consulta 6: Dashboard de métricas generales del sistema
SELECT 
    (SELECT COUNT(*) FROM pedidos) AS total_pedidos,
    (SELECT COUNT(*) FROM pedidos WHERE estado = 'pendiente') AS pedidos_pendientes,
    (SELECT COUNT(*) FROM pedidos WHERE estado = 'confirmado') AS pedidos_confirmados,
    (SELECT COUNT(*) FROM pedidos WHERE estado = 'cancelado') AS pedidos_cancelados,
    (SELECT COUNT(*) FROM productos WHERE estado = 'activo') AS productos_activos,
    (SELECT COUNT(*) FROM productos WHERE stock_disponible < stock_minimo) AS productos_stock_bajo,
    (SELECT COUNT(*) FROM productos WHERE stock_disponible = 0) AS productos_sin_stock,
    (SELECT COALESCE(SUM(monto_total), 0) FROM pedidos WHERE estado IN ('confirmado', 'enviado')) AS ingresos_totales,
    (SELECT COUNT(DISTINCT id_cliente) FROM pedidos) AS clientes_con_compras,
    (SELECT COUNT(*) FROM clientes) AS total_clientes;


