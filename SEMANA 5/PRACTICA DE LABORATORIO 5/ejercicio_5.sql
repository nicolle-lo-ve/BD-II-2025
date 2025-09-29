-- PARTE 1: CONFIGURACIÓN Y TRANSACCIONES BÁSICAS

-- Paso 1.1: Preparación del entorno

-- 1.1.1 Crear la base de datos de práctica
-- Conectarse como superusuario y crear la BD
CREATE DATABASE laboratorio_transacciones;

-- Conectarse a la nueva base de datos
\c laboratorio_transacciones;

-- 1.1.2 Crear las tablas necesarias

-- Tabla de cuentas bancarias
CREATE TABLE cuentas (
    id SERIAL PRIMARY KEY,
    numero_cuenta VARCHAR(20) UNIQUE NOT NULL,
    titular VARCHAR(100) NOT NULL,
    saldo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    fecha_apertura DATE DEFAULT CURRENT_DATE,
    activa BOOLEAN DEFAULT TRUE,
    CONSTRAINT saldo_positivo CHECK (saldo >= 0)
);

-- Tabla de transacciones bancarias
CREATE TABLE movimientos (
    id SERIAL PRIMARY KEY,
    cuenta_origen VARCHAR(20),
    cuenta_destino VARCHAR(20),
    monto DECIMAL(12,2) NOT NULL,
    tipo_operacion VARCHAR(20) NOT NULL,
    descripcion TEXT,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'COMPLETADO'
);

-- Tabla de productos para e-commerce
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    categoria VARCHAR(50),
    activo BOOLEAN DEFAULT TRUE,
    CONSTRAINT stock_no_negativo CHECK (stock >= 0)
);

-- Tabla de pedidos
CREATE TABLE pedidos (
    id SERIAL PRIMARY KEY,
    cliente_nombre VARCHAR(100) NOT NULL,
    cliente_email VARCHAR(100),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12,2) DEFAULT 0.00,
    estado VARCHAR(20) DEFAULT 'PENDIENTE'
);

-- Tabla de detalle de pedidos
CREATE TABLE detalle_pedidos (
    id SERIAL PRIMARY KEY,
    pedido_id INTEGER REFERENCES pedidos(id),
    producto_id INTEGER REFERENCES productos(id),
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL
);

-- 1.1.3 Insertar datos de prueba

-- Insertar cuentas bancarias
INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES 
('CTA-001', 'Juan Pérez', 5000.00),
('CTA-002', 'Maria García', 3500.00),
('CTA-003', 'Carlos López', 1200.00),
('CTA-004', 'Ana Martínez', 8900.00),
('CTA-005', 'Luis Torres', 450.00);

-- Insertar productos
INSERT INTO productos (nombre, precio, stock, categoria) VALUES 
('Laptop HP Pavilion', 2500.00, 15, 'Electrónicos'),
('Mouse Inalámbrico', 45.00, 50, 'Accesorios'),
('Teclado Mecánico', 180.00, 25, 'Accesorios'),
('Monitor 24''', 800.00, 8, 'Electrónicos'),
('Webcam HD', 120.00, 30, 'Accesorios');

-- Verificar datos insertados
SELECT 'Cuentas' as tabla, COUNT(*) as registros FROM cuentas 
UNION ALL 
SELECT 'Productos', COUNT(*) FROM productos;

-- Paso 1.2: Primera transacción básica

-- 1.2.1 Transferencia bancaria simple

-- Ver saldos iniciales
SELECT numero_cuenta, titular, saldo
FROM cuentas
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

-- TRANSFERENCIA: Juan transfiere $500 a María
BEGIN;
-- Debitar cuenta origen
UPDATE cuentas
SET saldo = saldo - 500.00
WHERE numero_cuenta = 'CTA-001';

-- Acreditar cuenta destino
UPDATE cuentas
SET saldo = saldo + 500.00
WHERE numero_cuenta = 'CTA-002';

