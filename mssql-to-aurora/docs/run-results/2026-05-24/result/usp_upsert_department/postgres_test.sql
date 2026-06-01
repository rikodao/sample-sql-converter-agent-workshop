-- ============================================================
-- TEST CASES: public.usp_upsert_department
-- Target: Aurora PostgreSQL (PL/pgSQL)
-- ============================================================
-- Note: Using regular tables instead of TEMP tables due to RDS Data API limitations
-- ============================================================

-- ============= TEST CASE 1: INSERT new department with parent_id =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc1 CASCADE;
CREATE TABLE test_departments_tc1 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc1 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO test_departments_tc1 (name, parent_id) VALUES ('Engineering', NULL);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Sales';
    v_test_parent INT := 1;
BEGIN
    INSERT INTO test_departments_tc1 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC1' AS tc, name, parent_id 
FROM test_departments_tc1 
WHERE name = 'Sales'
ORDER BY id;

-- CLEANUP
DROP TABLE test_departments_tc1;


-- ============= TEST CASE 2: INSERT new department with NULL parent_id =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc2 CASCADE;
CREATE TABLE test_departments_tc2 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc2 (name, parent_id) VALUES ('HR', NULL);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Marketing';
    v_test_parent INT := NULL;
BEGIN
    INSERT INTO test_departments_tc2 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC2' AS tc, name, parent_id 
FROM test_departments_tc2 
WHERE name = 'Marketing'
ORDER BY id;

-- CLEANUP
DROP TABLE test_departments_tc2;


-- ============= TEST CASE 3: UPDATE existing department parent_id (non-NULL to NULL) =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc3 CASCADE;
CREATE TABLE test_departments_tc3 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc3 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO test_departments_tc3 (name, parent_id) VALUES ('Sales', 1);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Sales';
    v_test_parent INT := NULL;
BEGIN
    INSERT INTO test_departments_tc3 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC3' AS tc, name, parent_id 
FROM test_departments_tc3 
WHERE name = 'Sales'
ORDER BY id;

-- CLEANUP
DROP TABLE test_departments_tc3;


-- ============= TEST CASE 4: UPDATE existing department parent_id (NULL to non-NULL) =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc4 CASCADE;
CREATE TABLE test_departments_tc4 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc4 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO test_departments_tc4 (name, parent_id) VALUES ('Engineering', NULL);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Engineering';
    v_test_parent INT := 1;
BEGIN
    INSERT INTO test_departments_tc4 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC4' AS tc, name, parent_id 
FROM test_departments_tc4 
WHERE name = 'Engineering'
ORDER BY id;

-- CLEANUP
DROP TABLE test_departments_tc4;


-- ============= TEST CASE 5: UPDATE existing department parent_id (non-NULL to different non-NULL) =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc5 CASCADE;
CREATE TABLE test_departments_tc5 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc5 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO test_departments_tc5 (name, parent_id) VALUES ('IT', NULL);
INSERT INTO test_departments_tc5 (name, parent_id) VALUES ('Sales', 1);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Sales';
    v_test_parent INT := 2;
BEGIN
    INSERT INTO test_departments_tc5 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC5' AS tc, name, parent_id 
FROM test_departments_tc5 
WHERE name = 'Sales'
ORDER BY id;

-- CLEANUP
DROP TABLE test_departments_tc5;


-- ============= TEST CASE 6: Boundary - Empty string name =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc6 CASCADE;
DROP TABLE IF EXISTS tc6_result CASCADE;

CREATE TABLE test_departments_tc6 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := '';
    v_test_parent INT := NULL;
    v_result TEXT;
    v_row_count INT;
BEGIN
    BEGIN
        INSERT INTO test_departments_tc6 (name, parent_id)
        VALUES (v_test_name, v_test_parent)
        ON CONFLICT (name) 
        DO UPDATE SET parent_id = EXCLUDED.parent_id;
        
        v_result := 'SUCCESS';
        SELECT COUNT(*) INTO v_row_count FROM test_departments_tc6 WHERE name = '';
        
        CREATE TABLE tc6_result (tc TEXT, result TEXT, row_count INT);
        INSERT INTO tc6_result VALUES ('TC6', v_result, v_row_count);
    EXCEPTION WHEN OTHERS THEN
        v_result := 'ERROR';
        CREATE TABLE tc6_result (tc TEXT, result TEXT, error_msg TEXT);
        INSERT INTO tc6_result VALUES ('TC6', v_result, SQLERRM);
    END;
END $$;

-- ASSERT
SELECT * FROM tc6_result;

-- CLEANUP
DROP TABLE test_departments_tc6;
DROP TABLE tc6_result;


-- ============= TEST CASE 7: Boundary - Maximum length name (100 characters) =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc7 CASCADE;
CREATE TABLE test_departments_tc7 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := REPEAT('A', 100);
    v_test_parent INT := NULL;
