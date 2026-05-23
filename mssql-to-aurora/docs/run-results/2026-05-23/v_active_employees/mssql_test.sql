-- ============================================================================
-- TEST SUITE: VIEW dbo.v_active_employees
-- Target: SQL Server
-- Note: Uses IDENTITY_INSERT for explicit ID assignment
-- ============================================================================

-- ============================================================================
-- SETUP: テストデータ準備
-- ============================================================================

-- 既存テストデータのクリーンアップ
SET IDENTITY_INSERT dbo.salaries ON;
DELETE FROM dbo.salaries WHERE salary_id >= 90000;
SET IDENTITY_INSERT dbo.salaries OFF;

SET IDENTITY_INSERT dbo.employees ON;
DELETE FROM dbo.employees WHERE employee_id >= 9000;
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.departments ON;
DELETE FROM dbo.departments WHERE department_id >= 9000;
SET IDENTITY_INSERT dbo.departments OFF;

-- テスト用部署作成
SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (9001, N'Test Department A', NULL, GETDATE()),
    (9002, N'Test Department B', NULL, GETDATE()),
    (9003, N'Test Department C', NULL, GETDATE());
SET IDENTITY_INSERT dbo.departments OFF;

-- テスト用従業員作成
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES
    -- 正常系: アクティブ従業員（給与あり）
    (9001, 9001, N'John', N'Doe', '2020-01-15', 1, N'john.doe@test.com', GETDATE()),
    (9002, 9001, N'Jane', N'Smith', '2019-06-01', 1, N'jane.smith@test.com', GETDATE()),
    (9003, 9002, N'Bob', N'Johnson', '2021-03-10', 1, N'bob.johnson@test.com', GETDATE()),
    
    -- 境界値: 給与情報なし
    (9004, 9002, N'Alice', N'Williams', '2023-12-01', 1, N'alice.w@test.com', GETDATE()),
    
    -- 境界値: 当年入社（勤続年数0年）
    (9005, 9003, N'Charlie', N'Brown', CAST(GETDATE() AS DATE), 1, N'charlie.b@test.com', GETDATE()),
    
    -- 境界値: 古い入社日（勤続年数大）
    (9006, 9003, N'David', N'Miller', '1995-01-01', 1, N'david.m@test.com', GETDATE()),
    
    -- 例外系: 非アクティブ従業員（表示されない）
    (9007, 9001, N'Eve', N'Davis', '2018-05-20', 0, N'eve.davis@test.com', GETDATE()),
    
    -- 正常系: 複数給与履歴あり（最新を取得）
    (9008, 9002, N'Frank', N'Wilson', '2017-08-15', 1, N'frank.w@test.com', GETDATE()),
    
    -- 境界値: NULL許容フィールドのテスト
    (9009, 9003, N'Grace', N'Taylor', '2022-02-28', 1, NULL, GETDATE());
SET IDENTITY_INSERT dbo.employees OFF;

-- テスト用給与データ作成
SET IDENTITY_INSERT dbo.salaries ON;
INSERT INTO dbo.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES
    -- 9001: 単一給与
    (90001, 9001, 50000.00, '2020-01-15', NULL),
    
    -- 9002: 単一給与
    (90002, 9002, 60000.00, '2019-06-01', NULL),
    
    -- 9003: 単一給与
    (90003, 9003, 55000.00, '2021-03-10', NULL),
    
    -- 9004: 給与なし（テストケース）
    
    -- 9005: 当年入社の給与
    (90005, 9005, 45000.00, CAST(GETDATE() AS DATE), NULL),
    
    -- 9006: 古い従業員の給与
    (90006, 9006, 80000.00, '1995-01-01', NULL),
    
    -- 9007: 非アクティブ従業員の給与（表示されない）
    (90007, 9007, 52000.00, '2018-05-20', NULL),
    
    -- 9008: 複数給与履歴（最新を取得すべき）
    (90008, 9008, 48000.00, '2017-08-15', '2019-12-31'),
    (90009, 9008, 53000.00, '2020-01-01', '2021-12-31'),
    (90010, 9008, 58000.00, '2022-01-01', NULL),  -- 最新
    
    -- 9009: 単一給与
    (90011, 9009, 47000.00, '2022-02-28', NULL);
