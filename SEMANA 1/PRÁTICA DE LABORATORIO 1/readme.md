# Práctica de Almacenamiento - Análisis Comparativo

### *Elaborado por Nicolle Lozano*

## Descripción General

Esta práctica compara el rendimiento de tres estructuras de almacenamiento en PostgreSQL: **HEAP** (montón), **ORDENADA** (con índice) y **HASH** (particionada). El objetivo es analizar cómo cada estructura afecta el rendimiento en operaciones de inserción, búsqueda exacta y consultas por rango, utilizando datos de estudiantes como caso de estudio.

## Objetivos de la Práctica

- **Comparar** el rendimiento de búsquedas exactas por ID en diferentes estructuras
- **Analizar** la eficiencia de consultas por rangos de valores
- **Evaluar** el impacto de las inserciones masivas en cada estructura
- **Medir** el consumo de espacio de cada enfoque de almacenamiento
- **Identificar** colisiones en implementaciones hash y sus efectos

## Estructuras Implementadas

1. **HEAP**: Estructura básica sin índices (escaneo secuencial)
2. **ORDENADA**: Tabla con índice B-tree para búsquedas rápidas  
3. **HASH**: Tabla particionada con función hash personalizada

## Métricas Analizadas

- Tiempo de respuesta en búsquedas
- Espacio en disco utilizado
- Distribución de datos en particiones
- Frecuencia de colisiones hash
- Rendimiento en inserciones masivas

Esta práctica permite entender las compensaciones entre diferentes estrategias de almacenamiento y cuándo conviene usar cada una según el tipo de operaciones requeridas.

## Ejecuciones Relevantes del Código

### 1. Búsqueda en Estructura HEAP
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM estudiantes_heap WHERE id_estudiante = 1077;
```
<img width="1012" height="328" alt="image" src="https://github.com/user-attachments/assets/38b5617b-07dd-4baa-966e-8a152e0b1f64" />

**Resultado:** Escaneo secuencial - Examina TODOS los registros (10 filas) porque no hay índices.

### 2. Búsqueda en Estructura ORDENADA
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM estudiantes_ordenados WHERE id_estudiante = 1077;
```
<img width="1050" height="400" alt="image" src="https://github.com/user-attachments/assets/771982e4-1b53-4033-bbed-c983009aa575" />

**Resultado:** Escaneo por índice - Solo examina 1 registro usando el índice creado.

### 3. Distribución Hash Manual
```sql
SELECT 
    hash_estudiante(id_estudiante) as posicion_hash,
    COUNT(*) as cantidad_registros,
    ARRAY_AGG(id_estudiante ORDER BY id_estudiante) as ids_en_posicion
FROM estudiantes
GROUP BY hash_estudiante(id_estudiante)
ORDER BY posicion_hash;
```
<img width="829" height="173" alt="image" src="https://github.com/user-attachments/assets/f05acbf6-d1dd-4d4b-8c04-e372fdfbf67f" />

**Resultado:** Se observan colisiones - múltiples IDs en la misma posición hash.

### 4. Distribución Particiones Hash
```sql
SELECT
    nspname as schemaname,
    relname as tablename,
    reltuples as registros_insertados
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE relname LIKE 'estudiantes_hash_%'
ORDER BY relname;
```
<img width="641" height="247" alt="image" src="https://github.com/user-attachments/assets/2f953961-0ed8-4e31-b931-5879a05dd51b" />

**Resultado:** Las particiones tienen distribución desigual de registros.

### 5. Espacio Utilizado
```sql
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as tamano
FROM pg_tables
WHERE tablename LIKE 'estudiantes_%'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;
```
<img width="551" height="361" alt="image" src="https://github.com/user-attachments/assets/68f50fd3-f82f-482b-bfdc-4fb999cfc5b9" />

**Resultado:** La tabla ordenada ocupa más espacio por el índice adicional.

---

## Preguntas de Análisis

