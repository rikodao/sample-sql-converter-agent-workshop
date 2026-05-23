-- ============================================================================
-- Sample T-SQL objects for migration validation
-- These objects exercise common T-SQL features that need to be tested for
-- Babelfish compatibility and PL/pgSQL conversion.
--
-- 投入手順は scripts/deploy.sh が SSM RunCommand で sqlcmd を呼び出す。
-- ============================================================================

-- 0. データベース・スキーマ準備 ---------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'migration_demo')
BEGIN
    CREATE DATABASE migration_demo;
END
GO

USE migration_demo;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dbo')
BEGIN
    EXEC('CREATE SCHEMA dbo');
END
GO

-- 1. テーブル定義 ------------------------------------------------------------

IF OBJECT_ID('dbo.departments', 'U') IS NOT NULL DROP TABLE dbo.departments;
IF OBJECT_ID('dbo.employees', 'U') IS NOT NULL DROP TABLE dbo.employees;
IF OBJECT_ID('dbo.salaries', 'U') IS NOT NULL DROP TABLE dbo.salaries;
IF OBJECT_ID('dbo.bonuses', 'U') IS NOT NULL DROP TABLE dbo.bonuses;
IF OBJECT_ID('dbo.audit_log', 'U') IS NOT NULL DROP TABLE dbo.audit_log;
IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL DROP TABLE dbo.orders;
IF OBJECT_ID('dbo.orders_archive', 'U') IS NOT NULL DROP TABLE dbo.orders_archive;
GO

