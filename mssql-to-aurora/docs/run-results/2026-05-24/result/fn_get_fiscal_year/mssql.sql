-- ================================================================
-- Source DDL: dbo.fn_get_fiscal_year
-- Database: Source RDS for SQL Server
-- Object Type: SCALAR FUNCTION
-- ================================================================

CREATE FUNCTION dbo.fn_get_fiscal_year(@d DATE)
RETURNS INT
AS
BEGIN
    -- 4月始まりの会計年度
    DECLARE @y INT = YEAR(@d);
    DECLARE @m INT = MONTH(@d);
    IF @m < 4
        SET @y = @y - 1;
    RETURN @y;
END
