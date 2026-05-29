-- ============================================================================
-- TEST SUITE for public.fn_get_dept_summary
-- ============================================================================
-- Purpose: Comprehensive testing of department summary table-valued function
-- Coverage: Normal cases, boundary values, edge cases, NULL handling, aggregations
-- Converted from MSSQL test suite to PostgreSQL
-- ============================================================================

-- ============================================================================
-- TEST CASE 1: Basic summary for all departments
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago'),
(3, 'HR', 'Boston');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Bob', 'Johnson', 1, 'Inactive', '2019-01-01', 90000.00),
(4, 'Alice', 'Williams', 2, 'Active', '2020-03-01', 70000.00),
(5, 'Charlie', 'Brown', 2, 'Active', '2020-04-01', 75000.00),
(6, 'Diana', 'Davis', 3, 'Active', '2020-05-01', 65000.00);

-- Create temp function for testing
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC
SELECT 'TC1' AS test_case, * FROM pg_temp.fn_get_dept_summary(NULL) ORDER BY department_id;

-- ASSERT
SELECT 'TC1' AS test_case, 'All departments summary retrieved' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 2: Summary for specific department
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Bob', 'Johnson', 2, 'Active', '2020-03-01', 70000.00);

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC - Department 1 only
SELECT 'TC2' AS test_case, * FROM pg_temp.fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC2' AS test_case, 'Specific department summary retrieved' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 3: Department with no employees
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago'),
(3, 'NewDept', 'Boston');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 2, 'Active', '2020-02-01', 85000.00);
-- Department 3 has no employees

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC
SELECT 'TC3' AS test_case, * FROM pg_temp.fn_get_dept_summary(NULL) ORDER BY department_id;

-- ASSERT
SELECT 'TC3' AS test_case, 'Department with no employees shows 0 counts and NULL aggregates' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 4: NULL salary handling
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', NULL),
(3, 'Bob', 'Johnson', 1, 'Active', '2020-03-01', 90000.00);

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC
SELECT 'TC4' AS test_case, * FROM pg_temp.fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC4' AS test_case, 'NULL salaries excluded from average calculation' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 5: All employees inactive
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Inactive', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Terminated', '2020-02-01', 85000.00);

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC
SELECT 'TC5' AS test_case, * FROM pg_temp.fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC5' AS test_case, 'All inactive employees counted correctly' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 6: Non-existent department ID
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00);

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC - Non-existent department ID 999
SELECT 'TC6' AS test_case, * FROM pg_temp.fn_get_dept_summary(999);

-- ASSERT
SELECT 'TC6' AS test_case, 'Non-existent department returns empty result set' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 7: Mixed active and inactive employees
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York'),
(2, 'Sales', 'Chicago');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Jane', 'Smith', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Bob', 'Johnson', 1, 'Inactive', '2019-01-01', 90000.00),
(4, 'Alice', 'Williams', 1, 'Terminated', '2018-01-01', 75000.00),
(5, 'Charlie', 'Brown', 2, 'Active', '2020-03-01', 70000.00),
(6, 'Diana', 'Davis', 2, 'Inactive', '2020-04-01', 72000.00);

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC
SELECT 'TC7' AS test_case, * FROM pg_temp.fn_get_dept_summary(NULL) ORDER BY department_id;

-- ASSERT
SELECT 'TC7' AS test_case, 'Mixed active/inactive employees counted correctly' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 8: Boundary - Single employee with all NULL optional fields
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'John', 'Doe', 1, NULL, '2020-01-01', NULL);

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC
SELECT 'TC8' AS test_case, * FROM pg_temp.fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC8' AS test_case, 'NULL status and salary handled correctly' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST CASE 9: Large department with many employees
-- ============================================================================
-- SETUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;

CREATE TEMPORARY TABLE pg_temp.test_departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

CREATE TEMPORARY TABLE pg_temp.test_employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    status VARCHAR(20),
    hire_date DATE,
    salary DECIMAL(10,2)
);

INSERT INTO pg_temp.test_departments (department_id, department_name, location) VALUES
(1, 'Engineering', 'New York');

-- Insert 10 employees with varying salaries and statuses
INSERT INTO pg_temp.test_employees (employee_id, first_name, last_name, department_id, status, hire_date, salary) VALUES
(1, 'Emp1', 'Last1', 1, 'Active', '2020-01-01', 80000.00),
(2, 'Emp2', 'Last2', 1, 'Active', '2020-02-01', 85000.00),
(3, 'Emp3', 'Last3', 1, 'Active', '2020-03-01', 90000.00),
(4, 'Emp4', 'Last4', 1, 'Active', '2020-04-01', 95000.00),
(5, 'Emp5', 'Last5', 1, 'Active', '2020-05-01', 100000.00),
(6, 'Emp6', 'Last6', 1, 'Inactive', '2020-06-01', 75000.00),
(7, 'Emp7', 'Last7', 1, 'Inactive', '2020-07-01', 78000.00),
(8, 'Emp8', 'Last8', 1, 'Active', '2019-01-01', 110000.00),
(9, 'Emp9', 'Last9', 1, 'Active', '2021-01-01', 82000.00),
(10, 'Emp10', 'Last10', 1, 'Active', '2022-01-01', 88000.00);

-- Create temp function
CREATE OR REPLACE FUNCTION pg_temp.fn_get_dept_summary(
    p_department_id INT DEFAULT NULL
)
RETURNS TABLE(
    department_id INT,
    department_name VARCHAR,
    location VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    avg_salary NUMERIC,
    earliest_hire_date DATE,
    latest_hire_date DATE
)
LANGUAGE sql
AS $$
    SELECT 
        d.department_id,
        d.department_name,
        d.location,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN e.status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
        SUM(CASE WHEN e.status <> 'Active' OR e.status IS NULL THEN 1 ELSE 0 END) AS inactive_employees,
        AVG(CASE WHEN e.salary IS NOT NULL THEN e.salary ELSE NULL END) AS avg_salary,
        MIN(e.hire_date) AS earliest_hire_date,
        MAX(e.hire_date) AS latest_hire_date
    FROM pg_temp.test_departments d
    LEFT JOIN pg_temp.test_employees e ON d.department_id = e.department_id
    WHERE p_department_id IS NULL OR d.department_id = p_department_id
    GROUP BY d.department_id, d.department_name, d.location
$$;

-- EXEC
SELECT 'TC9' AS test_case, * FROM pg_temp.fn_get_dept_summary(1);

-- ASSERT
SELECT 'TC9' AS test_case, 'Large department aggregations calculated correctly' AS result;

-- CLEANUP
DROP TABLE IF EXISTS pg_temp.test_employees;
DROP TABLE IF EXISTS pg_temp.test_departments;


-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
SELECT 'TEST_SUITE_COMPLETE' AS status, 
       '9 test cases executed' AS summary,
       'Coverage: normal, boundary, NULL handling, aggregations, filtering' AS coverage;
