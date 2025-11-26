
-- MEDIDATAOPTIMIZER - SISTEMA DE GESTIÓN HOSPITALARIA

-- PARTE 2: CREACIÓN DE TABLAS BASE (SIN PARTICIONAMIENTO)


-- Tabla de Pacientes
CREATE TABLE pacientes (
    id_paciente SERIAL PRIMARY KEY,
    dni VARCHAR(8) UNIQUE NOT NULL,
    nombres VARCHAR(50) NOT NULL,
    apellidos VARCHAR(50) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    genero CHAR(1) CHECK (genero IN ('M', 'F')),
    direccion TEXT,
    telefono VARCHAR(15),
    email VARCHAR(100),
    tipo_sangre VARCHAR(5),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de Doctores
CREATE TABLE doctores (
    id_doctor SERIAL PRIMARY KEY,
    nombres VARCHAR(50) NOT NULL,
    apellidos VARCHAR(50) NOT NULL,
    especialidad VARCHAR(100) NOT NULL,
    cmp VARCHAR(20) UNIQUE NOT NULL,
    telefono VARCHAR(15),
    email VARCHAR(100),
    horario_atencion VARCHAR(200),
    fecha_contratacion DATE NOT NULL
);

-- Tabla de Departamentos Médicos
CREATE TABLE departamentos (
    id_departamento SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    ubicacion VARCHAR(100),
    telefono VARCHAR(15),
    jefe_departamento INTEGER REFERENCES doctores(id_doctor)
);


-- PARTE 3: TABLA PARTICIONADA - HISTORIAS CLÍNICAS


-- Tabla maestra particionada por año
CREATE TABLE historias_clinicas (
    id_historia SERIAL,
    id_paciente INTEGER NOT NULL REFERENCES pacientes(id_paciente),
    id_doctor INTEGER NOT NULL REFERENCES doctores(id_doctor),
    fecha_consulta DATE NOT NULL,
    diagnostico TEXT NOT NULL,
    sintomas TEXT,
    tratamiento TEXT,
    medicamentos TEXT,
    observaciones TEXT,
    estado VARCHAR(20) DEFAULT 'ACTIVO',
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_historia, fecha_consulta)
) PARTITION BY RANGE (fecha_consulta);

-- Crear particiones por año (2021-2025)
CREATE TABLE historias_clinicas_2021 PARTITION OF historias_clinicas
    FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');

CREATE TABLE historias_clinicas_2022 PARTITION OF historias_clinicas
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');

CREATE TABLE historias_clinicas_2023 PARTITION OF historias_clinicas
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE historias_clinicas_2024 PARTITION OF historias_clinicas
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE historias_clinicas_2025 PARTITION OF historias_clinicas
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');


-- PARTE 4: TABLA DE CITAS (CON TRANSACCIONES ACID)