-- Registrar el movimiento
INSERT INTO movimientos (cuenta_origen, cuenta_destino, monto, tipo_operacion, descripcion)
VALUES ('CTA-001', 'CTA-002', 500.00, 'TRANSFERENCIA', 'Transferencia entre cuentas');

-- Ver estado ANTES del commit
SELECT numero_cuenta, titular, saldo
FROM cuentas
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

COMMIT;

-- Ver estado DESPUÉS del commit
SELECT numero_cuenta, titular, saldo
FROM cuentas
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

-- 1.2.2 Demostrar el comportamiento sin COMMIT

-- Abrir una nueva conexión/terminal para este ejercicio
BEGIN;
    UPDATE cuentas
    SET saldo = saldo - 100.00
    WHERE numero_cuenta = 'CTA-003';

-- Ver el saldo en esta sesión
    SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta = 'CTA-003';

-- En OTRA ventana/conexión, ejecutar:
-- SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta = 'CTA-003';

-- ¿Qué observan? Los cambios no son visibles en otras sesiones hasta el COMMIT

-- Volver a la primera ventana y hacer rollback
ROLLBACK;

-- Verificar que el saldo volvió a su estado original
SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta = 'CTA-003';

-- Paso 1.3: Transacción de pedido e-commerce

-- 1.3.1 Crear un pedido completo

-- Ver inventario inicial
SELECT id, nombre, precio, stock FROM productos WHERE id IN (1, 2, 3);

-- PEDIDO: Cliente compra 1 Laptop + 2 Mouse + 1 Teclado
BEGIN;

-- Crear el pedido principal
INSERT INTO pedidos (cliente_nombre, cliente_email, estado)
VALUES ('Roberto Silva', 'roberto@email.com', 'PROCESANDO');

-- Obtener el ID del pedido recién creado
-- En PostgreSQL podemos usar RETURNING

-- Método alternativo más claro:
END;

-- Reiniciemos con un enfoque más didáctico:
BEGIN;

-- 1. Verificar stock disponible ANTES de procesar
SELECT nombre, stock FROM productos WHERE id IN (1, 2, 3);

-- 2. Crear el pedido
INSERT INTO pedidos (cliente_nombre, cliente_email, estado)
VALUES ('Roberto Silva', 'roberto@email.com', 'PROCESANDO');

-- 3. Obtener el ID del pedido (para simplificar, asumimos que es el último)
-- En la práctica real usarían RETURNING o variables

-- 4. Agregar detalles del pedido y actualizar inventario
-- Laptop HP Pavilion (1 unidad)
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (1, 1, 1, 2500.00, 2500.00);

UPDATE productos SET stock = stock - 1 WHERE id = 1;

-- Mouse Inalámbrico (2 unidades)
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (1, 2, 2, 45.00, 90.00);

UPDATE productos SET stock = stock - 2 WHERE id = 2;

-- Teclado Mecánico (1 unidad)
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (1, 3, 1, 180.00, 180.00);

UPDATE productos SET stock = stock - 1 WHERE id = 3;

-- 5. Calcular y actualizar el total del pedido
UPDATE pedidos
SET total = (SELECT SUM(subtotal) FROM detalle_pedidos WHERE pedido_id = 1),
    estado = 'CONFIRMADO'
WHERE id = 1;

-- Verificar el estado antes del commit
SELECT 'PEDIDO' as tipo, id, cliente_nombre, total, estado FROM pedidos WHERE id = 1
UNION ALL
SELECT 'STOCK', id, nombre, stock::text, '' FROM productos WHERE id IN (1, 2, 3);

COMMIT;

-- Verificar estado final
SELECT * FROM pedidos WHERE id = 1;
SELECT * FROM detalle_pedidos WHERE pedido_id = 1;
SELECT id, nombre, stock FROM productos WHERE id IN (1, 2, 3);

-- PARTE 2: PROPIEDADES ACID EN LA PRÁCTICA

-- Paso 2.1: Demostrando ATOMICIDAD

