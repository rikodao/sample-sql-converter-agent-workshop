-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.fn_split_csv
-- Type: TABLE-VALUED FUNCTION
-- Converted from: SQL Server dbo.fn_split_csv (INLINE TVF)
-- ============================================================================
-- CONVERSION NOTES:
-- - T-SQL XML-based splitting replaced with string_to_array + unnest
-- - @parameter syntax changed to p_parameter (PostgreSQL convention)
-- - NVARCHAR(MAX) mapped to TEXT
-- - LTRIM(RTRIM(...)) mapped to btrim(...)
-- - ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) replaced with row_number() over ordinality
-- - NULL check handled: NULL input returns empty result set (same as SQL Server)
-- - Empty string handling: returns empty result set (matches SQL Server behavior)
-- - Uses string_to_array for literal delimiter matching (no regex escaping needed)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_split_csv(
    p_csv_string TEXT,
    p_delimiter TEXT DEFAULT ','
)
RETURNS TABLE (
    item_id BIGINT,
    item_value TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Return empty set if input is NULL or empty (matches SQL Server behavior)
    IF p_csv_string IS NULL OR p_csv_string = '' THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY ord)::BIGINT AS item_id,
        btrim(value) AS item_value
    FROM 
        unnest(string_to_array(p_csv_string, p_delimiter)) WITH ORDINALITY AS t(value, ord);
END;
$$;

-- ============================================================================
-- FUNCTION DESCRIPTION
-- ============================================================================
-- Purpose: Splits a delimited string into a table of values
-- 
-- Parameters:
--   p_csv_string  - The delimited string to split (TEXT)
--   p_delimiter   - The delimiter character (default: ',')
--
-- Returns: Table with columns:
--   item_id     - Sequential row number (BIGINT)
--   item_value  - The extracted value (TEXT), trimmed
--
-- Behavior:
--   - NULL input returns empty result set
--   - Empty string returns empty result set
--   - Trims leading/trailing whitespace from each value
--   - Consecutive delimiters produce empty string values
--   - Delimiter is treated as literal string (not regex pattern)
--   - Compatible with PostgreSQL 9.1 and later
--
-- Example Usage:
--   SELECT * FROM public.fn_split_csv('A,B,C', ',');
--   -- Returns: (1,'A'), (2,'B'), (3,'C')
--
--   SELECT * FROM public.fn_split_csv('1|2|3|4', '|');
--   -- Returns: (1,'1'), (2,'2'), (3,'3'), (4,'4')
--
--   SELECT * FROM public.fn_split_csv('apple, banana, cherry', ',');
--   -- Returns: (1,'apple'), (2,'banana'), (3,'cherry')
--
--   SELECT * FROM public.fn_split_csv('A,,C', ',');
--   -- Returns: (1,'A'), (2,''), (3,'C')
--
--   SELECT * FROM public.fn_split_csv(NULL, ',');
--   -- Returns: (empty result set)
--
--   SELECT * FROM public.fn_split_csv('', ',');
--   -- Returns: (empty result set)
--
-- Differences from SQL Server version:
--   - Uses string_to_array + unnest instead of XML parsing
--   - Better performance (no XML overhead)
--   - Delimiter is treated as literal string (matches SQL Server behavior)
--   - More efficient memory usage for large strings
--
-- ============================================================================

COMMENT ON FUNCTION public.fn_split_csv(TEXT, TEXT) IS 
'Splits a delimited string into a table of values. Converted from SQL Server dbo.fn_split_csv.';
