CREATE TABLE cuentas ( 
	id SERIAL PRIMARY KEY, 
	numero_cuenta VARCHAR(20) UNIQUE NOT NULL, 
	titular VARCHAR(100) NOT NULL, 
	saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0), 
	sucursal VARCHAR(50) DEFAULT 'Lima', 
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

-- Insertar datos iniciales 
INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES 
('LIMA-001', 'Juan Pérez Rodríguez', 5000.00), 
('LIMA-002', 'María García Flores', 3000.00), 
('LIMA-003', 'Carlos López Mendoza', 7500.00), 
('LIMA-004', 'Ana Torres Vargas', 2800.00), 
('LIMA-005', 'Pedro Ramírez Castro', 6200.00); 

-- Verificar inserción 
SELECT * FROM cuentas;

-- Ejercicio 1
SELECT 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MISS') AS transaccion_id; 

-- Iniciar transaccion
BEGIN; 

-- Registrar inicio en control 2PC
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20251103-161514', 'INICIADA', 'LIMA'); 

-- Mostrar estado
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251103-161514'; 

-- FASE 1: PREPARE (Preparación) 
-- Terminal 1 (Lima) - Participante ORIGEN: 

-- PASO 1.1: Verificar saldo suficiente 
SELECT numero_cuenta, titular, saldo 
FROM cuentas 
WHERE numero_cuenta = 'LIMA-001' 
FOR UPDATE; 

-- PASO 1.2: Registrar operacion PENDIENTE 
INSERT INTO transacciones_log 
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
SELECT 
	'TXN-20251103-161514', 
	id, 
	'DEBITO', 
	1000.00, 
	'PENDING', 
	'Transferencia a CUSCO-001' 
FROM cuentas 
WHERE numero_cuenta = 'LIMA-001'; 

-- PASO 1.3: Cambiar estado a PREPARED 
UPDATE transacciones_log 
SET estado = 'PREPARED', 
	timestamp_prepare = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20251103-161514' 
AND tipo_operacion = 'DEBITO'; 

-- PASO 1.4: VOTAR COMMIT 
UPDATE control_2pc 
SET votos_commit = votos_commit + 1, 
	estado_global = 'PREPARANDO' 
WHERE transaccion_id = 'TXN-20251103-161514';

-- Verificar estado 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251103-161514'; 
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251103-161514'; 

-- IMPORTANTE: NO HACER COMMIT NI ROLLBACK AÚN 
-- La transacción sigue abierta esperando fase 2

-- FASE 2: DECISIÓN (Commit o Abort) 
-- Terminal 4 (Monitor/Coordinador): 

-- Verificar votos 
SELECT transaccion_id, estado_global, votos_commit, votos_abort, 
	CASE 
		WHEN votos_commit = 2 THEN 'TODOS VOTARON COMMIT - PROCEDER A COMMIT' 
		WHEN votos_abort > 0 THEN 'HAY VOTOS ABORT - PROCEDER A ABORT' 
		ELSE 'ESPERANDO VOTOS'
	END AS decision 
FROM control_2pc 
WHERE transaccion_id = 'TXN-20251103-161514'; 

-- Si todos votaron COMMIT (votos_commit = 2): 
-- Terminal 1 (Lima): 
 
-- EJECUTAR LA OPERACIÓN 
UPDATE cuentas 
SET saldo = saldo - 1000.00, 
	ultima_modificacion = CURRENT_TIMESTAMP, 
	version = version + 1 
WHERE numero_cuenta = 'LIMA-001'; 


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
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'LIMA-001';

-- VERIFICACIÓN FINAL 
-- Terminal 4 (Monitor): 

-- Ver estado final en Lima 

SELECT * FROM cuentas WHERE numero_cuenta IN ('LIMA-001'); 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251103-161514'; 
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251103-161514';

SELECT 'TXN-' || to_char(now(),'YYYYMMDD-HH24MISS') AS transaccion_id;

-- Terminal 1 (Lima): 

BEGIN; 

INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20251103-181454', 'INICIADA', 'LIMA');

-- Intentar preparar 
SELECT numero_cuenta, titular, saldo 
FROM cuentas 
WHERE numero_cuenta = 'LIMA-002' 
FOR UPDATE; 

-- Saldo 300 < 10000 = INSUFICIENTE

-- Registrar intento 
INSERT INTO transacciones_log 
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
SELECT 
	'TXN-20251103-181454', 
	id, 
	'DEBITO', 
	10000.00, 
	'PENDING', 
	'Transferencia a AQP-061 - SALDO INSUFICIENTE' 
