# Laboratorio: Diseño Físico y Particionamiento en PostgreSQL

**Elaborado por:** Nicolle Lozano  

## Descripción General
Esta práctica analiza el impacto del particionamiento de tablas en PostgreSQL, comparando el rendimiento entre tablas sin particionar, con particionamiento por rango y con particionamiento híbrido. A través de ejercicios prácticos, se evalúa cómo el particionamiento mejora el rendimiento de consultas y facilita el mantenimiento de grandes volúmenes de datos.

## Objetivos de la Práctica
- Analizar el rendimiento de consultas en tablas sin particionamiento
- Implementar particionamiento por rango de fechas
- Diseñar particionamiento híbrido (range + hash)
- Comparar la eficiencia entre diferentes estrategias de particionamiento
- Medir el impacto del particionamiento en el consumo de espacio
- Implementar mantenimiento automatizado de particiones

## Estructuras Implementadas
- **Sin particionamiento:** Tabla base para comparación
- **Particionamiento por rango:** División por años (2020-2024)
- **Particionamiento híbrido:** Range por fecha + Hash por cliente_id

## Ejecuciones Relevantes del Código

### 1. Consulta por Rango de Fechas - Comparación entre Tablas
```sql
-- Consulta en tabla sin particionamiento
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
FROM ventas_sin_particion
WHERE fecha_venta BETWEEN '2023-06-01' AND '2023-08-31';
```
<img width="1433" height="645" alt="Captura de pantalla 2025-10-03 095504" src="https://github.com/user-attachments/assets/f8222cac-91d1-4c2f-8f9d-21f216009184" />
<img width="1434" height="147" alt="Captura de pantalla 2025-10-03 095532" src="https://github.com/user-attachments/assets/5093b90b-a0bc-4785-a06d-5b890172c1bf" />

```sql
-- Misma consulta en tabla particionada
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
FROM ventas_particionada
WHERE fecha_venta BETWEEN '2023-06-01' AND '2023-08-31';
```
<img width="1324" height="688" alt="Captura de pantalla 2025-10-03 095620" src="https://github.com/user-attachments/assets/a898b829-c095-418f-898e-55c547a119d6" />


**Resultados de Tablas**
| Partición | Sin Partición | Particionada |
|-----------|-----------|--------------|
| Tiempo de ejecución | 76.936 ms | 48.162 ms |
| Buffers | 20,571 | 4,128 |
| Plan | Parallel Bitmap Heap Scan en toda la tabla |  Parallel Seq Scan solo en partición ventas_2023 |
| Filas Procesadas | 100,800 de 2,000,000 | 100,800 de 400,414 (solo la partición 2023) |

La tabla particionada mostró una mejora del 37.4% en el tiempo de ejecución. PostgreSQL utilizó **Partition Pruning** para acceder únicamente a la partición de 2023, evitando escanear los 1.6 millones de registros de otros años. Esto redujo significativamente la cantidad de buffers necesarios de 20,571 a solo 4,128, demostrando la eficiencia del particionamiento para consultas por rangos temporales.

### 2. Consulta Específica por Cliente - Comparación de Estrategias
```sql
-- Consulta por cliente específico - tabla sin particiones
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT * FROM ventas_sin_particion
WHERE cliente_id = 5000
AND fecha_venta >= '2024-01-01'
ORDER BY fecha_venta DESC
LIMIT 100;
```

<img width="1224" height="620" alt="Captura de pantalla 2025-10-03 095715" src="https://github.com/user-attachments/assets/f657cae3-b01b-4f71-aa76-fe101fe8677e" />
<img width="1225" height="192" alt="Captura de pantalla 2025-10-03 095752" src="https://github.com/user-attachments/assets/063340c8-51e1-46da-a164-e6741f903a87" />

