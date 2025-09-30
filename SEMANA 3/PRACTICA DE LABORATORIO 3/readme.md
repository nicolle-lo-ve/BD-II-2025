# Laboratorio de Optimización de Consultas PostgreSQL

## Descripción del Proyecto
Este repositorio contiene un laboratorio práctico de optimización de consultas en PostgreSQL, donde se analizan diferentes técnicas de mejora de rendimiento, índices, algoritmos de join y reescritura de consultas.

## Objetivos del Laboratorio
- Analizar planes de ejecución de consultas
- Implementar y comparar diferentes tipos de índices
- Evaluar algoritmos de JOIN
- Optimizar consultas mediante reescritura
- Comprender el impacto de las estadísticas en el optimizador

## Estructura de la Base de Datos
Las tablas creadas para el laboratorio son:
- `clientes` (10,000 registros)
- `productos` (1,000 registros) 
- `pedidos` (50,000 registros)
- `detalle_pedidos` (150,000 registros)

## Análisis de Resultados

### Parte 2: Análisis de Planes de Ejecución

#### **Ejercicio 2.1: Consulta Básica sin Optimización**
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre
ORDER BY total_pedidos DESC;
```
<img width="1303" height="623" alt="Captura de pantalla 2025-09-29 214653" src="https://github.com/user-attachments/assets/b748214d-1293-4029-b021-0ae0eb67e0d5" />
<img width="1305" height="336" alt="Captura de pantalla 2025-09-29 214723" src="https://github.com/user-attachments/assets/41d4e100-ddda-4d50-a545-b0543b89d292" />

**Resultados:**
**¿Tiempo total de ejecución?**
- **29.798 ms** - Este tiempo incluye tanto el planning (0.729 ms) como la ejecución (29.069 ms)

**¿Qué algoritmo de JOIN se está usando?**
- **Hash Right Join** - PostgreSQL eligió este algoritmo porque:
  - Necesita unir todas las filas de `pedidos` con los clientes filtrados de Lima
  - La tabla `pedidos` es más grande (50,000 registros) y no está filtrada
  - Hash Join es eficiente para uniones por igualdad cuando una tabla cabe en memoria

**¿Cuántas filas se están procesando?**
- **10,000 filas en el JOIN** (100,000 operaciones reales considerando loops):
  - 2,000 filas de clientes de Lima (20% del total)
  - 50,000 filas de pedidos
  - Relación 1:5 entre clientes de Lima y sus pedidos

---

#### **Ejercicio 2.2: Análisis del Plan de Ejecución**
<img width="1863" height="517" alt="Captura de pantalla 2025-09-29 215919" src="https://github.com/user-attachments/assets/bd516ebb-5878-4308-b848-9ad1a5d1ea16" />
<img width="1454" height="507" alt="Captura de pantalla 2025-09-29 220320" src="https://github.com/user-attachments/assets/94ceeece-478c-4633-91aa-77bf020bdb4e" />
<img width="1452" height="719" alt="Captura de pantalla 2025-09-29 220415" src="https://github.com/user-attachments/assets/09cf1c38-e350-4596-905b-e57ff4987684" />

**Resultados:**
**Interpretación de cada nodo del plan:**

1. **Sort** (costo: 1422.96-1437.96)
   - Ordena los resultados por `total_pedidos DESC`
   - Usa quicksort en memoria (158kB)

2. **HashAggregate** (costo: 1303.31-1323.31)
   - Agrupa por `cliente_id` y calcula `COUNT(p.pedido_id)`
   - Procesa 10,000 filas para generar 2,000 grupos

3. **Hash Right Join** (costo: 254.00-1253.31)
   - Construye tabla hash con `clientes` y prueba `pedidos`
   - Condición: `p.cliente_id = c.cliente_id`

4. **Seq Scan on pedidos** (costo: 0.00-868.00)
   - Escaneo secuencial completo de 50,000 registros

5. **Seq Scan on clientes** (costo: 0.00-229.00)
   - Escaneo secuencial con filtro `ciudad = 'Lima'`
   - Descarta 8,000 de 10,000 registros

**Identificación de costos estimados:**
- **Costo total estimado**: 1437.96 unidades de costo
- **Operación más costosa**: Hash Right Join (1253.31)
- **Operación menos costosa**: Seq Scan on clientes (229.00)

**¿Qué operaciones son más costosas?**
1. **Hash Right Join** (87% del costo total)
2. **Sort** (1% del costo total pero crítico para respuesta ordenada)
3. **Seq Scan on pedidos** (60% del costo del join).

---

### Parte 3: Optimización con Índices

#### **Ejercicio 3.1: Comparación con Índices**
**Después de crear índices:**
```sql
CREATE INDEX idx_clientes_ciudad ON clientes(ciudad);
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido);
CREATE INDEX idx_pedidos_cliente_fecha ON pedidos(cliente_id, fecha_pedido);
```
<img width="1354" height="776" alt="Captura de pantalla 2025-09-29 220953" src="https://github.com/user-attachments/assets/2137beae-495f-4e8d-87cc-372995340faa" />
<img width="1353" height="492" alt="Captura de pantalla 2025-09-29 221015" src="https://github.com/user-attachments/assets/43950763-d8c8-4b9a-bcf1-bb3747f3b3d6" />

**Resultados:**
**Comparación de tiempos:**
- **Sin índices**: 29.798 ms
- **Con índices**: 26.675 ms
- **Mejora**: 3.123 ms (10.5% de mejora)

**¿Cambió el algoritmo de JOIN?**
- **No**, se mantuvo **Hash Right Join** porque:
  - La naturaleza de la consulta (LEFT JOIN) favorece este algoritmo
  - La distribución de datos no cambió significativamente
  - El optimizador determinó que sigue siendo la opción más eficiente

**¿Se está usando Index Scan o Sequential Scan?**
- **Clientes**: Cambió de Seq Scan a **Bitmap Heap Scan** + **Bitmap Index Scan**
- **Pedidos**: Se mantuvo **Seq Scan** porque:
  - No hay filtros en la tabla pedidos para esta consulta
  - El índice `idx_pedidos_cliente_fecha` no es útil sin filtrar por fecha

**Análisis detallado del cambio:**
```sql
-- Antes: Seq Scan on clientes
Seq Scan on clientes c (cost=0.00..229.00 rows=2000 width=16)

