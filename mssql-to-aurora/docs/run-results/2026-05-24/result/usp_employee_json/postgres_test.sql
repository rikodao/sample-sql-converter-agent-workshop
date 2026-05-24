-- =============================================
-- TEST SUITE for public.usp_employee_json
-- Target: PostgreSQL (PL/pgSQL)
-- =============================================
-- This test suite validates the stored procedure that returns employee
-- information as JSON via an INOUT parameter.
--
-- Test Categories:
-- - Normal cases: Valid employee IDs
-- - Boundary cases: NULL input, non-existent ID, edge IDs
-- - Exception cases: Invalid data types (handled by PostgreSQL)
-- - JSON format validation: Verify JSON structure and content
-- =============================================

-- ============= TEST CASE 1: Valid employee ID (normal case) =============
-- SETUP
DO $$
DECLARE
    v_json_result TEXT;
BEGIN
    -- EXEC
    CALL public.usp_employee_json(1, v_json_result);
    
    -- ASSERT
    RAISE NOTICE 'TC1|Valid employee ID|%|%|%|%|%',
        v_json_result,
        CASE WHEN v_json_result IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result LIKE '%employee_id%' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result LIKE '%first_name%' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result LIKE '%department_name%' THEN 'PASS' ELSE 'FAIL' END;
END $$;

SELECT 'TC1' AS tc, 
       'Valid employee ID' AS test_description,
       v_json_result AS json_output,
       CASE WHEN v_json_result IS NOT NULL THEN 'PASS' ELSE 'FAIL' END AS status,
       CASE WHEN v_json_result LIKE '%employee_id%' THEN 'PASS' ELSE 'FAIL' END AS has_employee_id,
       CASE WHEN v_json_result LIKE '%first_name%' THEN 'PASS' ELSE 'FAIL' END AS has_first_name,
       CASE WHEN v_json_result LIKE '%department_name%' THEN 'PASS' ELSE 'FAIL' END AS has_department_name
FROM (
    SELECT NULL::TEXT AS v_json_result
) t;

-- Actual TC1 implementation
DO $$
DECLARE
    v_json_result TEXT;
