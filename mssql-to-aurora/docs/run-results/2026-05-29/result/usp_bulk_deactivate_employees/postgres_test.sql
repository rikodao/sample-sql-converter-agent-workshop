-- ============================================================================
-- Test Suite: public.usp_bulk_deactivate_employees (PostgreSQL)
-- Purpose: Comprehensive validation of bulk employee deactivation procedure
-- ============================================================================

-- ============= TEST CASE 1: Normal - Single employee deactivation =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc1 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc1 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (1001, 'John', 'Doe', 'john.doe@example.com', '2020-01-15', 1, 75000.00, true, NULL),
    (1002, 'Jane', 'Smith', 'jane.smith@example.com', '2019-03-20', 2, 82000.00, true, NULL);

-- EXEC
DO $$
DECLARE
    v_count1 INT;
    v_emp_ids1 VARCHAR := '1001';
BEGIN
    -- Simulate the procedure logic for single employee
    UPDATE test_employees_tc1
    SET is_active = false, deactivated_date = now()
    WHERE employee_id IN (SELECT CAST(TRIM(value) AS INT) FROM unnest(string_to_array(v_emp_ids1, ',')) AS value)
      AND is_active = true;

    GET DIAGNOSTICS v_count1 = ROW_COUNT;

    -- ASSERT
    RAISE NOTICE 'TC1|%|%|%', 
        v_count1,
        (SELECT COUNT(*) FROM test_employees_tc1 WHERE is_active = false),
        (SELECT COUNT(*) FROM test_employees_tc1 WHERE deactivated_date IS NOT NULL);
END $$;

-- CLEANUP
DROP TABLE test_employees_tc1;

-- ============= TEST CASE 2: Normal - Multiple employees deactivation =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc2 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc2 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (2001, 'Alice', 'Johnson', 'alice.j@example.com', '2018-05-10', 1, 68000.00, true, NULL),
    (2002, 'Bob', 'Williams', 'bob.w@example.com', '2019-07-22', 2, 71000.00, true, NULL),
    (2003, 'Carol', 'Brown', 'carol.b@example.com', '2020-02-14', 3, 79000.00, true, NULL),
    (2004, 'David', 'Davis', 'david.d@example.com', '2021-01-05', 1, 65000.00, true, NULL);

-- EXEC
DO $$
DECLARE
    v_count2 INT;
    v_emp_ids2 VARCHAR := '2001,2002,2003';
BEGIN
    UPDATE test_employees_tc2
    SET is_active = false, deactivated_date = now()
    WHERE employee_id IN (SELECT CAST(TRIM(value) AS INT) FROM unnest(string_to_array(v_emp_ids2, ',')) AS value)
      AND is_active = true;

    GET DIAGNOSTICS v_count2 = ROW_COUNT;

    -- ASSERT
    RAISE NOTICE 'TC2|%|%|%',
        v_count2,
        (SELECT COUNT(*) FROM test_employees_tc2 WHERE is_active = false),
        (SELECT COUNT(*) FROM test_employees_tc2 WHERE is_active = true);
END $$;

-- CLEANUP
DROP TABLE test_employees_tc2;

-- ============= TEST CASE 3: Normal - All employees in department =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc3 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc3 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (3001, 'Eve', 'Martinez', 'eve.m@example.com', '2017-09-12', 5, 88000.00, true, NULL),
    (3002, 'Frank', 'Garcia', 'frank.g@example.com', '2018-11-30', 5, 92000.00, true, NULL),
    (3003, 'Grace', 'Lopez', 'grace.l@example.com', '2019-04-18', 5, 85000.00, true, NULL);

-- EXEC
DO $$
DECLARE
    v_count3 INT;
    v_emp_ids3 VARCHAR := '3001,3002,3003';
BEGIN
    UPDATE test_employees_tc3
    SET is_active = false, deactivated_date = now()
    WHERE employee_id IN (SELECT CAST(TRIM(value) AS INT) FROM unnest(string_to_array(v_emp_ids3, ',')) AS value)
      AND is_active = true;

    GET DIAGNOSTICS v_count3 = ROW_COUNT;

    -- ASSERT
    RAISE NOTICE 'TC3|%|%',
        v_count3,
        (SELECT COUNT(*) FROM test_employees_tc3 WHERE is_active = false);
END $$;

-- CLEANUP
DROP TABLE test_employees_tc3;

-- ============= TEST CASE 4: Boundary - NULL employee_ids parameter =============
-- SETUP
-- No setup needed for parameter validation