### **Pregunta 1: ¿Qué estructura es más eficiente para búsquedas exactas por ID? ¿Por qué?**

**Respuesta:** La estructura HASH es la más eficiente para búsquedas exactas. Cuando ejecuté las consultas, noté que:

- **HEAP**: Hace un Sequential Scan (escaneo secuencial) de TODA la tabla
- **ORDENADA**: Hace un Index Scan usando el índice creado (más rápido que HEAP)
- **HASH**: Va directo a la partición correcta sin examinar registros innecesarios

En las pruebas con `EXPLAIN ANALYZE`, la búsqueda en HASH fue consistentemente más rápida porque PostgreSQL sabe exactamente en qué partición buscar, mientras que en las otras estructuras tiene que examinar más datos.

### **Pregunta 2: ¿Cuál sería la mejor estructura para consultas que buscan rangos de IDs? Justifique su respuesta.**

**Respuesta:** La estructura ORDENADA es mejor para rangos. Cuando ejecuté:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM estudiantes_ordenados 
WHERE id_estudiante BETWEEN 1030 AND 1080;
```
<img width="1370" height="364" alt="image" src="https://github.com/user-attachments/assets/d341b8d9-e79f-4500-92ce-8d47fea3ee61" />

El resultado mostró que el índice permite un escaneo eficiente de rangos. En cambio, con HASH, los registros están dispersos en diferentes particiones, lo que obliga a buscar en múltiples particiones y luego unir los resultados, haciendo las consultas de rango más lentas.

### **Pregunta 3: Si el sistema requiere insertar 1000 registros por minuto, ¿qué estructura recomendaría? ¿Por qué?**

**Respuesta:** Recomendaría la estructura HEAP porque:

1. **Sin overhead de estructuras adicionales**
     - A diferencia de ORDENADO, no requiere mantener ni actualizar índices durante las inserciones
     - A diferencia de HASH, no tiene el overhead de calcular distribuciones hash y gestionar múltiples particiones
2. **Inserciones más rápidas**
     - Las operaciones de inserción en HEAP son siempre O(1) ya que simplemente añaden nuevos registros al final de la tabla, sin necesidad de reordenar datos o actualizar estructuras auxiliares.
  
### **Pregunta 4: Analice las colisiones en la tabla hash. ¿Cómo afectan al rendimiento? ¿Qué estrategias propondría para reducirlas?**

**Respuesta:** En [3.Distribución Hash Manual](#3.-Distribución-Hash-Manual) encontré que algunas posiciones hash tenían múltiples registros (colisiones). Esto afecta el rendimiento porque:
1. **Más registros por bucket**: Mayor tiempo de búsqueda dentro de la misma partición
2. **Desbalance**: Algunas particiones tienen más carga que otras

**Estrategias para reducir colisiones:**
- **Hash dinámico con redistribución**: Implementar un sistema que cuando una partición tenga demasiados registros, automáticamente crea más particiones y redistribuye los datos.
- **Usar particionamiento por rango-hash**: Primero divide los datos por rangos y luego aplica hash dentro de cada rango. Es como tener "cajones dentro de cajones".
- **Monitoreo continuo**: Implementar alertas que avisen cuando una partición tenga más del 20% de los registros totales, indicando necesidad de rebalanceo

### **Pregunta 5: Compare el espacio utilizado por cada estructura. ¿Hay diferencias significativas? ¿A qué se deben?**

**Respuesta:** Sí hay diferencias significativas:

1. **HEAP**: Ocupa menos espacio (solo los datos)
2. **ORDENADA**: Ocupa más espacio (datos + índice)
3. **HASH**: Ocupa espacio intermedio (datos + overhead de particiones)

La diferencia se debe a:
- **Índices**: La tabla ordenada tiene un índice adicional que consume espacio
- **Metadatos**: Las particiones hash tienen metadatos adicionales de gestión
- **Fragmentación**: Las estructuras más complejas tienden a tener más overhead
