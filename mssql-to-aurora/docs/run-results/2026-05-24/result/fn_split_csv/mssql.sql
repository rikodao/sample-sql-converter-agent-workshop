CREATE FUNCTION dbo.fn_split_csv(@csv NVARCHAR(MAX), @sep CHAR(1))
RETURNS @result TABLE (idx INT, value NVARCHAR(200))
AS
BEGIN
    DECLARE @i INT = 1;
    DECLARE @start INT = 1;
    DECLARE @pos INT;

    IF @csv IS NULL OR LEN(@csv) = 0
        RETURN;

    SET @pos = CHARINDEX(@sep, @csv, @start);
    WHILE @pos > 0
    BEGIN
        INSERT INTO @result(idx, value) VALUES(@i, SUBSTRING(@csv, @start, @pos - @start));
        SET @i = @i + 1;
        SET @start = @pos + 1;
        SET @pos = CHARINDEX(@sep, @csv, @start);
    END
    INSERT INTO @result(idx, value) VALUES(@i, SUBSTRING(@csv, @start, LEN(@csv) - @start + 1));
    RETURN;
END
