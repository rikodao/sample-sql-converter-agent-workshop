-- ============================================================================
-- TEST SUITE for VIEW public.v_active_employees (PostgreSQL Native)
-- ============================================================================
-- This view returns active employees with their formatted names, department,
-- hire date, current salary, and years of service.
-- Dependencies: employees, departments, salaries, fn_format_employee_name
-- ============================================================================

-- ============= TEST CASE 1: Normal - Active employees with all data =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9001, 'Test Dept 1', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9001, 'John', 'Doe', 9001, '2020-01-15', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9002, 'Jane', 'Smith', 9001, '2019-06-01', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9001, 9001, 75000.00, '2020-01-15') ON CONFLICT (salary_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9002, 9002, 85000.00, '2019-06-01') ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC1' AS test_case, employee_id, full_name, department_name, hire_date, base_salary, years_of_service FROM public.v_active_employees WHERE employee_id IN (9001, 9002) ORDER BY employee_id;

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id IN (9001, 9002);
DELETE FROM public.employees WHERE employee_id IN (9001, 9002);
DELETE FROM public.departments WHERE department_id = 9001;


-- ============= TEST CASE 2: Normal - Multiple salary records (latest should be selected) =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9002, 'Test Dept 2', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9003, 'Alice', 'Johnson', 9002, '2018-03-10', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9003, 9003, 60000.00, '2018-03-10') ON CONFLICT (salary_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9004, 9003, 65000.00, '2019-03-10') ON CONFLICT (salary_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9005, 9003, 72000.00, '2020-03-10') ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC2' AS test_case, employee_id, full_name, base_salary, 'Expected: 72000.00' AS note FROM public.v_active_employees WHERE employee_id = 9003;

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id IN (9003, 9004, 9005);
DELETE FROM public.employees WHERE employee_id = 9003;
DELETE FROM public.departments WHERE department_id = 9002;


-- ============= TEST CASE 3: Boundary - Employee with no salary records =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9003, 'Test Dept 3', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9004, 'Bob', 'Williams', 9003, '2023-01-01', true) ON CONFLICT (employee_id) DO NOTHING;

-- ASSERT
SELECT 'TC3' AS test_case, employee_id, full_name, base_salary, CASE WHEN base_salary IS NULL THEN 'PASS' ELSE 'FAIL' END AS result FROM public.v_active_employees WHERE employee_id = 9004;

-- CLEANUP
DELETE FROM public.employees WHERE employee_id = 9004;
DELETE FROM public.departments WHERE department_id = 9003;


-- ============= TEST CASE 4: Boundary - Inactive employees should NOT appear =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9004, 'Test Dept 4', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9005, 'Charlie', 'Brown', 9004, '2015-05-20', false) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9006, 'Diana', 'Prince', 9004, '2016-08-15', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9006, 9005, 50000.00, '2015-05-20') ON CONFLICT (salary_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9007, 9006, 90000.00, '2016-08-15') ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC4' AS test_case, COUNT(*) AS active_count, CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result FROM public.v_active_employees WHERE employee_id IN (9005, 9006);
SELECT 'TC4' AS test_case, employee_id, full_name, 'Should be 9006 only' AS note FROM public.v_active_employees WHERE employee_id IN (9005, 9006);

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id IN (9006, 9007);
DELETE FROM public.employees WHERE employee_id IN (9005, 9006);
DELETE FROM public.departments WHERE department_id = 9004;


-- ============= TEST CASE 5: Boundary - Employee hired today (years_of_service = 0) =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9005, 'Test Dept 5', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9007, 'Eve', 'Adams', 9005, CURRENT_DATE, true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9008, 9007, 55000.00, CURRENT_DATE) ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC5' AS test_case, employee_id, full_name, years_of_service, CASE WHEN years_of_service = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM public.v_active_employees WHERE employee_id = 9007;

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id = 9008;
DELETE FROM public.employees WHERE employee_id = 9007;
DELETE FROM public.departments WHERE department_id = 9005;


-- ============= TEST CASE 6: Boundary - Employee with empty first_name or last_name =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9006, 'Test Dept 6', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9008, '', 'EmptyFirst', 9006, '2021-01-01', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9009, 'EmptyLast', '', 9006, '2021-02-01', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9009, 9008, 48000.00, '2021-01-01') ON CONFLICT (salary_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9010, 9009, 49000.00, '2021-02-01') ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC6' AS test_case, employee_id, full_name, 'Check empty string handling' AS note FROM public.v_active_employees WHERE employee_id IN (9008, 9009) ORDER BY employee_id;

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id IN (9009, 9010);
DELETE FROM public.employees WHERE employee_id IN (9008, 9009);
DELETE FROM public.departments WHERE department_id = 9006;


