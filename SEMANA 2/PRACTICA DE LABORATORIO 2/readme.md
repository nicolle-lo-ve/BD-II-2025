# Práctica de Indexación para ficheros - Análisis Comparativo

### *Elaborado por Nicolle Lozano*

---

## Descripción General

Esta práctica analiza el impacto real de los índices en PostgreSQL. A través de tres ejercicios, se experimenta directamente cómo los índices mejoran el rendimiento de las consultas, comparando diferentes estrategias de indexación. 

## Objetivos de la Práctica

- Analizar el rendimiento de consultas sin índices aplicados
- Evaluar la mejora de rendimiento al implementar índices B-tree
- Comparar la eficiencia entre índices B-tree e índices Hash
- Medir el impacto de los índices en el consumo de espacio en disco
- Identificar los mejores casos de uso para cada tipo de índice

## Estructuras Implementadas

1. **Sin Índices**: Tablas base sin estructuras de optimización
2. **Índices B-tree**: Implementación estándar para búsquedas por igualdad y rangos
3. **Índices Hash**: Optimizados para búsquedas exactas por igualdad



## Ejecuciones Relevantes del Código

### 1. Consulta Sin Índices - Join entre Tablas

```sql
EXPLAIN ANALYZE
SELECT e.nombre, COUNT(*) as total_ventas
FROM empleados e
JOIN ventas v ON e.id = v.empleado_id
WHERE v.fecha_venta >= '2023-06-01'
GROUP BY e.id, e.nombre
ORDER BY total_ventas DESC
LIMIT 10;
```
<img width="1040" height="687" alt="image" src="https://github.com/user-attachments/assets/be9f2f04-86f6-4411-a2e2-877e58bd492d" />

**Resultado:** Esta consulta fue la más lenta sin índices. PostgreSQL tuvo que:
  - Hacer Sequential Scan de TODAS las 100,000 ventas
  - Filtrar manualmente por fecha (descartó 41,017 registros)
  - Hacer Sequential Scan de los 1,000 empleados
  - Realizar un Hash Join para unir las tablas
  - Agrupar, ordenar y limitar los resultados

### 2. Consulta Con Índice B-tree - Join entre Tablas

```sql
EXPLAIN ANALYZE
SELECT e.nombre, COUNT(*) as total_ventas
FROM empleados e
JOIN ventas v ON e.id = v.empleado_id
WHERE v.fecha_venta >= '2023-06-01'
GROUP BY e.id, e.nombre
ORDER BY total_ventas DESC
LIMIT 10;
```
<img width="1387" height="688" alt="image" src="https://github.com/user-attachments/assets/6c41ecaf-cd42-4da5-aec3-bf6d073a95fb" />

**Resultado:** Después de crear los índices, el mismo JOIN mostró una mejora evidente:
  - PostgreSQL usó Index Scan en lugar de Sequential Scan
  - El filtro por fecha fue mucho más eficiente usando el índice de fecha
  - La unión con empleados fue más rápida usando el índice de empleado_id
  - El tiempo de ejecución se redujo aproximadamente

### 3. Comparación B-tree vs Hash

```sql
-- Con índice B-tree
EXPLAIN ANALYZE SELECT * FROM empleados WHERE departamento = 'Ventas';
```
<img width="1297" height="362" alt="image" src="https://github.com/user-attachments/assets/49f26a93-fd74-43c6-887e-842d58e628e9" />

```sql
-- Con índice Hash
CREATE INDEX idx_empleados_dept_hash ON empleados USING HASH(departamento);
EXPLAIN ANALYZE SELECT * FROM empleados WHERE departamento = 'Ventas';
```
<img width="1219" height="361" alt="image" src="https://github.com/user-attachments/assets/8af9e414-511a-4787-810c-2afe0171fe8d" />

**Resultado:** Ambos índices mostraban rendimiento similar para búsquedas exactas, aunque el índice Hash tenía una ligera ventaja en algunos casos. 

### 4. Análisis de Espacio Utilizado por Índices

```sql
SELECT
    schemaname,
    relname as tablename,
    indexrelname as indexname,
    pg_size_pretty(pg_total_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_total_relation_size(indexrelid) DESC;
```
<img width="761" height="440" alt="image" src="https://github.com/user-attachments/assets/ebe4cfb0-22d5-4ef4-97a8-cfc5aee7098f" />

**Resultado:** Los índices ocupan espacio adicional en disco, pero personalmente, el costo vale la pena por la mejora en rendimiento. Los índices compuestos fueron los que más espacio consumieron.

---
## Resultados y Análisis

### Registro de Resultados - Ejercicio 1 (Sin Índices)

| Consulta | Tiempo (ms) | Filas Analizadas | Costo Total |
|----------|-------------|------------------|-------------|
| Búsqueda por ID | 0.031 | 1 | 8.29 |
| Búsqueda por departamento | 0.233 | 200 | 23.50 |
| Rango de salarios | 0.393 | 205 | 26.00 |
| JOIN con agregación |69.085| 100,000 | 3896.18 |

### Registro de Resultados - Ejercicio 2 (Con Índices)

| Consulta | Tiempo Sin Índice | Tiempo Con Índice | Mejora (%) |
|----------|-------------------|-------------------|------------|
| Búsqueda por ID | 0.031 | 0.038 | -22.58% |
| Búsqueda por departamento | 0.233 | 0.141 | 39.48% |
| Rango de salarios | 0.393 | 0.158 | 59.80% |
| JOIN con agregación | 69.085 | 42.739 | 38.14% |

### Observaciones 
- *En Búsqueda por ID empeoró ligeramente. Esto es normal porque el ID ya tiene índice automático (PRIMARY KEY), y añadir más índices a veces puede crear overhead.*
---

## Conclusiones Finales

- Los índices B-tree son los más versátiles y deberían ser la primera opción en la mayoría de casos
- Los índices Hash son especializados y solo útiles para casos muy específicos
- El espacio adicional consumido por los índices generalmente se justifica por la mejora de rendimiento
- Es importante elegir sabiamente qué columnas indexar basándose en los patrones de consulta


## Dificultades Encontradas

Tuve algunos problemas iniciales con la inserción de datos porque generaba IDs de empleados fuera de rango, pero luego de ajustar la función FLOOR(RANDOM() * 1000) + 1, funcionó correctamente. 