-- 2.1.1 Transferencia que falla por saldo insuficiente

-- Ver saldos actuales
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta IN ('CTA-005', 'CTA-001');

-- Intentar transferencia imposible: Luis (saldo $450) transfiere $1000 a Juan
BEGIN;
    UPDATE cuentas SET saldo = saldo - 1000.00 WHERE numero_cuenta = 'CTA-005';
    UPDATE cuentas SET saldo = saldo + 1000.00 WHERE numero_cuenta = 'CTA-001';

-- Esta transacción violará la restricción CHECK (saldo >= 0)
-- PostgreSQL automáticamente hará ROLLBACK
COMMIT;

-- Verificar que los saldos NO cambiaron (atomicidad)
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta IN ('CTA-005', 'CTA-001');

-- 2.1.2 Demostrar rollback manual

BEGIN;
-- Simular un proceso de múltiples pasos
INSERT INTO pedidos (cliente_nombre, cliente_email)
VALUES ('Cliente Temporal', 'temp@test.com');

    UPDATE productos SET stock = stock - 5 WHERE id = 1;

    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    VALUES (2, 1, 5, 2500.00, 12500.00);

-- Simular detección de un error en la lógica de negocio
-- (ejemplo: cliente no tiene crédito suficiente)

ROLLBACK; -- Cancelar todo manualmente

-- Verificar que NADA se guardó
SELECT COUNT(*) as pedidos_temporales FROM pedidos WHERE cliente_nombre = 'Cliente Temporal';
SELECT stock FROM productos WHERE id = 1; -- Debe ser el stock original

-- Paso 2.2: Demostrando CONSISTENCIA

-- 2.2.1 Violación de restricciones de integridad

-- Intentar crear inconsistentias en los datos
BEGIN;
    -- Esto debería fallar por la restricción CHECK
    INSERT INTO cuentas (numero_cuenta, titular, saldo)
    VALUES ('CTA-999', 'Cuenta Inválida', -1000.00);

    COMMIT; -- No se ejecutará debido al error

    -- Verificar que la cuenta no se creó
    SELECT COUNT(*) FROM cuentas WHERE numero_cuenta = 'CTA-999';

-- 2.2.2 Consistencia en relaciones

BEGIN;
-- Intentar crear un detalle de pedido para un pedido inexistente
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (9999, 1, 1, 100.00, 100.00); -- pedido_id 9999 no existe

COMMIT; -- Fallará por violación de clave foránea

-- Verificar que no se insertó el registro inválido
SELECT COUNT(*) FROM detalle_pedidos WHERE pedido_id = 9999;

-- Paso 2.3: Demostrando AISLAMIENTO

-- 2.3.1 Preparar escenario de concurrencia

-- Este ejercicio requiere DOS ventanas/conexiones de base de datos

-- VENTANA 1 (Sesión A):
BEGIN;
SELECT saldo FROM cuentas WHERE numero_cuenta = 'CTA-004'; -- Ana: $8900

-- Símulan procesamiento lento (en la práctica, aquí habría lógica compleja)
-- NO ejecutar COMMIT todavía

-- VENTANA 2 (Sesión B):
BEGIN;
SELECT saldo FROM cuentas WHERE numero_cuenta = 'CTA-004'; -- También $8900

UPDATE cuentas SET saldo = saldo - 200.00 WHERE numero_cuenta = 'CTA-004';

COMMIT; -- Sesión B termina primero

-- Volver a VENTANA 1:
UPDATE cuentas SET saldo = saldo - 500.00 WHERE numero_cuenta = 'CTA-004';

COMMIT;

-- Verificar el resultado final
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CTA-004';
-- El saldo final debería ser: 8900 - 200 - 500 = 8200

-- PARTE 3: MANEJO DE ERRORES Y ROLLBACK

-- Paso 3.1: Tipos de errores en transacciones

-- 3.1.1 Error por violación de restricciones

