/* 02_usp_normalizar.sql
   Normaliza EVA.Beneficio_Trabajo -> EVA.Beneficio_Detalle (una fila por dia).
   Decisiones:
   - Set-based (STRING_SPLIT) en el motor: mucho mas rapido que fila a fila.
   - Recarga completa e idempotente dentro de UNA transaccion: si falla, rollback
     y Detalle queda como estaba. Re-ejecutar no duplica datos.
   - Valores invalidos / vacios NO detienen el proceso: van a EVA.ETL_Error.
   - FechaCarga es la misma para todo el lote.                                  */
USE EvaDB;
GO
CREATE OR ALTER PROCEDURE EVA.usp_Normalizar_Beneficio
    @ExecutionGuid UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Fecha DATETIME2(0) = SYSDATETIME(),
            @Leidas INT, @Insertadas INT, @Rechazadas INT, @LogID INT;

    INSERT INTO EVA.ETL_Log (ExecutionGuid, Paso, Estado, FechaInicio)
    VALUES (@ExecutionGuid, N'usp_Normalizar_Beneficio', N'EN_CURSO', @Fecha);
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidas = COUNT(*) FROM EVA.Beneficio_Trabajo;

        -- 1) Tokens limpios (sin espacios/tab/CR/LF, sin vacios)
        DROP TABLE IF EXISTS #Tokens;
        SELECT t.ID, t.Beneficio,
               Token = LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(s.value, CHAR(9), N''), CHAR(10), N''), CHAR(13), N'')))
        INTO #Tokens
        FROM EVA.Beneficio_Trabajo t
        CROSS APPLY STRING_SPLIT(ISNULL(t.Dia, N''), N',') s;

        DELETE FROM #Tokens WHERE Token = N'';

        BEGIN TRAN;

            -- 2) Recarga idempotente
            DELETE FROM EVA.Beneficio_Detalle;

            INSERT INTO EVA.Beneficio_Detalle (ID, Beneficio, Dia, FechaCarga)
            SELECT DISTINCT k.ID, k.Beneficio, d.Dia, @Fecha
            FROM #Tokens k
            JOIN EVA.Dim_Dia d
              ON d.Dia COLLATE Latin1_General_CI_AI = k.Token COLLATE Latin1_General_CI_AI;
            SET @Insertadas = @@ROWCOUNT;

            -- 3) Rechazos: dias invalidos
            INSERT INTO EVA.ETL_Error (ExecutionGuid, Origen, Motivo, ID, Beneficio, Dia)
            SELECT @ExecutionGuid, N'usp_Normalizar_Beneficio', N'Dia invalido: ' + k.Token, k.ID, k.Beneficio, k.Token
            FROM #Tokens k
            LEFT JOIN EVA.Dim_Dia d
              ON d.Dia COLLATE Latin1_General_CI_AI = k.Token COLLATE Latin1_General_CI_AI
            WHERE d.DiaNum IS NULL;
            SET @Rechazadas = @@ROWCOUNT;

            -- 4) Rechazos: sin dia (NULL o vacio)
            INSERT INTO EVA.ETL_Error (ExecutionGuid, Origen, Motivo, ID, Beneficio, Dia)
            SELECT @ExecutionGuid, N'usp_Normalizar_Beneficio', N'Dia nulo o vacio', ID, Beneficio, Dia
            FROM EVA.Beneficio_Trabajo
            WHERE NULLIF(LTRIM(RTRIM(Dia)), N'') IS NULL;
            SET @Rechazadas = @Rechazadas + @@ROWCOUNT;

        COMMIT;

        UPDATE EVA.ETL_Log
           SET Estado = N'OK', FilasLeidas = @Leidas, FilasInsertadas = @Insertadas,
               FilasRechazadas = @Rechazadas, FechaFin = SYSDATETIME()
         WHERE LogID = @LogID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;

        UPDATE EVA.ETL_Log
           SET Estado = N'ERROR', Mensaje = ERROR_MESSAGE(), FechaFin = SYSDATETIME()
         WHERE LogID = @LogID;

        THROW;
    END CATCH
END
GO
