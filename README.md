# Prueba Técnica – Ingeniero de Datos

Solución completa: SQL Server, SSIS + endpoint en IIS, revisión de PySpark y bonus de riesgo.

## Estructura
```
01_sql/                           Ejercicio 1 + creación del dataset
02_ssis/                          Ejercicio 2 (scripts,API para IIS)
03_pyspark/                       Ejercicio 3 (código corregido)
```

## Orden de ejecución (≈ 3–4 h la primera vez)

| Paso | Qué hacer | Archivo |
|---|---|---|
| 1 | Crear BD, tablas y datos de prueba (SSMS) | `01_sql/00_setup.sql` |
| 2 | Ejercicio 1: ejecutar y capturar resultados | `01_sql/02_consultas.sql` |
| 3 | Crear tablas de log/error y el procedimiento | `02_ssis/scripts/01_…` y `02_…` |
| 4 | Validar la lógica sin SSIS | `02_ssis/scripts/03_probar_manual.sql` |
| 6 | Publicar la API en IIS y permisos |`scripts/04_permisos_iis.sql` |
| 7 | Probar `POST /api/etl/beneficios` con PowerShell | – |

## Supuestos
- No se entregó dataset: se crearon datos de prueba con casos límite (espacios, mayúsculas, tildes, duplicados, comas sobrantes, vacíos, `NULL` y un día inválido).
- "Total de beneficios por día" = beneficios **distintos** (por `ID`) que aplican ese día.
- Los valores que no corresponden a un día de la semana se excluyen del conteo y se registran (`EVA.ETL_Error`).
- La carga a `Beneficio_Detalle` es recarga completa e idempotente.
- Las reglas del bonus asumen una tabla de transacciones que no forma parte de la prueba.

