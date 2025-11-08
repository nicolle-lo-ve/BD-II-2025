# Informe de Laboratorio 6: Control de Concurrencia Distribuida



## Introducción

El presente informe documenta la implementación y prueba de protocolos de control de concurrencia en sistemas de bases de datos distribuidas. Se trabajó con tres bases de datos PostgreSQL simulando sucursales bancarias en Lima, Cusco y Arequipa. El laboratorio se dividió en tres partes principales: implementación manual de Two-Phase Commit (2PC), automatización con funciones PL/pgSQL y el patrón SAGA para transacciones de larga duración.

## Objetivos

1. Implementar manualmente el protocolo Two-Phase Commit para garantizar atomicidad en transacciones distribuidas
2. Automatizar el proceso 2PC mediante funciones almacenadas en PL/pgSQL
3. Implementar el patrón SAGA con mecanismos de compensación para transacciones complejas
4. Simular y analizar escenarios de fallo: saldo insuficiente y deadlocks distribuidos

## Parte A: SQL Puro con Múltiples Terminales

### Preparación del Entorno

Se crearon tres bases de datos independientes representando las sucursales bancarias:

- banco_lima: Sucursal principal actuando como coordinador
- banco_cusco: Sucursal participante
- banco_arequipa: Sucursal participante

### Ejercicio 1: Two-Phase Commit Manual Paso a Paso

Este ejercicio implementó una transferencia de 1000 dólares de LIMA-001 a CUSCO-001 utilizando el protocolo 2PC de forma manual.
**Generación del ID de Transacción:**
Se generó un identificador único usando la función de PostgreSQL. Este identificador se utilizó consistentemente en ambos nodos participantes.

---
**Fase 0: Iniciar Transacción**

---


- En ambas terminales (Lima y Cusco) se ejecutó BEGIN para iniciar las transacciones locales. En Lima se insertó un registro en control_2pc marcando la transacción como INICIADA y designando a Lima como coordinador.
---
**Fase 1: Prepare (Preparación)**

---
Terminal Lima (Participante Origen):
1. Se bloqueó la cuenta LIMA-001 usando FOR UPDATE
2. Se verificó que el saldo fuera suficiente (5000 >= 1000)
3. Se registró la operación como PENDING en transacciones_log
4. Se cambió el estado a PREPARED
5. Se emitió un voto COMMIT incrementando votos_commit en control_2pc
---
Terminal Cusco (Participante Destino):
1. Se verificó la existencia de la cuenta CUSCO-001 con FOR UPDATE
2. Se registró la operación de CREDITO como PENDING
3. Se cambió el estado a PREPARED
4. Se emitió un voto COMMIT
---
Resultado de verificación:
- votos_commit: 2
- votos_abort: 0
- Decisión: GLOBAL-COMMIT
---
**Fase 2: Decisión (Commit)**

---
Una terminal monitora verificó que ambos participantes votaron COMMIT. Se procedió entonces a ejecutar la fase de commit en ambos nodos:

---
Terminal Lima:
- Se ejecutó el débito: UPDATE cuentas SET saldo = saldo - 1000.00
- Se actualizó transacciones_log a estado COMMITTED
- Se actualizó control_2pc a estado CONFIRMADA
- Se ejecutó COMMIT final
---
Terminal Cusco:
- Se ejecutó el crédito: UPDATE cuentas SET saldo = saldo + 1000.00
- Se actualizaron registros de log y control
- Se ejecutó COMMIT final
---
**Verificación Final:**

| Cuenta | Saldo Inicial | Saldo Final | Operación |
|--------|---------------|-------------|-----------|
| LIMA-001 | 5000.00 | 4000.00 | -1000.00 |
| CUSCO-001 | 2000.00 | 3000.00 | +1000.00 |

La transacción se completó exitosamente manteniendo la consistencia entre ambas bases de datos.

---
### Ejercicio 2: Simulación de Abort (Saldo Insuficiente)
---
Se intentó transferir 10000 dólares de LIMA-002 (saldo: 3000) a AQP-001 para simular un fallo por saldo insuficiente.

