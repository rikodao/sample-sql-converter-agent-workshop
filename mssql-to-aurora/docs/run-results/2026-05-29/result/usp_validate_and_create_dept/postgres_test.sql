-- ============================================================================
-- TEST SUITE: public.usp_validate_and_create_dept
-- Target: Aurora PostgreSQL (Native PL/pgSQL)
-- Purpose: Comprehensive validation and creation testing
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Normal creation with all parameters
-- ============================================================================
-- SETUP
DO $$
DECLARE
    tc1_dept_id INT;
    tc1_status VARCHAR(50);
    tc1_error VARCHAR(500);
    tc1_manager_id INT;
BEGIN
    -- Get a valid manager ID
    SELECT employee_id INTO tc1_manager_id
    FROM public.employees 
    WHERE is_active = TRUE
    ORDER BY employee_id
    LIMIT 1;

    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Department TC1',
        p_location := 'New York',
        p_manager_id := tc1_manager_id,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc1_dept_id,
        p_validation_status := tc1_status,
        p_error_message := tc1_error
    );

    -- ASSERT
    RAISE NOTICE 'TC1|Normal creation with all parameters|%|%|%|%',
        tc1_status,
        CASE WHEN tc1_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc1_error IS NULL THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc1_error, 'NULL');

    -- CLEANUP
    IF tc1_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc1_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 2: Normal creation with minimal parameters (no manager, no location)
-- ============================================================================
DO $$
DECLARE
    tc2_dept_id INT;
    tc2_status VARCHAR(50);
    tc2_error VARCHAR(500);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Department TC2',
        p_location := NULL,
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc2_dept_id,
        p_validation_status := tc2_status,
        p_error_message := tc2_error
    );

    -- ASSERT
    RAISE NOTICE 'TC2|Minimal parameters (no manager, no location)|%|%|%',
        tc2_status,
        CASE WHEN tc2_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc2_error IS NULL THEN 'PASS' ELSE 'FAIL' END;

    -- CLEANUP
    IF tc2_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc2_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 3: Normal creation with default validation thresholds
-- ============================================================================
DO $$
DECLARE
    tc3_dept_id INT;
    tc3_status VARCHAR(50);
    tc3_error VARCHAR(500);
BEGIN
    -- EXEC (using default min/max values)
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Department TC3',
        p_location := 'Boston',
        p_manager_id := NULL,
        p_new_department_id := tc3_dept_id,
        p_validation_status := tc3_status,
        p_error_message := tc3_error
    );

    -- ASSERT
    RAISE NOTICE 'TC3|Default validation thresholds|%|%',
        tc3_status,
        CASE WHEN tc3_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END;

    -- CLEANUP
    IF tc3_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc3_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 4: Boundary - Minimum length name (exactly 3 characters)
-- ============================================================================
DO $$
DECLARE
    tc4_dept_id INT;
    tc4_status VARCHAR(50);
    tc4_error VARCHAR(500);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'ABC',
        p_location := NULL,
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc4_dept_id,
        p_validation_status := tc4_status,
        p_error_message := tc4_error
    );

    -- ASSERT
    RAISE NOTICE 'TC4|Minimum length (3 chars)|%|%|%',
        tc4_status,
        CASE WHEN tc4_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc4_error, 'NULL');

    -- CLEANUP
    IF tc4_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc4_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 5: Boundary - Below minimum length (2 characters)
-- ============================================================================
DO $$
DECLARE
    tc5_dept_id INT;
    tc5_status VARCHAR(50);
    tc5_error VARCHAR(500);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'AB',
        p_location := NULL,
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc5_dept_id,
        p_validation_status := tc5_status,
        p_error_message := tc5_error
    );

    -- ASSERT
    RAISE NOTICE 'TC5|Below minimum length (2 chars)|%|%|%|%',
        tc5_status,
        CASE WHEN tc5_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc5_error LIKE '%at least%' THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc5_error, 'NULL');
END $$;

