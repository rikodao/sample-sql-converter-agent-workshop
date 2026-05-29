-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_propagate_salary_raise
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common salary raise propagation patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_propagate_salary_raise
    @department_id INT = NULL,
    @raise_percentage DECIMAL(5,2) = NULL,
    @raise_amount DECIMAL(18,2) = NULL,
    @effective_date DATE = NULL,
    @reason NVARCHAR(200) = NULL,
    @affected_count INT OUTPUT,
    @total_increase DECIMAL(18,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;
    DECLARE @max_raise_percentage DECIMAL(5,2) = 20.00;
    DECLARE @min_days_since_last_raise INT = 180; -- 6 months
    
    -- Initialize output parameters
    SET @affected_count = 0;
    SET @total_increase = 0.00;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate inputs
        IF @raise_percentage IS NULL AND @raise_amount IS NULL
        BEGIN
            RAISERROR('Either raise_percentage or raise_amount must be specified.', 16, 1);
            RETURN;
        END
        
        IF @raise_percentage IS NOT NULL AND @raise_amount IS NOT NULL
        BEGIN
            RAISERROR('Cannot specify both raise_percentage and raise_amount.', 16, 1);
            RETURN;
        END
        
        IF @raise_percentage IS NOT NULL AND (@raise_percentage <= 0 OR @raise_percentage > @max_raise_percentage)
        BEGIN
            RAISERROR('Raise percentage must be between 0 and 20.', 16, 1);
            RETURN;
        END
        
        IF @raise_amount IS NOT NULL AND @raise_amount <= 0
        BEGIN
            RAISERROR('Raise amount must be greater than 0.', 16, 1);
            RETURN;
        END
        
        -- Default effective date to today if not provided
        IF @effective_date IS NULL
            SET @effective_date = CAST(GETDATE() AS DATE);
        
        -- Default reason if not provided
        IF @reason IS NULL
            SET @reason = 'Annual salary adjustment';
        
        -- Create temp table to hold raise calculations
        CREATE TABLE #raise_calc (
            employee_id INT,
            old_salary DECIMAL(18,2),
            new_salary DECIMAL(18,2),
            raise_amount DECIMAL(18,2),
            days_since_last_raise INT
        );
        
        -- Calculate raises for eligible employees
        INSERT INTO #raise_calc (
            employee_id,
            old_salary,
            new_salary,
            raise_amount,
            days_since_last_raise
        )
        SELECT 
            e.employee_id,
            e.salary AS old_salary,
            CASE 
                WHEN @raise_percentage IS NOT NULL THEN 
                    e.salary * (1 + @raise_percentage / 100.0)
                ELSE 
                    e.salary + @raise_amount
            END AS new_salary,
            CASE 
                WHEN @raise_percentage IS NOT NULL THEN 
                    e.salary * (@raise_percentage / 100.0)
                ELSE 
                    @raise_amount
            END AS raise_amount,
            DATEDIFF(DAY, ISNULL(e.last_raise_date, e.hire_date), GETDATE()) AS days_since_last_raise
        FROM dbo.employees e
        WHERE 
            -- Filter by department if provided
            (@department_id IS NULL OR e.department_id = @department_id)
            -- Only active employees
            AND ISNULL(e.is_active, 1) = 1
            -- Valid salary
            AND e.salary > 0
            -- Minimum time since last raise
            AND DATEDIFF(DAY, ISNULL(e.last_raise_date, e.hire_date), GETDATE()) >= @min_days_since_last_raise;
        
        -- Update employees table with new salaries
        UPDATE e
        SET 
            e.salary = rc.new_salary,
            e.last_raise_date = @effective_date
        FROM dbo.employees e
        INNER JOIN #raise_calc rc ON e.employee_id = rc.employee_id;
        
        -- Insert audit records into salary_history (if table exists)
        IF OBJECT_ID('dbo.salary_history', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.salary_history (
                employee_id,
                old_salary,
                new_salary,
                change_date,
                reason
            )
            SELECT 
                rc.employee_id,
                rc.old_salary,
                rc.new_salary,
                @effective_date,
                @reason
            FROM #raise_calc rc;
        END
        
        -- Get count and total increase
        SELECT 
            @affected_count = COUNT(*),
            @total_increase = ISNULL(SUM(raise_amount), 0.00)
        FROM #raise_calc;
        
        -- Clean up temp table
        DROP TABLE #raise_calc;
        
        COMMIT TRANSACTION;
        
        -- Return summary result set
        SELECT 
            @affected_count AS employees_affected,
            @total_increase AS total_salary_increase,
            @effective_date AS effective_date,
            @reason AS reason,
            GETDATE() AS processed_date;
        
    END TRY
    BEGIN CATCH
        -- Rollback transaction on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Clean up temp table if it exists
        IF OBJECT_ID('tempdb..#raise_calc') IS NOT NULL
            DROP TABLE #raise_calc;
        
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