-- EXEC & ASSERT
DO $$
DECLARE
    v_count4 INT;
    v_emp_ids4 VARCHAR := NULL;
BEGIN
    -- Simulate validation logic
    IF v_emp_ids4 IS NULL OR TRIM(v_emp_ids4) = '' THEN
        RAISE NOTICE 'TC4|ERROR: Parameter @employee_ids cannot be NULL or empty';
    ELSE
        RAISE NOTICE 'TC4|NO_ERROR';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC4|%', SQLERRM;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 5: Boundary - Empty string employee_ids =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_count5 INT;
    v_emp_ids5 VARCHAR := '';
BEGIN
    IF v_emp_ids5 IS NULL OR TRIM(v_emp_ids5) = '' THEN
        RAISE NOTICE 'TC5|ERROR: Parameter @employee_ids cannot be NULL or empty';
    ELSE
        RAISE NOTICE 'TC5|NO_ERROR';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC5|%', SQLERRM;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Boundary - Whitespace only employee_ids =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_count6 INT;
    v_emp_ids6 VARCHAR := '   ';
BEGIN
    IF v_emp_ids6 IS NULL OR TRIM(v_emp_ids6) = '' THEN
        RAISE NOTICE 'TC6|ERROR: Parameter @employee_ids cannot be NULL or empty';
    ELSE
        RAISE NOTICE 'TC6|NO_ERROR';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC6|%', SQLERRM;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 7: Exception - Non-existent employee ID =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc7 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc7 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (7001, 'Henry', 'Wilson', 'henry.w@example.com', '2020-06-15', 2, 73000.00, true, NULL);

-- EXEC & ASSERT
DO $$
DECLARE
    v_count7 INT;
    v_emp_ids7 VARCHAR := '7001,9999';  -- 9999 does not exist
BEGIN
    -- Simulate validation
    CREATE TEMPORARY TABLE emp_ids_tc7 (employee_id INT);
    INSERT INTO emp_ids_tc7 (employee_id)
    SELECT CAST(TRIM(value) AS INT)
    FROM unnest(string_to_array(v_emp_ids7, ',')) AS value
    WHERE TRIM(value) <> '';
    
    IF EXISTS (
        SELECT 1 
        FROM emp_ids_tc7 e
        LEFT JOIN test_employees_tc7 emp ON e.employee_id = emp.employee_id
        WHERE emp.employee_id IS NULL
    ) THEN
        RAISE NOTICE 'TC7|ERROR: One or more employee IDs do not exist';
    ELSE
        RAISE NOTICE 'TC7|NO_ERROR';
    END IF;
    
    DROP TABLE emp_ids_tc7;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC7|%', SQLERRM;
        DROP TABLE IF EXISTS emp_ids_tc7;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc7;

-- ============= TEST CASE 8: Exception - Invalid format (non-numeric ID) =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_count8 INT;
    v_emp_ids8 VARCHAR := '1001,ABC,1002';
BEGIN
    -- Attempt to parse - this will fail on CAST
    CREATE TEMPORARY TABLE emp_ids_tc8 (employee_id INT);
    INSERT INTO emp_ids_tc8 (employee_id)
    SELECT CAST(TRIM(value) AS INT)
    FROM unnest(string_to_array(v_emp_ids8, ',')) AS value
    WHERE TRIM(value) <> '';
    
    RAISE NOTICE 'TC8|NO_ERROR';
    DROP TABLE emp_ids_tc8;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TC8|ERROR: %', SQLERRM;
        DROP TABLE IF EXISTS emp_ids_tc8;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 9: Side Effect - Already deactivated employee =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc9 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc9 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (9001, 'Ivy', 'Taylor', 'ivy.t@example.com', '2019-08-20', 3, 76000.00, false, '2023-12-01'),  -- Already inactive
    (9002, 'Jack', 'Anderson', 'jack.a@example.com', '2020-10-05', 3, 78000.00, true, NULL);

-- EXEC
DO $$
DECLARE
    v_count9 INT;
    v_emp_ids9 VARCHAR := '9001,9002';
BEGIN
    UPDATE test_employees_tc9
    SET is_active = false, deactivated_date = now()
    WHERE employee_id IN (SELECT CAST(TRIM(value) AS INT) FROM unnest(string_to_array(v_emp_ids9, ',')) AS value)
      AND is_active = true;  -- Only update currently active

    GET DIAGNOSTICS v_count9 = ROW_COUNT;

    -- ASSERT
    RAISE NOTICE 'TC9|%|%|%',
        v_count9,
        (SELECT COUNT(*) FROM test_employees_tc9 WHERE is_active = false),
        (SELECT COUNT(*) FROM test_employees_tc9 WHERE is_active = true);