-- ============================================================================
-- TEST CASE 6: Boundary - Maximum length name (exactly 100 characters)
-- ============================================================================
DO $$
DECLARE
    tc6_dept_id INT;
    tc6_status VARCHAR(50);
    tc6_error VARCHAR(500);
    tc6_long_name VARCHAR(100);
BEGIN
    tc6_long_name := REPEAT('A', 100);

    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := tc6_long_name,
        p_location := NULL,
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc6_dept_id,
        p_validation_status := tc6_status,
        p_error_message := tc6_error
    );

    -- ASSERT
    RAISE NOTICE 'TC6|Maximum length (100 chars)|%|%|%',
        tc6_status,
        CASE WHEN tc6_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        LENGTH(tc6_long_name);

    -- CLEANUP
    IF tc6_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc6_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 7: Boundary - Above maximum length (101 characters)
-- ============================================================================
DO $$
DECLARE
    tc7_dept_id INT;
    tc7_status VARCHAR(50);
    tc7_error VARCHAR(500);
    tc7_long_name VARCHAR(110);
BEGIN
    tc7_long_name := REPEAT('B', 101);

    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := tc7_long_name,
        p_location := NULL,
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc7_dept_id,
        p_validation_status := tc7_status,
        p_error_message := tc7_error
    );

    -- ASSERT
    RAISE NOTICE 'TC7|Above maximum length (101 chars)|%|%|%|%',
        tc7_status,
        CASE WHEN tc7_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc7_error LIKE '%not exceed%' THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc7_error, 'NULL');
END $$;

-- ============================================================================
-- TEST CASE 8: Exception - NULL department name
-- ============================================================================
DO $$
DECLARE
    tc8_dept_id INT;
    tc8_status VARCHAR(50);
    tc8_error VARCHAR(500);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := NULL,
        p_location := 'Chicago',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc8_dept_id,
        p_validation_status := tc8_status,
        p_error_message := tc8_error
    );

    -- ASSERT
    RAISE NOTICE 'TC8|NULL department name|%|%|%|%',
        tc8_status,
        CASE WHEN tc8_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc8_error LIKE '%NULL%' THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc8_error, 'NULL');
END $$;

-- ============================================================================
-- TEST CASE 9: Exception - Empty string department name
-- ============================================================================
DO $$
DECLARE
    tc9_dept_id INT;
    tc9_status VARCHAR(50);
    tc9_error VARCHAR(500);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := '',
        p_location := 'Seattle',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc9_dept_id,
        p_validation_status := tc9_status,
        p_error_message := tc9_error
    );

    -- ASSERT
    RAISE NOTICE 'TC9|Empty string department name|%|%|%|%',
        tc9_status,
        CASE WHEN tc9_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc9_error LIKE '%empty%' THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc9_error, 'NULL');
END $$;

-- ============================================================================
-- TEST CASE 10: Exception - Whitespace only department name
-- ============================================================================
DO $$
DECLARE
    tc10_dept_id INT;
    tc10_status VARCHAR(50);
    tc10_error VARCHAR(500);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := '     ',
        p_location := 'Portland',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc10_dept_id,
        p_validation_status := tc10_status,
        p_error_message := tc10_error
    );

    -- ASSERT
    RAISE NOTICE 'TC10|Whitespace only department name|%|%|%|%',
        tc10_status,
        CASE WHEN tc10_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc10_error LIKE '%empty%whitespace%' THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc10_error, 'NULL');
END $$;

-- ============================================================================
-- TEST CASE 11: Exception - Duplicate department name
-- ============================================================================
DO $$
DECLARE
    tc11_dept_id1 INT;
    tc11_dept_id2 INT;
    tc11_status1 VARCHAR(50);
    tc11_status2 VARCHAR(50);
    tc11_error1 VARCHAR(500);
    tc11_error2 VARCHAR(500);