-- Error por CHECK constraint
BEGIN;
    UPDATE cuentas SET saldo = -100 WHERE numero_cuenta = 'CTA-001';
COMMIT;
-- Error: new row for relation "cuentas" violates check constraint "saldo_positive"

-- Error por UNIQUE constraint
BEGIN;
    INSERT INTO cuentas (numero_cuenta, titular, saldo)
    VALUES ('CTA-001', 'Cuenta Duplicada', 1000.00); -- CTA-001 ya existe
COMMIT;
-- Error: duplicate key value violates unique constraint

-- Error por FOREIGN KEY constraint
BEGIN;
    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    VALUES (9999, 1, 1, 100.00, 100.00); -- pedido_id 9999 no existe
COMMIT;
-- Error: insert or update on table "detalle_pedidos" violates foreign key constraint

-- 3.1.2 Manejo programático de errores

-- En PostgreSQL, podemos usar bloques de excepción
DO $$
DECLARE
    cuenta_inexistente EXCEPTION;
    saldo_actual DECIMAL(12,2);
BEGIN
    BEGIN
    -- Intentar una operación que puede fallar
    UPDATE cuentas SET saldo = saldo - 1000
    WHERE numero_cuenta = 'CTA-INEXISTENTE';

    -- Verificar si la actualización afectó alguna fila
    GET DIAGNOSTICS saldo_actual = ROW_COUNT;

    IF saldo_actual = 0 THEN
    RAISE cuenta_inexistente;
    END IF;

    RAISE NOTICE 'Transferencia exitosa';

EXCEPTION
    WHEN cuenta_inexistente THEN
    RAISE NOTICE 'Error: La cuenta no existe';
    ROLLBACK;
    WHEN check_violation THEN
    RAISE NOTICE 'Error: Saldo insuficiente';
    ROLLBACK;
END;
END $$;

-- Paso 3.2: Rollback manual vs automático

-- 3.2.1 Rollback manual con SAVEPOINT

BEGIN;

 -- Operación 1: Exitosa
 INSERT INTO cuentas (numero_cuenta, titular, saldo)
 VALUES ('CTA-TEMP1', 'Cuenta Temporal 1', 1000.00);

 SAVEPOINT sp1;

 -- Operación 2: Problemática
 INSERT INTO cuentas (numero_cuenta, titular, saldo)
 VALUES ('CTA-TEMP2', 'Cuenta Temporal 2', -500.00); -- Violará CHECK

 -- Si llegamos aquí sin error, crear otro savepoint
 SAVEPOINT sp2;

 -- Operación 3: Más cambios
 UPDATE cuentas SET saldo = saldo + 100 WHERE numero_cuenta = 'CTA-TEMP1';

 -- Si hay error en operación 2, podemos hacer:
 ROLLBACK TO sp1; -- Solo deshace operación 2, mantiene operación 1

 -- Corregir la operación problemática
 INSERT INTO cuentas (numero_cuenta, titular, saldo)
 VALUES ('CTA-TEMP2', 'Cuenta Temporal 2', 500.00); -- Ahora correcto

 COMMIT;

 -- Verificar resultado
 SELECT * FROM cuentas WHERE numero_cuenta LIKE 'CTA-TEMP%';

-- 3.2.2 Simulación de falla del sistema

 -- Crear una función que simule una falla
 CREATE OR REPLACE FUNCTION simular_falla_sistema()
 RETURNS VOID AS $$
 BEGIN
 RAISE EXCEPTION 'Falla simulada del sistema';
 END;
 $$ LANGUAGE plpgsql;

 -- Usar la función en una transacción
 BEGIN;
 UPDATE cuentas SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-001';

 -- Simular falla en el medio de la transacción
 SELECT simular_falla_sistema();

 UPDATE cuentas SET saldo = saldo + 1000 WHERE numero_cuenta = 'CTA-002';

 COMMIT;

 -- Verificar que NINGÚN cambio se aplicó (rollback automático)
 SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta IN ('CTA-001', 'CTA-002');
