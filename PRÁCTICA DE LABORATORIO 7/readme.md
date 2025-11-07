# Laboratorio 7: Técnicas de Recuperación de Bases de Datos

## Descripción del Proyecto
Este laboratorio práctico explora las técnicas de recuperación de bases de datos PostgreSQL, incluyendo configuración WAL, transacciones ACID, checkpoints, simulación de fallos y estrategias de backup/restore.

## Objetivos del Laboratorio
- Comprender el funcionamiento del Write-Ahead Log (WAL)
- Analizar el comportamiento de transacciones y rollbacks
- Implementar y medir checkpoints
- Simular diferentes tipos de fallos del sistema
- Practicar técnicas de backup y restauración

## Estructura de la Base de Datos
Las tablas creadas para el laboratorio son:
- `cuentas_bancarias` (8 cuentas de prueba)
- `transacciones` (registro de operaciones financieras)
- `auditoria_sistema` (log de operaciones del sistema)
- `configuracion_sistema` (parámetros críticos del sistema)
- `metricas_rendimiento` (mediciones de performance)

## Análisis de Resultados

### Parte 1: Configuración Inicial y WAL

#### **Configuración WAL Inicial**
```sql
SHOW wal_level;
SHOW fsync;
SHOW synchronous_commit;
SHOW wal_buffers;
SHOW checkpoint_timeout;
SHOW max_wal_size;
SHOW min_wal_size;
```

- imagen

**Parámetros WAL y su significado:**

- **wal_level**: Determina cuánta información se escribe en el WAL (minimal, replica, logical)
- **fsync**: Garantiza que las operaciones se escriban físicamente en disco
- **synchronous_commit**: Controla cuándo el servidor reporta éxito en una transacción
- **wal_buffers**: Memoria dedicada para buffers WAL antes de escribirse a disco
- **checkpoint_timeout**: Tiempo máximo entre checkpoints automáticos
- **max_wal_size**: Tamaño máximo que puede crecer el WAL
- **min_wal_size**: Tamaño mínimo reservado para archivos WAL

---

### Parte 2: Transacciones y Comportamiento del Log

#### **Ejercicio 2.1: Transacción Exitosa Simple**
```sql
BEGIN;
-- Operaciones de transferencia...
COMMIT;
SELECT pg_current_wal_lsn();
```

- imagen
  
**Resultados:**
**¿Qué observa en los saldos antes y después del COMMIT? ¿Cambió el LSN?**
- Los saldos solo se hacen permanentes después del COMMIT
- El LSN (Log Sequence Number) incrementa después de cada transacción commitada
- Las operaciones se registran en WAL antes de confirmarse

---

#### **Ejercicio 2.3: Transacción Abortada**
```sql
BEGIN;
-- Operaciones...
ROLLBACK;
```

- imagen
  
**Resultados:**
**¿Los cambios persisten después del ROLLBACK? ¿Se registró la operación en la tabla de auditoría? ¿Por qué?**
- **NO** persisten los cambios después del ROLLBACK
- **SÍ** se registró en auditoría porque el INSERT se ejecutó inmediatamente
- PostgreSQL usa WAL para deshacer cambios no commitados durante recovery

---

#### **Ejercicio 2.4: Violación de Restricción**
```sql
BEGIN;
UPDATE cuentas_bancarias SET saldo = saldo - 10000.00 WHERE numero_cuenta = 'CTA-007';
COMMIT;
```

- imagen
  
**Resultados:**
**¿Qué error obtiene? ¿La transacción se completó? ¿Qué mecanismo de recuperación actuó aquí?**
- Error: `ERROR: new row for relation "cuentas_bancarias" violates check constraint`
- La transacción **NO** se completó - se abortó automáticamente
- Mecanismo: **Atomicidad** de transacciones ACID + constraints CHECK

---

#### **Ejercicio 2.7: Procedimiento Almacenado**
```sql
SELECT transferir_fondos('CTA-003', 'CTA-004', 50000.00);
```

- imagen
  