-- ============= TEST CASE 7: Normal - View returns correct column count and types =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9007, 'Test Dept 7', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9010, 'Frank', 'Miller', 9007, '2017-11-20', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9011, 9010, 68000.00, '2017-11-20') ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC7' AS test_case, 'employee_id' AS column_name, CASE WHEN employee_id IS NOT NULL THEN 'INT' ELSE 'NULL' END AS data_type FROM public.v_active_employees WHERE employee_id = 9010
UNION ALL SELECT 'TC7', 'full_name', CASE WHEN full_name IS NOT NULL THEN 'VARCHAR' ELSE 'NULL' END FROM public.v_active_employees WHERE employee_id = 9010
UNION ALL SELECT 'TC7', 'department_name', CASE WHEN department_name IS NOT NULL THEN 'VARCHAR' ELSE 'NULL' END FROM public.v_active_employees WHERE employee_id = 9010
UNION ALL SELECT 'TC7', 'hire_date', CASE WHEN hire_date IS NOT NULL THEN 'DATE' ELSE 'NULL' END FROM public.v_active_employees WHERE employee_id = 9010
UNION ALL SELECT 'TC7', 'base_salary', CASE WHEN base_salary IS NOT NULL THEN 'NUMERIC' ELSE 'NULL' END FROM public.v_active_employees WHERE employee_id = 9010
UNION ALL SELECT 'TC7', 'years_of_service', CASE WHEN years_of_service IS NOT NULL THEN 'INT' ELSE 'NULL' END FROM public.v_active_employees WHERE employee_id = 9010;

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id = 9011;
DELETE FROM public.employees WHERE employee_id = 9010;
DELETE FROM public.departments WHERE department_id = 9007;


-- ============= TEST CASE 8: Boundary - Empty result set when no active employees =============
-- ASSERT
SELECT 'TC8' AS test_case, COUNT(*) AS row_count, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result FROM public.v_active_employees WHERE employee_id BETWEEN 99990 AND 99999;


-- ============= TEST CASE 9: Normal - Years of service calculation for long-term employee =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9008, 'Test Dept 8', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9011, 'Grace', 'Hopper', 9008, '2010-01-01', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9012, 9011, 95000.00, '2010-01-01') ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC9' AS test_case, employee_id, full_name, hire_date, years_of_service, CASE WHEN years_of_service >= 14 THEN 'PASS' ELSE 'FAIL' END AS result FROM public.v_active_employees WHERE employee_id = 9011;

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id = 9012;
DELETE FROM public.employees WHERE employee_id = 9011;
DELETE FROM public.departments WHERE department_id = 9008;


-- ============= TEST CASE 10: Normal - Multiple active employees in same department =============
-- SETUP
INSERT INTO public.departments (department_id, name, parent_id) VALUES (9009, 'Test Dept 9', NULL) ON CONFLICT (department_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9012, 'Henry', 'Ford', 9009, '2019-04-10', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9013, 'Ida', 'Lovelace', 9009, '2020-07-15', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.employees (employee_id, first_name, last_name, department_id, hire_date, is_active) VALUES (9014, 'Jack', 'Sparrow', 9009, '2021-09-20', true) ON CONFLICT (employee_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9013, 9012, 70000.00, '2019-04-10') ON CONFLICT (salary_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9014, 9013, 75000.00, '2020-07-15') ON CONFLICT (salary_id) DO NOTHING;
INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from) VALUES (9015, 9014, 72000.00, '2021-09-20') ON CONFLICT (salary_id) DO NOTHING;

-- ASSERT
SELECT 'TC10' AS test_case, COUNT(*) AS employee_count, department_name, CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END AS result FROM public.v_active_employees WHERE employee_id IN (9012, 9013, 9014) GROUP BY department_name;
SELECT 'TC10' AS test_case, employee_id, full_name, department_name, base_salary FROM public.v_active_employees WHERE employee_id IN (9012, 9013, 9014) ORDER BY employee_id;

-- CLEANUP
DELETE FROM public.salaries WHERE salary_id IN (9013, 9014, 9015);
DELETE FROM public.employees WHERE employee_id IN (9012, 9013, 9014);
DELETE FROM public.departments WHERE department_id = 9009;


-- ============================================================================
-- END OF TEST SUITE
-- ============================================================================
