-- ============================================================================
-- Stage 3: PostgreSQL Native Conversion
-- Object: PROCEDURE dbo.usp_dept_headcount_pivot
-- Conversion: T-SQL PIVOT → PL/pgSQL with CASE expressions
-- ============================================================================
-- 
-- Original T-SQL used PIVOT syntax which has runtime limitations in Babelfish.
-- This conversion replaces PIVOT with standard CASE expressions and GROUP BY.
--
-- Key Changes:
-- 1. PIVOT → COUNT(CASE WHEN ... END) pattern
-- 2. PROCEDURE → FUNCTION returning TABLE (for easier testing)
-- 3. Schema: dbo → public
-- 4. Column names: [Active], [Inactive] → "Active", "Inactive" (quoted for case preservation)
-- 5. Boolean comparison: is_active = 1 → is_active = TRUE (PostgreSQL boolean type)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.usp_dept_headcount_pivot()
RETURNS TABLE (
    department_name VARCHAR(100),
    "Active" BIGINT,
    "Inactive" BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.name AS department_name,
        COUNT(CASE WHEN e.is_active = TRUE THEN e.employee_id END) AS "Active",
        COUNT(CASE WHEN e.is_active = FALSE OR e.is_active IS NULL THEN e.employee_id END) AS "Inactive"
    FROM public.departments d
    LEFT JOIN public.employees e ON d.department_id = e.department_id
    GROUP BY d.name
    ORDER BY d.name;
END;
$$;

-- ============================================================================
-- Usage Example:
-- ============================================================================
-- SELECT * FROM public.usp_dept_headcount_pivot();
-- ============================================================================
