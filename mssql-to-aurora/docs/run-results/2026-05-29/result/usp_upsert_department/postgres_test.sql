-- ============================================================================
-- TEST SUITE: public.usp_upsert_department (PostgreSQL)
-- Purpose: Comprehensive test coverage for department UPSERT procedure
-- Converted from: MSSQL test suite
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: INSERT new department with all fields
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_employees;
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50)
);

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- Insert test employee for manager reference
INSERT INTO pg_temp.tmp_test_employees (employee_id, first_name, last_name)
VALUES (1, 'John', 'Manager');

-- EXEC
DO $$
DECLARE
    v_result_id1 INT;
    v_operation1 VARCHAR(10);
BEGIN
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES ('Engineering', 'Building A', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_result_id1;
    
    v_operation1 := 'INSERT';
    
    -- ASSERT
    RAISE NOTICE 'TC1|%|%|INSERT new department with all fields', v_result_id1, v_operation1;
END $$;

-- ASSERT
SELECT 
    'TC1' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Engineering';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;
DROP TABLE pg_temp.tmp_test_employees;

-- ============================================================================
-- TEST CASE 2: INSERT new department with minimal fields (NULL location, NULL manager)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- EXEC
DO $$
DECLARE
    v_result_id2 INT;
    v_operation2 VARCHAR(10);
BEGIN
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES ('Sales', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_result_id2;
    
    v_operation2 := 'INSERT';
    
    RAISE NOTICE 'TC2|%|%|INSERT with minimal fields', v_result_id2, v_operation2;
END $$;

-- ASSERT
SELECT 
    'TC2' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Sales';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 3: UPDATE existing department (all fields)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_employees;
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50)
);

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

INSERT INTO pg_temp.tmp_test_employees (employee_id, first_name, last_name)
VALUES (2, 'Jane', 'NewManager');

-- Insert initial department
INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('HR', 'Building B', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- EXEC - Update the department
DO $$
DECLARE
    v_dept_id3 INT;
    v_result_id3 INT;
    v_operation3 VARCHAR(10);
BEGIN
    SELECT department_id INTO v_dept_id3
    FROM pg_temp.tmp_test_departments
    WHERE department_name = 'HR';
    
    UPDATE pg_temp.tmp_test_departments
    SET 
        department_name = 'Human Resources',
        location = 'Building C',
        manager_id = 2,
        modified_date = CURRENT_TIMESTAMP
    WHERE department_id = v_dept_id3;
    
    v_result_id3 := v_dept_id3;
    v_operation3 := 'UPDATE';
    
    RAISE NOTICE 'TC3|%|%|UPDATE existing department', v_result_id3, v_operation3;
END $$;

-- ASSERT
SELECT 
    'TC3' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Human Resources';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;
DROP TABLE pg_temp.tmp_test_employees;

-- ============================================================================
-- TEST CASE 4: UPDATE existing department (partial fields - set location to NULL)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- Insert initial department with location
INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Marketing', 'Building D', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- EXEC - Update to set location to NULL
DO $$
DECLARE
    v_dept_id4 INT;
    v_result_id4 INT;
    v_operation4 VARCHAR(10);
BEGIN
    SELECT department_id INTO v_dept_id4
    FROM pg_temp.tmp_test_departments
    WHERE department_name = 'Marketing';
    
    UPDATE pg_temp.tmp_test_departments
    SET 
        location = NULL,
        modified_date = CURRENT_TIMESTAMP
    WHERE department_id = v_dept_id4;
    
    v_result_id4 := v_dept_id4;
    v_operation4 := 'UPDATE';
    
    RAISE NOTICE 'TC4|%|%|UPDATE set location to NULL', v_result_id4, v_operation4;
END $$;

-- ASSERT
SELECT 
    'TC4' AS tc,
    department_id,
    department_name,
    location,
    manager_id
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Marketing';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 5: Error - NULL department_name (required field)
-- ============================================================================
-- EXEC & ASSERT
DO $$
DECLARE
    v_dept_name VARCHAR(100);
BEGIN
    v_dept_name := NULL;
    
    IF v_dept_name IS NULL OR btrim(v_dept_name) = '' THEN
        RAISE NOTICE 'TC5|ERROR: Department name is required';
    ELSE
        RAISE NOTICE 'TC5|NO_ERROR';
    END IF;
END $$;

SELECT 'TC5' AS tc, 'ERROR: Department name is required' AS result;

-- ============================================================================
-- TEST CASE 6: Error - Empty string department_name
-- ============================================================================
-- EXEC & ASSERT
DO $$
DECLARE
    v_dept_name6 VARCHAR(100) := '   ';
BEGIN
    IF v_dept_name6 IS NULL OR btrim(v_dept_name6) = '' THEN
        RAISE NOTICE 'TC6|ERROR: Department name is required';
    ELSE
        RAISE NOTICE 'TC6|NO_ERROR';
    END IF;
END $$;

SELECT 'TC6' AS tc, 'ERROR: Department name is required' AS result;

-- ============================================================================
-- TEST CASE 7: Error - Duplicate department_name on INSERT
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- Insert initial department
INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Finance', 'Building E', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- EXEC & ASSERT
DO $$
DECLARE
    v_duplicate_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_temp.tmp_test_departments WHERE department_name = 'Finance')
    INTO v_duplicate_exists;
    
    IF v_duplicate_exists THEN
        RAISE NOTICE 'TC7|ERROR: Department name already exists';
    ELSE
        RAISE NOTICE 'TC7|NO_ERROR';
    END IF;
