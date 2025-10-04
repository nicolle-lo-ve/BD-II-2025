# Laboratorio 5: Introducción al Procesamiento de Transacciones en PostgreSQL

**Elaborado por:** Nicolle Lozano  

## Descripción General
Esta práctica introduce los conceptos fundamentales de las transacciones en bases de datos, demostrando las propiedades ACID (Atomicidad, Consistencia, Aislamiento, Durabilidad) a través de ejercicios prácticos con escenarios bancarios y de e-commerce.

## Objetivos de la Práctica
- Comprender el concepto de transacciones en bases de datos
- Demostrar las propiedades ACID en escenarios reales
- Implementar transacciones básicas y complejas
- Manejar errores y rollbacks en operaciones transaccionales
- Analizar el comportamiento de transacciones concurrentes

## Estructuras Implementadas
- **Sistema Bancario:** Tablas de cuentas y movimientos
- **E-commerce:** Tablas de productos, pedidos y detalles de pedidos
- **Restricciones de Integridad:** CHECK constraints y FOREIGN KEY constraints

## Ejecuciones Relevantes del Código

### 1. Transferencia Bancaria Básica - Atomicidad
```sql
BEGIN;
    UPDATE cuentas SET saldo = saldo - 500.00 WHERE numero_cuenta = 'CTA-001';
    UPDATE cuentas SET saldo = saldo + 500.00 WHERE numero_cuenta = 'CTA-002';
    INSERT INTO movimientos (cuenta_origen, cuenta_destino, monto, tipo_operacion) 
    VALUES ('CTA-001', 'CTA-002', 500.00, 'TRANSFERENCIA');
COMMIT;
```
<img width="697" height="135" alt="Captura de pantalla 2025-10-03 211137" src="https://github.com/user-attachments/assets/d88ce690-3e38-4a0d-8736-f693fca8093a" />
<img width="695" height="134" alt="Captura de pantalla 2025-10-03 211359" src="https://github.com/user-attachments/assets/5e2a6ce4-853a-4606-ad72-b5dce1f32a3c" />

La transacción demostró **atomicidad** al ejecutar tres operaciones como una única unidad. Todas las operaciones se completaron exitosamente o ninguna se aplicó. El COMMIT aseguró que los cambios fueran permanentes y visibles para otras sesiones.

### 2. Comportamiento sin COMMIT - Aislamiento
```sql
-- Sesión 1
BEGIN;
UPDATE cuentas SET saldo = saldo - 100.00 WHERE numero_cuenta = 'CTA-003';
```

<img width="455" height="93" alt="Captura de pantalla 2025-10-03 211618" src="https://github.com/user-attachments/assets/2be70bb7-75f0-4b07-9471-3229e0b3f97e" />

```sql
-- Sesión 2 (conexión diferente)
SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta = 'CTA-003';
```
<img width="457" height="97" alt="Captura de pantalla 2025-10-03 211756" src="https://github.com/user-attachments/assets/85dc7517-3f00-40ae-923d-f4875ffa962f" />


Se demostró el **aislamiento** entre transacciones. Los cambios no son visibles para otras sesiones hasta que se ejecuta COMMIT. Esto previene lecturas de datos inconsistentes y mantiene la integridad durante transacciones concurrentes.

### 3. Pedido E-commerce Completo - Consistencia
```sql
BEGIN;
    INSERT INTO pedidos (cliente_nombre, cliente_email, estado) 
    VALUES ('Roberto Silva', 'roberto@email.com', 'PROCESANDO');
    
    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal) 
    VALUES (1, 1, 1, 2500.00, 2500.00);
    UPDATE productos SET stock = stock - 1 WHERE id = 1;
    
    -- Operaciones similares para otros productos...
    
    UPDATE pedidos SET total = 2770.00, estado = 'CONFIRMADO' WHERE id = 1;
COMMIT;
```
<img width="928" height="104" alt="Captura de pantalla 2025-10-03 221612" src="https://github.com/user-attachments/assets/dc9d3e9c-dd2c-4868-b06d-af0d8014d7fd" />
<img width="734" height="175" alt="Captura de pantalla 2025-10-03 221706" src="https://github.com/user-attachments/assets/1ae3c9cf-f7ce-4960-8014-fb6a11121408" />

La transacción mantuvo la **consistencia** de la base de datos. Las restricciones CHECK y FOREIGN KEY aseguraron que los datos permanecieran válidos throughout la transacción, y las relaciones entre pedidos y productos se mantuvieron íntegras.

