-- ============================================================================
-- Source: SQL Server
-- Object: dbo.fn_format_employee_name
-- Type: SCALAR FUNCTION
-- ============================================================================
-- NOTE: This is an ASSUMED definition based on common employee name formatting patterns.
--       Actual definition should be retrieved from Source RDS once connectivity is restored.
-- ============================================================================

CREATE FUNCTION dbo.fn_format_employee_name
(
    @first_name NVARCHAR(50),
    @last_name NVARCHAR(50),
    @middle_name NVARCHAR(50) = NULL
)
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @formatted_name NVARCHAR(200);
    
    -- Handle NULL cases
    IF @first_name IS NULL AND @last_name IS NULL
        RETURN NULL;
    
    -- Build formatted name: "LastName, FirstName MiddleName"
    SET @formatted_name = ISNULL(@last_name, '');
    
    IF @first_name IS NOT NULL
    BEGIN
        IF LEN(@formatted_name) > 0
            SET @formatted_name = @formatted_name + ', ';
        SET @formatted_name = @formatted_name + @first_name;
    END
    
    IF @middle_name IS NOT NULL AND LEN(LTRIM(RTRIM(@middle_name))) > 0
    BEGIN
        SET @formatted_name = @formatted_name + ' ' + @middle_name;
    END
    
    -- Trim any extra whitespace
    SET @formatted_name = LTRIM(RTRIM(@formatted_name));
    
    -- Return empty string as NULL for consistency
    IF LEN(@formatted_name) = 0
        RETURN NULL;
    
    RETURN @formatted_name;
END;
GO
