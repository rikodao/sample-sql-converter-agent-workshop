-- ============================================================================
-- Source: SQL Server
-- Object: dbo.fn_get_fiscal_year
-- Type: SCALAR FUNCTION
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common fiscal year function patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE FUNCTION dbo.fn_get_fiscal_year
(
    @input_date DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @fiscal_year INT;
    DECLARE @fiscal_start_month INT = 4; -- April start (common for many organizations)
    
    -- If month is >= fiscal start month, fiscal year = calendar year
    -- Otherwise, fiscal year = calendar year - 1
    IF MONTH(@input_date) >= @fiscal_start_month
        SET @fiscal_year = YEAR(@input_date);
    ELSE
        SET @fiscal_year = YEAR(@input_date) - 1;
    
    RETURN @fiscal_year;
END;
GO