---
**Proceso en Terminal Lima:**
1. Se inició la transacción y se registró en control_2pc
2. Se bloqueó LIMA-002 con FOR UPDATE
3. Al verificar el saldo: 3000 < 10000 (INSUFICIENTE)
4. Se registró la operación como PENDING con descripción del error
5. Se emitió voto ABORT incrementando votos_abort
6. Se marcó la transacción como ABORTED en todos los registros
7. Se ejecutó ROLLBACK
---
**Proceso en Terminal Arequipa:**
Al consultar el estado global desde Arequipa, se observó que el coordinador ya había decidido ABORT, por lo que este participante también abortó sin intentar prepararse.

---
**Resultado:**

| Parámetro | Valor |
|-----------|-------|
| Estado Global | ABORTADA |
| Votos Abort | 1 |
| Votos Commit | 0 |
| Saldo LIMA-002 | 3000.00 (sin cambios) |
| Saldo AQP-001 | 6000.00 (sin cambios) |

Este ejercicio demostró cómo el protocolo 2PC maneja correctamente los fallos durante la fase de preparación, evitando inconsistencias en el sistema distribuido.

---
### Ejercicio 3: Simulación de Deadlock Distribuido
---
Se implementó un escenario de deadlock mediante dos transferencias cruzadas ejecutadas simultáneamente:

- Transferencia A: LIMA-003 a CUSCO-002 (500 dólares)
- Transferencia B: CUSCO-002 a LIMA-003 (300 dólares)

**Instalación de dblink:**

Para permitir acceso remoto entre bases de datos se instaló la extensión dblink en ambos nodos:

```sql
CREATE EXTENSION IF NOT EXISTS dblink;
```

Se configuraron las conexiones:
- Lima conecta a Cusco: conn_cusco
- Cusco conecta a Lima: conn_lima
---
**Ejecución del Deadlock:**

---
Terminal 1 (Lima):
1. BEGIN
2. Bloquea LIMA-003 localmente con FOR UPDATE (BLOQUEADO)
3. Espera 5 segundos con pg_sleep(5)
4. Intenta bloquear CUSCO-002 remotamente vía dblink

---
Terminal 2 (Cusco):
1. BEGIN (ejecutado inmediatamente después)
2. Bloquea CUSCO-002 localmente con FOR UPDATE (BLOQUEADO)
3. Espera 2 segundos
4. Intenta bloquear LIMA-003 remotamente vía dblink

---
**Resultado Esperado:**
Se produce un deadlock circular:
- Lima tiene bloqueado LIMA-003 y espera CUSCO-002
- Cusco tiene bloqueado CUSCO-002 y espera LIMA-003

PostgreSQL detecta el deadlock después del timeout configurado y aborta una de las transacciones automáticamente, permitiendo que la otra continúe. Se ejecutó ROLLBACK en ambas terminales para limpiar el estado.

Este ejercicio evidenció que en sistemas distribuidos, los deadlocks son más difíciles de detectar que en sistemas centralizados, ya que no existe un grafo global de espera. La solución típica incluye timeouts y mecanismos de retry.

---
## Parte B: Automatización con PL/pgSQL

---
### Paso 4: Creación de Funciones Almacenadas
---
#### Función preparar_debito (Lima)

Esta función encapsula la lógica de la fase PREPARE para operaciones de débito:

**Parámetros:**
- p_transaccion_id: Identificador de la transacción
- p_numero_cuenta: Cuenta a debitar
- p_monto: Cantidad a debitar

**Lógica implementada:**
1. Bloquea la cuenta con FOR UPDATE
2. Verifica existencia de la cuenta
3. Valida saldo suficiente
4. Registra operación en transacciones_log con estado PREPARED
5. Retorna TRUE (VOTE-COMMIT) o FALSE (VOTE-ABORT)

**Pruebas realizadas:**

Prueba exitosa:
```sql
SELECT preparar_debito('TXN-TEST-001', 'LIMA-001', 500.00);
-- Resultado: TRUE
```

Prueba con saldo insuficiente:
```sql
SELECT preparar_debito('TXN-TEST-002', 'LIMA-001', 50000.00);
-- Resultado: FALSE (Saldo insuficiente)
```
---
#### Función preparar_credito (Cusco)

---
Similar a preparar_debito pero para operaciones de crédito:

**Diferencias clave:**
- No valida saldo (los créditos no requieren saldo previo)
- Registra tipo_operacion como CREDITO
- Siempre retorna TRUE si la cuenta existe

