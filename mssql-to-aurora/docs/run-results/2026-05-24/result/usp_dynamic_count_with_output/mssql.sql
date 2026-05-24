CREATE PROCEDURE dbo.usp_dynamic_count_with_output
    @table_name SYSNAME,
    @filter_column SYSNAME,
    @filter_value NVARCHAR(200),
    @row_count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'SELECT @cnt = COUNT(*) FROM ' + QUOTENAME(@table_name)
        + N' WHERE ' + QUOTENAME(@filter_column) + N' = @val';

    EXEC sp_executesql @sql,
        N'@val NVARCHAR(200), @cnt INT OUTPUT',
        @val = @filter_value,
        @cnt = @row_count OUTPUT;
END