SET IDENTITY_INSERT dbo.salaries OFF;


-- ============================================================================
-- TEST CASE 1: 正常系 - アクティブ従業員の基本取得
-- ============================================================================
SELECT 
    'TC1_Active_Employees' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id IN (9001, 9002, 9003)
ORDER BY employee_id;


-- ============================================================================
-- TEST CASE 2: 境界値 - 給与情報が存在しない従業員
-- ============================================================================
SELECT 
    'TC2_No_Salary' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id = 9004;


-- ============================================================================
-- TEST CASE 3: 境界値 - 当年入社（勤続年数0年）
-- ============================================================================
SELECT 
    'TC3_Zero_Years' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id = 9005;


-- ============================================================================
-- TEST CASE 4: 境界値 - 古い入社日（勤続年数大）
-- ============================================================================
SELECT 
    'TC4_Long_Service' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id = 9006;


-- ============================================================================
-- TEST CASE 5: 例外系 - 非アクティブ従業員は表示されない
-- ============================================================================
SELECT 
    'TC5_Inactive_Not_Shown' AS test_case,
    COUNT(*) AS record_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS: No inactive employees shown' ELSE 'FAIL: Inactive employee found' END AS result
FROM dbo.v_active_employees
WHERE employee_id = 9007;


-- ============================================================================
-- TEST CASE 6: 正常系 - 複数給与履歴から最新を取得
-- ============================================================================
SELECT 
    'TC6_Latest_Salary' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id = 9008;


-- ============================================================================
-- TEST CASE 7: 正常系 - 複数部署にまたがる取得
-- ============================================================================
SELECT 
    'TC7_Multiple_Departments' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id IN (9001, 9003, 9006)
ORDER BY employee_id;


-- ============================================================================
-- TEST CASE 8: 境界値 - NULL許容フィールド（email NULL）
-- ============================================================================
SELECT 
    'TC8_Null_Email' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id = 9009;


-- ============================================================================
-- TEST CASE 9: データ整合性 - 全テスト従業員の件数確認
-- ============================================================================
SELECT 
    'TC9_Count_Check' AS test_case,
    COUNT(*) AS active_employee_count,
    'Expected: 8 (9007 is inactive)' AS expected_result
FROM dbo.v_active_employees
WHERE employee_id BETWEEN 9001 AND 9009;


-- ============================================================================
-- TEST CASE 10: データ整合性 - ORDER BY での結果順序
-- ============================================================================
SELECT 
    'TC10_Order_By_HireDate' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id IN (9001, 9002, 9003, 9006)
ORDER BY hire_date ASC;


-- ============================================================================
-- TEST CASE 11: 追加テスト - 全テスト従業員の一覧
-- ============================================================================
SELECT 
    'TC11_All_Test_Employees' AS test_case,
    employee_id,
    full_name,
    department_name,
    hire_date,
    base_salary,
    years_of_service
FROM dbo.v_active_employees
WHERE employee_id BETWEEN 9001 AND 9009
ORDER BY employee_id;


-- ============================================================================
-- CLEANUP: テストデータ削除
-- ============================================================================
SET IDENTITY_INSERT dbo.salaries ON;
DELETE FROM dbo.salaries WHERE salary_id >= 90000;
SET IDENTITY_INSERT dbo.salaries OFF;

SET IDENTITY_INSERT dbo.employees ON;
DELETE FROM dbo.employees WHERE employee_id >= 9000;
SET IDENTITY_INSERT dbo.employees OFF;

SET IDENTITY_INSERT dbo.departments ON;
DELETE FROM dbo.departments WHERE department_id >= 9000;
SET IDENTITY_INSERT dbo.departments OFF;

-- 完了メッセージ
SELECT 'Test suite completed successfully' AS status;
