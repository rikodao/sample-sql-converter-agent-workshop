-- ============================================================
-- Object: public.usp_recursive_org_chart
-- Type: STORED PROCEDURE (converted to FUNCTION for result set)
-- Source: SQL Server (converted to PL/pgSQL)
-- Description: Recursive CTE to build organizational hierarchy
-- ============================================================
-- Note: T-SQL PROCEDURE が結果セットを返すため、
--       PostgreSQL では FUNCTION として実装する必要がある

CREATE OR REPLACE FUNCTION public.usp_recursive_org_chart(
    p_root_id INT
)
RETURNS TABLE(
    department_id INT,
    name VARCHAR,
    depth INT,
    path VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- T-SQL の SET NOCOUNT ON は PG では不要
    
    -- Recursive CTE を使用して組織階層を構築し、結果を返す
    RETURN QUERY
    WITH RECURSIVE org AS (
        SELECT 
            d.department_id, 
            d.name, 
            d.parent_id, 
            0 AS depth, 
            CAST(d.name AS VARCHAR) AS path
        FROM public.departments d
        WHERE d.department_id = p_root_id

        UNION ALL

        SELECT 
            d.department_id, 
            d.name, 
            d.parent_id, 
            o.depth + 1,
            o.path || ' > ' || d.name
        FROM public.departments d
        INNER JOIN org o ON d.parent_id = o.department_id
    )
    SELECT o.department_id, o.name, o.depth, o.path 
    FROM org o
    ORDER BY o.path;
    
END;
$$;
