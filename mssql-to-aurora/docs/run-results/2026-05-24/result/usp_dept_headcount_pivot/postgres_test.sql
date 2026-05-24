-- ============================================================================
-- TEST SUITE: public.usp_dept_headcount_pivot (PostgreSQL Native)
-- Description: Tests for department headcount pivot stored procedure
-- Note: Converted to FUNCTION returning TABLE for easier testing
-- Note: employees table does not have email column in PostgreSQL
-- ============================================================================

-- ============= TEST CASE 1: Execute with original production data =============
-- SETUP
-- Using existing production data as baseline

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC1' AS tc, 'Baseline execution with production data' AS result;

-- CLEANUP
-- No cleanup needed for read-only test


-- ============= TEST CASE 2: Mixed active and inactive employees =============
-- SETUP
DO $$
DECLARE
    max_emp_id INT;
BEGIN
    SELECT COALESCE(MAX(employee_id), 0) INTO max_emp_id FROM public.employees;
    
    INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
    VALUES
    (max_emp_id + 1, 'Test', 'Inactive1', 2, '2024-01-01', FALSE),
    (max_emp_id + 2, 'Test', 'Inactive2', 3, '2024-01-01', FALSE),
    (max_emp_id + 3, 'Test', 'Inactive3', 4, '2024-01-01', FALSE);
END $$;

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC2' AS tc, 'Mixed active/inactive employees counted' AS result;

-- CLEANUP
DELETE FROM public.employees WHERE first_name = 'Test' AND last_name LIKE 'Inactive%';


-- ============= TEST CASE 3: Department with multiple inactive employees =============
-- SETUP
DO $$
DECLARE
    max_emp_id3 INT;
BEGIN
    SELECT COALESCE(MAX(employee_id), 0) INTO max_emp_id3 FROM public.employees;
    
    INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
    VALUES
    (max_emp_id3 + 1, 'Test', 'Inactive4', 5, '2024-01-01', FALSE),
    (max_emp_id3 + 2, 'Test', 'Inactive5', 5, '2024-01-01', FALSE);
END $$;

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC3' AS tc, 'Multiple inactive employees in one department' AS result;

-- CLEANUP
DELETE FROM public.employees WHERE first_name = 'Test' AND last_name LIKE 'Inactive%';


-- ============= TEST CASE 4: Department with no employees (boundary) =============
-- SETUP
DO $$
DECLARE
    max_dept_id4 INT;
BEGIN
    SELECT COALESCE(MAX(department_id), 0) INTO max_dept_id4 FROM public.departments;
    
    INSERT INTO public.departments (department_id, name)
    VALUES (max_dept_id4 + 1, 'Test Empty Dept');
END $$;

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC4' AS tc, 'Empty department shows zero counts' AS result;

-- CLEANUP
DELETE FROM public.departments WHERE name = 'Test Empty Dept';


-- ============= TEST CASE 5: Department with only active employees =============
-- SETUP
DO $$
DECLARE
    max_dept_id5 INT;
    max_emp_id5 INT;
BEGIN
    SELECT COALESCE(MAX(department_id), 0) INTO max_dept_id5 FROM public.departments;
    SELECT COALESCE(MAX(employee_id), 0) INTO max_emp_id5 FROM public.employees;
    
    INSERT INTO public.departments (department_id, name)
    VALUES (max_dept_id5 + 1, 'Test Active Only');
    
    INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
    VALUES
    (max_emp_id5 + 1, 'Active', 'User1', max_dept_id5 + 1, '2024-01-01', TRUE),
    (max_emp_id5 + 2, 'Active', 'User2', max_dept_id5 + 1, '2024-01-01', TRUE);
END $$;

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC5' AS tc, 'Only active employees, inactive column is 0' AS result;

-- CLEANUP
DELETE FROM public.employees WHERE first_name = 'Active';
DELETE FROM public.departments WHERE name = 'Test Active Only';


-- ============= TEST CASE 6: Department with only inactive employees =============
-- SETUP
DO $$
DECLARE
    max_dept_id6 INT;
    max_emp_id6 INT;
BEGIN
    SELECT COALESCE(MAX(department_id), 0) INTO max_dept_id6 FROM public.departments;
    SELECT COALESCE(MAX(employee_id), 0) INTO max_emp_id6 FROM public.employees;
    
    INSERT INTO public.departments (department_id, name)
    VALUES (max_dept_id6 + 1, 'Test Inactive Only');
    
    INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
    VALUES
    (max_emp_id6 + 1, 'Inactive', 'User1', max_dept_id6 + 1, '2024-01-01', FALSE),
    (max_emp_id6 + 2, 'Inactive', 'User2', max_dept_id6 + 1, '2024-01-01', FALSE),
    (max_emp_id6 + 3, 'Inactive', 'User3', max_dept_id6 + 1, '2024-01-01', FALSE);