CREATE TABLE dbo.departments (
    department_id  INT IDENTITY(1,1) PRIMARY KEY,
    name           NVARCHAR(100) NOT NULL,
    parent_id      INT NULL,
    created_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.employees (
    employee_id    INT IDENTITY(1,1) PRIMARY KEY,
    department_id  INT NOT NULL REFERENCES dbo.departments(department_id),
    first_name     NVARCHAR(50) NOT NULL,
    last_name      NVARCHAR(50) NOT NULL,
    hire_date      DATE NOT NULL,
    is_active      BIT NOT NULL DEFAULT 1,
    email          NVARCHAR(200) NULL,
    created_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.salaries (
    salary_id      INT IDENTITY(1,1) PRIMARY KEY,
    employee_id    INT NOT NULL REFERENCES dbo.employees(employee_id),
    base_salary    MONEY NOT NULL,
    effective_from DATE NOT NULL,
    effective_to   DATE NULL
);

CREATE TABLE dbo.bonuses (
    bonus_id       INT IDENTITY(1,1) PRIMARY KEY,
    employee_id    INT NOT NULL REFERENCES dbo.employees(employee_id),
    fiscal_year    INT NOT NULL,
    bonus_amount   MONEY NOT NULL,
    awarded_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.audit_log (
    audit_id       BIGINT IDENTITY(1,1) PRIMARY KEY,
    table_name     NVARCHAR(100) NOT NULL,
    operation      NVARCHAR(10) NOT NULL,
    primary_key    INT NULL,
    changed_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    changed_by     NVARCHAR(100) NOT NULL DEFAULT SUSER_SNAME()
);

CREATE TABLE dbo.orders (
    order_id       INT IDENTITY(1,1) PRIMARY KEY,
    customer_id    INT NOT NULL,
    order_date     DATETIME2 NOT NULL,
    total_amount   MONEY NOT NULL,
    status         NVARCHAR(20) NOT NULL DEFAULT N'NEW'
);

CREATE TABLE dbo.orders_archive (
    order_id       INT NOT NULL PRIMARY KEY,
    customer_id    INT NOT NULL,
    order_date     DATETIME2 NOT NULL,
    total_amount   MONEY NOT NULL,
    status         NVARCHAR(20) NOT NULL,
    archived_at    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- 2. 種データ ---------------------------------------------------------------

INSERT INTO dbo.departments (name, parent_id) VALUES
    (N'Engineering', NULL),
    (N'Backend', 1),
    (N'Frontend', 1),
    (N'Sales', NULL),
    (N'HR', NULL);

INSERT INTO dbo.employees (department_id, first_name, last_name, hire_date, email) VALUES
    (2, N'Alice',  N'Anderson', '2020-01-15', N'alice@example.com'),
    (2, N'Bob',    N'Brown',    '2021-03-01', N'bob@example.com'),
    (3, N'Carol',  N'Chen',     '2019-06-12', N'carol@example.com'),
    (4, N'David',  N'Davis',    '2022-09-01', N'david@example.com'),
    (5, N'Eve',    N'Evans',    '2018-11-20', NULL);

INSERT INTO dbo.salaries (employee_id, base_salary, effective_from) VALUES
    (1, 80000, '2020-01-15'),
    (2, 75000, '2021-03-01'),
    (3, 90000, '2019-06-12'),
    (4, 70000, '2022-09-01'),
    (5, 65000, '2018-11-20');

INSERT INTO dbo.orders (customer_id, order_date, total_amount, status) VALUES
    (1001, '2024-01-15', 1200.50, N'COMPLETED'),
    (1002, '2024-02-20',  450.00, N'COMPLETED'),
    (1003, '2025-01-10',  890.75, N'PENDING'),
    (1004, '2026-04-01', 2300.00, N'COMPLETED');
GO

-- 3. ユーザー定義関数 (SCALAR / TVF) ----------------------------------------

IF OBJECT_ID('dbo.fn_get_fiscal_year', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_get_fiscal_year;
GO
CREATE FUNCTION dbo.fn_get_fiscal_year(@d DATE)
RETURNS INT
AS
BEGIN
    -- 4月始まりの会計年度
    DECLARE @y INT = YEAR(@d);
    DECLARE @m INT = MONTH(@d);
    IF @m < 4
        SET @y = @y - 1;
    RETURN @y;
END
GO

IF OBJECT_ID('dbo.fn_format_employee_name', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_format_employee_name;
GO
CREATE FUNCTION dbo.fn_format_employee_name(@first NVARCHAR(50), @last NVARCHAR(50))
RETURNS NVARCHAR(105)
AS
BEGIN
    IF @first IS NULL OR @last IS NULL
        RETURN N'(unknown)';
    RETURN @last + N', ' + @first;
END
GO

IF OBJECT_ID('dbo.fn_split_csv', 'TF') IS NOT NULL DROP FUNCTION dbo.fn_split_csv;
GO
CREATE FUNCTION dbo.fn_split_csv(@csv NVARCHAR(MAX), @sep CHAR(1))
RETURNS @result TABLE (idx INT, value NVARCHAR(200))
AS
BEGIN
    DECLARE @i INT = 1;
    DECLARE @start INT = 1;
    DECLARE @pos INT;

    IF @csv IS NULL OR LEN(@csv) = 0
        RETURN;

    SET @pos = CHARINDEX(@sep, @csv, @start);
    WHILE @pos > 0
    BEGIN
        INSERT INTO @result(idx, value) VALUES(@i, SUBSTRING(@csv, @start, @pos - @start));
        SET @i = @i + 1;
        SET @start = @pos + 1;
        SET @pos = CHARINDEX(@sep, @csv, @start);
    END
    INSERT INTO @result(idx, value) VALUES(@i, SUBSTRING(@csv, @start, LEN(@csv) - @start + 1));
    RETURN;
END
GO

-- 4. ストアドプロシージャ --------------------------------------------------

-- 4.1 シンプルな計算プロシージャ (ボーナス計算)
IF OBJECT_ID('dbo.usp_calculate_employee_bonus', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_calculate_employee_bonus;
GO
CREATE PROCEDURE dbo.usp_calculate_employee_bonus
    @employee_id INT,
    @fiscal_year INT,
    @bonus       MONEY OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @base MONEY;
    DECLARE @years INT;

    SELECT TOP 1 @base = base_salary
    FROM dbo.salaries
    WHERE employee_id = @employee_id
    ORDER BY effective_from DESC;

    IF @base IS NULL
    BEGIN
        SET @bonus = 0;
        RETURN;
    END

    SELECT @years = DATEDIFF(yy, hire_date, DATEFROMPARTS(@fiscal_year, 12, 31))
    FROM dbo.employees WHERE employee_id = @employee_id;

    SET @bonus = @base * 0.10 * (1 + ISNULL(@years, 0) * 0.05);

    -- 既存があれば置換、なければ INSERT (UPSERT)
    IF EXISTS (SELECT 1 FROM dbo.bonuses WHERE employee_id = @employee_id AND fiscal_year = @fiscal_year)
        UPDATE dbo.bonuses SET bonus_amount = @bonus
        WHERE employee_id = @employee_id AND fiscal_year = @fiscal_year;
    ELSE
        INSERT INTO dbo.bonuses(employee_id, fiscal_year, bonus_amount)
        VALUES(@employee_id, @fiscal_year, @bonus);
END
GO

-- 4.2 古い注文を archive に移動 (BEGIN TRAN, TRY/CATCH, OUTPUT)
IF OBJECT_ID('dbo.usp_archive_old_orders', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_archive_old_orders;
GO
CREATE PROCEDURE dbo.usp_archive_old_orders
    @cutoff_date DATE,
    @rows_archived INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @rows_archived = 0;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @archived TABLE(order_id INT);

        DELETE FROM dbo.orders
        OUTPUT DELETED.order_id, DELETED.customer_id, DELETED.order_date,
               DELETED.total_amount, DELETED.status
        INTO dbo.orders_archive(order_id, customer_id, order_date, total_amount, status)
        WHERE order_date < @cutoff_date AND status = N'COMPLETED';

        SET @rows_archived = @@ROWCOUNT;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(2000) = ERROR_MESSAGE();
        THROW 50001, @msg, 1;
    END CATCH
END
GO

-- 4.3 部署の UPSERT (MERGE 文)
IF OBJECT_ID('dbo.usp_upsert_department', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_upsert_department;
GO
CREATE PROCEDURE dbo.usp_upsert_department
    @name      NVARCHAR(100),
    @parent_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.departments AS tgt
    USING (SELECT @name AS name, @parent_id AS parent_id) AS src
    ON tgt.name = src.name
    WHEN MATCHED THEN
        UPDATE SET parent_id = src.parent_id
    WHEN NOT MATCHED THEN
        INSERT (name, parent_id) VALUES (src.name, src.parent_id);
END
GO

-- 4.4 再帰 CTE による組織図出力
IF OBJECT_ID('dbo.usp_recursive_org_chart', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_recursive_org_chart;
GO
CREATE PROCEDURE dbo.usp_recursive_org_chart
    @root_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH org AS (
        SELECT department_id, name, parent_id, 0 AS depth, CAST(name AS NVARCHAR(MAX)) AS path
        FROM dbo.departments
        WHERE department_id = @root_id

        UNION ALL

        SELECT d.department_id, d.name, d.parent_id, o.depth + 1,
               o.path + N' > ' + d.name
        FROM dbo.departments d
        INNER JOIN org o ON d.parent_id = o.department_id
    )
    SELECT department_id, name, depth, path FROM org ORDER BY path;
END
GO

-- 5. トリガー --------------------------------------------------------------

IF OBJECT_ID('dbo.trg_audit_employees', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_audit_employees;
GO
CREATE TRIGGER dbo.trg_audit_employees
ON dbo.employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        SELECT 'employees', 'UPDATE', employee_id FROM inserted;
    ELSE IF EXISTS(SELECT 1 FROM inserted)
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        SELECT 'employees', 'INSERT', employee_id FROM inserted;
    ELSE IF EXISTS(SELECT 1 FROM deleted)
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        SELECT 'employees', 'DELETE', employee_id FROM deleted;
END
GO

-- 6. ビュー -----------------------------------------------------------------

IF OBJECT_ID('dbo.v_active_employees', 'V') IS NOT NULL DROP VIEW dbo.v_active_employees;
GO
CREATE VIEW dbo.v_active_employees AS
SELECT
    e.employee_id,
    dbo.fn_format_employee_name(e.first_name, e.last_name) AS full_name,
    d.name AS department_name,
    e.hire_date,
    s.base_salary,
    DATEDIFF(yy, e.hire_date, GETDATE()) AS years_of_service
FROM dbo.employees e
INNER JOIN dbo.departments d ON e.department_id = d.department_id
OUTER APPLY (
    SELECT TOP 1 base_salary
    FROM dbo.salaries
    WHERE employee_id = e.employee_id
    ORDER BY effective_from DESC
) s
WHERE e.is_active = 1;
GO

PRINT N'Sample objects created successfully.';
GO
