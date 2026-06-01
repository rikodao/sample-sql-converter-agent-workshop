-- ============================================================================
-- Source: SQL Server RDS
-- Object: dbo.usp_calculate_employee_bonus
-- Type: STORED PROCEDURE
-- ============================================================================

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