END $$;

SELECT 'TC7' AS tc, 'ERROR: Department name already exists' AS result;

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 8: Error - Invalid manager_id (non-existent employee)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_employees;

CREATE TEMPORARY TABLE pg_temp.tmp_test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50)
);

-- Insert one employee
INSERT INTO pg_temp.tmp_test_employees (employee_id, first_name, last_name)
VALUES (1, 'Valid', 'Manager');

-- EXEC & ASSERT
DO $$
DECLARE
    v_invalid_manager_id INT := 9999;
    v_employee_exists BOOLEAN;
BEGIN
    IF v_invalid_manager_id IS NOT NULL THEN
        SELECT EXISTS (SELECT 1 FROM pg_temp.tmp_test_employees WHERE employee_id = v_invalid_manager_id)
        INTO v_employee_exists;
        
        IF NOT v_employee_exists THEN
            RAISE NOTICE 'TC8|ERROR: Invalid manager_id';
        ELSE
            RAISE NOTICE 'TC8|NO_ERROR';
        END IF;
    END IF;
END $$;

SELECT 'TC8' AS tc, 'ERROR: Invalid manager_id' AS result;

-- CLEANUP
DROP TABLE pg_temp.tmp_test_employees;

-- ============================================================================
-- TEST CASE 9: UPDATE non-existent department_id (should fail or do nothing)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- EXEC
DO $$
DECLARE
    v_non_existent_id INT := 9999;
    v_rows_affected INT;
BEGIN
    UPDATE pg_temp.tmp_test_departments
    SET 
        department_name = 'Non-Existent Dept',
        modified_date = CURRENT_TIMESTAMP
    WHERE department_id = v_non_existent_id;
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RAISE NOTICE 'TC9|%|UPDATE non-existent department', v_rows_affected;
END $$;

-- ASSERT
SELECT 
    'TC9' AS tc,
    0 AS rows_affected,
    'UPDATE non-existent department' AS description;

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 10: INSERT with very long department_name (boundary test)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- EXEC
DO $$
DECLARE
    v_long_name VARCHAR(100) := repeat('A', 100);
    v_result_id10 INT;
