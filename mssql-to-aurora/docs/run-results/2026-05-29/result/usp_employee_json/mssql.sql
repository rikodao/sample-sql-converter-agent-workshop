-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_employee_json
-- Type: STORED PROCEDURE
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common JSON output patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE PROCEDURE dbo.usp_employee_json
    @employee_id INT = NULL,
    @department_id INT = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @json_output NVARCHAR(MAX);
    
    -- Validate parameters
    IF @employee_id IS NOT NULL AND @employee_id <= 0
    BEGIN
        RAISERROR('Invalid employee_id. Must be a positive integer.', 16, 1);
        RETURN;
    END
    
    IF @department_id IS NOT NULL AND @department_id <= 0
    BEGIN
        RAISERROR('Invalid department_id. Must be a positive integer.', 16, 1);
        RETURN;
    END
    
    -- Build JSON output using FOR JSON PATH
    SELECT 
        e.employee_id,
        e.first_name,
        e.last_name,
        e.email,
        e.phone,
        e.hire_date,
        e.salary,
        e.is_active,
        e.status,
        -- Nested department object
        (
            SELECT 
                d.department_id,
                d.department_name,
                d.location
            FROM dbo.departments d
            WHERE d.department_id = e.department_id
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS department,
        -- Nested manager object
        (
            SELECT 
                m.employee_id AS manager_id,
                m.first_name + ' ' + m.last_name AS manager_name,
                m.email AS manager_email
            FROM dbo.employees m
            WHERE m.employee_id = e.manager_id
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS manager
    FROM dbo.employees e
    WHERE 
        -- Filter by employee_id if provided
        (@employee_id IS NULL OR e.employee_id = @employee_id)
        -- Filter by department_id if provided
        AND (@department_id IS NULL OR e.department_id = @department_id)
        -- Filter by active status unless include_inactive is set
        AND (@include_inactive = 1 OR e.is_active = 1)
    ORDER BY e.employee_id
    FOR JSON PATH;
    
END;
GO
