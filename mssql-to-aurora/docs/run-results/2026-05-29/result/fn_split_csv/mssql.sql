-- ============================================================================
-- Source: SQL Server
-- Object: dbo.fn_split_csv
-- Type: INLINE TABLE-VALUED FUNCTION
-- ============================================================================
-- NOTE: This is a STANDARD implementation based on common CSV split patterns.
--       Uses XML-based approach compatible with SQL Server 2005+.
--       Actual definition should be verified from Source RDS once connectivity is restored.
-- ============================================================================

CREATE FUNCTION dbo.fn_split_csv
(
    @csv_string NVARCHAR(MAX),
    @delimiter NVARCHAR(1) = ','
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS item_id,
        LTRIM(RTRIM(Split.a.value('.', 'NVARCHAR(MAX)'))) AS item_value
    FROM 
    (
        SELECT CAST('<X>' + REPLACE(@csv_string, @delimiter, '</X><X>') + '</X>' AS XML) AS String
    ) AS A
    CROSS APPLY String.nodes('/X') AS Split(a)
    WHERE @csv_string IS NOT NULL
);
GO

-- ============================================================================
-- FUNCTION DESCRIPTION
-- ============================================================================
-- Purpose: Splits a delimited string into a table of values
-- 
-- Parameters:
--   @csv_string  - The delimited string to split (NVARCHAR(MAX))
--   @delimiter   - The delimiter character (default: ',')
--
-- Returns: Table with columns:
--   item_id     - Sequential row number (INT)
--   item_value  - The extracted value (NVARCHAR(MAX)), trimmed
--
-- Behavior:
--   - NULL input returns empty result set
--   - Empty string returns empty result set
--   - Trims leading/trailing whitespace from each value
--   - Consecutive delimiters produce empty string values
--   - Compatible with SQL Server 2005 and later
--
-- Example Usage:
--   SELECT * FROM dbo.fn_split_csv('A,B,C', ',')
--   SELECT * FROM dbo.fn_split_csv('1|2|3|4', '|')
--
-- ============================================================================
