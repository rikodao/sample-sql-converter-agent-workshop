CREATE PROCEDURE dbo.usp_search_employees_paged
    @search_term NVARCHAR(100),
    @page_no INT = 1,
    @page_size INT = 20,
    @total_rows INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Total
    SELECT @total_rows = COUNT(*)
    FROM dbo.employees e
    WHERE e.first_name LIKE N'%' + @search_term + N'%'
       OR e.last_name  LIKE N'%' + @search_term + N'%'
       OR ISNULL(e.email, N'') LIKE N'%' + @search_term + N'%';

    -- 2) Page
    SELECT
        e.employee_id,
        e.first_name + N' ' + e.last_name AS full_name,
        d.name AS department_name,
        e.email,
        ROW_NUMBER() OVER (ORDER BY e.last_name, e.first_name) AS row_num
    FROM dbo.employees e
    INNER JOIN dbo.departments d ON e.department_id = d.department_id
    WHERE e.first_name LIKE N'%' + @search_term + N'%'
       OR e.last_name  LIKE N'%' + @search_term + N'%'
       OR ISNULL(e.email, N'') LIKE N'%' + @search_term + N'%'
    ORDER BY e.last_name, e.first_name
    OFFSET (@page_no - 1) * @page_size ROWS
    FETCH NEXT @page_size ROWS ONLY;
END
