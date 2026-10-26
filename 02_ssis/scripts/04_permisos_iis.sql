/* 04_permisos_iis.sql
   Da permiso a la identidad del App Pool de IIS para ejecutar paquetes en SSISDB.
   Ajusta el nombre si tu App Pool se llama distinto (aqui: BeneficiosEtlApi). */
USE master;
GO
IF SUSER_ID(N'IIS APPPOOL\BeneficiosEtlApi') IS NULL
    CREATE LOGIN [IIS APPPOOL\BeneficiosEtlApi] FROM WINDOWS;
GO
USE SSISDB;
GO
IF USER_ID(N'IIS APPPOOL\BeneficiosEtlApi') IS NULL
    CREATE USER [IIS APPPOOL\BeneficiosEtlApi] FOR LOGIN [IIS APPPOOL\BeneficiosEtlApi];
ALTER ROLE ssis_admin ADD MEMBER [IIS APPPOOL\BeneficiosEtlApi];
GO
/* El paquete lee/escribe en EvaDB: la misma identidad necesita acceso ahi
   (si tu conexion SSIS usa Windows Authentication). */
USE EvaDB;
GO
IF USER_ID(N'IIS APPPOOL\BeneficiosEtlApi') IS NULL
    CREATE USER [IIS APPPOOL\BeneficiosEtlApi] FOR LOGIN [IIS APPPOOL\BeneficiosEtlApi];
ALTER ROLE db_datareader ADD MEMBER [IIS APPPOOL\BeneficiosEtlApi];
ALTER ROLE db_datawriter ADD MEMBER [IIS APPPOOL\BeneficiosEtlApi];
GRANT EXECUTE ON SCHEMA::EVA TO [IIS APPPOOL\BeneficiosEtlApi];
GRANT ALTER  ON SCHEMA::EVA TO [IIS APPPOOL\BeneficiosEtlApi];  -- necesario para TRUNCATE
GO
