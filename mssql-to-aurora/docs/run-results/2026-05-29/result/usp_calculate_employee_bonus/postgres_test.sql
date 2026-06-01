-- ============================================================================
-- Test Suite for: public.usp_calculate_employee_bonus (PostgreSQL)
-- ============================================================================
-- Purpose: Comprehensive test coverage for employee bonus calculation procedure
-- Test Categories:
--   - Normal cases (various performance ratings)
--   - Boundary cases (NULL values, zero salary, minimum employment)
--   - Exception cases (invalid parameters, no eligible employees)
--   - Transaction behavior (rollback on error)
--   - Side effects (UPDATE counts, INOUT parameters)
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Normal case - Calculate bonus for employee with rating 5
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc1 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc1 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1001, 'John', 'Doe', 100000.00, 5, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count1 INT := 0;
    v_total1 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1001,
        p_fiscal_year := 2024,
        p_calculated_count := v_count1,
        p_total_bonus_amount := v_total1
    );
    
    -- ASSERT
    RAISE NOTICE 'TC1|%|%|%|%',
        v_count1,
        v_total1,
        (SELECT bonus_amount FROM test_employees_tc1 WHERE employee_id = 1001),
        CASE WHEN v_total1 = 15000.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc1;

-- ============================================================================
-- TEST CASE 2: Normal case - Calculate bonus for employee with rating 4
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc2 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc2 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1002, 'Jane', 'Smith', 80000.00, 4, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count2 INT := 0;
    v_total2 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1002,
        p_fiscal_year := 2024,
        p_calculated_count := v_count2,
        p_total_bonus_amount := v_total2
    );
    
    -- ASSERT
    RAISE NOTICE 'TC2|%|%|%|%',
        v_count2,
        v_total2,
        (SELECT bonus_amount FROM test_employees_tc2 WHERE employee_id = 1002),
        CASE WHEN v_total2 = 8000.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc2;

-- ============================================================================
-- TEST CASE 3: Normal case - Calculate bonus for employee with rating 3
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc3 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc3 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1003, 'Bob', 'Johnson', 60000.00, 3, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count3 INT := 0;
    v_total3 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1003,
        p_fiscal_year := 2024,
        p_calculated_count := v_count3,
        p_total_bonus_amount := v_total3
    );
    
    -- ASSERT
    RAISE NOTICE 'TC3|%|%|%|%',
        v_count3,
        v_total3,
        (SELECT bonus_amount FROM test_employees_tc3 WHERE employee_id = 1003),
        CASE WHEN v_total3 = 3000.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc3;

-- ============================================================================
-- TEST CASE 4: Boundary case - NULL performance rating (should default to 0)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc4 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc4 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1004, 'Alice', 'Williams', 70000.00, NULL, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count4 INT := 0;
    v_total4 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1004,
        p_fiscal_year := 2024,
        p_calculated_count := v_count4,
        p_total_bonus_amount := v_total4
    );
    
    -- ASSERT
    RAISE NOTICE 'TC4|%|%|%',
        v_count4,
        v_total4,
        CASE WHEN v_total4 = 0.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc4;

-- ============================================================================
-- TEST CASE 5: Boundary case - Rating 2 (minimal bonus)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc5 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc5 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1005, 'Charlie', 'Brown', 50000.00, 2, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count5 INT := 0;
    v_total5 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1005,
        p_fiscal_year := 2024,
        p_calculated_count := v_count5,
        p_total_bonus_amount := v_total5
    );
    
    -- ASSERT
    RAISE NOTICE 'TC5|%|%|%',
        v_count5,
        v_total5,
        CASE WHEN v_total5 = 1000.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc5;

-- ============================================================================
-- TEST CASE 6: Boundary case - Rating 1 (no bonus)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc6 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc6 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1006, 'David', 'Davis', 55000.00, 1, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count6 INT := 0;
    v_total6 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1006,
        p_fiscal_year := 2024,
        p_calculated_count := v_count6,
        p_total_bonus_amount := v_total6
    );
    
    -- ASSERT
    RAISE NOTICE 'TC6|%|%|%',
        v_count6,
        v_total6,
        CASE WHEN v_total6 = 0.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc6;

-- ============================================================================
-- TEST CASE 7: Boundary case - Employee hired less than 6 months ago (ineligible)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc7 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc7 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1007, 'Eve', 'Miller', 65000.00, 4, CURRENT_DATE - INTERVAL '100 days', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count7 INT := 0;
    v_total7 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1007,
        p_fiscal_year := 2024,
        p_calculated_count := v_count7,
        p_total_bonus_amount := v_total7
    );
    
    -- ASSERT
    RAISE NOTICE 'TC7|%|%|%',
        v_count7,
        v_total7,
        CASE WHEN v_count7 = 0 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc7;

-- ============================================================================
-- TEST CASE 8: Boundary case - Inactive employee (should be excluded)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc8 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc8 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1008, 'Frank', 'Wilson', 75000.00, 5, '2023-01-01', false, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count8 INT := 0;
    v_total8 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1008,
        p_fiscal_year := 2024,
        p_calculated_count := v_count8,
        p_total_bonus_amount := v_total8
    );
    
    -- ASSERT
    RAISE NOTICE 'TC8|%|%|%',
        v_count8,
        v_total8,
        CASE WHEN v_count8 = 0 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc8;