CREATE TABLE citas (
    id_cita SERIAL PRIMARY KEY,
    id_paciente INTEGER NOT NULL REFERENCES pacientes(id_paciente),
    id_doctor INTEGER NOT NULL REFERENCES doctores(id_doctor),
    fecha_hora TIMESTAMP NOT NULL,
    motivo TEXT NOT NULL,
    estado VARCHAR(20) DEFAULT 'PROGRAMADA' CHECK (estado IN ('PROGRAMADA', 'CONFIRMADA', 'ATENDIDA', 'CANCELADA')),
    duracion_minutos INTEGER DEFAULT 30,
    consultorio VARCHAR(20),
    observaciones TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de Tratamientos
CREATE TABLE tratamientos (
    id_tratamiento SERIAL PRIMARY KEY,
    id_historia INTEGER NOT NULL,
    descripcion TEXT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    dosis VARCHAR(100),
    frecuencia VARCHAR(100),
    costo DECIMAL(10,2),
    estado VARCHAR(20) DEFAULT 'EN_CURSO' CHECK (estado IN ('EN_CURSO', 'COMPLETADO', 'SUSPENDIDO')),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- PARTE 5: TABLA DE AUDITORÍA PARA TRANSACCIONES
CREATE TABLE auditoria_transacciones (
    id_auditoria SERIAL PRIMARY KEY,
    tabla_afectada VARCHAR(50),
    operacion VARCHAR(20),
    id_registro INTEGER,
    usuario VARCHAR(100),
    fecha_operacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    detalles TEXT
);


-- PARTE 6: INSERCIÓN DE DATOS DE PRUEBA

-- Insertar Doctores
INSERT INTO doctores (nombres, apellidos, especialidad, cmp, telefono, email, fecha_contratacion) VALUES
('Carlos', 'Pérez García', 'Cardiología', 'CMP-12345', '987654321', 'cperez@hospital.com', '2018-03-15'),
('María', 'López Ruiz', 'Pediatría', 'CMP-12346', '987654322', 'mlopez@hospital.com', '2019-06-20'),
('José', 'Martínez Silva', 'Traumatología', 'CMP-12347', '987654323', 'jmartinez@hospital.com', '2017-01-10'),
('Ana', 'González Torres', 'Neurología', 'CMP-12348', '987654324', 'agonzalez@hospital.com', '2020-02-14'),
('Luis', 'Fernández Díaz', 'Gastroenterología', 'CMP-12349', '987654325', 'lfernandez@hospital.com', '2016-09-05'),
('Elena', 'Rodríguez Castro', 'Dermatología', 'CMP-12350', '987654326', 'erodriguez@hospital.com', '2019-11-22'),
('Miguel', 'Sánchez Vega', 'Oftalmología', 'CMP-12351', '987654327', 'msanchez@hospital.com', '2018-07-30'),
('Patricia', 'Ramírez Flores', 'Ginecología', 'CMP-12352', '987654328', 'pramirez@hospital.com', '2021-04-12');

-- Insertar Departamentos
INSERT INTO departamentos (nombre, ubicacion, telefono, jefe_departamento) VALUES
('Cardiología', 'Piso 3 - Ala Norte', '054-234567', 1),
('Pediatría', 'Piso 2 - Ala Sur', '054-234568', 2),
('Traumatología', 'Piso 1 - Emergencias', '054-234569', 3),
('Neurología', 'Piso 4 - Ala Este', '054-234570', 4);

-- Función para generar datos masivos de pacientes
CREATE OR REPLACE FUNCTION insertar_pacientes_masivos(cantidad INTEGER)
RETURNS void AS $$
DECLARE
    i INTEGER;
	nombres_array TEXT[] := ARRAY['Gabriel', 'Elena', 'Roberto', 'Claudia', 'Daniel', 'Lucia', 'Alejandro', 'Victoria', 'Hector', 'Beatriz'];    
	apellidos_array TEXT[] := ARRAY['Quispe', 'Chávez', 'Flores', 'Díaz', 'Rojas', 'Vásquez', 'Castillo', 'Gutiérrez', 'Mendoza', 'Silva'];
    tipo_sangre_array TEXT[] := ARRAY['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
BEGIN
    FOR i IN 1..cantidad LOOP
        INSERT INTO pacientes (dni, nombres, apellidos, fecha_nacimiento, genero, direccion, telefono, tipo_sangre)
        VALUES (
            LPAD((10000000 + i)::TEXT, 8, '0'),
            nombres_array[1 + floor(random() * 10)],
            apellidos_array[1 + floor(random() * 10)] || ' ' || apellidos_array[1 + floor(random() * 10)],
            DATE '1950-01-01' + (random() * 25000)::INTEGER,
            CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END,
            'Av. Principal ' || (100 + i),
            '9' || LPAD((floor(random() * 100000000))::TEXT, 8, '0'),
            tipo_sangre_array[1 + floor(random() * 8)]
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Insertar 10,000 pacientes
SELECT insertar_pacientes_masivos(10000);

-- Función para generar historias clínicas masivas
CREATE OR REPLACE FUNCTION insertar_historias_masivas(cantidad INTEGER)
RETURNS void AS $$
DECLARE
    i INTEGER;
    diagnosticos TEXT[] := ARRAY[
        -- Cardiología
    'Hipertensión arterial esencial', 'Insuficiencia cardíaca congestiva', 'Arritmia cardíaca', 'Cardiopatía isquémica',
    'Infarto agudo de miocardio', 'Soplo cardíaco funcional', 'Taquicardia supraventricular', 'Enfermedad arterial periférica',
    
    -- Traumatología
    'Fractura de radio distal', 'Esguince de tobillo grado II', 'Lumbalgia mecánica aguda', 'Hernia discal lumbar',
    'Tendinitis rotuliana', 'Fractura de clavícula', 'Síndrome del túnel carpiano', 'Artrosis de rodilla',
    
    -- Neurología
    'Cefalea tensional crónica', 'Epilepsia focal idiopática', 'Accidente cerebrovascular isquémico', 'Neuralgia del trigémino',
    'Enfermedad de Parkinson inicial', 'Migraña con aura', 'Neuropatía periférica diabética', 'Esclerosis múltiple remitente-recurrente',
    
    -- Gastroenterología
    'Gastritis erosiva aguda', 'Enfermedad por reflujo gastroesofágico', 'Síndrome de intestino irritable', 'Colitis ulcerosa en remisión',
    'Colelitiasis sintomática', 'Hepatitis viral aguda', 'Diverticulosis colónica', 'Pancreatitis aguda leve',
    
    -- Dermatología
    'Acné vulgar moderado', 'Psoriasis en placas', 'Dermatitis atópica', 'Carcinoma basocelular facial',
    'Micosis cutánea', 'Urticaria crónica', 'Rosácea erythematotelangiectatica', 'Vitíligo segmentario',
    
    -- Oftalmología
    'Catarata senil incipiente', 'Glaucoma de ángulo abierto', 'Conjuntivitis alérgica estacional', 'Retinopatía diabética no proliferativa',
    'Desprendimiento de vítreo posterior', 'Miopía progresiva', 'Ojo seco moderado', 'Blefaritis crónica'
    ];
    fecha_aleatoria DATE;
    anio INTEGER;
BEGIN
    FOR i IN 1..cantidad LOOP
        -- Generar fecha aleatoria entre 2021 y 2025
        anio := 2021 + floor(random() * 5);
        fecha_aleatoria := DATE (anio || '-01-01') + (random() * 364)::INTEGER;
        
        INSERT INTO historias_clinicas (id_paciente, id_doctor, fecha_consulta, diagnostico, sintomas, tratamiento, medicamentos)
        VALUES (
            1 + floor(random() * 10000),
            1 + floor(random() * 8),
            fecha_aleatoria,
            diagnosticos[1 + floor(random() * 48)],
            'Síntomas relacionados con el diagnóstico - Registro ' || i,
            'Tratamiento estándar según protocolo médico',
            'Medicamentos prescritos según diagnóstico'
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Insertar 50,000 historias clínicas distribuidas en las particiones
SELECT insertar_historias_masivas(50000);

-- Insertar citas de ejemplo
INSERT INTO citas (id_paciente, id_doctor, fecha_hora, motivo, estado) 
SELECT 
    1 + floor(random() * 10000),
    1 + floor(random() * 8),
    CURRENT_TIMESTAMP + (random() * 30 || ' days')::INTERVAL,
    'Consulta general',
    CASE floor(random() * 4)
        WHEN 0 THEN 'PROGRAMADA'
        WHEN 1 THEN 'CONFIRMADA'
        WHEN 2 THEN 'ATENDIDA'
        ELSE 'CANCELADA'
    END
FROM generate_series(1, 5000);


-- PARTE 7: CREACIÓN DE ÍNDICES B-TREE Y HASH

-- Índices B-tree para búsquedas por rango y ordenamiento
CREATE INDEX idx_btree_pacientes_dni ON pacientes USING btree(dni);
CREATE INDEX idx_btree_pacientes_apellidos ON pacientes USING btree(apellidos);
CREATE INDEX idx_btree_doctores_especialidad ON doctores USING btree(especialidad);

-- Índices en particiones de historias clínicas
CREATE INDEX idx_btree_historias_paciente ON historias_clinicas(id_paciente);
CREATE INDEX idx_btree_historias_doctor ON historias_clinicas(id_doctor);
CREATE INDEX idx_btree_historias_fecha ON historias_clinicas(fecha_consulta);
CREATE INDEX idx_btree_historias_diagnostico ON historias_clinicas USING btree(diagnostico);

-- Índices Hash para búsquedas exactas
CREATE INDEX idx_hash_pacientes_dni ON pacientes USING hash(dni);
CREATE INDEX idx_hash_doctores_cmp ON doctores USING hash(cmp);

-- Índices para citas
CREATE INDEX idx_btree_citas_paciente ON citas(id_paciente);
CREATE INDEX idx_btree_citas_doctor ON citas(id_doctor);
CREATE INDEX idx_btree_citas_fecha ON citas(fecha_hora);
CREATE INDEX idx_btree_citas_estado ON citas(estado);


-- PARTE 8: CLUSTERING - AGRUPAR DATOS FÍSICAMENTE


-- Clustering: Reorganizar físicamente las tablas según índices principales
CLUSTER pacientes USING idx_btree_pacientes_dni;
CLUSTER doctores USING idx_btree_doctores_especialidad;
CLUSTER historias_clinicas_2024 USING idx_btree_historias_fecha;
CLUSTER citas USING idx_btree_citas_fecha;

-- Analizar tablas después del clustering
ANALYZE pacientes;
ANALYZE doctores;
ANALYZE historias_clinicas;
ANALYZE citas;


-- PARTE 9: TRANSACCIONES ACID - PROCEDIMIENTOS

-- Procedimiento para registrar cita con transacción ACID
CREATE OR REPLACE FUNCTION registrar_cita_transaccion(
    p_id_paciente INTEGER,
    p_id_doctor INTEGER,
    p_fecha_hora TIMESTAMP,
    p_motivo TEXT
) RETURNS INTEGER AS $$
DECLARE
    v_id_cita INTEGER;
    v_paciente_existe BOOLEAN;
    v_doctor_existe BOOLEAN;
    v_doctor_disponible BOOLEAN;
BEGIN
    -- Iniciar punto de guardado
    SAVEPOINT inicio_registro;
    
    -- Verificar que el paciente existe
    SELECT EXISTS(SELECT 1 FROM pacientes WHERE id_paciente = p_id_paciente)
    INTO v_paciente_existe;
    
    IF NOT v_paciente_existe THEN
        RAISE EXCEPTION 'El paciente con ID % no existe', p_id_paciente;
    END IF;
    
    -- Verificar que el doctor existe
    SELECT EXISTS(SELECT 1 FROM doctores WHERE id_doctor = p_id_doctor)
    INTO v_doctor_existe;
    
    IF NOT v_doctor_existe THEN
        RAISE EXCEPTION 'El doctor con ID % no existe', p_id_doctor;
    END IF;
    
    -- Verificar disponibilidad del doctor en ese horario
    SELECT NOT EXISTS(
        SELECT 1 FROM citas 
        WHERE id_doctor = p_id_doctor 
        AND fecha_hora = p_fecha_hora
        AND estado IN ('PROGRAMADA', 'CONFIRMADA')
    ) INTO v_doctor_disponible;
    
    IF NOT v_doctor_disponible THEN
        RAISE EXCEPTION 'El doctor no está disponible en ese horario';
    END IF;
    
    -- Insertar la cita
    INSERT INTO citas (id_paciente, id_doctor, fecha_hora, motivo, estado)
    VALUES (p_id_paciente, p_id_doctor, p_fecha_hora, p_motivo, 'PROGRAMADA')
    RETURNING id_cita INTO v_id_cita;
    
    -- Registrar en auditoría
    INSERT INTO auditoria_transacciones (tabla_afectada, operacion, id_registro, usuario, detalles)
    VALUES ('citas', 'INSERT', v_id_cita, CURRENT_USER, 'Cita registrada exitosamente');
    
    RETURN v_id_cita;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback al punto de guardado
        ROLLBACK TO SAVEPOINT inicio_registro;
        RAISE NOTICE 'Error: %', SQLERRM;
        RETURN -1;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para registrar tratamiento con transacción
CREATE OR REPLACE FUNCTION registrar_tratamiento_transaccion(
    p_id_historia INTEGER,
    p_descripcion TEXT,
    p_fecha_inicio DATE,
    p_fecha_fin DATE,
    p_costo DECIMAL
) RETURNS INTEGER AS $$
DECLARE
    v_id_tratamiento INTEGER;
    v_historia_existe BOOLEAN;
BEGIN
    -- Verificar que la historia clínica existe
    SELECT EXISTS(SELECT 1 FROM historias_clinicas WHERE id_historia = p_id_historia)
    INTO v_historia_existe;
    
    IF NOT v_historia_existe THEN
        RAISE EXCEPTION 'La historia clínica con ID % no existe', p_id_historia;
    END IF;
    
    -- Insertar tratamiento
    INSERT INTO tratamientos (id_historia, descripcion, fecha_inicio, fecha_fin, costo)
    VALUES (p_id_historia, p_descripcion, p_fecha_inicio, p_fecha_fin, p_costo)
    RETURNING id_tratamiento INTO v_id_tratamiento;
    
    -- Auditoría
    INSERT INTO auditoria_transacciones (tabla_afectada, operacion, id_registro, usuario, detalles)
    VALUES ('tratamientos', 'INSERT', v_id_tratamiento, CURRENT_USER, 
            'Tratamiento registrado - Costo: ' || p_costo);
    
    RETURN v_id_tratamiento;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al registrar tratamiento: %', SQLERRM;
        RETURN -1;
END;
$$ LANGUAGE plpgsql;


-- PARTE 10: CONSULTAS COMPLEJAS CON EXPLAIN ANALYZE

-- CONSULTA 1: Búsqueda de paciente por DNI


-- SIN ÍNDICE (simulado eliminando temporalmente)
DROP INDEX IF EXISTS idx_btree_pacientes_dni;
DROP INDEX IF EXISTS idx_hash_pacientes_dni;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT p.*, COUNT(h.id_historia) as total_consultas
FROM pacientes p
LEFT JOIN historias_clinicas h ON p.id_paciente = h.id_paciente
WHERE p.dni = '10001000'
GROUP BY p.id_paciente;

-- Recrear índices
CREATE INDEX idx_btree_pacientes_dni ON pacientes USING btree(dni);
CREATE INDEX idx_hash_pacientes_dni ON pacientes USING hash(dni);

-- CON ÍNDICE
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT p.*, COUNT(h.id_historia) as total_consultas
FROM pacientes p
LEFT JOIN historias_clinicas h ON p.id_paciente = h.id_paciente
WHERE p.dni = '10001000'
GROUP BY p.id_paciente;


-- CONSULTA 2: Historias clínicas por rango de fechas


-- Esta consulta aprovecha el particionamiento
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    h.id_historia,
    h.fecha_consulta,
    p.nombres || ' ' || p.apellidos as paciente,
    d.nombres || ' ' || d.apellidos as doctor,
    h.diagnostico
FROM historias_clinicas h
JOIN pacientes p ON h.id_paciente = p.id_paciente
JOIN doctores d ON h.id_doctor = d.id_doctor
WHERE h.fecha_consulta BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY h.fecha_consulta DESC
LIMIT 100;


-- CONSULTA 3: Estadísticas por especialidad


EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    d.especialidad,
    COUNT(DISTINCT h.id_paciente) as pacientes_atendidos,
    COUNT(h.id_historia) as total_consultas,
    AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.fecha_nacimiento))) as edad_promedio_pacientes
FROM historias_clinicas h
JOIN doctores d ON h.id_doctor = d.id_doctor
JOIN pacientes p ON h.id_paciente = p.id_paciente
WHERE h.fecha_consulta >= '2024-01-01'
GROUP BY d.especialidad
ORDER BY total_consultas DESC;


-- CONSULTA 4: Diagnósticos más frecuentes por año


EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    EXTRACT(YEAR FROM fecha_consulta) as anio,
    diagnostico,
    COUNT(*) as frecuencia,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY EXTRACT(YEAR FROM fecha_consulta)), 2) as porcentaje
