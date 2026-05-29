-- ============================================================================
-- Source: SQL Server
-- Object: dbo.trg_audit_employees
-- Type: TRIGGER
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common audit trigger patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
--       
--       Common audit trigger patterns include:
--       - Logging INSERT/UPDATE/DELETE operations
--       - Recording old and new values
--       - Capturing operation type, user, and timestamp
--       - Writing to an audit table (e.g., employee_audit, audit_log)
-- ============================================================================

CREATE TRIGGER dbo.trg_audit_employees
ON dbo.employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @operation_type VARCHAR(10);
    DECLARE @current_user NVARCHAR(128) = SYSTEM_USER;
    DECLARE @current_time DATETIME = GETDATE();
    
    -- Determine operation type
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
        SET @operation_type = 'UPDATE';
    ELSE IF EXISTS (SELECT * FROM inserted)
        SET @operation_type = 'INSERT';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @operation_type = 'DELETE';
    
    -- Log DELETE operations (capture old values)
    IF @operation_type = 'DELETE'
    BEGIN
        INSERT INTO dbo.employee_audit (
            audit_id,
            employee_id,
            operation_type,
            operation_date,
            operation_user,
            old_first_name,
            old_last_name,
            old_email,
            old_department_id,
            old_salary,
            old_hire_date,
            old_is_active,
            new_first_name,
            new_last_name,
            new_email,
            new_department_id,
            new_salary,
            new_hire_date,
            new_is_active
        )
        SELECT
            NEWID(),
            d.employee_id,
            @operation_type,
            @current_time,
            @current_user,
            d.first_name,
            d.last_name,
            d.email,
            d.department_id,
            d.salary,
            d.hire_date,
            d.is_active,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
        FROM deleted d;
    END
    
    -- Log INSERT operations (capture new values)
    IF @operation_type = 'INSERT'
    BEGIN
        INSERT INTO dbo.employee_audit (
            audit_id,
            employee_id,
            operation_type,
            operation_date,
            operation_user,
            old_first_name,
            old_last_name,
            old_email,
            old_department_id,
            old_salary,
            old_hire_date,
            old_is_active,
            new_first_name,
            new_last_name,
            new_email,
            new_department_id,
            new_salary,
            new_hire_date,
            new_is_active
        )
        SELECT
            NEWID(),
            i.employee_id,
            @operation_type,
            @current_time,
            @current_user,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            i.first_name,
            i.last_name,
            i.email,
            i.department_id,
            i.salary,
            i.hire_date,
            i.is_active
        FROM inserted i;
    END
    
    -- Log UPDATE operations (capture both old and new values)
    IF @operation_type = 'UPDATE'
    BEGIN
        INSERT INTO dbo.employee_audit (
            audit_id,
            employee_id,
            operation_type,
            operation_date,
            operation_user,
            old_first_name,
            old_last_name,
            old_email,
            old_department_id,
            old_salary,
            old_hire_date,
            old_is_active,
            new_first_name,
            new_last_name,
            new_email,
            new_department_id,
            new_salary,
            new_hire_date,
            new_is_active
        )
        SELECT
            NEWID(),
            i.employee_id,
            @operation_type,
            @current_time,
            @current_user,
            d.first_name,
            d.last_name,
            d.email,
            d.department_id,
            d.salary,
            d.hire_date,
            d.is_active,
            i.first_name,
            i.last_name,
            i.email,
            i.department_id,
            i.salary,
            i.hire_date,
            i.is_active
        FROM inserted i
        INNER JOIN deleted d ON i.employee_id = d.employee_id;
    END
END;
GO