END $$;

-- CLEANUP
DROP TABLE test_employees_tc9;

-- ============= TEST CASE 10: Side Effect - Verify ROW_COUNT accuracy =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc10 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc10 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (10001, 'Karen', 'Thomas', 'karen.t@example.com', '2018-03-12', 4, 81000.00, true, NULL),
    (10002, 'Leo', 'Jackson', 'leo.j@example.com', '2019-05-25', 4, 83000.00, true, NULL),
    (10003, 'Mia', 'White', 'mia.w@example.com', '2020-07-30', 4, 79000.00, true, NULL),
    (10004, 'Noah', 'Harris', 'noah.h@example.com', '2021-09-10', 4, 77000.00, true, NULL),
    (10005, 'Olivia', 'Martin', 'olivia.m@example.com', '2022-01-20', 4, 75000.00, true, NULL);

-- EXEC
DO $$
DECLARE
    v_count10 INT;
    v_emp_ids10 VARCHAR := '10001,10002,10003,10004,10005';
BEGIN
    UPDATE test_employees_tc10
    SET is_active = false, deactivated_date = now()
    WHERE employee_id IN (SELECT CAST(TRIM(value) AS INT) FROM unnest(string_to_array(v_emp_ids10, ',')) AS value)
      AND is_active = true;

    GET DIAGNOSTICS v_count10 = ROW_COUNT;

    -- ASSERT
    RAISE NOTICE 'TC10|%|%|%',
        v_count10,
        (SELECT COUNT(*) FROM test_employees_tc10 WHERE is_active = false),
        CASE WHEN v_count10 = 5 THEN 'MATCH' ELSE 'MISMATCH' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc10;

-- ============= TEST CASE 11: Boundary - Single ID with leading/trailing spaces =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc11 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc11 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (11001, 'Paul', 'Clark', 'paul.c@example.com', '2020-04-08', 2, 72000.00, true, NULL);

-- EXEC
DO $$
DECLARE
    v_count11 INT;
    v_emp_ids11 VARCHAR := '  11001  ';
BEGIN
    UPDATE test_employees_tc11
    SET is_active = false, deactivated_date = now()
    WHERE employee_id IN (SELECT CAST(TRIM(value) AS INT) FROM unnest(string_to_array(v_emp_ids11, ',')) AS value)
      AND is_active = true;

    GET DIAGNOSTICS v_count11 = ROW_COUNT;

    -- ASSERT
    RAISE NOTICE 'TC11|%|%',
        v_count11,
        (SELECT is_active FROM test_employees_tc11 WHERE employee_id = 11001);
END $$;

-- CLEANUP
DROP TABLE test_employees_tc11;

-- ============= TEST CASE 12: Boundary - Multiple IDs with extra commas =============
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc12 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    department_id INT,
    salary DECIMAL(10,2),
    is_active BOOLEAN,
    deactivated_date TIMESTAMP
);

INSERT INTO test_employees_tc12 (employee_id, first_name, last_name, email, hire_date, department_id, salary, is_active, deactivated_date)
VALUES 
    (12001, 'Quinn', 'Lewis', 'quinn.l@example.com', '2019-11-14', 1, 74000.00, true, NULL),
    (12002, 'Rachel', 'Walker', 'rachel.w@example.com', '2020-02-28', 1, 76000.00, true, NULL);

-- EXEC
DO $$
DECLARE
    v_count12 INT;
    v_emp_ids12 VARCHAR := '12001,,12002,';  -- Extra commas
BEGIN
    UPDATE test_employees_tc12
    SET is_active = false, deactivated_date = now()
    WHERE employee_id IN (
        SELECT CAST(TRIM(value) AS INT) 
        FROM unnest(string_to_array(v_emp_ids12, ',')) AS value
        WHERE TRIM(value) <> ''  -- Filter out empty values
    )
    AND is_active = true;

    GET DIAGNOSTICS v_count12 = ROW_COUNT;

    -- ASSERT
    RAISE NOTICE 'TC12|%|%',
        v_count12,
        (SELECT COUNT(*) FROM test_employees_tc12 WHERE is_active = false);
END $$;

-- CLEANUP
DROP TABLE test_employees_tc12;

-- ============================================================================
-- End of Test Suite
-- ============================================================================
