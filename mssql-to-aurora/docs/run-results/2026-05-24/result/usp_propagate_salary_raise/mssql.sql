-- =============================================
-- Source: SQL Server RDS
-- Object: dbo.usp_propagate_salary_raise
-- Type: STORED PROCEDURE
-- =============================================

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