BEGIN
    -- Create first department
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Duplicate Test Dept',
        p_location := 'Miami',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc11_dept_id1,
        p_validation_status := tc11_status1,
        p_error_message := tc11_error1
    );

    -- EXEC - Try to create duplicate
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Duplicate Test Dept',
        p_location := 'Dallas',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc11_dept_id2,
        p_validation_status := tc11_status2,
        p_error_message := tc11_error2
    );

    -- ASSERT
    RAISE NOTICE 'TC11|Duplicate department name|%|%|%|%',
        tc11_status2,
        CASE WHEN tc11_dept_id2 IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc11_error2 LIKE '%already exists%' THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc11_error2, 'NULL');

    -- CLEANUP
    IF tc11_dept_id1 IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc11_dept_id1;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 12: Exception - Duplicate department name (case-insensitive)
-- ============================================================================
DO $$
DECLARE
    tc12_dept_id1 INT;
    tc12_dept_id2 INT;
    tc12_status1 VARCHAR(50);
    tc12_status2 VARCHAR(50);
    tc12_error1 VARCHAR(500);
    tc12_error2 VARCHAR(500);
BEGIN
    -- Create first department
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Case Test Dept',
        p_location := 'Austin',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc12_dept_id1,
        p_validation_status := tc12_status1,
        p_error_message := tc12_error1
    );

    -- EXEC - Try to create with different case
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'CASE TEST DEPT',
        p_location := 'Denver',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc12_dept_id2,
        p_validation_status := tc12_status2,
        p_error_message := tc12_error2
    );

    -- ASSERT
    RAISE NOTICE 'TC12|Duplicate name (case-insensitive)|%|%|%',
        tc12_status2,
        CASE WHEN tc12_dept_id2 IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc12_error2 LIKE '%already exists%' THEN 'PASS' ELSE 'FAIL' END;

    -- CLEANUP
    IF tc12_dept_id1 IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc12_dept_id1;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 13: Exception - Invalid manager_id (non-existent)
-- ============================================================================
DO $$
DECLARE
    tc13_dept_id INT;
    tc13_status VARCHAR(50);
    tc13_error VARCHAR(500);
    tc13_invalid_manager INT;
BEGIN
    -- Get a non-existent employee ID
    SELECT COALESCE(MAX(employee_id), 0) + 9999 INTO tc13_invalid_manager FROM public.employees;

    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Dept TC13',
        p_location := 'Phoenix',
        p_manager_id := tc13_invalid_manager,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc13_dept_id,
        p_validation_status := tc13_status,
        p_error_message := tc13_error
    );

    -- ASSERT
    RAISE NOTICE 'TC13|Invalid manager_id (non-existent)|%|%|%|%',
        tc13_status,
        CASE WHEN tc13_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc13_error LIKE '%Invalid manager%does not exist%' THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc13_error, 'NULL');
END $$;

-- ============================================================================
-- TEST CASE 14: Exception - Inactive manager
-- ============================================================================
DO $$
DECLARE
    tc14_dept_id INT;
    tc14_status VARCHAR(50);
    tc14_error VARCHAR(500);
    tc14_inactive_manager INT;
