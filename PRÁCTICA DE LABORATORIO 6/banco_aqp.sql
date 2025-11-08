CREATE TABLE cuentas ( 
	id SERIAL PRIMARY KEY, 
	numero_cuenta VARCHAR(20) UNIQUE NOT NULL, 
	titular VARCHAR(100) NOT NULL, 
	saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0), 
	sucursal VARCHAR(50) DEFAULT 'Arequipa', 
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
('AQP-001', 'Luis Vargas Bellido', 6000.00), 
('AQP-002', 'Carmen Silva Medina', 2800.00),
('AQP-003', 'Roberto Mendoza Pinto', 9200.00), 
('AQP-004', 'Isabel Díaz Salazar', 4100.00), 
('AQP-005', 'Jorge Paredes Ramos', 7000.00); 


SELECT * FROM cuentas;

-- Terminal 3 (Arequipa): 
BEGIN; 

-- Como el coordinador ya decidio ABORT, este participante tambien aborta
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20251103-181454', 'ABORTADA', 'LIMA'); 

ROLLBACK; 

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