BEGIN
    CALL public.usp_employee_json(1, v_json_result);
    
    -- Create temp table to store result
    CREATE TEMP TABLE IF NOT EXISTS tc1_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT,
        has_employee_id TEXT,
        has_first_name TEXT,
        has_department_name TEXT
    );
    
    INSERT INTO tc1_result VALUES (
        'TC1',
        'Valid employee ID',
        v_json_result,
        CASE WHEN v_json_result IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result LIKE '%employee_id%' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result LIKE '%first_name%' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result LIKE '%department_name%' THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc1_result;
DROP TABLE tc1_result;

-- ============= TEST CASE 2: Another valid employee ID =============
DO $$
DECLARE
    v_json_result2 TEXT;
BEGIN
    CALL public.usp_employee_json(2, v_json_result2);
    
    CREATE TEMP TABLE IF NOT EXISTS tc2_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT
    );
    
    INSERT INTO tc2_result VALUES (
        'TC2',
        'Another valid employee ID',
        v_json_result2,
        CASE WHEN v_json_result2 IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc2_result;
DROP TABLE tc2_result;

-- ============= TEST CASE 3: Non-existent employee ID (boundary) =============
DO $$
DECLARE
    v_json_result3 TEXT;
BEGIN
    CALL public.usp_employee_json(999999, v_json_result3);
    
    CREATE TEMP TABLE IF NOT EXISTS tc3_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT
    );
    
    INSERT INTO tc3_result VALUES (
        'TC3',
        'Non-existent employee ID',
        v_json_result3,
        CASE WHEN v_json_result3 IS NULL THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc3_result;
DROP TABLE tc3_result;

-- ============= TEST CASE 4: NULL employee ID (boundary) =============
DO $$
DECLARE
    v_json_result4 TEXT;
BEGIN
    CALL public.usp_employee_json(NULL, v_json_result4);
    
    CREATE TEMP TABLE IF NOT EXISTS tc4_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT
    );
    
    INSERT INTO tc4_result VALUES (
        'TC4',
        'NULL employee ID',
        v_json_result4,
        CASE WHEN v_json_result4 IS NULL THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc4_result;
DROP TABLE tc4_result;

-- ============= TEST CASE 5: Zero employee ID (boundary) =============
DO $$
DECLARE
    v_json_result5 TEXT;
BEGIN
    CALL public.usp_employee_json(0, v_json_result5);
    
    CREATE TEMP TABLE IF NOT EXISTS tc5_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT
    );
    
    INSERT INTO tc5_result VALUES (
        'TC5',
        'Zero employee ID',
        v_json_result5,
        CASE WHEN v_json_result5 IS NULL THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc5_result;
DROP TABLE tc5_result;

-- ============= TEST CASE 6: Negative employee ID (boundary) =============
DO $$
DECLARE
    v_json_result6 TEXT;
BEGIN
    CALL public.usp_employee_json(-1, v_json_result6);
    
    CREATE TEMP TABLE IF NOT EXISTS tc6_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT
    );
    
    INSERT INTO tc6_result VALUES (
        'TC6',
        'Negative employee ID',
        v_json_result6,
        CASE WHEN v_json_result6 IS NULL THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc6_result;
DROP TABLE tc6_result;

-- ============= TEST CASE 7: Verify JSON structure with known employee =============
DO $$
DECLARE
    v_json_result7 TEXT;
    v_expected_first_name VARCHAR(100);
    v_expected_last_name VARCHAR(100);
    v_expected_email VARCHAR(255);
    v_expected_dept_name VARCHAR(100);
BEGIN
    SELECT 
        e.first_name,
        e.last_name,
        e.email,
        d.name
    INTO
        v_expected_first_name,
        v_expected_last_name,
        v_expected_email,
        v_expected_dept_name
    FROM public.employees e
    INNER JOIN public.departments d ON e.department_id = d.department_id
    WHERE e.employee_id = 1
    LIMIT 1;
    
    CALL public.usp_employee_json(1, v_json_result7);
    
    CREATE TEMP TABLE IF NOT EXISTS tc7_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        expected_first_name VARCHAR(100),
        expected_last_name VARCHAR(100),
        expected_email VARCHAR(255),
        expected_dept_name VARCHAR(100),
        first_name_match TEXT,
        last_name_match TEXT,
        email_match TEXT
    );
    
    INSERT INTO tc7_result VALUES (
        'TC7',
        'Verify JSON content matches database',
        v_json_result7,
        v_expected_first_name,
        v_expected_last_name,
        v_expected_email,
        v_expected_dept_name,
        CASE WHEN v_json_result7 LIKE '%' || v_expected_first_name || '%' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result7 LIKE '%' || v_expected_last_name || '%' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_json_result7 LIKE '%' || v_expected_email || '%' THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc7_result;
DROP TABLE tc7_result;

-- ============= TEST CASE 8: Employee without department (exception case) =============
-- SETUP
DO $$
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS temp_employees (
        employee_id INT PRIMARY KEY,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        email VARCHAR(255),
        department_id INT,
        hire_date DATE
    );

    CREATE TEMP TABLE IF NOT EXISTS temp_departments (
        department_id INT PRIMARY KEY,
        name VARCHAR(100)
    );

    INSERT INTO temp_departments (department_id, name) VALUES (1, 'Test Dept');
    INSERT INTO temp_employees (employee_id, first_name, last_name, email, department_id, hire_date)
    VALUES (9999, 'Test', 'User', 'test@example.com', 1, '2020-01-01');
    
    -- Simulate test with temp tables
    CREATE TEMP TABLE IF NOT EXISTS tc8_result (
        tc TEXT,
        test_description TEXT,
        note TEXT
    );
    
    INSERT INTO tc8_result VALUES (
        'TC8',
        'Employee with valid department in temp table',
        'Simulated test - actual procedure uses real tables'
    );
END $$;

SELECT * FROM tc8_result;
DROP TABLE IF EXISTS tc8_result;
DROP TABLE IF EXISTS temp_employees;
DROP TABLE IF EXISTS temp_departments;

-- ============= TEST CASE 9: Maximum INT value for employee_id (boundary) =============
DO $$
DECLARE
    v_json_result9 TEXT;
BEGIN
    CALL public.usp_employee_json(2147483647, v_json_result9);
    
    CREATE TEMP TABLE IF NOT EXISTS tc9_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT
    );
    
    INSERT INTO tc9_result VALUES (
        'TC9',
        'Maximum INT value for employee_id',
        v_json_result9,
        CASE WHEN v_json_result9 IS NULL THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc9_result;
DROP TABLE tc9_result;

-- ============= TEST CASE 10: Verify INOUT parameter is properly set =============
DO $$
DECLARE
    v_json_result10 TEXT := 'INITIAL_VALUE';
BEGIN
    CALL public.usp_employee_json(1, v_json_result10);
    
    CREATE TEMP TABLE IF NOT EXISTS tc10_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        status TEXT
    );
    
    INSERT INTO tc10_result VALUES (
        'TC10',
        'OUTPUT parameter properly overwrites initial value',
        v_json_result10,
        CASE WHEN v_json_result10 != 'INITIAL_VALUE' AND v_json_result10 IS NOT NULL THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc10_result;
DROP TABLE tc10_result;

-- ============= TEST CASE 11: Verify JSON is valid and parseable =============
DO $$
DECLARE
    v_json_result11 TEXT;
    v_is_valid_json BOOLEAN;
    v_parsed_json JSONB;
BEGIN
    CALL public.usp_employee_json(1, v_json_result11);
    
    -- Try to parse JSON
    BEGIN
        v_parsed_json := v_json_result11::JSONB;
        v_is_valid_json := TRUE;
    EXCEPTION WHEN OTHERS THEN
        v_is_valid_json := FALSE;
    END;
    
    CREATE TEMP TABLE IF NOT EXISTS tc11_result (
        tc TEXT,
        test_description TEXT,
        json_output TEXT,
        is_valid_json BOOLEAN,
        status TEXT
    );
    
    INSERT INTO tc11_result VALUES (
        'TC11',
        'JSON validity check',
        v_json_result11,
        v_is_valid_json,
        CASE WHEN v_is_valid_json = TRUE THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc11_result;
DROP TABLE tc11_result;

-- ============= TEST CASE 12: Parse JSON and verify field values =============
DO $$
DECLARE
    v_json_result12 TEXT;
    v_parsed_json JSONB;
BEGIN
    CALL public.usp_employee_json(1, v_json_result12);
    
    v_parsed_json := v_json_result12::JSONB;
    
    CREATE TEMP TABLE IF NOT EXISTS tc12_result (
        tc TEXT,
        test_description TEXT,
        parsed_employee_id TEXT,
        parsed_first_name TEXT,
        parsed_last_name TEXT,
        parsed_email TEXT,
        parsed_department_name TEXT,
        parsed_hire_date TEXT,
        employee_id_match TEXT
    );
    
    INSERT INTO tc12_result VALUES (
        'TC12',
        'Parse JSON and extract field values',
        v_parsed_json->>'employee_id',
        v_parsed_json->>'first_name',
        v_parsed_json->>'last_name',
        v_parsed_json->>'email',
        v_parsed_json->>'department_name',
        v_parsed_json->>'hire_date',
        CASE WHEN (v_parsed_json->>'employee_id')::INT = 1 THEN 'PASS' ELSE 'FAIL' END
    );
END $$;

SELECT * FROM tc12_result;
DROP TABLE tc12_result;
