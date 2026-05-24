-- ============================================================
-- POSTGRES NATIVE CONVERSION: dbo.usp_upsert_department
-- Converted from: T-SQL PROCEDURE
-- Target: Aurora PostgreSQL (PL/pgSQL)
-- ============================================================
-- CONVERSION NOTES:
-- - MERGE statement converted to INSERT ... ON CONFLICT (PostgreSQL UPSERT)
-- - Requires UNIQUE constraint on departments.name column
-- - @name -> p_name, @parent_id -> p_parent_id (PG naming convention)
-- - SET NOCOUNT ON removed (not applicable in PG)
-- - dbo schema -> public schema
-- ============================================================

CREATE OR REPLACE PROCEDURE public.usp_upsert_department(
    p_name      VARCHAR(100),
    p_parent_id INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- MERGE equivalent: INSERT with ON CONFLICT clause
    -- This is atomic and handles race conditions properly
    INSERT INTO public.departments (name, parent_id)
    VALUES (p_name, p_parent_id)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
    
    -- Note: ON CONFLICT requires a unique constraint or unique index on departments.name
    -- If the constraint doesn't exist, this will fail with:
    -- ERROR: there is no unique or exclusion constraint matching the ON CONFLICT specification
END;
$$;