Esta función es más simple porque las operaciones de crédito tienen menos restricciones.

---
#### Función confirmar_transaccion

---
Implementa la fase COMMIT del protocolo 2PC:

**Proceso:**
1. Busca todas las operaciones en estado PREPARED
2. Para cada operación:
   - Si es DEBITO: resta el monto del saldo
   - Si es CREDITO: suma el monto al saldo
   - Actualiza version y ultima_modificacion
   - Marca la operación como COMMITTED
3. Actualiza control_2pc a estado CONFIRMADA

Esta función se copió idénticamente en ambos nodos (Lima y Cusco) para mantener consistencia en el proceso de confirmación.

---
#### Función abortar_transaccion

---
Maneja la fase ABORT del protocolo:
**Acciones:**
- Marca todas las operaciones de la transacción como ABORTED
- Actualiza control_2pc a estado ABORTADA
- Registra timestamp de decisión

No revierte cambios en cuentas porque las operaciones preparadas no modifican saldos hasta el commit.


---
### Ejercicio 4: Uso de Funciones para 2PC Automatizado
---
Se realizó una transferencia de 800 dólares de LIMA-004 a CUSCO-003 usando las funciones creadas.

---
**Terminal Lima:**
```
Transacción: TXN-20251105-110032
```

1. BEGIN
2. Se registró en control_2pc con estado PREPARANDO
3. Se ejecutó preparar_debito('TXN-20251105-110032', 'LIMA-004', 800.00)
   - Resultado: TRUE (VOTE-COMMIT)
4. Se mantuvo la transacción abierta esperando el voto del participante destino

---
**Terminal Cusco:**

1. BEGIN
2. Se ejecutó preparar_credito('TXN-20251105-110032', 'CUSCO-003', 800.00)
   - Resultado: TRUE (VOTE-COMMIT)
3. Se verificó el estado en transacciones_log

---
**Terminal Monitor (Verificación de Votos):**

Se consultó control_2pc confirmando:
- votos_commit: 2
- votos_abort: 0
- Decisión: Proceder a COMMIT

---
**Fase de Confirmación:**

Terminal Lima:
- Se ejecutó confirmar_transaccion('TXN-20251105-110032')
- COMMIT de la transacción

Terminal Cusco:
- Se ejecutó confirmar_transaccion('TXN-20251105-110032')
- COMMIT de la transacción

---
**Resultados Finales:**

| Cuenta | Saldo Inicial | Saldo Final | Cambio |
|--------|---------------|-------------|---------|
| LIMA-004 | 2800.00 | 2000.00 | -800.00 |
| CUSCO-003 | 1800.00 | 2600.00 | +800.00 |

La automatización mediante funciones redujo significativamente la posibilidad de errores humanos y simplificó el proceso de ejecución del protocolo 2PC.

---
### Paso 5: Función Coordinadora Completa
---
Se implementó una función de alto nivel que orquesta todo el proceso 2PC de forma transparente.

#### Función transferencia_distribuida_coordinador

**Parámetros:**
- p_cuenta_origen: Cuenta de débito
- p_cuenta_destino: Cuenta de crédito
- p_monto: Cantidad a transferir
- p_db_destino: Nombre de la base de datos destino (cusco, arequipa)

**Retorna:**
Una tabla con tres columnas:
- exito: BOOLEAN indicando éxito o fallo
- mensaje: Descripción del resultado
- transaccion_id: ID generado para la transacción

**Funcionamiento interno:**

1. Genera ID único con componente aleatorio para evitar colisiones
2. Configura conexión dblink dinámicamente según p_db_destino
3. Conecta a la base de datos remota
4. Registra transacción en control_2pc con lista de participantes

**Fase 1: PREPARE**
- Ejecuta preparar_debito localmente
- Ejecuta preparar_credito remotamente vía dblink usando format() para inyección segura de parámetros
- Recolecta ambos votos

**Fase 2: DECISIÓN**

Si ambos votos son positivos (COMMIT):
- Ejecuta confirmar_transaccion localmente
- Ejecuta confirmar_transaccion remotamente
- Desconecta dblink
- Retorna éxito

Si hay algún voto negativo (ABORT):
- Ejecuta abortar_transaccion localmente
- Ejecuta abortar_transaccion remotamente
- Desconecta dblink
- Retorna fallo con mensaje explicativo