FROM historias_clinicas
WHERE fecha_consulta >= '2021-01-01'
GROUP BY EXTRACT(YEAR FROM fecha_consulta), diagnostico
HAVING COUNT(*) > 10
ORDER BY anio DESC, frecuencia DESC;


-- CONSULTA 5: Carga de trabajo por doctor


EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    d.id_doctor,
    d.nombres || ' ' || d.apellidos as doctor,
    d.especialidad,
    COUNT(DISTINCT DATE(c.fecha_hora)) as dias_trabajados,
    COUNT(c.id_cita) as total_citas,
    COUNT(CASE WHEN c.estado = 'ATENDIDA' THEN 1 END) as citas_atendidas,
    ROUND(COUNT(CASE WHEN c.estado = 'ATENDIDA' THEN 1 END)::NUMERIC / 
          NULLIF(COUNT(c.id_cita), 0) * 100, 2) as tasa_atencion
FROM doctores d
LEFT JOIN citas c ON d.id_doctor = c.id_doctor
WHERE c.fecha_hora >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY d.id_doctor, d.nombres, d.apellidos, d.especialidad
ORDER BY total_citas DESC;


-- PARTE 11: FUNCIÓN PARA PRUEBAS DE RENDIMIENTO


CREATE OR REPLACE FUNCTION prueba_rendimiento_completa()
RETURNS TABLE(
    consulta VARCHAR,
    tiempo_sin_indices DECIMAL,
    tiempo_con_indices DECIMAL,
    mejora_porcentual DECIMAL
) AS $$
DECLARE
    inicio TIMESTAMP;
    fin TIMESTAMP;
    tiempo1 DECIMAL;
    tiempo2 DECIMAL;
