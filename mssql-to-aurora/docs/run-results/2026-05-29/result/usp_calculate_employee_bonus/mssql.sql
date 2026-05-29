-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_calculate_employee_bonus
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common bonus calculation patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_calculate_employee_bonus
    @employee_id INT = NULL,
    @fiscal_year INT = NULL,
    @calculated_count INT OUTPUT,
    @total_bonus_amount DECIMAL(18,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;
    DECLARE @current_year INT;
    DECLARE @min_employment_days INT = 180; -- 6 months minimum
    
    -- Initialize output parameters
    SET @calculated_count = 0;
    SET @total_bonus_amount = 0.00;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Default fiscal year to current year if not provided
        IF @fiscal_year IS NULL
            SET @fiscal_year = YEAR(GETDATE());
        
        -- Validate fiscal year
        IF @fiscal_year < 2000 OR @fiscal_year > YEAR(GETDATE()) + 1
        BEGIN
            RAISERROR('Invalid fiscal year. Must be between 2000 and next year.', 16, 1);
            RETURN;
        END
        
        -- Create temp table to hold bonus calculations
        CREATE TABLE #bonus_calc (
            employee_id INT,
            salary DECIMAL(18,2),
            performance_rating INT,
            employment_days INT,
            bonus_percentage DECIMAL(5,2),
            bonus_amount DECIMAL(18,2)
        );
        
        -- Calculate bonuses for eligible employees
        INSERT INTO #bonus_calc (
            employee_id,
            salary,
            performance_rating,
            employment_days,
            bonus_percentage,
            bonus_amount
        )
        SELECT 
            e.employee_id,
            e.salary,
            ISNULL(e.performance_rating, 0) AS performance_rating,
            DATEDIFF(DAY, e.hire_date, GETDATE()) AS employment_days,
            CASE 
                WHEN ISNULL(e.performance_rating, 0) = 5 THEN 15.00
                WHEN ISNULL(e.performance_rating, 0) = 4 THEN 10.00
                WHEN ISNULL(e.performance_rating, 0) = 3 THEN 5.00
                WHEN ISNULL(e.performance_rating, 0) = 2 THEN 2.00
                ELSE 0.00
            END AS bonus_percentage,
            CASE 
                WHEN ISNULL(e.performance_rating, 0) = 5 THEN e.salary * 0.15
                WHEN ISNULL(e.performance_rating, 0) = 4 THEN e.salary * 0.10
                WHEN ISNULL(e.performance_rating, 0) = 3 THEN e.salary * 0.05
                WHEN ISNULL(e.performance_rating, 0) = 2 THEN e.salary * 0.02
                ELSE 0.00
            END AS bonus_amount
        FROM dbo.employees e
        WHERE 
            -- Filter by employee_id if provided
            (@employee_id IS NULL OR e.employee_id = @employee_id)
            -- Only active employees
            AND ISNULL(e.is_active, 1) = 1
            -- Minimum employment period
            AND DATEDIFF(DAY, e.hire_date, GETDATE()) >= @min_employment_days
            -- Valid salary
            AND e.salary > 0;
        
        -- Update employees table with calculated bonuses
        UPDATE e
        SET 
            e.bonus_amount = bc.bonus_amount,
            e.last_bonus_date = GETDATE(),
            e.bonus_fiscal_year = @fiscal_year
        FROM dbo.employees e
        INNER JOIN #bonus_calc bc ON e.employee_id = bc.employee_id;
        
        -- Get count and total
        SELECT 
            @calculated_count = COUNT(*),
            @total_bonus_amount = ISNULL(SUM(bonus_amount), 0.00)
        FROM #bonus_calc;
        
        -- Clean up temp table
        DROP TABLE #bonus_calc;
        
        COMMIT TRANSACTION;
        
        -- Return summary result set
        SELECT 
            @calculated_count AS employees_processed,
            @total_bonus_amount AS total_bonus_amount,
            @fiscal_year AS fiscal_year,
            GETDATE() AS calculation_date;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Clean up temp table if it exists
        IF OBJECT_ID('tempdb..#bonus_calc') IS NOT NULL
            DROP TABLE #bonus_calc;
        
        -- Capture error information
        SELECT 
            @error_message = ERROR_MESSAGE(),
            @error_severity = ERROR_SEVERITY(),
            @error_state = ERROR_STATE();
        
        -- Re-raise the error
        RAISERROR(@error_message, @error_severity, @error_state);
        
        RETURN;
    END CATCH
    
END;
GO