FROM cuentas
WHERE numero_cuenta = 'LIMA-002'; 

-- VOTAR ABORT 
UPDATE control_2pc 
SET votos_abort = votos_abort + 1, 
	estado_global = 'ABORTADA'
WHERE transaccion_id = 'TXN-20251103-181454'; 

-- Marcar como ABORTADO
UPDATE transacciones_log 
SET estado = 'ABORTED', 
	timestamp_final = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20251103-181454'; 

-- ROLLBACK
ROLLBACK; 


SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251103-181454';

-- Terminal 1 (Transferencia A - Lima primero): 
BEGIN; 

-- Bloquear LIMA-003
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-003' FOR UPDATE; 
-- BLOQUEADO

-- Esperar 5 segundo (simular procesamiento)
SELECT pg_sleep(5); 

-- Intertar bloquear CUSCO-002 (conectar a Cusco)
-- Esto requerira dblink o hacer manualmente

-- Instalación de dblink para deadlock distribuido 
-- Terminal 1 (Lima): 
-- Salir de la transaccion actual
ROLLBACK; 

-- Instalar extension dblink
CREATE EXTENSION IF NOT EXISTS dblink; 

-- Configurar conexion a Cusco
SELECT dblink_connect('conn_cusco', 
	'host=localhost dbname=banco_cusco user=estudiante password=lab2024'); 

BEGIN;
-- Bloquear local 
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-003' FOR UPDATE; 

-- Esperar 5 segundos 
SELECT pg_sleep(5);

-- Intentar bloquear remoto en Cusco 
SELECT * FROM dblink('conn_cusco', 
'SELECT * FROM cuentas WHERE numero_cuenta = ''CUSCO-002'' FOR UPDATE' 
) AS t1(id int, numero_cuenta varchar, titular varchar, saldo numeric, sucursal varchar, fecha_creacion timestamp, ultima_modificacion timestamp, version int); 

-- SE QUEDARÁ ESPERANDO 


ROLLBACK; 

-- PARTE B: AUTOMATIZACIÓN CON PL/pgSQL 
-- PASO 4: CREAR FUNCIONES ALMACENADAS 
-- 4.1 Función de preparación (PREPARE) 
-- Terminal 1 (Lima): 

CREATE OR REPLACE FUNCTION preparar_debito( 
	p_transaccion_id VARCHAR, 
	p_numero_cuenta VARCHAR, 
	p_monto NUMERIC 
) RETURNS BOOLEAN AS $$ 
DECLARE 
	v_cuenta_id INTEGER; 
	v_saldo_actual NUMERIC; 