-- Después: Bitmap Heap Scan + Bitmap Index Scan
Bitmap Heap Scan on clientes c (cost=27.79..156.78 rows=2000 width=16)
Bitmap Index Scan on idx_clientes_ciudad (cost=0.00..27.29 rows=2000 width=0)
```

---

#### **Ejercicio 3.2: Índices Parciales**
```sql
CREATE INDEX idx_clientes_lima_activos ON clientes(cliente_id) 
WHERE ciudad = 'Lima' AND activo = true;
```
<img width="1313" height="418" alt="Captura de pantalla 2025-09-29 221258" src="https://github.com/user-attachments/assets/2355df02-f326-4c6c-9766-ca0de26280c0" />

**Resultados:**
**¿Cuándo es útil un índice parcial?**
Un índice parcial es útil cuando:
1. **Consultas frecuentes con filtros específicos**: Como `ciudad = 'Lima' AND activo = true`
2. **Reducción de tamaño del índice**: Solo indexa un subconjunto de datos
3. **Mejora de mantenimiento**: Menor overhead en operaciones DML
4. **Casos con alta selectividad**: Cuando el filtro selecciona < 10-20% de la tabla

**Comparación de tamaño índice parcial vs. completo:**
- **Índice completo** (`idx_clientes_ciudad`): Indexa 10,000 registros
- **Índice parcial** (`idx_clientes_lima_activos`): Indexa aproximadamente 1,400 registros (14% del total)
- **Reducción estimada**: 86% en tamaño del índice

**Evidencia de eficiencia:**
```sql
-- Con índice parcial: 0.796 ms, Index Scan
Index Scan using idx_clientes_lima_activos on clientes c 
(cost=0.28..69.78 rows=1800 width=33)

-- Sin índice parcial: ~2-3 ms (estimado) con Sequential Scan + filtros
```

---

### Parte 4: Algoritmos de JOIN

#### **Ejercicio 4.1: Comparación de Algoritmos**
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre, p.total, pr.nombre_producto
FROM clientes c
JOIN pedidos p ON c.cliente_id = p.cliente_id
JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
JOIN productos pr ON dp.producto_id = pr.producto_id
WHERE c.ciudad ='Lima'
AND p.fecha_pedido >= '2025-01-01';
```
*Primera ejecución*
<img width="1396" height="622" alt="Captura de pantalla 2025-09-29 221526" src="https://github.com/user-attachments/assets/d14b5584-f9ef-4787-84cf-afb2f9c3f692" />
<img width="1396" height="616" alt="Captura de pantalla 2025-09-29 221605" src="https://github.com/user-attachments/assets/dfeef4d5-fda0-4810-8f19-771ea1270292" />
<img width="1395" height="376" alt="Captura de pantalla 2025-09-29 221656" src="https://github.com/user-attachments/assets/afac011d-0f5a-4240-aa90-1d8163541335" />

