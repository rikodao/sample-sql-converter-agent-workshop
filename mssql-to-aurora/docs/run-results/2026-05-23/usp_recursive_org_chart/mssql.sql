CREATE PROCEDURE dbo.usp_recursive_org_chart
    @root_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH org AS (
        SELECT department_id, name, parent_id, 0 AS depth, CAST(name AS NVARCHAR(MAX)) AS path
        FROM dbo.departments
        WHERE department_id = @root_id

        UNION ALL

        SELECT d.department_id, d.name, d.parent_id, o.depth + 1,
               o.path + N' > ' + d.name
        FROM dbo.departments d
        INNER JOIN org o ON d.parent_id = o.department_id
    )
    SELECT department_id, name, depth, path FROM org ORDER BY path;
END
