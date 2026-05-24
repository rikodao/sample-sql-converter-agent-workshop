CREATE FUNCTION dbo.fn_format_employee_name(@first NVARCHAR(50), @last NVARCHAR(50))
RETURNS NVARCHAR(105)
AS
BEGIN
    IF @first IS NULL OR @last IS NULL
        RETURN N'(unknown)';
    RETURN @last + N', ' + @first;
END
