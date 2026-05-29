-- ============================================================================
-- Source: SQL Server
-- Object: dbo.usp_recursive_org_chart
-- Type: STORED PROCEDURE
-- ============================================================================
-- ⚠️  WARNING: This is an ASSUMED definition based on common organizational
--    hierarchy patterns. Actual definition should be retrieved from Source RDS
--    once connectivity is restored.
-- ============================================================================
-- Purpose: Retrieve organizational hierarchy starting from a given employee
--          or from top-level management, showing reporting relationships
-- ============================================================================

CREATE PROCEDURE dbo.usp_recursive_org_chart
    @root_employee_id INT = NULL,
    @max_depth INT = NULL,
    @include_inactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;
    
    BEGIN TRY
        -- Validate inputs
        IF @root_employee_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM dbo.employees WHERE employee_id = @root_employee_id
        )
        BEGIN
            RAISERROR('Employee ID %d does not exist.', 16, 1, @root_employee_id);
            RETURN;
        END
        
        -- Default max depth to unlimited (NULL means no limit)
        -- If specified, must be positive
        IF @max_depth IS NOT NULL AND @max_depth <= 0
        BEGIN
            RAISERROR('Max depth must be a positive integer.', 16, 1);
            RETURN;
        END
        
        -- Recursive CTE to build organizational hierarchy
        ;WITH OrgHierarchy AS (
            -- Anchor: Start with root employee(s)
            SELECT 
                e.employee_id,
                e.first_name,
                e.last_name,
                e.job_title,
                e.department_id,
                e.manager_id,
                e.hire_date,
                e.is_active,
                CAST(e.last_name + ', ' + e.first_name AS NVARCHAR(1000)) AS full_name,
                0 AS level,
                CAST('/' + CAST(e.employee_id AS VARCHAR(10)) + '/' AS VARCHAR(1000)) AS path,
                CAST(e.last_name + ', ' + e.first_name AS NVARCHAR(1000)) AS sort_path
            FROM dbo.employees e
            WHERE 
                -- If root_employee_id specified, start there
                -- Otherwise, start with top-level (manager_id IS NULL)
                (
                    (@root_employee_id IS NOT NULL AND e.employee_id = @root_employee_id)
                    OR
                    (@root_employee_id IS NULL AND e.manager_id IS NULL)
                )
                -- Filter by active status if requested
                AND (
                    @include_inactive = 1 
                    OR ISNULL(e.is_active, 1) = 1
                )
            
            UNION ALL
            
            -- Recursive: Get direct reports
            SELECT 
                e.employee_id,
                e.first_name,
                e.last_name,
                e.job_title,
                e.department_id,
                e.manager_id,
                e.hire_date,
                e.is_active,
                CAST(e.last_name + ', ' + e.first_name AS NVARCHAR(1000)) AS full_name,
                oh.level + 1 AS level,
                CAST(oh.path + CAST(e.employee_id AS VARCHAR(10)) + '/' AS VARCHAR(1000)) AS path,
                CAST(oh.sort_path + ' > ' + e.last_name + ', ' + e.first_name AS NVARCHAR(1000)) AS sort_path
            FROM dbo.employees e
            INNER JOIN OrgHierarchy oh ON e.manager_id = oh.employee_id
            WHERE 
                -- Respect max_depth if specified
                (@max_depth IS NULL OR oh.level < @max_depth)
                -- Filter by active status if requested
                AND (
                    @include_inactive = 1 
                    OR ISNULL(e.is_active, 1) = 1
                )
        )
        -- Return the complete hierarchy
        SELECT 
            oh.employee_id,
            oh.first_name,
            oh.last_name,
            oh.full_name,
            oh.job_title,
            oh.department_id,
            d.department_name,
            oh.manager_id,
            m.first_name AS manager_first_name,
            m.last_name AS manager_last_name,
            CAST(m.last_name + ', ' + m.first_name AS NVARCHAR(200)) AS manager_full_name,
            oh.hire_date,
            oh.is_active,
            oh.level,
            oh.path,
            oh.sort_path,
            -- Calculate direct report count
            (
                SELECT COUNT(*) 
                FROM dbo.employees e2 
                WHERE e2.manager_id = oh.employee_id
                AND (@include_inactive = 1 OR ISNULL(e2.is_active, 1) = 1)
            ) AS direct_report_count
        FROM OrgHierarchy oh
        LEFT JOIN dbo.employees m ON oh.manager_id = m.employee_id
        LEFT JOIN dbo.departments d ON oh.department_id = d.department_id
        ORDER BY oh.sort_path;
        
    END TRY
    BEGIN CATCH
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
