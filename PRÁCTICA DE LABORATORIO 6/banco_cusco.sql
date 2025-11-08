CREATE TABLE cuentas ( 
	id SERIAL PRIMARY KEY, 
	numero_cuenta VARCHAR(20) UNIQUE NOT NULL, 
	titular VARCHAR(100) NOT NULL, 
	saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0), 
	sucursal VARCHAR(50) DEFAULT 'Cusco', 
	fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	version INTEGER DEFAULT 1 
);

-- Tabla de log de transacciones 
CREATE TABLE transacciones_log ( 
	id SERIAL PRIMARY KEY, 
	transaccion_id VARCHAR(50) NOT NULL, 
	cuenta_id INTEGER REFERENCES cuentas(id), 
	tipo_operacion VARCHAR(20), 
	monto NUMERIC(15,2), 
	estado VARCHAR(20),
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_prepare TIMESTAMP, 
	timestamp_final TIMESTAMP, 
	descripcion TEXT 
);

-- Tabla de control 2PC 
CREATE TABLE control_2pc ( 
	transaccion_id VARCHAR(58) PRIMARY KEY, 
	estado_global VARCHAR(28),
	participantes TEXT[], 
	votos_commit INTEGER DEFAULT 0, 
	votos_abort INTEGER DEFAULT 0, 
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_decision TIMESTAMP, 
	coordinador VARCHAR(50) 
);

-- Datos iniciales 
INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES 
('CUSCO-001', 'Rosa Quispe Huamán', 2000.00), 
('CUSCO-002', 'Pedro Mamani Condori', 4500.00), 
('CUSCO-003', 'Carmen Ccoa Flores', 1800.00), 
('CUSCO-004', 'Luis Apaza Choque', 5300.00), 
('CUSCO-005', 'Elena Puma Quispe', 3700.00); 

SELECT * FROM cuentas;

-- Terminal 2 (Cusco): 
BEGIN; 

-- Registrar participacion
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20251103-161514', 'INICIADA', 'LIMA');

-- PASO 2.1: Verificar que cuenta destino existe 
SELECT numero_cuenta, titular, saldo 
FROM cuentas 
WHERE numero_cuenta = 'CUSCO-001' 
FOR UPDATE; 

INSERT INTO transacciones_log 
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
SELECT 
	'TXN-20251103-161514', 
	id, 
	'CREDITO', 
	1000.00, 
	'PENDING', 
	'Transferencia desde LIMA-001'
FROM cuentas 
WHERE numero_cuenta = 'CUSCO-001'; 

-- PASO 2.3: Cambiar estado a PREPARED 
UPDATE transacciones_log 
SET estado = 'PREPARED', 
	timestamp_prepare = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20251103-161514' 
AND tipo_operacion = 'CREDITO'; 

-- PASO 2.4: VOTAR COMMIT 
UPDATE control_2pc 
SET votos_commit = votos_commit + 1 
WHERE transaccion_id = 'TXN-20251103-161514'; 

-- Verificar estado 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251103-161514'; 
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251103-161514'; 

-- Terminal 2 (Cusco)
-- EJECUTAR LA OPERACIÓN 
UPDATE cuentas 
SET saldo = saldo - 1000.00, 
	ultima_modificacion = CURRENT_TIMESTAMP, 
	version = version + 1 
WHERE numero_cuenta = 'CUSCO-001'; 


-- Marcar como COMMITTED 
UPDATE transacciones_log 
SET estado = 'COMMITTED', 
	timestamp_final = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20251103-161514' 
AND tipo_operacion = 'DEBITO'; 

-- Actualizar control 
UPDATE control_2pc 
SET estado_global = 'CONFIRMADA', 
	timestamp_decision = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20251103-161514'; 

-- COMMIT FINAL 
COMMIT; 

-- Verificar resultado 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-001';

SELECT * FROM cuentas WHERE numero_cuenta IN ('CUSCO-001'); 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251103-161514';

- Terminal 2 (Transferencia B - Cusco primero): 
-- EJECUTAR INMEDIATAMENTE DESPUES DE TERMINAL 1
BEGIN; 

SELECT * FROM cuentas WHERE numero_cuenta = 'CUSCO-002' FOR UPDATE; 
-- BLOQUEADO

-- Esperar 2 segundos
SELECT pg_sleep(2);
-- Intertar bloquear LIMA - 003
-- ESTO CAUSARA ESPERA (terminal 1 ya lo tiene bloqueado)