**Manejo de excepciones:**
En caso de error en cualquier punto:
- Intenta abortar en ambos nodos
- Intenta desconectar dblink de forma segura
- Retorna error con SQLERRM

---
#### Prueba de la Función Coordinadora

Se realizó transferencia de 1200 dólares de LIMA-005 a CUSCO-004:

```sql
BEGIN;
SELECT * FROM transferencia_distribuida_coordinador(
    'LIMA-005',
    'CUSCO-004',
    1200.00,
    'cusco'
);
COMMIT;
```

**Salida de RAISE NOTICE observada:**
```
--- FASE 1: PREPARE ---
Prepare ORIGEN: COMMIT
Prepare DESTINO: COMMIT
--- FASE 2: DECISIÓN ---
Decisión: GLOBAL-COMMIT
Operación DEBITO confirmada para cuenta ID 5
Transacción TXN-20251105-1234-5678 confirmada exitosamente
```

**Verificación en Lima:**

| Cuenta | Saldo Final |
|--------|-------------|
| LIMA-005 | 5000.00 |

**Verificación en Cusco:**

| Cuenta | Saldo Final |
|--------|-------------|
| CUSCO-004 | 6500.00 |

La función coordinadora demostró ser efectiva para encapsular toda la complejidad del protocolo 2PC, proporcionando una interfaz simple para transacciones distribuidas.

---
## Parte C: SAGA Pattern con Triggers
---
### Paso 6: Implementar SAGA con Compensaciones

---
El patrón SAGA se implementó para manejar transacciones de larga duración con posibilidad de compensación.

#### Creación de Tablas SAGA

Se crearon tres tablas en Lima, Cusco y Arequipa:

**Tabla saga_ordenes:**
- Almacena información general de cada SAGA
- Campos: orden_id, tipo, estado, datos (JSONB), paso_actual, timestamps
- Estados posibles: INICIADA, EN PROGRESO, COMPLETADA, FALLIDA, COMPENSANDO, COMPENSADA

**Tabla saga_pasos:**
- Registra cada paso individual de la SAGA
- Incluye: numero_paso, nombre_paso, estado, accion_ejecutada, compensacion_ejecutada
- Permite rastrear qué pasos se ejecutaron y cuáles se compensaron

**Tabla saga_eventos:**
- Bitácora detallada de eventos
- Útil para auditoría y debugging
- Tipos de eventos: PASO COMPLETADO, PASO_FALLIDO, COMPENSACION_EJECUTADA

---
#### Función ejecutar_saga_transferencia

Esta función implementa una SAGA de tres pasos para transferencias distribuidas:

**Paso 1: Bloquear Fondos Origen**

Acciones:
- Bloquea cuenta origen con FOR UPDATE
- Verifica existencia de cuenta
- Valida saldo suficiente
- Incrementa version como mecanismo de bloqueo lógico
- Registra paso como EJECUTADO

Compensación (si fallo posterior):
- Decrementa version para desbloquear fondos
- Marca paso como COMPENSADO

**Paso 2: Transferir a Destino**

Acciones:
- Conecta a base de datos destino vía dblink
- Ejecuta UPDATE para acreditar monto en cuenta destino
- Desconecta dblink
- Registra paso como EJECUTADO

Compensación (si fallo posterior):
- Reconecta a destino
- Revierte crédito restando el monto
- Desconecta
- Marca paso como COMPENSADO

**Paso 3: Confirmar Débito Origen**

Acciones:
- Ejecuta débito final: UPDATE cuentas SET saldo = saldo - monto
- Actualiza ultima_modificacion
- Registra paso como EJECUTADO
- Marca SAGA como COMPLETADA

Compensación (si fallo):
- Compensa Paso 2: revierte crédito en destino
- Compensa Paso 1: desbloquea fondos
- Marca SAGA como COMPENSADA

**Manejo de Errores:**

Cada paso está envuelto en un bloque BEGIN...EXCEPTION:
- Si el paso falla, se registra el error en error_mensaje
- Se actualiza estado del paso a FALLIDO
- Se inicia proceso de compensación de pasos previos ejecutados
- Se actualiza saga_ordenes a estado COMPENSANDO o COMPENSADA

