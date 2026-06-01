SET NOCOUNT ON;
PRINT '=== Step 1: SELECT @@VERSION ===';
SELECT @@VERSION;
GO

PRINT '=== Step 2: CREATE DATABASE ===';
IF DB_ID(N'PocTestDb') IS NULL
    CREATE DATABASE PocTestDb;
GO

USE PocTestDb;
GO

PRINT '=== Step 3: CREATE TABLE + INSERT ===';
CREATE TABLE dbo.test_emp (
    id     INT IDENTITY(1,1) PRIMARY KEY,
    name   NVARCHAR(50)    NOT NULL,
    salary DECIMAL(10,2)   NOT NULL
);
INSERT INTO dbo.test_emp(name, salary) VALUES
    (N'Alice',   5000.00),
    (N'Bob',     6000.00),
    (N'Charlie', 7500.00);
SELECT COUNT(*) AS row_count FROM dbo.test_emp;
GO

PRINT '=== Step 4: CREATE PROCEDURE ===';
GO
CREATE OR ALTER PROCEDURE dbo.usp_get_emp
    @min_sal DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, salary
    FROM dbo.test_emp
    WHERE salary >= @min_sal
    ORDER BY salary DESC;
END
GO

PRINT '=== Step 5: EXEC PROCEDURE (min_sal=5500) ===';
EXEC dbo.usp_get_emp @min_sal = 5500;
GO

PRINT '=== Step 6: sys.objects metadata readout (SCT-style) ===';
SELECT type_desc, name
FROM sys.objects
WHERE is_ms_shipped = 0
ORDER BY type_desc, name;
GO

PRINT '=== Step 7: CLEANUP ===';
USE master;
GO
DROP DATABASE PocTestDb;
GO

PRINT '=== DONE ===';
GO
