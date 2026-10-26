/* 01_tablas_etl.sql - Tablas de logging y errores del ETL */
USE EvaDB;
GO
DROP TABLE IF EXISTS EVA.ETL_Error;
DROP TABLE IF EXISTS EVA.ETL_Log;
GO

CREATE TABLE EVA.ETL_Log (
    LogID           INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionGuid   UNIQUEIDENTIFIER NULL,          -- System::ExecutionInstanceGUID de SSIS
    Paso            NVARCHAR(100)    NOT NULL,
    Estado          NVARCHAR(20)     NOT NULL,      -- EN_CURSO | OK | ERROR
    FilasLeidas     INT              NULL,
    FilasInsertadas INT              NULL,
    FilasRechazadas INT              NULL,
    Mensaje         NVARCHAR(MAX)    NULL,
    FechaInicio     DATETIME2(0)     NOT NULL DEFAULT SYSDATETIME(),
    FechaFin        DATETIME2(0)     NULL
);

CREATE TABLE EVA.ETL_Error (
    ErrorID       INT IDENTITY(1,1) PRIMARY KEY,
    ExecutionGuid UNIQUEIDENTIFIER NULL,
    Origen        NVARCHAR(100)    NOT NULL,        -- componente / procedimiento
    Motivo        NVARCHAR(400)    NULL,
    ErrorCode     INT              NULL,            -- columnas estandar de Error Output SSIS
    ErrorColumn   INT              NULL,
    ID            INT              NULL,
    Beneficio     NVARCHAR(100)    NULL,
    Dia           NVARCHAR(200)    NULL,
    Fecha         DATETIME2(0)     NOT NULL DEFAULT SYSDATETIME()
);
GO