### 4. Transferencia con Saldo Insuficiente - Atomicidad con Error
```sql
BEGIN;
    UPDATE cuentas SET saldo = saldo - 1000.00 WHERE numero_cuenta = 'CTA-005';
    UPDATE cuentas SET saldo = saldo + 1000.00 WHERE numero_cuenta = 'CTA-001';
COMMIT;
```
<img width="1122" height="182" alt="Captura de pantalla 2025-10-03 222128" src="https://github.com/user-attachments/assets/1c2efed2-f966-4fde-80fa-30ba9fb642e6" />

PostgreSQL aplicó **atomicidad automática** al detectar la violación de la restricción CHECK. La transacción completa fue revertida, demostrando que en una transacción, "todo o nada" se aplica incluso con errores automáticamente detectados.

### 5. Escenario de Concurrencia - Aislamiento
```sql
-- Sesión A
BEGIN;
SELECT saldo FROM cuentas WHERE numero_cuenta = 'CTA-004'; -- $8,900

-- Sesión B
BEGIN;
UPDATE cuentas SET saldo = saldo - 200.00 WHERE numero_cuenta = 'CTA-004';
COMMIT;

-- Sesión A continúa
UPDATE cuentas SET saldo = saldo - 500.00 WHERE numero_cuenta = 'CTA-004';
COMMIT;
```
<img width="694" height="96" alt="Captura de pantalla 2025-10-03 223231" src="https://github.com/user-attachments/assets/fa14913e-c7cd-4151-a2a4-e41c82e925e3" />

- Saldo final de CTA-004: $8,200.00 ($8,900 - $200 - $500)

Ambas transacciones se ejecutaron concurrentemente sin conflictos. PostgreSQL manejó el **aislamiento** permitiendo que ambas transacciones modificaran la misma cuenta de manera secuencial, manteniendo la consistencia final de los datos.

### 6. Manejo de Errores Programático
```sql
DO $$
DECLARE
    cuenta_inexistente EXCEPTION;
    saldo_actual DECIMAL(12,2);
BEGIN
    UPDATE cuentas SET saldo = saldo - 1000 WHERE numero_cuenta = 'CTA-INEXISTENTE';
    GET DIAGNOSTICS saldo_actual = ROW_COUNT;
    
    IF saldo_actual = 0 THEN
        RAISE cuenta_inexistente;
    END IF;
EXCEPTION
    WHEN cuenta_inexistente THEN
        RAISE NOTICE 'Error: La cuenta no existe';
        ROLLBACK;
END $$;
```
- Mensaje: "Error: La cuenta no existe"
- Transacción revertida automáticamente

El manejo programático de errores permite una gestión más granular de las transacciones fallidas. Los bloques EXCEPTION en PostgreSQL proporcionan control sobre el comportamiento de rollback y permiten una respuesta específica a diferentes tipos de errores.

## Resultados y Análisis

### Comportamiento de Transacciones
| Escenario | Resultado | Propiedad ACID Demostrada |
|-----------|-----------|---------------------------|
| Transferencia exitosa | Cambios aplicados permanentemente | Atomicidad, Durabilidad |
| Transferencia con error | Rollback automático completo | Atomicidad |
| Consulta sin COMMIT | Cambios visibles solo en sesión actual | Aislamiento |
| Violación de restricción | Transacción rechazada | Consistencia |
| Transacciones concurrentes | Ejecución secuencial sin conflictos | Aislamiento |

### Impacto en el Sistema
- **Integridad de Datos:** Las restricciones aseguran que solo datos válidos se persistan
- **Concurrencia:** Múltiples usuarios pueden operar simultáneamente sin corromper datos
- **Recuperación:** Los COMMIT y ROLLBACK proporcionan control sobre la persistencia de cambios

### Respuestas a Preguntas Clave

**¿Por qué es importante el COMMIT?**
- Hace permanentes los cambios
- Hace visibles los cambios a otras sesiones
- Libera los bloqueos de recursos

**¿Qué sucede con los cambios sin COMMIT?**
- Son temporales y específicos de la sesión
- Se pierden al finalizar la conexión
- No son visibles para otros usuarios

**¿Cómo maneja PostgreSQL los errores?**
- Rollback automático ante violaciones de constraints
- Bloqueo de registros durante transacciones
- Mantenimiento de consistencia automática

## Conclusiones Finales

1. **Las transacciones son esenciales** para operaciones que requieren múltiples pasos
2. **PostgreSQL provee soporte ACID completo** de manera nativa
3. **El manejo adecuado de COMMIT/ROLLBACK** es crucial para la integridad de datos
4. **El aislamiento entre transacciones** es crucial para sistemas multi-usuario
5. **Las restricciones de integridad** son la primera línea de defensa para la consistencia de datos
