-- =============================================
-- Object: dbo.usp_employee_json
-- Type: STORED PROCEDURE
-- Description: Retrieves employee information as JSON via OUTPUT parameter
-- =============================================

CREATE PROCEDURE dbo.usp_employee_json
    @employee_id INT,
    @json_out NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @json_out = (
        SELECT
            e.employee_id,
            e.first_name,
            e.last_name,
            e.email,
            d.name AS department_name,
            e.hire_date
        FROM dbo.employees e
        INNER JOIN dbo.departments d ON e.department_id = d.department_id
        WHERE e.employee_id = @employee_id
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    );
END
