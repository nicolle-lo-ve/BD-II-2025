-- Tabla de cuentas
CREATE TABLE cuentas (
    cuenta_id VARCHAR(20) PRIMARY KEY,
    titular VARCHAR(100) NOT NULL,
    saldo DECIMAL(12,2) NOT NULL CHECK (saldo >= 0),
    sucursal VARCHAR(50) DEFAULT 'LIMA'
);

-- Tabla de log de transacciones distribuidas
CREATE TABLE transaction_log (
    txn_id VARCHAR(50) PRIMARY KEY,
    estado VARCHAR(20) CHECK (estado IN ('PREPARE', 'COMMIT', 'ABORT')),
    cuenta_id VARCHAR(20),
    monto DECIMAL(12,2),
    tipo VARCHAR(10) CHECK (tipo IN ('DEBITO', 'CREDITO')),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de votos 2PC
CREATE TABLE votos_2pc (
    txn_id VARCHAR(50),
    nodo VARCHAR(50),
    voto VARCHAR(10) CHECK (voto IN ('COMMIT', 'ABORT')),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (txn_id, nodo)
);

-- Insertar datos de prueba
INSERT INTO cuentas (cuenta_id, titular, saldo) VALUES
    ('LIMA-001', 'Juan Pérez', 5000.00),
    ('LIMA-002', 'María García', 3000.00),
    ('LIMA-003', 'Carlos Rodríguez', 8000.00),
    ('LIMA-004', 'Ana Torres', 6000.00);

-- Verificar datos
SELECT * FROM cuentas;
