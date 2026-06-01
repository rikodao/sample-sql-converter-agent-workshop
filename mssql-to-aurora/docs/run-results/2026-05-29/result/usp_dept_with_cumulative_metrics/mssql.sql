-- ============================================================================
-- Object: dbo.usp_dept_with_cumulative_metrics
-- Type: STORED PROCEDURE
-- Description: Calculate cumulative metrics by department over time
-- ============================================================================
-- NOTE: This is a REPRESENTATIVE IMPLEMENTATION based on common patterns
--       Actual implementation should be verified against source database
-- ============================================================================

CREATE PROCEDURE dbo.usp_dept_with_cumulative_metrics
    @start_date DATETIME = NULL,
    @end_date DATETIME = NULL,
    @department_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default date range to last 12 months if not specified
    IF @start_date IS NULL
        SET @start_date = DATEADD(YEAR, -1, GETDATE());
    
    IF @end_date IS NULL
        SET @end_date = GETDATE();
    
    -- Validate date range
    IF @start_date > @end_date
    BEGIN
        RAISERROR('Start date cannot be after end date', 16, 1);
        RETURN;
    END
    
    -- Main query with cumulative metrics
    WITH EmployeeHires AS (
        SELECT 
            e.employee_id,
            e.first_name,
            e.last_name,
            e.hire_date,
            e.salary,
            e.department_id,
            d.department_name,
            d.location
        FROM dbo.employees e
        INNER JOIN dbo.departments d ON e.department_id = d.department_id
        WHERE e.hire_date BETWEEN @start_date AND @end_date
          AND (@department_id IS NULL OR e.department_id = @department_id)
          AND e.status = 'Active'
    ),
    CumulativeMetrics AS (
        SELECT 
            department_id,
            department_name,
            location,
            hire_date,
            employee_id,
            first_name,
            last_name,
            salary,
            -- Cumulative count of employees hired
            ROW_NUMBER() OVER (
                PARTITION BY department_id 
                ORDER BY hire_date, employee_id
            ) AS cumulative_employee_count,
            -- Running total of salaries
            SUM(salary) OVER (
                PARTITION BY department_id 
                ORDER BY hire_date, employee_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_salary_total,
            -- Running average of salaries
            AVG(salary) OVER (
                PARTITION BY department_id 
                ORDER BY hire_date, employee_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS cumulative_salary_avg,
            -- Department rank by hire date
            DENSE_RANK() OVER (
                ORDER BY hire_date
            ) AS hire_date_rank
        FROM EmployeeHires
    )
    SELECT 
        department_id,
        department_name,
        location,
        hire_date,
        employee_id,
        first_name + ' ' + last_name AS employee_name,
        salary,
        cumulative_employee_count,
        cumulative_salary_total,
        CAST(cumulative_salary_avg AS DECIMAL(10,2)) AS cumulative_salary_avg,
        hire_date_rank
    FROM CumulativeMetrics
    ORDER BY 
        department_id,
        hire_date,
        employee_id;
END;
GO
