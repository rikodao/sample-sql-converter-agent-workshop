-- =============================================
-- Object: dbo.trg_audit_employees
-- Type: TRIGGER (AFTER INSERT, UPDATE, DELETE)
-- Parent: dbo.employees
-- Description: Audit trigger that logs all DML operations on employees table
-- =============================================

CREATE TRIGGER dbo.trg_audit_employees
ON dbo.employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        SELECT 'employees', 'UPDATE', employee_id FROM inserted;
    ELSE IF EXISTS(SELECT 1 FROM inserted)
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        SELECT 'employees', 'INSERT', employee_id FROM inserted;
    ELSE IF EXISTS(SELECT 1 FROM deleted)
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        SELECT 'employees', 'DELETE', employee_id FROM deleted;
END
