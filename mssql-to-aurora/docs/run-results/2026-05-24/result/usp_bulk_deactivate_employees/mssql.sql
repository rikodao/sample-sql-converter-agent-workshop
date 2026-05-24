-- ============================================================
-- Source: SQL Server RDS
-- Object: dbo.usp_bulk_deactivate_employees
-- Type: STORED PROCEDURE
-- ============================================================

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