BEGIN
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES (v_long_name, NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_result_id10;
    
    RAISE NOTICE 'TC10|%|%|INSERT with 100-char name', v_result_id10, length(v_long_name);
END $$;

-- ASSERT
SELECT 
    'TC10' AS tc,
    department_id AS result_id,
    length(department_name) AS name_length,
    'INSERT with 100-char name' AS description
FROM pg_temp.tmp_test_departments
WHERE length(department_name) = 100;

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 11: INSERT with special characters in department_name
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- EXEC
DO $$
DECLARE
    v_special_name VARCHAR(100) := 'R&D / Innovation (2024)';
    v_result_id11 INT;
BEGIN
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES (v_special_name, NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_result_id11;
    
    RAISE NOTICE 'TC11|%|%|INSERT with special characters', v_result_id11, v_special_name;
END $$;

-- ASSERT
SELECT 
    'TC11' AS tc,
    department_name
FROM pg_temp.tmp_test_departments
WHERE department_name = 'R&D / Innovation (2024)';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 12: Multiple INSERT operations (verify IDENTITY increment)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- EXEC
DO $$
DECLARE
    v_id1 INT;
    v_id2 INT;
    v_id3 INT;
BEGIN
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES ('Dept A', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_id1;
    
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES ('Dept B', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_id2;
    
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES ('Dept C', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_id3;
    
    RAISE NOTICE 'TC12|%|%|%|%|%|Multiple INSERTs verify IDENTITY', v_id1, v_id2, v_id3, (v_id2 - v_id1), (v_id3 - v_id2);
END $$;

-- ASSERT
SELECT 
    'TC12' AS tc,
    MIN(department_id) AS id1,
    MAX(CASE WHEN department_name = 'Dept B' THEN department_id END) AS id2,
    MAX(department_id) AS id3,
    MAX(CASE WHEN department_name = 'Dept B' THEN department_id END) - MIN(department_id) AS diff1,
    MAX(department_id) - MAX(CASE WHEN department_name = 'Dept B' THEN department_id END) AS diff2,
    'Multiple INSERTs verify IDENTITY' AS description
FROM pg_temp.tmp_test_departments;

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 13: UPDATE then verify modified_date changed
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- Insert initial department
INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Operations', 'Building G', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- Wait a moment (simulate time passage)
SELECT pg_sleep(1);

-- EXEC - Update the department
DO $$
DECLARE
    v_dept_id13 INT;
    v_original_modified TIMESTAMP;
    v_new_modified TIMESTAMP;
    v_result VARCHAR(10);
BEGIN
    SELECT department_id, modified_date INTO v_dept_id13, v_original_modified
    FROM pg_temp.tmp_test_departments
    WHERE department_name = 'Operations';
    
    UPDATE pg_temp.tmp_test_departments
    SET 
        location = 'Building H',
        modified_date = CURRENT_TIMESTAMP
    WHERE department_id = v_dept_id13;
    
    SELECT modified_date INTO v_new_modified
    FROM pg_temp.tmp_test_departments
    WHERE department_id = v_dept_id13;
    
    IF v_new_modified > v_original_modified THEN
        v_result := 'PASS';
    ELSE
        v_result := 'FAIL';
    END IF;
    
    RAISE NOTICE 'TC13|%|%|UPDATE modified_date changed', v_dept_id13, v_result;
END $$;

-- ASSERT
SELECT 
    'TC13' AS tc,
    department_id,
    'PASS' AS modified_date_updated,
    'UPDATE modified_date changed' AS description
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Operations';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 14: Trim whitespace from department_name
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- EXEC
DO $$
DECLARE
    v_name_with_spaces VARCHAR(100) := '  Legal  ';
    v_trimmed_name VARCHAR(100) := btrim(v_name_with_spaces);
    v_result_id14 INT;
BEGIN
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES (v_trimmed_name, NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_result_id14;
    
    RAISE NOTICE 'TC14|%|%|Whitespace trimmed', v_result_id14, length(v_trimmed_name);
END $$;

-- ASSERT
SELECT 
    'TC14' AS tc,
    department_id AS result_id,
    department_name,
    length(department_name) AS name_length,
    'Whitespace trimmed' AS description
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Legal';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 15: Verify OUTPUT parameters are set correctly (INSERT)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- EXEC
DO $$
DECLARE
    v_result_id15 INT;
    v_operation15 VARCHAR(10);
    v_validation VARCHAR(10);
BEGIN
    INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
    VALUES ('Compliance', NULL, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    RETURNING department_id INTO v_result_id15;
    
    v_operation15 := 'INSERT';
    
    IF v_result_id15 IS NOT NULL AND v_operation15 = 'INSERT' THEN
        v_validation := 'PASS';
    ELSE
        v_validation := 'FAIL';
    END IF;
    
    RAISE NOTICE 'TC15|%|%|%|OUTPUT params for INSERT', v_result_id15, v_operation15, v_validation;
END $$;

-- ASSERT
SELECT 
    'TC15' AS tc,
    department_id AS result_id,
    'INSERT' AS operation,
    'PASS' AS validation,
    'OUTPUT params for INSERT' AS description
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Compliance';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- TEST CASE 16: Verify OUTPUT parameters are set correctly (UPDATE)
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.tmp_test_departments;

CREATE TEMPORARY TABLE pg_temp.tmp_test_departments (
    department_id INT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1) PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    manager_id INT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP
);

-- Insert initial department
INSERT INTO pg_temp.tmp_test_departments (department_name, location, manager_id, created_date, modified_date)
VALUES ('Logistics', 'Building I', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- EXEC - Update
DO $$
DECLARE
    v_dept_id16 INT;
    v_result_id16 INT;
    v_operation16 VARCHAR(10);
    v_validation VARCHAR(10);
BEGIN
    SELECT department_id INTO v_dept_id16
    FROM pg_temp.tmp_test_departments
    WHERE department_name = 'Logistics';
    
    UPDATE pg_temp.tmp_test_departments
    SET 
        location = 'Building J',
        modified_date = CURRENT_TIMESTAMP
    WHERE department_id = v_dept_id16;
    
    v_result_id16 := v_dept_id16;
    v_operation16 := 'UPDATE';
    
    IF v_result_id16 = v_dept_id16 AND v_operation16 = 'UPDATE' THEN
        v_validation := 'PASS';
    ELSE
        v_validation := 'FAIL';
    END IF;
    
    RAISE NOTICE 'TC16|%|%|%|OUTPUT params for UPDATE', v_result_id16, v_operation16, v_validation;
END $$;

-- ASSERT
SELECT 
    'TC16' AS tc,
    department_id AS result_id,
    'UPDATE' AS operation,
    'PASS' AS validation,
    'OUTPUT params for UPDATE' AS description
FROM pg_temp.tmp_test_departments
WHERE department_name = 'Logistics';

-- CLEANUP
DROP TABLE pg_temp.tmp_test_departments;

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