BEGIN
    -- Get an inactive employee ID (or skip if none exists)
    SELECT employee_id INTO tc14_inactive_manager
    FROM public.employees 
    WHERE is_active = FALSE
    ORDER BY employee_id
    LIMIT 1;

    -- If no inactive employee exists, skip this test
    IF tc14_inactive_manager IS NOT NULL THEN
        -- EXEC
        CALL public.usp_validate_and_create_dept(
            p_department_name := 'Test Dept TC14',
            p_location := 'Las Vegas',
            p_manager_id := tc14_inactive_manager,
            p_min_name_length := 3,
            p_max_name_length := 100,
            p_new_department_id := tc14_dept_id,
            p_validation_status := tc14_status,
            p_error_message := tc14_error
        );

        -- ASSERT
        RAISE NOTICE 'TC14|Inactive manager|%|%|%|%',
            tc14_status,
            CASE WHEN tc14_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
            CASE WHEN tc14_error LIKE '%active employee%' THEN 'PASS' ELSE 'FAIL' END,
            COALESCE(tc14_error, 'NULL');
    ELSE
        -- ASSERT - Test skipped
        RAISE NOTICE 'TC14|Inactive manager|SKIPPED|N/A|N/A|No inactive employees available for testing';
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 15: Boundary - Name with leading/trailing spaces (should be trimmed)
-- ============================================================================
DO $$
DECLARE
    tc15_dept_id INT;
    tc15_status VARCHAR(50);
    tc15_error VARCHAR(500);
    tc15_dept_name VARCHAR(100);
    tc15_trim_check VARCHAR(10);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := '   Trimmed Dept TC15   ',
        p_location := 'Atlanta',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc15_dept_id,
        p_validation_status := tc15_status,
        p_error_message := tc15_error
    );

    -- Get department name from table
    IF tc15_dept_id IS NOT NULL THEN
        SELECT department_name INTO tc15_dept_name
        FROM public.departments
        WHERE department_id = tc15_dept_id;
        
        tc15_trim_check := CASE WHEN tc15_dept_name = 'Trimmed Dept TC15' THEN 'PASS' ELSE 'FAIL' END;
    ELSE
        tc15_dept_name := 'NULL';
        tc15_trim_check := 'FAIL';
    END IF;

    -- ASSERT
    RAISE NOTICE 'TC15|Name with leading/trailing spaces|%|%|%|%',
        tc15_status,
        CASE WHEN tc15_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        tc15_dept_name,
        tc15_trim_check;

    -- CLEANUP
    IF tc15_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc15_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 16: Boundary - Empty location string (should be treated as NULL)
-- ============================================================================
DO $$
DECLARE
    tc16_dept_id INT;
    tc16_status VARCHAR(50);
    tc16_error VARCHAR(500);
    tc16_location VARCHAR(100);
    tc16_location_check VARCHAR(10);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Dept TC16',
        p_location := '',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc16_dept_id,
        p_validation_status := tc16_status,
        p_error_message := tc16_error
    );

    -- Get location from table
    IF tc16_dept_id IS NOT NULL THEN
        SELECT location INTO tc16_location
        FROM public.departments
        WHERE department_id = tc16_dept_id;
        
        tc16_location_check := CASE WHEN tc16_location IS NULL THEN 'PASS' ELSE 'FAIL' END;
    ELSE
        tc16_location := 'ERROR';
        tc16_location_check := 'FAIL';
    END IF;

    -- ASSERT
    RAISE NOTICE 'TC16|Empty location string|%|%|%|%',
        tc16_status,
        CASE WHEN tc16_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        COALESCE(tc16_location, 'NULL'),
        tc16_location_check;

    -- CLEANUP
    IF tc16_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc16_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 17: Transaction - Verify rollback on error
-- ============================================================================
DO $$
DECLARE
    tc17_dept_id INT;
    tc17_status VARCHAR(50);
    tc17_error VARCHAR(500);
    tc17_count_before INT;
    tc17_count_after INT;
BEGIN
    SELECT COUNT(*) INTO tc17_count_before FROM public.departments;

    -- EXEC - Try to create with invalid manager (should rollback)
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Dept TC17',
        p_location := 'Houston',
        p_manager_id := 999999,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc17_dept_id,
        p_validation_status := tc17_status,
        p_error_message := tc17_error
    );

    SELECT COUNT(*) INTO tc17_count_after FROM public.departments;

    -- ASSERT
    RAISE NOTICE 'TC17|Transaction rollback on error|%|%|%|%|%',
        tc17_status,
        tc17_count_before,
        tc17_count_after,
        CASE WHEN tc17_count_before = tc17_count_after THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc17_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ============================================================================
