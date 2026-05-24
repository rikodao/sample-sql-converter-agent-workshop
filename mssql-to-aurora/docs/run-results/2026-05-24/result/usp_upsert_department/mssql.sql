-- ============================================================
-- SOURCE DDL: dbo.usp_upsert_department
-- Extracted from: Source RDS for SQL Server
-- ============================================================

CREATE PROCEDURE dbo.usp_upsert_department
    @name      NVARCHAR(100),
    @parent_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.departments AS tgt
    USING (SELECT @name AS name, @parent_id AS parent_id) AS src
    ON tgt.name = src.name
    WHEN MATCHED THEN
        UPDATE SET parent_id = src.parent_id
    WHEN NOT MATCHED THEN
        INSERT (name, parent_id) VALUES (src.name, src.parent_id);
END