---
### Ejercicio 6.3: Probar SAGA Exitosa
---
Se ejecutó transferencia de 300 dólares de LIMA-001 a CUSCO-005:

```sql
BEGIN;
SELECT * FROM ejecutar_saga_transferencia(
    'LIMA-001',
    'CUSCO-005',
    300.00,
    'cusco'
);
COMMIT;
```

**Resultado:**

| exito | orden_id | mensaje |
|-------|----------|---------|
| TRUE | SAGA-20251107-143022 | Transferencia SAGA completada |

**Consulta de saga_ordenes:**

| Campo | Valor |
|-------|-------|
| orden_id | SAGA-20251107-143022 |
| tipo | TRANSFERENCIA |
| estado | COMPLETADA |
| paso_actual | 3 |

**Consulta de saga_pasos:**

| numero_paso | nombre_paso | estado | accion_ejecutada |
|-------------|-------------|--------|------------------|
| 1 | Bloquear Fondos Origen | EJECUTADO | Bloqueados $300 en cuenta LIMA-001 |
| 2 | Transferir a Destino | EJECUTADO | Acreditados $300 en cuenta CUSCO-005 |
| 3 | Confirmar Débito Origen | EJECUTADO | Debitados $300 de cuenta LIMA-001 |

**Consulta de saga_eventos:**

Los eventos registrados mostraron la progresión completa:
1. Paso 1: Fondos bloqueados
2. Paso 2: Fondos acreditados en destino
3. Paso 3: Débito confirmado

**Verificación de saldos:**

| Cuenta | Saldo Final |
|--------|-------------|
| LIMA-001 | 3700.00 |
| CUSCO-005 | 4000.00 |

La SAGA se ejecutó exitosamente completando los tres pasos sin necesidad de compensación.

---
### Ejercicio 6.4: Probar SAGA con Fallo y Compensación
---
Se intentó transferir 500 dólares de LIMA-002 a CUSCO-999 (cuenta inexistente) para forzar un fallo en el Paso 2:

```sql
BEGIN;
SELECT * FROM ejecutar_saga_transferencia(
    'LIMA-002',
    'CUSCO-999',
    500.00,
    'cusco'
);
COMMIT;
```

**Resultado:**

| exito | orden_id | mensaje |
|-------|----------|---------|
| FALSE | SAGA-20251107-145530 | Fallo en paso 2 (compensado): ... |

**Consulta de saga_ordenes:**

| Campo | Valor |
|-------|-------|
| orden_id | SAGA-20251107-145530 |
| tipo | TRANSFERENCIA |
| estado | COMPENSADA |
| paso_actual | 2 |

**Análisis detallado de saga_pasos:**

| numero_paso | nombre_paso | estado | accion_ejecutada | compensacion_ejecutada | error_mensaje |
|-------------|-------------|--------|------------------|------------------------|---------------|
| 1 | Bloquear Fondos Origen | COMPENSADO | Bloqueados $500 en cuenta LIMA-002 | Fondos desbloqueados | NULL |
| 2 | Transferir a Destino | FALLIDO | NULL | NULL | cuenta no encontrada |
| 3 | Confirmar Débito Origen | PENDIENTE | NULL | NULL | NULL |

**Secuencia de eventos observada:**

1. Paso 1 se ejecutó exitosamente bloqueando fondos
2. Paso 2 intentó acreditar en CUSCO-999
3. La cuenta no existe, se lanzó excepción
4. Se actualizó saga_ordenes a estado COMPENSANDO
5. Se ejecutó compensación del Paso 1 (desbloquear fondos)
6. Se actualizó saga_ordenes a estado COMPENSADA
7. La función retornó FALSE con mensaje de error

**Verificación de saga_eventos:**

| tipo_evento | descripcion |
|-------------|-------------|
| PASO COMPLETADO | Paso 1: Fondos bloqueados |
| PASO_FALLIDO | Paso 2: cuenta no encontrada |
| COMPENSACION_EJECUTADA | Compensación Paso 1: Fondos desbloqueados |

**Verificación de saldos:**

| Cuenta | Saldo Final |
|--------|-------------|
| LIMA-002 | 3000.00 |

El saldo permaneció sin cambios gracias al mecanismo de compensación, demostrando que el patrón SAGA mantiene la consistencia eventual incluso ante fallos.