-- TEST CASE 18: Side effect - Verify created_date and modified_date are set
-- ============================================================================
DO $$
DECLARE
    tc18_dept_id INT;
    tc18_status VARCHAR(50);
    tc18_error VARCHAR(500);
    tc18_created_date TIMESTAMP;
    tc18_modified_date TIMESTAMP;
    tc18_seconds_since INT;
    tc18_created_check VARCHAR(10);
    tc18_modified_check VARCHAR(10);
    tc18_dates_equal_check VARCHAR(10);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Dept TC18',
        p_location := 'San Francisco',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc18_dept_id,
        p_validation_status := tc18_status,
        p_error_message := tc18_error
    );

    -- Get dates from table
    IF tc18_dept_id IS NOT NULL THEN
        SELECT created_date, modified_date 
        INTO tc18_created_date, tc18_modified_date
        FROM public.departments
        WHERE department_id = tc18_dept_id;
        
        tc18_created_check := CASE WHEN tc18_created_date IS NOT NULL THEN 'PASS' ELSE 'FAIL' END;
        tc18_modified_check := CASE WHEN tc18_modified_date IS NOT NULL THEN 'PASS' ELSE 'FAIL' END;
        tc18_dates_equal_check := CASE WHEN tc18_created_date = tc18_modified_date THEN 'PASS' ELSE 'FAIL' END;
        tc18_seconds_since := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - tc18_created_date))::INT;
    ELSE
        tc18_created_check := 'FAIL';
        tc18_modified_check := 'FAIL';
        tc18_dates_equal_check := 'FAIL';
        tc18_seconds_since := -1;
    END IF;

    -- ASSERT
    RAISE NOTICE 'TC18|Verify created_date and modified_date|%|%|%|%|%',
        tc18_status,
        tc18_created_check,
        tc18_modified_check,
        tc18_dates_equal_check,
        tc18_seconds_since;

    -- CLEANUP
    IF tc18_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc18_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 19: Side effect - Verify OUTPUT parameters are set correctly
-- ============================================================================
DO $$
DECLARE
    tc19_dept_id INT;
    tc19_status VARCHAR(50);
    tc19_error VARCHAR(500);
BEGIN
    -- EXEC
    CALL public.usp_validate_and_create_dept(
        p_department_name := 'Test Dept TC19',
        p_location := 'San Diego',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc19_dept_id,
        p_validation_status := tc19_status,
        p_error_message := tc19_error
    );

    -- ASSERT
    RAISE NOTICE 'TC19|Verify OUTPUT parameters|%|%|%|%|%|%',
        COALESCE(tc19_dept_id::TEXT, 'NULL'),
        COALESCE(tc19_status, 'NULL'),
        COALESCE(tc19_error, 'NULL'),
        CASE WHEN tc19_dept_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc19_status = 'SUCCESS' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc19_error IS NULL THEN 'PASS' ELSE 'FAIL' END;

    -- CLEANUP
    IF tc19_dept_id IS NOT NULL THEN
        DELETE FROM public.departments WHERE department_id = tc19_dept_id;
    END IF;
END $$;

-- ============================================================================
-- TEST CASE 20: Side effect - Verify OUTPUT parameters on validation failure
-- ============================================================================
DO $$
DECLARE
    tc20_dept_id INT;
    tc20_status VARCHAR(50);
    tc20_error VARCHAR(500);
BEGIN
    -- EXEC - Validation should fail (NULL name)
    CALL public.usp_validate_and_create_dept(
        p_department_name := NULL,
        p_location := 'Philadelphia',
        p_manager_id := NULL,
        p_min_name_length := 3,
        p_max_name_length := 100,
        p_new_department_id := tc20_dept_id,
        p_validation_status := tc20_status,
        p_error_message := tc20_error
    );

    -- ASSERT
    RAISE NOTICE 'TC20|OUTPUT parameters on validation failure|%|%|%|%|%|%',
        COALESCE(tc20_dept_id::TEXT, 'NULL'),
        COALESCE(tc20_status, 'NULL'),
        COALESCE(tc20_error, 'NULL'),
        CASE WHEN tc20_dept_id IS NULL THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc20_status = 'FAILED' THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN tc20_error IS NOT NULL THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
