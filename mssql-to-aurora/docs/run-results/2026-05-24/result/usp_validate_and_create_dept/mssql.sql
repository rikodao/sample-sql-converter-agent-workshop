CREATE PROCEDURE dbo.usp_validate_and_create_dept
    @name NVARCHAR(100),
    @parent_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @name IS NULL OR LTRIM(RTRIM(@name)) = N''
            THROW 51001, N'Department name cannot be empty.', 1;

        IF EXISTS (SELECT 1 FROM dbo.departments WHERE name = @name)
            THROW 51002, N'Department with same name already exists.', 1;

        IF @parent_id IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.departments WHERE department_id = @parent_id)
            THROW 51003, N'Parent department does not exist.', 1;

        INSERT INTO dbo.departments(name, parent_id) VALUES(@name, @parent_id);
    END TRY
    BEGIN CATCH
        DECLARE @err_num   INT = ERROR_NUMBER();
        DECLARE @err_sev   INT = ERROR_SEVERITY();
        DECLARE @err_state INT = ERROR_STATE();
        DECLARE @err_msg   NVARCHAR(2000) = ERROR_MESSAGE();

        -- ログ書き込みとリレイズ
        INSERT INTO dbo.audit_log(table_name, operation, primary_key)
        VALUES (N'departments_validation_failed', N'CREATE', NULL);

        ;THROW;
    END CATCH
END