-- ============================================================================
-- TEST CASE 9: Exception case - Invalid fiscal year (too old)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc9 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc9 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1009, 'Grace', 'Moore', 85000.00, 4, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count9 INT := 0;
    v_total9 NUMERIC(18,2) := 0.00;
    v_error_caught BOOLEAN := false;
    v_error_message TEXT;
BEGIN
    BEGIN
        CALL public.usp_calculate_employee_bonus(
            p_employee_id := 1009,
            p_fiscal_year := 1999,
            p_calculated_count := v_count9,
            p_total_bonus_amount := v_total9
        );
    EXCEPTION
        WHEN OTHERS THEN
            v_error_caught := true;
            v_error_message := SQLERRM;
    END;
    
    -- ASSERT
    IF v_error_caught AND v_error_message LIKE '%Invalid fiscal year%' THEN
        RAISE NOTICE 'TC9|PASS|%', v_error_message;
    ELSE
        RAISE NOTICE 'TC9|FAIL|NO_ERROR';
    END IF;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc9;

-- ============================================================================
-- TEST CASE 10: Exception case - Invalid fiscal year (too far in future)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc10 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc10 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1010, 'Henry', 'Taylor', 90000.00, 5, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count10 INT := 0;
    v_total10 NUMERIC(18,2) := 0.00;
    v_error_caught BOOLEAN := false;
    v_error_message TEXT;
BEGIN
    BEGIN
        CALL public.usp_calculate_employee_bonus(
            p_employee_id := 1010,
            p_fiscal_year := 2050,
            p_calculated_count := v_count10,
            p_total_bonus_amount := v_total10
        );
    EXCEPTION
        WHEN OTHERS THEN
            v_error_caught := true;
            v_error_message := SQLERRM;
    END;
    
    -- ASSERT
    IF v_error_caught AND v_error_message LIKE '%Invalid fiscal year%' THEN
        RAISE NOTICE 'TC10|PASS|%', v_error_message;
    ELSE
        RAISE NOTICE 'TC10|FAIL|NO_ERROR';
    END IF;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc10;

-- ============================================================================
-- TEST CASE 11: Normal case - Calculate for all employees (NULL employee_id)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc11 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc11 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES 
    (2001, 'User1', 'Test1', 100000.00, 5, '2023-01-01', true, 0.00, NULL, NULL),
    (2002, 'User2', 'Test2', 80000.00, 4, '2023-01-01', true, 0.00, NULL, NULL),
    (2003, 'User3', 'Test3', 60000.00, 3, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count11 INT := 0;
    v_total11 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := NULL,
        p_fiscal_year := 2024,
        p_calculated_count := v_count11,
        p_total_bonus_amount := v_total11
    );
    
    -- ASSERT
    RAISE NOTICE 'TC11|%|%|%',
        v_count11,
        v_total11,
        CASE WHEN v_count11 = 3 AND v_total11 = 26000.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc11;

-- ============================================================================
-- TEST CASE 12: Boundary case - Zero salary (should be excluded)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc12 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc12 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1012, 'Ivy', 'Anderson', 0.00, 5, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count12 INT := 0;
    v_total12 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1012,
        p_fiscal_year := 2024,
        p_calculated_count := v_count12,
        p_total_bonus_amount := v_total12
    );
    
    -- ASSERT
    RAISE NOTICE 'TC12|%|%|%',
        v_count12,
        v_total12,
        CASE WHEN v_count12 = 0 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc12;

-- ============================================================================
-- TEST CASE 13: Normal case - Default fiscal year (NULL parameter)
-- ============================================================================
-- SETUP
CREATE TEMPORARY TABLE test_employees_tc13 (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    salary NUMERIC(18,2),
    performance_rating INT,
    hire_date DATE,
    is_active BOOLEAN,
    bonus_amount NUMERIC(18,2),
    last_bonus_date TIMESTAMP,
    bonus_fiscal_year INT
);

INSERT INTO test_employees_tc13 (employee_id, first_name, last_name, salary, performance_rating, hire_date, is_active, bonus_amount, last_bonus_date, bonus_fiscal_year)
VALUES (1013, 'Jack', 'Thomas', 95000.00, 4, '2023-01-01', true, 0.00, NULL, NULL);

-- EXEC
DO $$
DECLARE
    v_count13 INT := 0;
    v_total13 NUMERIC(18,2) := 0.00;
BEGIN
    CALL public.usp_calculate_employee_bonus(
        p_employee_id := 1013,
        p_fiscal_year := NULL,
        p_calculated_count := v_count13,
        p_total_bonus_amount := v_total13
    );
    
    -- ASSERT
    RAISE NOTICE 'TC13|%|%|%|%',
        v_count13,
        v_total13,
        (SELECT bonus_fiscal_year FROM test_employees_tc13 WHERE employee_id = 1013),
        CASE WHEN v_total13 = 9500.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- CLEANUP
DROP TABLE test_employees_tc13;

-- ============================================================================
-- End of Test Suite
-- ============================================================================
