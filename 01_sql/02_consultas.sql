/* =====================================================================
   02_consultas.sql  -  EJERCICIO 1 (SQL Server)
   Supuestos:
   - "Total de beneficios por dia" = beneficios DISTINTOS (por ID) que aplican ese dia.
   - Se normalizan espacios, tabuladores/saltos de linea, mayusculas y tildes.
   - Valores que no son un dia valido se excluyen del conteo y se reportan (consulta 5).
   ===================================================================== */
USE EvaDB;
GO

/* Usa EVA.Dim_Dia + collation CI_AI (insensible a mayusculas y tildes)
   para que 'miercoles', 'MIÉRCOLES' y ' Miércoles ' se unifiquen en 'Miércoles'. */
DROP TABLE IF EXISTS #Dias;

SELECT DISTINCT b.ID, b.Beneficio, d.DiaNum, d.Dia
INTO #Dias
FROM EVA.Beneficio b
CROSS APPLY STRING_SPLIT(
        REPLACE(REPLACE(REPLACE(ISNULL(b.Dia, N''), CHAR(9), N''), CHAR(10), N''), CHAR(13), N''), N',') s
JOIN EVA.Dim_Dia d
  ON d.Dia COLLATE Latin1_General_CI_AI = LTRIM(RTRIM(s.value)) COLLATE Latin1_General_CI_AI;

-- (1) y (2): una fila por (ID, Beneficio, Dia)
SELECT ID, Beneficio, Dia FROM #Dias ORDER BY ID, DiaNum;

-- (3) Total de beneficios por dia (incluye dias con 0)
SELECT d.Dia, COUNT(DISTINCT x.ID) AS TotalBeneficios
FROM EVA.Dim_Dia d
LEFT JOIN #Dias x ON x.DiaNum = d.DiaNum
GROUP BY d.DiaNum, d.Dia
ORDER BY d.DiaNum;

-- (4) Dia con mayor numero de beneficios (WITH TIES devuelve todos los empatados)
SELECT TOP (1) WITH TIES Dia, COUNT(DISTINCT ID) AS TotalBeneficios
FROM #Dias
GROUP BY Dia
ORDER BY COUNT(DISTINCT ID) DESC;

/* ---------- (5) Calidad de datos: que se descarto y por que ---------- */
-- 5a) Valores que no corresponden a un dia valido
SELECT b.ID, b.Beneficio, b.Dia AS DiaOriginal, LTRIM(RTRIM(s.value)) AS ValorInvalido
FROM EVA.Beneficio b
CROSS APPLY STRING_SPLIT(ISNULL(b.Dia, N''), N',') s
LEFT JOIN EVA.Dim_Dia d
  ON d.Dia COLLATE Latin1_General_CI_AI = LTRIM(RTRIM(s.value)) COLLATE Latin1_General_CI_AI
WHERE LTRIM(RTRIM(s.value)) <> N'' AND d.DiaNum IS NULL;

-- 5b) Beneficios sin dia (NULL o vacio)
SELECT ID, Beneficio, Dia
FROM EVA.Beneficio
WHERE NULLIF(LTRIM(RTRIM(Dia)), N'') IS NULL;
GO