BEGIN 
	-- Bloquear y verificar cuenta
	SELECT id, saldo INTO v_cuenta_id, v_saldo_actual 
	FROM cuentas
	WHERE numero_cuenta = p_numero_cuenta 
	FOR UPDATE;

	-- Verificar si cuenta existe
	IF NOT FOUND THEN
		RAISE NOTICE 'Cuenta % no encontrada', p_numero_cuenta; 
		RETURN FALSE; 
	END IF;

 	-- Verificar saldo suficiente
	IF v_saldo_actual < p_monto THEN 
		RAISE NOTICE 'Saldo insuficiente. Disponible: %, Requerido: %', 
			v_saldo_actual, p_monto; 
		RETURN FALSE; 
	END IF; 
	
	-- Registrar en log 
	INSERT INTO transacciones_log (transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
	VALUES (
		p_transaccion_id, 
		v_cuenta_id, 
		'DEBITO', 
		p_monto, 
		'PREPARED', 
		'Preparado para débito' 
	);

	RAISE NOTICE 'VOTE-COMMIT para cuenta %', p_numero_cuenta; 
	RETURN TRUE; 

EXCEPTION 
	WHEN OTHERS THEN 
		RAISE NOTICE 'Error en preparación: %', SQLERRM; 
		RETURN FALSE; 
END; 
$$ LANGUAGE plpgsql; 

-- Probar la función

BEGIN; 
SELECT preparar_debito('TXN-TEST-001', 'LIMA-001', 500.00); 
-- Debe retornar TRUE 
ROLLBACK;

BEGIN; 
SELECT preparar_debito('TXN-TEST-002', 'LIMA-001', 50000.00); 
-- Debe retornar FALSE (saldo insuficiente) 
ROLLBACK; 

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


SELECT 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MISS') AS transaccion_id; 

BEGIN;

-- Registrar en control
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20251105-110032', 'PREPARANDO', 'LIMA'); 

-- FASE PREPARE
SELECT preparar_debito('TXN-20251105-110032', 'LIMA-004', 800.00); 
-- Resultado: TRUE = VOTE-COMMIT
-- NO HACER COMMIT TODAVIA


SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251105-110032'; 


-- FASE  COMMIT 
SELECT confirmar_transaccion('TXN-20251105-110032');

-- COMMIT de la transacción 
COMMIT;

-- Verificar resultado 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'LIMA-004'; 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251105-110032'; 

-- PASO 5: FUNCIÓN COORDINADORA COMPLETA 
-- 5.1 Crear función coordinadora avanzada 
-- Terminal 1 (Lima): 

CREATE OR REPLACE FUNCTION transferencia_distribuida_coordinador( 
	p_cuenta_origen VARCHAR, 
	p_cuenta_destino VARCHAR, 
	p_monto NUMERIC, 
	p_db_destino VARCHAR 
) RETURNS TABLE ( 
exito BOOLEAN, 
mensaje TEXT, 
transaccion_id VARCHAR 
) AS $$
DECLARE 
	v_transaccion_id VARCHAR; 
	v_prepare_origen BOOLEAN; 
	v_prepare_destino BOOLEAN; 
	v_dblink_name VARCHAR; 
	v_dblink_conn VARCHAR; 
BEGIN 
	-- Generar ID único 
	v_transaccion_id := 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MI') || '-' || 
					floor(random() * 10000)::TEXT;
					
	-- Configurar conexión según destino 
	v_dblink_name := 'conn_' || p_db_destino; 
	v_dblink_conn := 'host=localhost dbname=banco_' || p_db_destino || 
					'user=estudiante password=lab2024'; 
	-- Conectar a base de datos destino 
	PERFORM dblink_connect (v_dblink_name, v_dblink_conn);

-- Iniciar en control 
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador, participantes) 
VALUES (v_transaccion_id, 'PREPARANDO', 'LIMA', ARRAY['LIMA', UPPER(p_db_destino)]);

-- FASE 1: PREPARE  
RAISE NOTICE '--- FASE 1: PREPARE --- ';

-- Preparar débito local 
v_prepare_origen := preparar_debito(v_transaccion_id, p_cuenta_origen, p_monto); 
RAISE NOTICE 'Prepare ORIGEN: %', CASE WHEN v_prepare_origen THEN 'COMMIT' ELSE 'ABORT' END; 

-- Preparar crédito remoto 
SELECT resultado INTO v_prepare_destino 
FROM dblink(v_dblink_name, 
	format('SELECT preparar_credito(%L, %L, %s)', 
			v_transaccion_id, p_cuenta_destino, p_monto) 
) AS t1(resultado BOOLEAN); 
RAISE NOTICE 'Prepare DESTINO: %', CASE WHEN v_prepare_destino THEN 'COMMIT' ELSE 'ABORT' END;

-- FASE 2: DECISIÓN 
RAISE NOTICE '--- FASE 2: DECISIÓN --- ';

IF v_prepare_origen AND v_prepare_destino THEN -- 
	-- COMMIT GLOBAL 
	RAISE NOTICE 'Decisión: GLOBAL-COMMIT';
	
	-- Confirmar local 
	PERFORM confirmar_transaccion(v_transaccion_id);
	
	-- Confirmar remoto 
	PERFORM dblink_exec(v_dblink_name, 
		format ('SELECT confirmar_transaccion(%L)', v_transaccion_id)
	);
	-- Desconectar 
	PERFORM dblink_disconnect(v_dblink_name); 
	
	RETURN QUERY SELECT TRUE, 'Transferencia exitosa', v_transaccion_id; 
ELSE 
	-- ABORT GLOBAL 
	RAISE NOTICE 'Decisión: GLOBAL-ABORT';
	
	-- Abortar local 
	PERFORM abortar_transaccion(v_transaccion_id);
	
	-- Abortar remoto 
	PERFORM dblink_exec(v_dblink_name, 
		format('SELECT abortar_transaccion(%L)', v_transaccion_id)
	);
	
		-- Desconectar 
		PERFORM dblink_disconnect(v_dblink_name); 
		RETURN QUERY SELECT FALSE, 'Transferencia abortada - Verificar logs', v_transaccion_id; 
	END IF; 