*Segunda ejecución*
<img width="1349" height="625" alt="Captura de pantalla 2025-09-29 221848" src="https://github.com/user-attachments/assets/46c34fff-08a2-4bea-9efb-92f166e956e6" />
<img width="1346" height="624" alt="Captura de pantalla 2025-09-29 221922" src="https://github.com/user-attachments/assets/11883af5-18c8-463e-87ab-e79d2762c644" />
<img width="1343" height="265" alt="Captura de pantalla 2025-09-29 222003" src="https://github.com/user-attachments/assets/ec81be9b-3961-410f-bf97-3b4d60f38f4f" />

**Resultados:**
**Comparación de tiempos:**
- **Nested Loop + Merge Join**: 236.272 ms
- **Hash Join**: 101.322 ms
- **Mejora con Hash Join**: 134.95 ms (57% más rápido)

**¿Cuál es más eficiente para esta consulta?**
- **Hash Join es significativamente más eficiente** porque:
  - Maneja mejor los grandes volúmenes de datos (150,000 filas en detalle_pedidos)
  - Evita operaciones de ordenamiento costosas
  - Minimiza el uso de almacenamiento temporal

**¿Por qué el optimizador elige un algoritmo específico?**
El optimizador elige basado en:

1. **Estadísticas de tablas**:
   - Tamaño estimado de cada tabla
   - Selectividad de los filtros
   - Cardinalidad de las uniones

2. **Características de la consulta**:
   - **Hash Join**: Ideal para uniones por igualdad con tablas grandes
   - **Nested Loop**: Mejor para tablas pequeñas o con índices muy selectivos
   - **Merge Join**: Óptimo cuando los datos ya están ordenados

3. **Recursos disponibles**:
   - Memoria para tablas hash
   - Espacio temporal para ordenamientos
   - Configuración de work_mem

**Evidencia en los planes:**
```sql
-- Hash Join: Menor uso de disco y memoria
Hash Join (cost=1462.59..4860.17 rows=30000 width=30)

-- Nested Loop + Merge: Mayor uso de temporal
Sort Method: external merge Disk: 2648kB
```

---


### Parte 5: Optimización Basada en Estadísticas
### **Ejercicio 5.1: Impacto de ANALYZE**
```sql
-- Ver estadísticas actuales
SELECT
	schemaname,
	relname AS tablename,
	n_tup_ins,
	n_tup_upd,
	n_tup_del,
	last_vacuum,
	last_analyze
FROM pg_stat_user_tables;
```
*Primera ejecución*
<img width="1225" height="644" alt="Captura de pantalla 2025-09-29 222647" src="https://github.com/user-attachments/assets/1a716869-8e1c-4181-b928-ac6204842b86" />

*Segunda ejecución*
<img width="1295" height="532" alt="Captura de pantalla 2025-09-29 222805" src="https://github.com/user-attachments/assets/67ec1d05-e6b1-4646-b147-3908ad8d9265" />

**Resultados:**
**¿Cambió el plan después de ANALYZE?**
- **Sí, significativamente**:
  - **Antes**: Bitmap Heap Scan + Bitmap Index Scan
  - **Después**: **Index Only Scan** (mejora radical)

**Cambios específicos identificados:**
```sql
-- ANTES de ANALYZE:
Bitmap Heap Scan on clientes (cost=39.39..231.65 rows=2981 width=0)
Bitmap Index Scan on idx_clientes_ciudad (cost=0.00..38.64 rows=2981 width=0)

-- DESPUÉS de ANALYZE:
Index Only Scan using idx_clientes_ciudad on clientes 
(cost=0.29..154.78 rows=7000 width=0)
```

**Mejoras cuantificables:**
- **Costo reducido**: 239.10 → 172.28 (28% menos)
- **Tiempo reducido**: 1.943 ms → 1.416 ms (27% más rápido)
- **Operaciones I/O**: Buffers reducidos de 163 → 9

**¿Por qué son importantes las estadísticas actualizadas?**

