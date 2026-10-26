/* 03_probar_manual.sql - Prueba del ETL SIN SSIS (util para validar la logica) */
USE EvaDB;
GO
TRUNCATE TABLE EVA.Beneficio_Trabajo;
INSERT INTO EVA.Beneficio_Trabajo (ID, Beneficio, Dia)
SELECT ID, Beneficio, Dia FROM EVA.Beneficio;

DECLARE @g UNIQUEIDENTIFIER = NEWID();
EXEC EVA.usp_Normalizar_Beneficio @ExecutionGuid = @g;
SELECT COUNT(*) AS FilasDetalle FROM EVA.Beneficio_Detalle;   -- 28
SELECT TOP (20) * FROM EVA.Beneficio_Detalle ORDER BY ID, Dia;
SELECT * FROM EVA.ETL_Log   ORDER BY LogID DESC;
SELECT * FROM EVA.ETL_Error ORDER BY ErrorID DESC;
GO