EXCEPTION 
	WHEN OTHERS THEN
	-- En caso de error, abortar todo 
	RAISE NOTICE 'Error: %', SQLERRM; 
	BEGIN 
		PERFORM abortar_transaccion(v_transaccion_id); 
		PERFORM dblink_disconnect(v_dblink_name); 
	EXCEPTION 
		WHEN OTHERS THEN NULL; 
	END; 
		RETURN QUERY SELECT FALSE, 'Error: ' || SQLERRM, v_transaccion_id;
END; 
$$ LANGUAGE plpgsql;


CREATE EXTENSION IF NOT EXISTS dblink;  

BEGIN; 

SELECT * FROM transferencia_distribuida_coordinador ( 
	'LIMA-005', 
	'CUSCO-004', 
	1200.00, 
	'cusco' 
); 

COMMIT;


-- Verificar resultados 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'LIMA-005'; 

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

CREATE OR REPLACE FUNCTION ejecutar_saga_transferencia( 
    p_cuenta_origen VARCHAR, 
    p_cuenta_destino VARCHAR, 
    p_monto NUMERIC, 
    p_db_destino VARCHAR 
) RETURNS TABLE ( 
    exito BOOLEAN, 
    orden_id VARCHAR, 
    mensaje TEXT 
) AS $$ 
DECLARE 
    v_orden_id VARCHAR; 
    v_paso1_exito BOOLEAN := FALSE; 
    v_paso2_exito BOOLEAN := FALSE; 
    v_paso3_exito BOOLEAN := FALSE; 
    v_cuenta_origen_id INTEGER; 
    v_saldo_origen NUMERIC; 