1. **Estimación precisa de cardinalidad**:
   - Antes: Estimaba 2,981 filas para Lima
   - Después: Estimó correctamente 7,000 filas
   - Diferencia: 135% de subestimación

2. **Selección óptima de algoritmos**:
   - Con estadísticas viejas: Bitmap Heap Scan (más conservador)
   - Con estadísticas actualizadas: Index Only Scan (más agresivo)

3. **Mejor uso de índices**:
   - Index Only Scan es posible porque el optimizador sabe que el índice contiene todos los datos necesarios
   - Evita acceso a la tabla principal (Heap Fetches: 0)

4. **Impacto en memoria**:
   - Plan anterior usaba más buffers (163 vs 9)
   - Mejor estimación de memoria para operaciones
---

### Parte 6: Reescritura de Consultas

### **Ejercicio 6.1: EXISTS vs IN vs JOINs**
*Primera Ejecución - IN*
```sql
-- Versión con IN (potencialmente menos eficiente)
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre
FROM clientes c
WHERE c.cliente_id IN (
	SELECT p.cliente_id
	FROM pedidos p
	WHERE p.total > 500
	);
```
<img width="1121" height="784" alt="Captura de pantalla 2025-09-29 223013" src="https://github.com/user-attachments/assets/885255a3-7e89-415d-a46c-4a85be33c210" />

*Segunda Ejecución - EXISTS*
```sql
-- Versión con EXISTS (generalmente más eficiente)
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre
FROM clientes c
WHERE EXISTS (
	SELECT 1
	FROM pedidos p
	WHERE p.cliente_id = c.cliente_id
	AND p.total > 500
	);
```
<img width="1101" height="785" alt="Captura de pantalla 2025-09-29 223136" src="https://github.com/user-attachments/assets/793ad00f-90f1-411a-a86c-9cb0a12d526a" />

**Resultados:**
**¿Cuál versión es más eficiente?**

**IN vs EXISTS**:
- **Rendimiento similar**: 39.758 ms vs 24.409 ms
- **Mismo plan de ejecución**: Hash Semi Join en ambos casos
- **PostgreSQL optimiza automáticamente** ambas construcciones

**Subconsultas vs JOINs**:
- **Subconsulta correlacionada**: 32.523 ms
- **JOIN tradicional**: 39.371 ms
- **Ganancia con subconsulta**: 6.848 ms (21% más rápida)

**Análisis detallado:**

**¿Por qué la subconsulta fue más eficiente?**
```sql
-- Subconsulta: Ejecuta COUNT(*) por cada cliente de Lima
SubPlan 1 (para cada fila de clientes)
-> Aggregate (cost=4.39..4.40 rows=1 width=8)
   -> Index Only Scan using idx_pedidos_cliente_fecha on pedidos p

-- JOIN: Agregación global después del join
HashAggregate (cost=1532.48..1602.48 rows=7000 width=26)
-> Hash Right Join (cost=416.53..1415.82 rows=23333 width=22)
```

La subconsulta aprovecha mejor el índice `idx_pedidos_cliente_fecha` y evita una agregación global masiva.

**¿En qué casos prefieres subconsultas vs JOINs?**

**Usar SUBCONSULTAS cuando:**
- Consultas correlacionadas con agregaciones por fila
- Existen índices específicos para las subconsultas
- La tabla principal es pequeña pero las relaciones son grandes
- Necesitas valores calculados por cada fila individual

**Usar JOINs cuando:**
- Agregaciones globales sobre múltiples tablas
- Necesitas datos de múltiples tablas simultáneamente
- Las tablas tienen tamaños similares
- Consultas complejas con múltiples condiciones

---