**Resultados:**
**¿Qué sucede cuando intenta la transferencia con saldo insuficiente? ¿Se aplicó algún cambio parcial?**
- Se genera excepción: `RAISE EXCEPTION 'Saldo insuficiente'`
- **NO** se aplican cambios parciales - toda la función se revierte
- Demostración de atomicidad a nivel de procedimiento almacenado

---

### Parte 3: Checkpoint y Análisis de Rendimiento

#### **Ejercicio 3.2: Medición Antes Checkpoint**
```sql
DO $$ 
-- Insertar 1000 transacciones
END $$;
```

- imagen
  
**Resultados:**
**¿Cuánto tiempo tomó insertar 1000 registros?**
- **Tiempo medido**: [Valor específico depende de hardware]
- Se almacena en tabla `metricas_rendimiento` para comparación

---

#### **Ejercicio 3.4: Estadísticas de Checkpoint**
```sql
SELECT * FROM pg_stat_bgwriter;
```

- imagen
  
**Resultados:**
**Checkpoints por tiempo vs Checkpoints solicitados:**
- **checkpoints_timed**: Checkpoints iniciados por timeout
- **checkpoints_req**: Checkpoints forzados por necesidad (WAL lleno)
- **Buffers escritos**: Cantidad de buffers de datos escritos durante checkpoint

---

#### **Ejercicio 3.5: Comparación Post-Checkpoint**
```sql
SELECT operacion, duracion_ms FROM metricas_rendimiento ORDER BY id;
```

- imagen
  
**Resultados:**
**Compare los tiempos antes y después del checkpoint. ¿Nota alguna diferencia? ¿Por qué?**
- Generalmente **más rápido después del checkpoint** porque:
  - Menos datos sucios (dirty buffers) en memoria
  - WAL más compacto y organizado
  - Menos operaciones de flush a disco necesarias

---

#### **Ejercicio 3.6: Transacciones Concurrentes**
```sql
-- Sesión 1, 2, 3 ejecutando simultáneamente
```

- imagen
  
**Resultados:**
**¿En qué orden se confirmaron las transacciones? ¿Qué implicaciones tiene esto para la recuperación?**
- Orden de COMMIT determina el orden en WAL
- Durante recovery, las transacciones se reaplican en orden cronológico
- Garantiza consistencia incluso con ejecución concurrente

---

#### **Ejercicio 3.7: Archivos WAL**
```bash
ls -lh [ruta_data_directory]/pg_wal/
```

- imagen
  
**Resultados:**
**¿Cuántos archivos WAL observa? ¿Cuál es el tamaño total del directorio WAL?**
- Normalmente 16-64 archivos de 16MB cada uno
- Tamaño total controlado por `max_wal_size`
- Archivos rotan circularmente

---

### Parte 4: Simulación de Fallos

#### **Ejercicio 4.2-4.7: Fallo Tipo 1 - Crash del Sistema**
```bash
sudo systemctl stop postgresql  # Simulación crash
sudo systemctl start postgresql # Recuperación
```

- imagen
  
**Resultados:**
**¿Qué mensajes específicos observa durante el proceso de recuperación?**
- "database system was interrupted" - Indica shutdown inesperado
- "redo starts at X/Y" - Inicio de recuperación desde LSN específico
- "redo done at X/Y" - Finalización de recuperación
- "database system is ready" - Sistema listo para operar

**¿Se mantuvieron las transacciones confirmadas? ¿Los valores coinciden?**
- **SÍ** todas las transacciones COMMITadas antes del crash se mantienen
- **SÍ** los valores coinciden exactamente con el estado pre-crash
- **NO** se pierde ninguna operación confirmada

---

#### **Ejercicio 4.8: Fallo Tipo 2 - Transacción Interrumpida**
```sql
-- Transacción iniciada pero no commitada antes del crash
```

- imagen
  
**Resultados:**
**¿La operación interrumpida se registró en auditoría? ¿Los saldos cambiaron? Explique por qué.**
- **NO** se registró en auditoría (no hubo COMMIT)
- **NO** cambiaron los saldos (ROLLBACK automático)
- **Porque**: WAL garantiza atomicidad - o toda la transacción o nada

