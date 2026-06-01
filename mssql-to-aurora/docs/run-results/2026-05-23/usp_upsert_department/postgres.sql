CREATE OR REPLACE PROCEDURE public.usp_upsert_department(
    name_param      TEXT,
    parent_id_param INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- T-SQL MERGE を PostgreSQL の INSERT ... ON CONFLICT に変換
    INSERT INTO public.departments (name, parent_id)
    VALUES (name_param, parent_id_param)
    ON CONFLICT (name)
    DO UPDATE SET
        parent_id = EXCLUDED.parent_id;
END
$$;
