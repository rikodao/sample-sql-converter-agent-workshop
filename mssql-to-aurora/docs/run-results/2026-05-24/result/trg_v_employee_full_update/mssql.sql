-- ============================================================
-- TRIGGER: dbo.trg_v_employee_full_update
-- Source: SQL Server (sys.sql_modules)
-- ============================================================

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