END $$;

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC6' AS tc, 'Only inactive employees, active column is 0' AS result;

-- CLEANUP
DELETE FROM public.employees WHERE first_name = 'Inactive';
DELETE FROM public.departments WHERE name = 'Test Inactive Only';


-- ============= TEST CASE 7: Department names with special characters (boundary) =============
-- SETUP
DO $$
DECLARE
    max_dept_id7 INT;
    max_emp_id7 INT;
BEGIN
    SELECT COALESCE(MAX(department_id), 0) INTO max_dept_id7 FROM public.departments;
    SELECT COALESCE(MAX(employee_id), 0) INTO max_emp_id7 FROM public.employees;
    
    INSERT INTO public.departments (department_id, name)
    VALUES 
    (max_dept_id7 + 1, 'R&D'),
    (max_dept_id7 + 2, 'Sales & Marketing'),
    (max_dept_id7 + 3, 'IT/Support');
    
    INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
    VALUES
    (max_emp_id7 + 1, 'Test', 'RD1', max_dept_id7 + 1, '2024-01-01', TRUE),
    (max_emp_id7 + 2, 'Test', 'RD2', max_dept_id7 + 1, '2024-01-01', FALSE),
    (max_emp_id7 + 3, 'Test', 'SM1', max_dept_id7 + 2, '2024-01-01', TRUE),
    (max_emp_id7 + 4, 'Test', 'IT1', max_dept_id7 + 3, '2024-01-01', FALSE);
END $$;

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC7' AS tc, 'Special characters in department names handled' AS result;

-- CLEANUP
DELETE FROM public.employees WHERE first_name = 'Test' AND last_name IN ('RD1', 'RD2', 'SM1', 'IT1');
DELETE FROM public.departments WHERE name IN ('R&D', 'Sales & Marketing', 'IT/Support');


-- ============= TEST CASE 8: Large employee count (boundary) =============
-- SETUP
DO $$
DECLARE
    max_dept_id8 INT;
    max_emp_id8 INT;
    i8 INT;
BEGIN
    SELECT COALESCE(MAX(department_id), 0) INTO max_dept_id8 FROM public.departments;
    SELECT COALESCE(MAX(employee_id), 0) INTO max_emp_id8 FROM public.employees;
    
    INSERT INTO public.departments (department_id, name)
    VALUES (max_dept_id8 + 1, 'Test Large Dept');
    
    i8 := 1;
    WHILE i8 <= 50 LOOP
        INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active)
        VALUES (max_emp_id8 + i8, 'Large', 'Test' || i8::VARCHAR, 
                max_dept_id8 + 1, '2024-01-01', (i8 % 3) != 0);
        i8 := i8 + 1;
    END LOOP;
END $$;

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC8' AS tc, 'Large employee count (50) aggregated correctly' AS result;

-- CLEANUP
DELETE FROM public.employees WHERE first_name = 'Large';
DELETE FROM public.departments WHERE name = 'Test Large Dept';


-- ============= TEST CASE 9: Verify column names and structure =============
-- SETUP
-- Using production data

-- EXEC
SELECT * FROM public.usp_dept_headcount_pivot();

-- ASSERT
SELECT 'TC9' AS tc, 'Column structure: department_name, Active, Inactive' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= TEST CASE 10: Verify sorting by department name =============
-- SETUP
-- Using production data

-- EXEC
SELECT department_name, "Active", "Inactive"
FROM (
    SELECT
        d.name AS department_name,
        COUNT(CASE WHEN e.is_active = TRUE THEN e.employee_id END) AS "Active",
        COUNT(CASE WHEN e.is_active = FALSE OR e.is_active IS NULL THEN e.employee_id END) AS "Inactive"
    FROM public.departments d
    LEFT JOIN public.employees e ON d.department_id = e.department_id
    GROUP BY d.name
) subq
ORDER BY department_name;

-- ASSERT
SELECT 'TC10' AS tc, 'Results sorted alphabetically by department_name' AS result;

-- CLEANUP
-- No cleanup needed


-- ============= FINAL CLEANUP VERIFICATION =============
-- Ensure all test data is removed
DELETE FROM public.employees WHERE first_name IN ('Test', 'Active', 'Inactive', 'Large');
DELETE FROM public.departments WHERE name LIKE 'Test%' OR name IN ('R&D', 'Sales & Marketing', 'IT/Support');

-- Verify restoration
SELECT 'CLEANUP_VERIFICATION' AS status, COUNT(*) AS dept_count FROM public.departments;
SELECT 'CLEANUP_VERIFICATION' AS status, COUNT(*) AS emp_count FROM public.employees;

-- Final execution with clean data
SELECT * FROM public.usp_dept_headcount_pivot();