CREATE EXTENSION IF NOT EXISTS dblink; 

SELECT dblink_connect('conn_lima', 
	'host=localhost dbname=banco_lima user=estudiante password=lab2024'); 
BEGIN;

-- Bloquear local
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-003' FOR UPDATE; 

-- Esperar 2 segundos 
SELECT pg_sleep(2);

-- Intentar bloquear remoto en Lima 
SELECT * FROM dblink('conn_lima', 
'SELECT * FROM cuentas WHERE numero_cuenta = ''LIMA-003'' FOR UPDATE' 
) AS t1(id int, numero_cuenta varchar, titular varchar, saldo numeric, sucursal varchar, fecha_creacion timestamp, ultima_modificacion timestamp, version int); 


ROLLBACK; 

-- 4.2 Función de preparación crédito 
-- Terminal 2 (Cusco): 


CREATE OR REPLACE FUNCTION preparar_credito( 
	p_transaccion_id VARCHAR, 
	p_numero_cuenta VARCHAR, 
	p_monto NUMERIC 
) RETURNS BOOLEAN AS $$ 
DECLARE 
	v_cuenta_id INTEGER; 
BEGIN 
	-- Bloquear y verificar cuenta 
	SELECT id INTO v_cuenta_id 
	FROM cuentas 
	WHERE numero_cuenta = p_numero_cuenta 
	FOR UPDATE;
	
	-- Verificar si cuenta existe 
	IF NOT FOUND THEN 
		RAISE NOTICE 'Cuenta % no encontrada', p_numero_cuenta; 
		RETURN FALSE; 
	END IF; 
	
	-- Registrar en log  
	INSERT INTO transacciones_log 
	(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
	VALUES( 
		p_transaccion_id, 
		v_cuenta_id, 
		'CREDITO', 
		p_monto, 
		'PREPARED', 
		'Preparado para crédito' 
	);
	
	RAISE NOTICE 'VOTE-COMMIT para cuenta %', p_numero_cuenta; 
	RETURN TRUE; 
	
EXCEPTION 
	WHEN OTHERS THEN 
		RAISE NOTICE 'Error en preparación: %', SQLERRM; 
		RETURN FALSE; 
END; 
$$ LANGUAGE plpgsql; 

-- 4.3 Función de commit 
-- Terminal 1 (Lima): 
 
CREATE OR REPLACE FUNCTION confirmar_transaccion( 
	p_transaccion_id VARCHAR 
) RETURNS VOID AS $$ 
DECLARE 
	v_registro RECORD; 
BEGIN 
-- Obtener todas las operaciones preparadas 
	FOR v_registro IN 
		SELECT cuenta_id, tipo_operacion, monto 
		FROM transacciones_log 
		WHERE transaccion_id = p_transaccion_id 
		AND estado = 'PREPARED' 
	LOOP
		-- Ejecutar operación 
		IF v_registro.tipo_operacion = 'DEBITO' THEN 
		UPDATE cuentas 
		SET saldo = saldo - v_registro.monto, 
			ultima_modificacion = CURRENT_TIMESTAMP, 
			version = version + 1 
		WHERE id = v_registro.cuenta_id; 
		
		ELSIF v_registro.tipo_operacion = 'CREDITO' THEN 
			UPDATE cuentas 
			SET saldo = saldo + v_registro.monto, 
				ultima_modificacion = CURRENT_TIMESTAMP, 
				version = version + 1 
			WHERE id = v_registro.cuenta_id; 
		END IF; 

		-- Actualizar log 
		UPDATE transacciones_log 
		SET estado = 'COMMITTED', 
			timestamp_final = CURRENT_TIMESTAMP 
		WHERE transaccion_id = p_transaccion_id 
			AND cuenta_id = v_registro.cuenta_id; 
		
		RAISE NOTICE 'Operación % confirmada para cuenta ID %', 
			v_registro.tipo_operacion, v_registro.cuenta_id; 
	END LOOP; 
	
	-- Actualizar control 2PC 
	UPDATE control_2pc 
	SET estado_global = 'CONFIRMADA', 
		timestamp_decision = CURRENT_TIMESTAMP 
	WHERE transaccion_id = p_transaccion_id; 
	
	RAISE NOTICE 'Transacción % confirmada exitosamente', p_transaccion_id;
END; 
$$ LANGUAGE plpgsql; 

-- 4.4 Función de abort 
-- Terminal 1 (Lima) y Terminal 2 (Cusco): 

CREATE OR REPLACE FUNCTION abortar_transaccion( 
	p_transaccion_id VARCHAR 
) RETURNS VOID AS $$ 
BEGIN 
	-- Marcar todas las opeaciones como Abortadas 
	UPDATE transacciones_log 
	SET estado = 'ABORTED', 
		timestamp_final = CURRENT_TIMESTAMP 
	WHERE transaccion_id = p_transaccion_id; 

	-- Actualizar control 
	UPDATE control_2pc 
	SET estado_global = 'ABORTADA', 
		timestamp_decision = CURRENT_TIMESTAMP 
	WHERE transaccion_id = p_transaccion_id; 

	RAISE NOTICE 'Transacción % abortada', p_transaccion_id; 
END; 
$$ LANGUAGE plpgsql;

BEGIN;
-- Registrar en control
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20251105-110032', 'PREPARANDO', 'LIMA'); 

-- FASE PREPARE
SELECT preparar_credito('TXN-20251105-110032', 'CUSCO-003', 800.00); 
-- Resultado: TRUE = VOTE-COMMIT
-- NO HACER COMMIT TODAVIA


SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251105-110032';

SELECT confirmar_transaccion('TXN-20251105-110032');

-- COMMIT de la transacción 
COMMIT;

-- Verificar resultado 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-003'; 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251105-110032';

-- Terminal 2 (Cusco): 
 
-- Verificar que se recibió el crédito 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-004';

-- Ver log de transacciones 
SELECT * FROM transacciones_log ORDER BY timestamp_inicio DESC LIMIT 5; 

-- PARTE C: SAGA PATTERN CON TRIGGERS 
-- PASO 6: IMPLEMENTAR SAGA CON COMPENSACIONES 
-- 6.1 Crear tablas para SAGA 
-- Terminal 1 (Lima): 

-- Tabla de órdenes SAGA 
CREATE TABLE saga_ordenes ( 
	orden_id VARCHAR(50) PRIMARY KEY, 
	tipo VARCHAR(50),
	estado VARCHAR(20), 
	datos JSONB,
	paso_actual INTEGER DEFAULT 0, 
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_final TIMESTAMP 
);

-- Tabla de pasos SAGA 
CREATE TABLE saga_pasos ( 
	id SERIAL PRIMARY KEY, 
	orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id), 
	numero_paso INTEGER, 
	nombre_paso VARCHAR(100), 
	estado VARCHAR(20), 
	accion_ejecutada TEXT, 
	compensacion_ejecutada TEXT, 
	timestamp_ejecucion TIMESTAMP, 
	timestamp_compensacion TIMESTAMP, 
	error_mensaje TEXT 
); 

