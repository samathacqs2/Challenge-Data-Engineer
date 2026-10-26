/* =====================================================================
   00_setup.sql  -  Crea la BD de pruebas, esquema EVA, tablas y datos
   Ejecutar completo en SSMS (conectado como sysadmin).
   Requiere SQL Server 2017+ (STRING_SPLIT, CONCAT_WS).
   ===================================================================== */
IF DB_ID('EvaDB') IS NULL CREATE DATABASE EvaDB;
GO
USE EvaDB;
GO
IF SCHEMA_ID('EVA') IS NULL EXEC('CREATE SCHEMA EVA');
GO

DROP TABLE IF EXISTS EVA.Beneficio_Detalle;
DROP TABLE IF EXISTS EVA.Beneficio_Trabajo;
DROP TABLE IF EXISTS EVA.Beneficio;
DROP TABLE IF EXISTS EVA.Dim_Dia;
GO

/* Tabla origen (segun enunciado): Dia contiene valores separados por coma */
CREATE TABLE EVA.Beneficio (
    ID        INT            NOT NULL PRIMARY KEY,
    Beneficio NVARCHAR(100)  NOT NULL,
    Dia       NVARCHAR(200)  NULL
);

/* Tabla de trabajo (staging) para el ETL */
CREATE TABLE EVA.Beneficio_Trabajo (
    ID        INT,
    Beneficio NVARCHAR(100),
    Dia       NVARCHAR(200)
);

/* Tabla destino normalizada */
CREATE TABLE EVA.Beneficio_Detalle (
    ID         INT           NOT NULL,
    Beneficio  NVARCHAR(100) NOT NULL,
    Dia        NVARCHAR(20)  NOT NULL,
    FechaCarga DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Beneficio_Detalle PRIMARY KEY (ID, Dia)
);

/* Catalogo de dias: fuente de verdad para consistencia de datos */
CREATE TABLE EVA.Dim_Dia (
    DiaNum TINYINT      NOT NULL PRIMARY KEY,   -- 1 = Lunes
    Dia    NVARCHAR(20) NOT NULL UNIQUE
);
INSERT INTO EVA.Dim_Dia (DiaNum, Dia) VALUES
(1,N'Lunes'),(2,N'Martes'),(3,N'Miércoles'),(4,N'Jueves'),
(5,N'Viernes'),(6,N'Sábado'),(7,N'Domingo');
GO

/* Datos de prueba con casos limite a proposito */
INSERT INTO EVA.Beneficio (ID, Beneficio, Dia) VALUES
(1,  N'10% Supermercado', N'Lunes,Martes'),
(2,  N'15% Restaurantes', N'Viernes,Sabado,Domingo'),
(3,  N'5% Gasolina',      N'Lunes, Miercoles, Viernes'),            -- espacios
(4,  N'20% Cine',         N'martes'),                               -- minuscula
(5,  N'2x1 Farmacia',     N'LUNES,MARTES,MIERCOLES,JUEVES,VIERNES,SABADO,DOMINGO'), -- todos
(6,  N'12% Ropa',         N' Sabado , Domingo '),                   -- espacios
(7,  N'8% Tecnologia',    N'Jueves,Jueves'),                        -- duplicado
(8,  N'10% Viajes',       N'Viernes,,Sabado'),                      -- coma doble
(9,  N'5% Streaming',     N'Lunes,'),                               -- coma final
(10, N'7% Educacion',     N''),                                     -- vacio
(11, N'9% Salud',         NULL),                                    -- nulo
(12, N'18% Mascotas',     N'Martes,Jueves'),
(13, N'6% Hogar',         N'Miércoles'),                            -- con tilde
(14, N'11% Belleza',      N'Sabado,Viernes'),
(15, N'4% Libreria',      N'Lunez,Martes');                         -- dia invalido (typo)
GO
SELECT COUNT(*) AS FilasCargadas FROM EVA.Beneficio;