BEGIN
    -- Generar ID de orden 
    v_orden_id := 'SAGA-' || to_char(now(), 'YYYYMMDD-HH24MISS');
    
    -- Crear orden SAGA 
    INSERT INTO saga_ordenes (orden_id, tipo, estado, datos) 
    VALUES ( 
        v_orden_id, 
        'TRANSFERENCIA', 
        'INICIADA', 
        jsonb_build_object( 
            'cuenta_origen', p_cuenta_origen, 
            'cuenta_destino', p_cuenta_destino, 
            'monto', p_monto, 
            'db_destino', p_db_destino
        )
    );

    -- Definir pasos 
    INSERT INTO saga_pasos (orden_id, numero_paso, nombre_paso, estado) 
    VALUES 
        (v_orden_id, 1, 'Bloquear Fondos Origen', 'PENDIENTE'), 
        (v_orden_id, 2, 'Transferir a Destino', 'PENDIENTE'), 
        (v_orden_id, 3, 'Confirmar Débito Origen', 'PENDIENTE'); 

    -- Actualizar estado 
    UPDATE saga_ordenes 
    SET estado = 'EN PROGRESO', paso_actual = 1 
    WHERE saga_ordenes.orden_id = v_orden_id; 

    -- ======== PASO 1: Bloquear Fondos Origen ========
    RAISE NOTICE '--- PASO 1: Bloquear Fondos Origen ---'; 
        
    BEGIN 
        SELECT id, saldo INTO v_cuenta_origen_id, v_saldo_origen 
        FROM cuentas 
        WHERE numero_cuenta = p_cuenta_origen 
        FOR UPDATE;

        IF NOT FOUND THEN 
            RAISE EXCEPTION 'Cuenta origen % no encontrada', p_cuenta_origen;  
        END IF; 
        
        IF v_saldo_origen < p_monto THEN 
            RAISE EXCEPTION 'Saldo insuficiente. Disponible: %, Requerido: %', 
            v_saldo_origen, p_monto; 
        END IF;
    
        -- Marcar fondos como bloqueados (usando version como lock) 
        UPDATE cuentas 
        SET version = version + 1 
        WHERE cuentas.id = v_cuenta_origen_id;
        
        -- Registrar éxito 
        UPDATE saga_pasos 
        SET estado = 'EJECUTADO', 
            timestamp_ejecucion = CURRENT_TIMESTAMP, 
            accion_ejecutada = format('Bloqueados $%s en cuenta %s', p_monto, p_cuenta_origen) 
        WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1; 

        INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
        VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 1: Fondos bloqueados');
        
        v_paso1_exito := TRUE; 
        RAISE NOTICE 'Paso 1 completado'; 
        
    EXCEPTION 
        WHEN OTHERS THEN 
            UPDATE saga_pasos 
            SET estado = 'FALLIDO', 
                timestamp_ejecucion = CURRENT_TIMESTAMP, 
                error_mensaje = SQLERRM 
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1; 
            
            INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
            VALUES (v_orden_id, 'PASO_FALLIDO', 'Paso 1: ' || SQLERRM); 
            
            RAISE NOTICE 'Paso 1 falló: %', SQLERRM;
            
            -- Finalizar SAGA como fallida 
            UPDATE saga_ordenes 
            SET estado = 'FALLIDA', timestamp_final = CURRENT_TIMESTAMP 
            WHERE saga_ordenes.orden_id = v_orden_id; 
            RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 1: ' || SQLERRM; 
            RETURN; 
    END;


    -- ============ PASO 2: Transferir a Destino ============: 
    RAISE NOTICE  ' --- PASO 2: Transferir a Destino ---'; 
    
    UPDATE saga_ordenes 
    SET paso_actual = 2 
    WHERE saga_ordenes.orden_id = v_orden_id; 
    
    BEGIN
    
        -- Simular transferencia a destino (usando dblink) 
        PERFORM dblink_connect('conn_destino', 
            format('host=localhost dbname=banco_%s user=estudiante password=lab2024', p_db_destino) 
        );

        -- Acreditar en destino 
        PERFORM dblink_exec('conn_destino', 
            format('UPDATE cuentas SET saldo = saldo + %s WHERE numero_cuenta = %L', 
            p_monto, p_cuenta_destino) 
        );
        
        PERFORM dblink_disconnect('conn_destino'); 
        
        -- Registrar éxito 
        UPDATE saga_pasos 
        SET estado = 'EJECUTADO', 
            timestamp_ejecucion = CURRENT_TIMESTAMP, 
            accion_ejecutada = format('Acreditados $%s en cuenta %s', p_monto, p_cuenta_destino) 
        WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 2; 

        INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
        VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 2: Fondos acreditados en destino'); 

        v_paso2_exito := TRUE; 
        RAISE NOTICE 'Paso 2 completado'; 
        
    EXCEPTION 
        WHEN OTHERS THEN 
            UPDATE saga_pasos 
            SET estado = 'FALLIDO', 
                timestamp_ejecucion = CURRENT_TIMESTAMP, 
                error_mensaje = SQLERRM 
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 2; 
            
            INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
            VALUES (v_orden_id, 'PASO_FALLIDO', 'Paso 2: ' || SQLERRM); 
            
            RAISE NOTICE 'Paso 2 falló: %', SQLERRM;
            
            -- COMPENSAR PASO 1 
            RAISE NOTICE 'Iniciando compensaciones...'; 
            UPDATE saga_ordenes 
            SET estado = 'COMPENSANDO' 
            WHERE saga_ordenes.orden_id = v_orden_id;
    
            -- Compensación: Desbloquear fondos 
            UPDATE cuentas 
            SET version = version - 1 
            WHERE cuentas.id = v_cuenta_origen_id; 
            
            UPDATE saga_pasos 
            SET estado = 'COMPENSADO', 
                timestamp_compensacion = CURRENT_TIMESTAMP, 
                compensacion_ejecutada = 'Fondos desbloqueados' 
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1; 
            
            INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
            VALUES (v_orden_id, 'COMPENSACION_EJECUTADA', 'Compensación Paso 1: Fondos desbloqueados');
    
            -- Finalizar SAGA como compensada 
            UPDATE saga_ordenes 
            SET estado = 'COMPENSADA', timestamp_final = CURRENT_TIMESTAMP 
            WHERE saga_ordenes.orden_id = v_orden_id; 
            
            RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 2 (compensado): ' || SQLERRM; 
            RETURN; 
    END;

    -- ========== PASO 3: Confirmar Débito Origen ==========
    RAISE NOTICE '--- PASO 3: Confirmar Débito Origen ---';
    
    UPDATE saga_ordenes 
    SET paso_actual = 3 
    WHERE saga_ordenes.orden_id = v_orden_id; 
    
    BEGIN
        -- Ejecutar débito final 
        UPDATE cuentas 
        SET saldo = saldo - p_monto, 
            ultima_modificacion = CURRENT_TIMESTAMP 
        WHERE cuentas.id = v_cuenta_origen_id; 
    
        -- Registrar éxito 
        UPDATE saga_pasos 
        SET estado = 'EJECUTADO', 
            timestamp_ejecucion = CURRENT_TIMESTAMP, 
            accion_ejecutada = format('Debitados $%s de cuenta %s', p_monto, p_cuenta_origen) 
        WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 3; 
        
        INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
        VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 3: Débito confirmado'); 
    
        v_paso3_exito := TRUE; 
        RAISE NOTICE 'Paso 3 completado';
        
        -- SAGA COMPLETADA 
        UPDATE saga_ordenes 
        SET estado = 'COMPLETADA', timestamp_final = CURRENT_TIMESTAMP 
        WHERE saga_ordenes.orden_id = v_orden_id; 
    
        RAISE NOTICE 'SAGA completada exitosamente';
        
        RETURN QUERY SELECT TRUE, v_orden_id, 'Transferencia SAGA completada';
        
    EXCEPTION 
        WHEN OTHERS THEN 
            UPDATE saga_pasos 
            SET estado = 'FALLIDO', 
                timestamp_ejecucion = CURRENT_TIMESTAMP, 
                error_mensaje = SQLERRM 
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 3;
            
            RAISE NOTICE 'Paso 3 falló: %', SQLERRM;
            
            -- COMPENSAR PASO 2 y PASO 1 
            RAISE NOTICE 'Iniciando compensaciones completas...'; 
            UPDATE saga_ordenes 
            SET estado = 'COMPENSANDO' 
            WHERE saga_ordenes.orden_id = v_orden_id; -- 
    
            -- Compensación Paso 2: Revertir crédito en destino 
            BEGIN 
                PERFORM dblink_connect('conn_destino', 
                    format('host=localhost dbname=banco_%s user=estudiante password=lab2024', p_db_destino)
                );
                
                PERFORM dblink_exec('conn_destino', 
                    format('UPDATE cuentas SET saldo = saldo - %s WHERE numero_cuenta = %L', 
                        p_monto, p_cuenta_destino) 
                );
                
                PERFORM dblink_disconnect('conn_destino'); 
                
                UPDATE saga_pasos 
                SET estado = 'COMPENSADO', 
                    timestamp_compensacion = CURRENT_TIMESTAMP, 
                    compensacion_ejecutada = 'Crédito revertido en destino' 
                WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 2; 
            EXCEPTION 
                WHEN OTHERS THEN 
                    RAISE NOTICE 'Error en compensación paso 2: %', SQLERRM; 
    
            END;
        
            -- Compensación Paso 1: Desbloquear fondos 
            UPDATE cuentas 
            SET version = version - 1 
            WHERE cuentas.id = v_cuenta_origen_id; 
            
            UPDATE saga_pasos 
            SET estado = 'COMPENSADO', 
                timestamp_compensacion = CURRENT_TIMESTAMP, 
                compensacion_ejecutada = 'Fondos desbloqueados' 
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1;
            
            -- Finalizar SAGA 
            UPDATE saga_ordenes 
            SET estado = 'COMPENSADA', timestamp_final = CURRENT_TIMESTAMP 
            WHERE saga_ordenes.orden_id = v_orden_id; 
            
            RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 3 (compensado): ' || SQLERRM; 
    END; 