### Parte 7: Consultas Complejas
### **Ejercicio 7.1: Análisis de Consulta Compleja**
```sql
-- Paso 7.1: Consulta de análisis de ventas
-- Análisis complejo: Top productos por ciudad y mes
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_mensuales AS (
	SELECT 
		c.ciudad,
		pr.nombre_producto,
		DATE_TRUNC('month', p.fecha_pedido) as mes,
		SUM(dp.cantidad * dp.precio_unitario) as total_ventas,
		COUNT(DISTINCT c.cliente_id) as clientes_unicos
	FROM clientes c
	JOIN pedidos p ON c.cliente_id = p.cliente_id
	JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
	JOIN productos pr ON dp.producto_id = pr.producto_id
	WHERE p.fecha_pedido >= '2024-01-01'
	AND p.estado = 'Completado'
	GROUP BY c.ciudad, pr.nombre_producto, DATE_TRUNC('month', p.fecha_pedido)
	),
	ranking_productos AS (
		SELECT *,
			ROW_NUMBER() OVER (
				PARTITION BY ciudad, mes
				ORDER BY total_ventas DESC
			) as rank_ventas
		FROM ventas_mensuales
	)
SELECT *
FROM ranking_productos 
WHERE rank_ventas <= 3
ORDER BY ciudad, mes, rank_ventas;
```
<img width="1439" height="623" alt="Captura de pantalla 2025-09-29 224032" src="https://github.com/user-attachments/assets/2fbef956-f223-4c32-9cf1-452c3d7787de" />
<img width="1438" height="625" alt="Captura de pantalla 2025-09-29 224058" src="https://github.com/user-attachments/assets/10040c76-1c06-43bf-911d-2705fef3e18b" />
<img width="1438" height="622" alt="Captura de pantalla 2025-09-29 224120" src="https://github.com/user-attachments/assets/2ba36a82-4443-4cfb-ad4c-9d480eb040b8" />
<img width="1440" height="414" alt="Captura de pantalla 2025-09-29 224142" src="https://github.com/user-attachments/assets/180ebdd8-2b16-4314-a72a-502e4eeb8822" />



**Análisis de cada paso del plan de ejecución:**

1. **Incremental Sort** (599.023 ms)
   - Ordena resultados para la función window ROW_NUMBER()
   - Claves: ciudad, mes, total_ventas DESC

2. **WindowAgg** (598.817 ms)
   - Calcula ROW_NUMBER() OVER (PARTITION BY ciudad, mes)
   - Aplica filtro WHERE rank_ventas <= 3

3. **GroupAggregate** (593.638 ms)
   - Agrupa por ciudad, producto, mes
   - Calcula SUM() y COUNT(DISTINCT)

4. **Sort** (553.457 ms)
   - Pre-ordenamiento para la agregación
   - Usa 3,660kB de memoria

5. **Hash Join** (181.747 ms)
   - Múltiples joins entre las 4 tablas

**¿Qué operaciones consumen más tiempo?**
1. **Operaciones de ordenamiento** (Sort + Incremental Sort): ~80% del tiempo
2. **Agregaciones** (GroupAggregate): ~15% del tiempo  
3. **Joins** (Hash Join): ~5% del tiempo

**¿Qué índices adicionales podrían ayudar?**

```sql
-- 1. Para mejorar el WHERE en pedidos
CREATE INDEX idx_pedidos_fecha_estado ON pedidos(fecha_pedido, estado);
-- Impacto: Filtra de 50,000 a 12,500 registros inmediatamente

-- 2. Para el ordenamiento final
CREATE INDEX idx_ventas_ciudad_mes_ventas ON (
    ciudad, DATE_TRUNC('month', fecha_pedido), total_ventas DESC
);
-- Impacto: Elimina necesidad de Incremental Sort

-- RESULTADO CON ÍNDICES: 533.961 ms (11% mejora)
```

**Análisis de la mejora con índices:**
- **Tiempo original**: 599.023 ms
- **Con índices**: 533.961 ms  
- **Reducción**: 65.062 ms (11% de mejora)
- **Límite de mejora**: Las operaciones de agregación y window functions siguen siendo costosas

**Recomendación adicional**:

- *Para mejoras adicionales, considerar particionamiento por mes en la tabla pedidos*
---

## Principales Lecciones Aprendidas
- Índices en columnas de filtro frecuente mejoran rendimiento
- Índices compuestos optimizan consultas con múltiples condiciones
- Índices parciales reducen tamaño y mejoran consultas específicas

### **PostgreSQL elige bien los algoritmos de JOIN**
- Hash Join generalmente más eficiente para grandes volúmenes
- El optimizador rara vez necesita intervención manual
- Forzar algoritmos específicos puede degradar rendimiento

## Métricas de Rendimiento

| Optimización | Tiempo Antes | Tiempo Después | Mejora |
|-------------|-------------|----------------|--------|
| Índices básicos | 29.798 ms | 26.675 ms | 10% |
| Estadísticas actualizadas | 1.943 ms | 1.416 ms | 27% |
| Hash Join vs Nested Loop | 236.272 ms | 101.322 ms | 57% |
| Índices para consulta compleja | 599.023 ms | 533.961 ms | 11% |
