-- ============================================================================
-- Sample T-SQL objects (ADVANCED) for migration validation
-- これらは Babelfish の互換性限界を試す難物パターン集。
-- 一部は意図的に "Babelfish では失敗する" → "PG-native へフォールバック" の
-- 動作を確認するためのもの。
--
-- 投入は scripts/deploy.sh 経由 (同じ migration_demo DB に追加)
-- ============================================================================

USE migration_demo;
GO

-- ============================================================================
-- 1. sp_executesql + OUTPUT パラメタ (Babelfish の弱点パターン)
-- ============================================================================
IF OBJECT_ID('dbo.usp_dynamic_count_with_output', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_dynamic_count_with_output;
GO
CREATE PROCEDURE dbo.usp_dynamic_count_with_output
    @table_name SYSNAME,
    @filter_column SYSNAME,
    @filter_value NVARCHAR(200),
    @row_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT @cnt = COUNT(*) FROM ' + QUOTENAME(@table_name)
        + N' WHERE ' + QUOTENAME(@filter_column) + N' = @val';

    EXEC sp_executesql @sql,
        N'@val NVARCHAR(200), @cnt INT OUTPUT',
        @val = @filter_value,
        @cnt = @row_count OUTPUT;
END
GO

-- ============================================================================
-- 2. Table-Valued Parameter (TVP) を使うストアド
--    Babelfish は TVP 部分対応 / PG-native では composite type/array に変換
-- ============================================================================
IF TYPE_ID('dbo.EmployeeIdList') IS NOT NULL DROP TYPE dbo.EmployeeIdList;
GO
CREATE TYPE dbo.EmployeeIdList AS TABLE (
    employee_id INT NOT NULL PRIMARY KEY
);
GO

IF OBJECT_ID('dbo.usp_bulk_deactivate_employees', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_bulk_deactivate_employees;
GO
CREATE PROCEDURE dbo.usp_bulk_deactivate_employees
    @employee_ids dbo.EmployeeIdList READONLY,
    @deactivated_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE e
    SET e.is_active = 0
    FROM dbo.employees e
    INNER JOIN @employee_ids ids ON e.employee_id = ids.employee_id;
    SET @deactivated_count = @@ROWCOUNT;
END
GO

-- ============================================================================
-- 3. CROSS APPLY + STRING_AGG / FOR XML PATH の文字列連結
--    OFFSET/FETCH ページング、ROW_NUMBER OVER の組合せ
-- ============================================================================
IF OBJECT_ID('dbo.usp_search_employees_paged', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_search_employees_paged;
GO
CREATE PROCEDURE dbo.usp_search_employees_paged
    @search_term NVARCHAR(100),
    @page_no INT = 1,
    @page_size INT = 20,
    @total_rows INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Total
    SELECT @total_rows = COUNT(*)
    FROM dbo.employees e
    WHERE e.first_name LIKE N'%' + @search_term + N'%'
       OR e.last_name  LIKE N'%' + @search_term + N'%'
       OR ISNULL(e.email, N'') LIKE N'%' + @search_term + N'%';

    -- 2) Page
    SELECT
        e.employee_id,
        e.first_name + N' ' + e.last_name AS full_name,
        d.name AS department_name,
        e.email,
        ROW_NUMBER() OVER (ORDER BY e.last_name, e.first_name) AS row_num
    FROM dbo.employees e
    INNER JOIN dbo.departments d ON e.department_id = d.department_id
    WHERE e.first_name LIKE N'%' + @search_term + N'%'
       OR e.last_name  LIKE N'%' + @search_term + N'%'
       OR ISNULL(e.email, N'') LIKE N'%' + @search_term + N'%'
    ORDER BY e.last_name, e.first_name
    OFFSET (@page_no - 1) * @page_size ROWS
    FETCH NEXT @page_size ROWS ONLY;
END
GO

-- ============================================================================
-- 4. PIVOT + UNPIVOT (T-SQL 固有構文。PG では crosstab/手書きへ)
-- ============================================================================
IF OBJECT_ID('dbo.usp_dept_headcount_pivot', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_dept_headcount_pivot;
GO
CREATE PROCEDURE dbo.usp_dept_headcount_pivot
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM (
        SELECT
            d.name AS department_name,
            CASE WHEN e.is_active = 1 THEN 'Active' ELSE 'Inactive' END AS status,
            e.employee_id
        FROM dbo.departments d
        LEFT JOIN dbo.employees e ON d.department_id = e.department_id
    ) src
    PIVOT (
        COUNT(employee_id) FOR status IN ([Active], [Inactive])
    ) p
    ORDER BY department_name;
END
GO

-- ============================================================================
-- 5. WHILE + CURSOR (典型的な再帰処理。PG では set-based 推奨パターン)
-- ============================================================================
IF OBJECT_ID('dbo.usp_propagate_salary_raise', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_propagate_salary_raise;
GO
CREATE PROCEDURE dbo.usp_propagate_salary_raise
    @raise_pct DECIMAL(5,2),  -- e.g., 5.00 = 5%
    @min_years_of_service INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @emp_id INT;
    DECLARE @cur_salary MONEY;
    DECLARE @new_salary MONEY;
    DECLARE @effective DATE = GETDATE();

    DECLARE emp_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT e.employee_id, s.base_salary
        FROM dbo.employees e
        OUTER APPLY (
            SELECT TOP 1 base_salary
            FROM dbo.salaries
            WHERE employee_id = e.employee_id
            ORDER BY effective_from DESC
        ) s
        WHERE e.is_active = 1
          AND DATEDIFF(yy, e.hire_date, GETDATE()) >= @min_years_of_service
          AND s.base_salary IS NOT NULL;

    OPEN emp_cursor;
    FETCH NEXT FROM emp_cursor INTO @emp_id, @cur_salary;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @new_salary = @cur_salary * (1 + @raise_pct / 100.0);

        -- 古い給与レコードを終了
        UPDATE dbo.salaries
        SET effective_to = DATEADD(dd, -1, @effective)
        WHERE employee_id = @emp_id AND effective_to IS NULL;

        -- 新しい給与レコードを挿入
        INSERT INTO dbo.salaries(employee_id, base_salary, effective_from)
        VALUES (@emp_id, @new_salary, @effective);

        FETCH NEXT FROM emp_cursor INTO @emp_id, @cur_salary;
    END
    CLOSE emp_cursor;
    DEALLOCATE emp_cursor;
END
GO

-- ============================================================================
-- 6. Multi-statement Table-Valued Function (MSTVF)
--    Babelfish 限定対応 / PG では table-returning function に書き換え必要
-- ============================================================================
IF OBJECT_ID('dbo.fn_get_dept_summary', 'TF') IS NOT NULL DROP FUNCTION dbo.fn_get_dept_summary;
GO
CREATE FUNCTION dbo.fn_get_dept_summary(@as_of DATE)
RETURNS @summary TABLE (
    department_id INT,
    department_name NVARCHAR(100),
    headcount INT,
    avg_salary MONEY,
    total_payroll MONEY
)
AS
BEGIN
    INSERT INTO @summary(department_id, department_name, headcount, avg_salary, total_payroll)
    SELECT
        d.department_id,
        d.name,
        COUNT(DISTINCT e.employee_id) AS headcount,
        AVG(s.base_salary) AS avg_salary,
        SUM(s.base_salary) AS total_payroll
    FROM dbo.departments d
    LEFT JOIN dbo.employees e ON d.department_id = e.department_id AND e.is_active = 1
    OUTER APPLY (
        SELECT TOP 1 base_salary
        FROM dbo.salaries
        WHERE employee_id = e.employee_id
          AND effective_from <= @as_of
          AND (effective_to IS NULL OR effective_to >= @as_of)
        ORDER BY effective_from DESC
    ) s
    GROUP BY d.department_id, d.name;
    RETURN;
END
GO

-- ============================================================================
-- 7. INSTEAD OF Trigger on View (Babelfish では限定対応)
-- ============================================================================
IF OBJECT_ID('dbo.v_employee_full', 'V') IS NOT NULL DROP VIEW dbo.v_employee_full;
GO
CREATE VIEW dbo.v_employee_full AS
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.email,
    e.is_active,
    d.department_id,
    d.name AS department_name
FROM dbo.employees e
INNER JOIN dbo.departments d ON e.department_id = d.department_id;
GO

IF OBJECT_ID('dbo.trg_v_employee_full_update', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_v_employee_full_update;
GO
CREATE TRIGGER dbo.trg_v_employee_full_update
ON dbo.v_employee_full
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE e
    SET e.first_name = i.first_name,
        e.last_name  = i.last_name,
        e.email      = i.email,
        e.is_active  = i.is_active
    FROM dbo.employees e
    INNER JOIN inserted i ON e.employee_id = i.employee_id;
END
GO

-- ============================================================================
-- 8. THROW + Re-raise + custom error severity (T-SQL 固有エラー処理)
-- ============================================================================
IF OBJECT_ID('dbo.usp_validate_and_create_dept', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_validate_and_create_dept;
GO
CREATE PROCEDURE dbo.usp_validate_and_create_dept
    @name NVARCHAR(100),
    @parent_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @name IS NULL OR LTRIM(RTRIM(@name)) = N''
            THROW 51001, N'Department name cannot be empty.', 1;

        IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = @name)
            THROW 51002, N'Department with same name already exists.', 1;

        IF @parent_id IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE department_id = @parent_id)
            THROW 51003, N'Parent department does not exist.', 1;

        INSERT INTO dbo.departments(name, parent_id) VALUES(@name, @parent_id);
    END TRY
    BEGIN CATCH
        DECLARE @err_num   INT = ERROR_NUMBER();
        DECLARE @err_sev   INT = ERROR_SEVERITY();
        DECLARE @err_state INT = ERROR_STATE();
        DECLARE @err_msg   NVARCHAR(2000) = ERROR_MESSAGE();

        -- ログ書き込みとリレイズ
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        VALUES (N'departments_validation_failed', N'CREATE', NULL);

        ;THROW;
    END CATCH
END
GO

-- ============================================================================
-- 9. WITH ENCRYPTION (Babelfish/PG 共に変換不可。NG パスのテスト用)
-- ============================================================================
-- 暗号化されたストアドは definition が NULL になり、SCT/エージェントが扱えない。
-- エージェントは prerequisites.txt にこのケースを記録して NG.txt を作成すべき。

IF OBJECT_ID('dbo.usp_encrypted_demo', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_encrypted_demo;
GO
CREATE PROCEDURE dbo.usp_encrypted_demo
    @x INT
WITH ENCRYPTION
AS
BEGIN
    SELECT @x * 2 AS doubled;
END
GO

-- ============================================================================
-- 10. JSON 関数 (T-SQL 2016+, Babelfish 部分対応, PG は別構文)
-- ============================================================================
IF OBJECT_ID('dbo.usp_employee_json', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_employee_json;
GO
CREATE PROCEDURE dbo.usp_employee_json
    @employee_id INT,
    @json_out NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @json_out = (
        SELECT
            e.employee_id,
            e.first_name,
            e.last_name,
            e.email,
            d.name AS department_name,
            e.hire_date
        FROM dbo.employees e
        INNER JOIN dbo.departments d ON e.department_id = d.department_id
        WHERE e.employee_id = @employee_id
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
GO

-- ============================================================================
-- 11. Common Table Expression with multiple references (再帰CTE+正規CTE混在)
-- ============================================================================
IF OBJECT_ID('dbo.usp_dept_with_cumulative_metrics', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_dept_with_cumulative_metrics;
GO
CREATE PROCEDURE dbo.usp_dept_with_cumulative_metrics
AS
BEGIN
    SET NOCOUNT ON;

    WITH
    dept_tree (department_id, name, parent_id, depth) AS (
        SELECT department_id, name, parent_id, 0
        FROM dbo.departments WHERE parent_id IS NULL
        UNION ALL
        SELECT d.department_id, d.name, d.parent_id, t.depth + 1
        FROM dbo.departments d
        INNER JOIN dept_tree t ON d.parent_id = t.department_id
    ),
    dept_employees AS (
        SELECT department_id, COUNT(*) AS cnt
        FROM dbo.employees WHERE is_active = 1
        GROUP BY department_id
    ),
    dept_payroll AS (
        SELECT e.department_id,
               SUM(s.base_salary) AS total_salary
        FROM dbo.employees e
        OUTER APPLY (
            SELECT TOP 1 base_salary FROM dbo.salaries
            WHERE employee_id = e.employee_id ORDER BY effective_from DESC
        ) s
        WHERE e.is_active = 1
        GROUP BY e.department_id
    )
    SELECT
        t.depth,
        t.name AS department_name,
        ISNULL(de.cnt, 0) AS active_headcount,
        ISNULL(dp.total_salary, 0) AS total_salary
    FROM dept_tree t
    LEFT JOIN dept_employees de ON t.department_id = de.department_id
    LEFT JOIN dept_payroll  dp ON t.department_id = dp.department_id
    ORDER BY t.depth, t.name;
END
GO

PRINT N'Advanced sample objects created successfully.';
GO