---

### Parte 5: Análisis de Archivos WAL

#### **Ejercicio 5.2: pg_waldump**
```bash
pg_waldump [archivo_wal] | head -100
```

- imagen
  
**Resultados:**
**Identifique en la salida de pg_waldump:**
- **Registros INSERT**: [Cantidad específica dependiente de carga]
- **Registros UPDATE**: [Cantidad específica dependiente de carga]  
- **Registros COMMIT**: [Cantidad específica dependiente de carga]
- Cada transacción genera múltiples registros WAL

---

#### **Ejercicio 5.3: Generación de Carga WAL**
```sql
SELECT * FROM generar_carga_wal(1000);
```

- imagen
  
**Resultados:**
**¿Cuántos bytes de WAL se generaron con cada carga? Compare los resultados.**
- **100 inserciones**: ~[X] MB
- **500 inserciones**: ~[Y] MB  
- **1000 inserciones**: ~[Z] MB
- Relación aproximadamente lineal entre operaciones y tamaño WAL

---

### Parte 6: Backups y Restauración

#### **Ejercicio 6.1: Backup con pg_basebackup**
```bash
pg_basebackup -D ~/backups_lab/backup_completo -Ft -z -P -U postgres
```

- imagen
  
**Resultados:**
**¿Cuánto tiempo tomó realizar el backup? ¿Qué tamaño tiene?**
- **Tiempo**: Depende del tamaño de la base de datos
- **Tamaño**: Comprimido significativamente menor que datos originales
- Incluye todos los archivos de datos + WAL necesario para consistencia

---

#### **Ejercicio 6.3-6.5: Restauración Completa**
```bash
# Eliminar BD original y restaurar desde backup
```

- imagen 

**Resultados:**
**¿Las operaciones realizadas después del backup están presentes? ¿Por qué?**
- **NO** están presentes las operaciones POST_BACKUP
- **Porque**: pg_basebackup captura estado consistente en momento del backup
- Para recuperar datos posteriores se necesitaría WAL continuo (PITR)

---

## Principales Lecciones Aprendidas

### **WAL es Fundamental para Recuperación**
- Garantiza durabilidad de transacciones COMMITadas
- Permite recuperación automática después de fallos
- Registra todas las modificaciones antes de aplicarlas a datos

### **Transacciones ACID en Acción**
- **Atomicidad**: Todo o nada - demostrado con ROLLBACK y excepciones
- **Consistencia**: Constraints mantienen integridad incluso en fallos
- **Aislamiento**: Transacciones concurrentes no se interfieren
- **Durabilidad**: Transacciones confirmadas sobreviven a crashes

### **Checkpoints Optimizan Rendimiento**
- Reducen tiempo de recuperación limitando WAL a procesar
- Mejoran performance agrupando escrituras a disco
- Balance entre frecuencia y overhead

### **Backups + WAL = Recuperación Completa**
- Backup base proporciona punto de partida consistente
- WAL permite recuperar hasta el último COMMIT antes del fallo
- Estrategia combinada garantiza máxima disponibilidad

## Métricas de Rendimiento y Recuperación

| Operación | Tiempo/Eficiencia | Observaciones |
|-----------|-------------------|---------------|
| 1000 inserciones antes checkpoint | [X] ms | Mayor overhead por buffers sucios |
| 1000 inserciones después checkpoint | [Y] ms | Mejor performance post-limpieza |
| Tiempo recuperación crash | [Z] segundos | Depende de cantidad de WAL pendiente |
| Tamaño backup completo | [T] MB | Comprimido y eficiente |
| Transacciones recuperadas post-crash | 100% | Zero pérdida de datos commitados |

## Conclusión
Este laboratorio demuestra la robustez de PostgreSQL en escenarios de fallo y la efectividad de las técnicas de recuperación basadas en WAL. La combinación de transacciones ACID, checkpoints estratégicos y backups regulares garantiza la integridad y disponibilidad de los datos incluso en situaciones críticas.