-- Tabla de eventos SAGA 
CREATE TABLE saga_eventos ( 
	id SERIAL PRIMARY KEY, 
	orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id), 
	tipo_evento VARCHAR(50), 
	descripcion TEXT, 
	timestamp_evento TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
);

-- PARTE C: SAGA PATTERN CON TRIGGERS 
-- PASO 6: IMPLEMENTAR SAGA CON COMPENSACIONES 
-- 6.1 Crear tablas para SAGA 
-- Terminal 1 (Lima): 

-- Tabla de órdenes SAGA 
CREATE TABLE saga_ordenes ( 
	orden_id VARCHAR(50) PRIMARY KEY, 
	tipo VARCHAR(50),
	estado VARCHAR(20), 
	datos JSONB,
	paso_actual INTEGER DEFAULT 0, 
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_final TIMESTAMP 
);

-- Tabla de pasos SAGA 
CREATE TABLE saga_pasos ( 
	id SERIAL PRIMARY KEY, 
	orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id), 
	numero_paso INTEGER, 
	nombre_paso VARCHAR(100), 
	estado VARCHAR(20), 
	accion_ejecutada TEXT, 
	compensacion_ejecutada TEXT, 
	timestamp_ejecucion TIMESTAMP, 
	timestamp_compensacion TIMESTAMP, 
	error_mensaje TEXT 
); 

-- Tabla de eventos SAGA 
CREATE TABLE saga_eventos ( 
	id SERIAL PRIMARY KEY, 
	orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id), 
	tipo_evento VARCHAR(50), 
	descripcion TEXT, 
	timestamp_evento TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
);