BEGIN
    -- Prueba 1: Búsqueda por DNI
    DROP INDEX IF EXISTS idx_hash_pacientes_dni;
    inicio := clock_timestamp();
    PERFORM * FROM pacientes WHERE dni = '10001000';
    fin := clock_timestamp();
    tiempo1 := EXTRACT(MILLISECONDS FROM (fin - inicio));
    
    CREATE INDEX idx_hash_pacientes_dni ON pacientes USING hash(dni);
    ANALYZE pacientes;
    
    inicio := clock_timestamp();
    PERFORM * FROM pacientes WHERE dni = '10001000';
    fin := clock_timestamp();
    tiempo2 := EXTRACT(MILLISECONDS FROM (fin - inicio));
    
    consulta := 'Búsqueda por DNI';
    tiempo_sin_indices := tiempo1;
    tiempo_con_indices := tiempo2;
    mejora_porcentual := ROUND(((tiempo1 - tiempo2) / tiempo1 * 100), 2);
    RETURN NEXT;
    
    -- Prueba 2: Búsqueda por diagnóstico
    DROP INDEX IF EXISTS idx_btree_historias_diagnostico;
    inicio := clock_timestamp();
    PERFORM * FROM historias_clinicas WHERE diagnostico = 'Diabetes tipo 2';
    fin := clock_timestamp();
    tiempo1 := EXTRACT(MILLISECONDS FROM (fin - inicio));
    
    CREATE INDEX idx_btree_historias_diagnostico ON historias_clinicas(diagnostico);
    ANALYZE historias_clinicas;
    
    inicio := clock_timestamp();
    PERFORM * FROM historias_clinicas WHERE diagnostico = 'Diabetes tipo 2';
    fin := clock_timestamp();
    tiempo2 := EXTRACT(MILLISECONDS FROM (fin - inicio));
    
    consulta := 'Búsqueda por diagnóstico';
    tiempo_sin_indices := tiempo1;
    tiempo_con_indices := tiempo2;
    mejora_porcentual := ROUND(((tiempo1 - tiempo2) / tiempo1 * 100), 2);
    RETURN NEXT;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Ejecutar pruebas de rendimiento
SELECT * FROM prueba_rendimiento_completa();


-- PARTE 12: VERIFICACIÓN Y MONITOREO


-- Ver tamaño de las particiones
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename LIKE 'historias_clinicas%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Ver índices creados
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Estadísticas de uso de índices
SELECT 
    schemaname,
    relname,
    indexrelname,
    idx_scan as veces_usado,
    idx_tup_read as tuplas_leidas,
    idx_tup_fetch as tuplas_obtenidas
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

SELECT * FROM resultados_rendimiento;

