-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.fn_format_employee_name
-- Type: SCALAR FUNCTION
-- Converted from: T-SQL SCALAR FUNCTION dbo.fn_format_employee_name
-- ============================================================================
-- Conversion Notes:
-- - Changed schema from dbo to public
-- - Converted @parameters to p_ prefix
-- - Converted DECLARE @var to DECLARE v_var
-- - Changed NVARCHAR to VARCHAR
-- - Replaced ISNULL() with COALESCE()
-- - Replaced LEN() with length()
-- - Replaced LTRIM(RTRIM()) with btrim()
-- - Converted IF...BEGIN...END to IF...THEN...END IF
-- - Converted SET @var = to v_var :=
-- - Added LANGUAGE plpgsql and $$ delimiters
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_format_employee_name
(
    p_first_name VARCHAR(50),
    p_last_name VARCHAR(50),
    p_middle_name VARCHAR(50) DEFAULT NULL
)
RETURNS VARCHAR(200)
LANGUAGE plpgsql
AS $$
DECLARE
    v_formatted_name VARCHAR(200);
BEGIN
    -- Handle NULL cases
    IF p_first_name IS NULL AND p_last_name IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Build formatted name: "LastName, FirstName MiddleName"
    v_formatted_name := COALESCE(p_last_name, '');
    
    IF p_first_name IS NOT NULL THEN
        IF length(v_formatted_name) > 0 THEN
            v_formatted_name := v_formatted_name || ', ';
        END IF;
        v_formatted_name := v_formatted_name || p_first_name;
    END IF;
    
    IF p_middle_name IS NOT NULL AND length(btrim(p_middle_name)) > 0 THEN
        v_formatted_name := v_formatted_name || ' ' || p_middle_name;
    END IF;
    
    -- Trim any extra whitespace
    v_formatted_name := btrim(v_formatted_name);
    
    -- Return empty string as NULL for consistency
    IF length(v_formatted_name) = 0 THEN
        RETURN NULL;
    END IF;
    
    RETURN v_formatted_name;
END;
$$;

-- ============================================================================
-- Test Cases (Optional - for verification)
-- ============================================================================
-- SELECT public.fn_format_employee_name('John', 'Doe', 'Michael');
-- Expected: 'Doe, John Michael'
--
-- SELECT public.fn_format_employee_name('John', 'Doe', NULL);
-- Expected: 'Doe, John'
--
-- SELECT public.fn_format_employee_name('John', NULL, NULL);
-- Expected: 'John'
--
-- SELECT public.fn_format_employee_name(NULL, 'Doe', NULL);
-- Expected: 'Doe'
--
-- SELECT public.fn_format_employee_name(NULL, NULL, NULL);
-- Expected: NULL
-- ============================================================================