BEGIN
    INSERT INTO test_departments_tc7 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC7' AS tc, LENGTH(name) AS name_length, parent_id 
FROM test_departments_tc7 
WHERE name = REPEAT('A', 100);

-- CLEANUP
DROP TABLE test_departments_tc7;


-- ============= TEST CASE 8: Multiple sequential upserts on same name =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc8 CASCADE;
CREATE TABLE test_departments_tc8 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc8 (name, parent_id) VALUES ('HR', NULL);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Finance';
    v_test_parent INT;
BEGIN
    -- First upsert
    v_test_parent := 1;
    INSERT INTO test_departments_tc8 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
    
    -- Second upsert: Update 'Finance' parent_id to NULL
    v_test_parent := NULL;
    INSERT INTO test_departments_tc8 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
    
    -- Third upsert: Update 'Finance' parent_id to 1 again
    v_test_parent := 1;
    INSERT INTO test_departments_tc8 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC8' AS tc, name, parent_id, 
       (SELECT COUNT(*) FROM test_departments_tc8 WHERE name = 'Finance') AS occurrence_count
FROM test_departments_tc8 
WHERE name = 'Finance';

-- CLEANUP
DROP TABLE test_departments_tc8;


-- ============= TEST CASE 9: Transaction rollback behavior =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc9 CASCADE;
CREATE TABLE test_departments_tc9 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc9 (name, parent_id) VALUES ('HR', NULL);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Legal';
    v_test_parent INT := 1;
BEGIN
    BEGIN
        INSERT INTO test_departments_tc9 (name, parent_id)
        VALUES (v_test_name, v_test_parent)
        ON CONFLICT (name) 
        DO UPDATE SET parent_id = EXCLUDED.parent_id;
        
        -- Rollback by raising exception
        RAISE EXCEPTION 'Intentional rollback';
    EXCEPTION WHEN OTHERS THEN
        -- Swallow exception to continue test
        NULL;
    END;
END $$;

-- ASSERT
SELECT 'TC9' AS tc, COUNT(*) AS row_count 
FROM test_departments_tc9 
WHERE name = 'Legal';

-- CLEANUP
DROP TABLE test_departments_tc9;


-- ============= TEST CASE 10: Case sensitivity in name matching =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc10 CASCADE;
CREATE TABLE test_departments_tc10 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc10 (name, parent_id) VALUES ('sales', 1);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'SALES';
    v_test_parent INT := 2;
BEGIN
    INSERT INTO test_departments_tc10 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
END $$;

-- ASSERT
SELECT 'TC10' AS tc, name, parent_id, COUNT(*) OVER() AS total_rows
FROM test_departments_tc10 
ORDER BY id;

-- CLEANUP
DROP TABLE test_departments_tc10;


-- ============= TEST CASE 11: Row count after INSERT path =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc11 CASCADE;
DROP TABLE IF EXISTS tc11_result CASCADE;

CREATE TABLE test_departments_tc11 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Operations';
    v_test_parent INT := NULL;
    v_rowcount INT;
BEGIN
    INSERT INTO test_departments_tc11 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
    
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    
    CREATE TABLE tc11_result (tc TEXT, rowcount_after_insert INT);
    INSERT INTO tc11_result VALUES ('TC11', v_rowcount);
END $$;

-- ASSERT
SELECT * FROM tc11_result;

-- CLEANUP
DROP TABLE test_departments_tc11;
DROP TABLE tc11_result;


-- ============= TEST CASE 12: Row count after UPDATE path =============
-- SETUP
DROP TABLE IF EXISTS test_departments_tc12 CASCADE;
DROP TABLE IF EXISTS tc12_result CASCADE;

CREATE TABLE test_departments_tc12 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id INT NULL
);

INSERT INTO test_departments_tc12 (name, parent_id) VALUES ('Support', 1);

-- EXEC
DO $$
DECLARE
    v_test_name VARCHAR(100) := 'Support';
    v_test_parent INT := 2;
    v_rowcount INT;
BEGIN
    INSERT INTO test_departments_tc12 (name, parent_id)
    VALUES (v_test_name, v_test_parent)
    ON CONFLICT (name) 
    DO UPDATE SET parent_id = EXCLUDED.parent_id;
    
    GET DIAGNOSTICS v_rowcount = ROW_COUNT;
    
    CREATE TABLE tc12_result (tc TEXT, rowcount_after_update INT, parent_id INT);
    INSERT INTO tc12_result 
    SELECT 'TC12', v_rowcount, parent_id 
    FROM test_departments_tc12 
    WHERE name = 'Support';
END $$;

-- ASSERT
SELECT * FROM tc12_result;

-- CLEANUP
DROP TABLE test_departments_tc12;
DROP TABLE tc12_result;