```sql
-- Misma consulta - tabla con subparticiones hash
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT * FROM ventas_hibrida
WHERE cliente_id = 5000
AND fecha_venta >= '2024-01-01'
ORDER BY fecha_venta DESC
LIMIT 100;
```
<img width="1178" height="585" alt="Captura de pantalla 2025-10-03 095823" src="https://github.com/user-attachments/assets/8bcbf43d-3d6d-44b3-9bd8-8639cc995b43" />

**Resultados de Tablas**
| Partición | Sin Partición | Subparticiones Hash |
|-----------|-----------|--------------|
| Tiempo de ejecución | 0.292 ms | 9.042 ms |
| Buffers | 220 | 1,033 |
| Plan | Bitmap Heap Scan usando índice en cliente_id |  Sequential Scan en subpartición ventas_2024_h0 |
| Estrategia | Índice B-tree tradicional | Partitioning + Hash directo |

La tabla sin particionamiento fue significativamente más rápida (0.292 ms vs 9.042 ms) debido a que utilizó eficientemente el índice B-tree existente. La tabla con subparticiones hash realizó un Sequential Scan porque el particionamiento hash ya había aislado los datos del cliente 5000 en una subpartición específica, pero sin índices adicionales. Esto demuestra que el particionamiento hash es efectivo para aislar datos, pero puede requerir índices complementarios para optimizar consultas específicas.

### 3. Análisis de Partition Pruning en Agregaciones
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT sucursal_id, SUM(total) as ventas_totales
FROM ventas_particionada
WHERE fecha_venta = '2023-12-25'
GROUP BY sucursal_id
ORDER BY ventas_totales DESC;
```

<img width="1444" height="616" alt="Captura de pantalla 2025-10-03 095955" src="https://github.com/user-attachments/assets/86f63313-fef3-4730-809e-5425a6331a32" />
<img width="1448" height="526" alt="Captura de pantalla 2025-10-03 100810" src="https://github.com/user-attachments/assets/9a97283a-95fe-4093-ab74-6d0fe62adfc8" />

**Resultado**
- Tiempo de ejecución: 58.201 ms
- Plan: Parallel Seq Scan exclusivamente en ventas_2023
- Rows Removed by Filter: 133,114 por worker
- Buffers: 4,128 (solo partición 2023)

PostgreSQL demostró un **Partition Pruning** perfecto, accediendo únicamente a la partición de 2023 y descartando automáticamente todas las demás particiones (2020, 2021, 2022, 2024). El optimizador reconoció que la fecha '2023-12-25' solo podía estar en la partición de 2023, evitando completamente el escaneo de 1.6 millones de registros en otras particiones. Esto optimizó significativamente la operación de agregación GROUP BY.

### 4. Distribución y Mantenimiento de Particiones
```sql
-- Creación automática de particiones mensuales
SELECT crear_particion_mensual('ventas_particionada', 2025, 1);
```

<img width="481" height="95" alt="Captura de pantalla 2025-10-03 101037" src="https://github.com/user-attachments/assets/dbc77651-21db-4249-b0f7-e18d9d9c8f22" />

**Resultado**
- Partición creada: ventas_particionada_2025_01
- Rango: FROM '2025-01-01' TO '2025-02-01'

La función de mantenimiento automatizado demostró la escalabilidad del diseño particionado. El sistema puede crecer temporalmente sin intervención manual, creando nuevas particiones para datos futuros. Esto facilita la administración a largo plazo y asegura que el rendimiento se mantenga consistente a medida que crece el volumen de datos.

## Conclusiones Finales

1. **El particionamiento por rango es ideal** para datos temporales, mostrando mejoras de hasta 37.4% en consultas por rangos de fecha
2. **El Partition Pruning** es la característica más valiosa, permitiendo descartar automáticamente particiones no relevantes
3. **Las estrategias híbridas** requieren planificación cuidadosa - el particionamiento hash es efectivo para distribución pero puede necesitar índices adicionales
4. **El mantenimiento automatizado** es crucial para la escalabilidad a largo plazo del sistema particionado
5. **El análisis de patrones de consulta** es esencial antes de implementar cualquier estrategia de particionamiento