END; 
$$ LANGUAGE plpgsql;

-- 6.3 Probar SAGA exitosa 
-- Terminal 1 (Lima): 

BEGIN; 

SELECT * FROM ejecutar_saga_transferencia( 
	'LIMA-001', 
	'CUSCO-005', 
	300.00, 
	'cusco' 
);

COMMIT; 

-- Ver el flujo completo de SAGA
SELECT * FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1; 
SELECT * FROM saga_pasos WHERE orden_id = ( 
	SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1 
) ORDER BY numero_paso; 
SELECT * FROM saga_eventos WHERE orden_id = ( 
	SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1 
) ORDER BY timestamp_evento; 

-- 6.4 Probar SAGA con fallo y compensación 
-- Terminal 1 (Lima): 

BEGIN;

-- Intentar transferir a cuenta inexistente (forzar fallo en paso 2) 
SELECT * FROM ejecutar_saga_transferencia( 
	'LIMA-002', 
	'CUSCO-999', 
	500.00, 
	'cusco' 
);

COMMIT; 

-- Ver cómo se compensó 
SELECT * FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1; 
SELECT 
	numero_paso, 
	nombre_paso, 
	estado, 
	accion_ejecutada, 
	compensacion_ejecutada, 
	error_mensaje 
FROM saga_pasos 
WHERE orden_id = (SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1) 
ORDER BY numero_paso;

-- Ver eventos de compensación 
SELECT * FROM saga_eventos 
WHERE orden_id = (SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1) 
ORDER BY timestamp_evento
