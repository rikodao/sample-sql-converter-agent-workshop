-- ================================================================================
-- Test Suite for public.usp_calculate_employee_bonus
-- ================================================================================
-- 対象: ストアドプロシージャ (INOUT パラメータ + UPSERT 処理)
-- 戦略: 正常系、境界値、例外系、副作用(INSERT/UPDATE)を網羅
-- 注意: 既存データ (employee_id: 1-5) を使用し、追加テストデータ (9001-9004) を作成
-- ================================================================================

-- ================================================================================
-- SETUP: テストデータ準備
-- ================================================================================
-- 既存データを使用: employees (1-5), salaries (1-5)
-- 追加テストデータを作成

-- テストデータのクリーンアップ
DELETE FROM public.bonuses WHERE employee_id >= 9000;
DELETE FROM public.salaries WHERE employee_id >= 9000;
DELETE FROM public.employees WHERE employee_id >= 9000;

-- 既存データに追加したボーナスレコードも削除
DELETE FROM public.bonuses WHERE employee_id IN (1, 2, 3, 4, 5) AND fiscal_year >= 2024;

SELECT 'SETUP: Cleanup complete' AS status;

-- ================================================================================
-- TEST CASE 1: 正常系 - employee_id = 1 (Alice, hire_date: 2020-01-15, salary: 80000)
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(1, 2024, v_bonus);
    
    -- DATEDIFF(yy, '2020-01-15', '2024-12-31') = 4
    -- Expected: 80000 * 0.10 * (1 + 4 * 0.05) = 80000 * 0.10 * 1.20 = 9600.00
    RAISE NOTICE 'Test Case 1: output_bonus=%, expected=9600.00, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 9600.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

SELECT 
    'Test Case 1' AS test_case,
    'Normal: employee_id=1, fiscal_year=2024' AS description,
    9600.00 AS expected_bonus,
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS result
FROM public.bonuses
WHERE employee_id = 1 AND fiscal_year = 2024;

SELECT 
    'Test Case 1 - Verify INSERT' AS test_case,
    employee_id, 
    fiscal_year, 
    bonus_amount
FROM public.bonuses
WHERE employee_id = 1 AND fiscal_year = 2024;

-- ================================================================================
-- TEST CASE 2: 正常系 - employee_id = 3 (Carol, hire_date: 2019-06-12, salary: 90000)
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(3, 2024, v_bonus);
    
    -- DATEDIFF(yy, '2019-06-12', '2024-12-31') = 5
    -- Expected: 90000 * 0.10 * (1 + 5 * 0.05) = 90000 * 0.10 * 1.25 = 11250.00
    RAISE NOTICE 'Test Case 2: output_bonus=%, expected=11250.00, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 11250.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ================================================================================
-- TEST CASE 3: 正常系 - employee_id = 5 (Eve, hire_date: 2018-11-20, salary: 65000)
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(5, 2024, v_bonus);
    
    -- DATEDIFF(yy, '2018-11-20', '2024-12-31') = 6
    -- Expected: 65000 * 0.10 * (1 + 6 * 0.05) = 65000 * 0.10 * 1.30 = 8450.00
    RAISE NOTICE 'Test Case 3: output_bonus=%, expected=8450.00, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 8450.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ================================================================================
-- TEST CASE 4: 境界値 - 新入社員 (employee_id = 4, hire_date: 2022-09-01)
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(4, 2024, v_bonus);
    
    -- DATEDIFF(yy, '2022-09-01', '2024-12-31') = 2
    -- Expected: 70000 * 0.10 * (1 + 2 * 0.05) = 70000 * 0.10 * 1.10 = 7700.00
    RAISE NOTICE 'Test Case 4: output_bonus=%, expected=7700.00, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 7700.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ================================================================================
-- TEST CASE 5: 境界値 - 給与レコードが存在しない従業員
-- ================================================================================
INSERT INTO public.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9001, 1, 'NoSalary', 'Test', '2021-05-01', true, 'nosalary@example.com', '2021-05-01 09:00:00');

DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(9001, 2024, v_bonus);
    
    RAISE NOTICE 'Test Case 5: output_bonus=%, expected=0.00, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 0.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- bonuses テーブルに INSERT されていないことを確認
SELECT 
    'Test Case 5 - Verify no INSERT' AS test_case,
    COUNT(*) AS record_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM public.bonuses
WHERE employee_id = 9001 AND fiscal_year = 2024;

-- ================================================================================
-- TEST CASE 6: 境界値 - 同年入社 (fiscal_year と同じ年)
-- ================================================================================
INSERT INTO public.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9002, 2, 'SameYear', 'Test', '2024-01-01', true, 'sameyear@example.com', '2024-01-01 09:00:00');

INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES (9002, 9002, 55000.00, '2024-01-01', NULL);

DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(9002, 2024, v_bonus);
    
    -- DATEDIFF(yy, '2024-01-01', '2024-12-31') = 0
    -- Expected: 55000 * 0.10 * (1 + 0 * 0.05) = 5500.00
    RAISE NOTICE 'Test Case 6: output_bonus=%, expected=5500.00, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 5500.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ================================================================================
-- TEST CASE 7: 境界値 - 極小給与
-- ================================================================================
INSERT INTO public.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9003, 3, 'MinSalary', 'Test', '2022-07-10', true, 'minsalary@example.com', '2022-07-10 09:00:00');

INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES (9003, 9003, 0.01, '2022-07-10', NULL);

DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(9003, 2024, v_bonus);
    
    -- DATEDIFF(yy, '2022-07-10', '2024-12-31') = 2
    -- Expected: 0.01 * 0.10 * (1 + 2 * 0.05) = 0.01 * 0.10 * 1.10 = 0.0011
    RAISE NOTICE 'Test Case 7: output_bonus=%, expected=0.0011, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 0.0011 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ================================================================================
-- TEST CASE 8: 例外系 - 存在しない従業員ID
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    BEGIN
        CALL public.usp_calculate_employee_bonus(99999, 2024, v_bonus);
        RAISE NOTICE 'Test Case 8: output_bonus=%, result=No error raised (returns 0)', v_bonus;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Test Case 8: Exception - error_message=%', SQLERRM;
    END;
END $$;

-- ================================================================================
-- TEST CASE 9: 例外系 - NULL パラメータ (employee_id)
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    BEGIN
        CALL public.usp_calculate_employee_bonus(NULL, 2024, v_bonus);
        RAISE NOTICE 'Test Case 9: output_bonus=%, result=No error raised', v_bonus;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Test Case 9: Exception - error_message=%', SQLERRM;
    END;
END $$;

-- ================================================================================
-- TEST CASE 10: 例外系 - 負の fiscal_year
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    BEGIN
        CALL public.usp_calculate_employee_bonus(1, -2024, v_bonus);
        RAISE NOTICE 'Test Case 10: output_bonus=%, result=Executed (may cause make_date error)', v_bonus;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Test Case 10: Exception - error_message=%', SQLERRM;
    END;
END $$;

-- ================================================================================
-- TEST CASE 11: 副作用 - 同一従業員・年度の複数回実行 (UPSERT 動作確認)
-- ================================================================================
DO $$
DECLARE
    v_bonus1 NUMERIC(19,4);
    v_bonus2 NUMERIC(19,4);
    v_count1 INT;
    v_count2 INT;
BEGIN
    v_bonus1 := NULL;
    v_bonus2 := NULL;
    
    -- 1回目実行
    CALL public.usp_calculate_employee_bonus(2, 2025, v_bonus1);
    SELECT COUNT(*) INTO v_count1 FROM public.bonuses WHERE employee_id = 2 AND fiscal_year = 2025;
    RAISE NOTICE 'Test Case 11a: First execution - record_count=%', v_count1;
    
    -- 2回目実行 (同じパラメータ)
    CALL public.usp_calculate_employee_bonus(2, 2025, v_bonus2);
    SELECT COUNT(*) INTO v_count2 FROM public.bonuses WHERE employee_id = 2 AND fiscal_year = 2025;
    RAISE NOTICE 'Test Case 11b: Second execution (UPSERT) - record_count=%, result=%', 
        v_count2,
        CASE WHEN v_count2 = 1 THEN 'PASS (UPDATE)' ELSE 'FAIL (Duplicate INSERT)' END;
END $$;

SELECT 
    'Test Case 11b' AS test_case,
    'Side effect: Second execution (UPSERT)' AS description,
    COUNT(*) AS record_count,
    MAX(bonus_amount) AS bonus_amount,
    CASE WHEN COUNT(*) = 1 THEN 'PASS (UPDATE)' ELSE 'FAIL (Duplicate INSERT)' END AS result
FROM public.bonuses
WHERE employee_id = 2 AND fiscal_year = 2025;

-- ================================================================================
-- TEST CASE 12: トランザクション - ロールバック動作確認
-- ================================================================================
DO $$
DECLARE
    v_bonus NUMERIC(19,4);
    v_count_before INT;
    v_count_after INT;
    v_count_final INT;
BEGIN
    SELECT COUNT(*) INTO v_count_before FROM public.bonuses WHERE employee_id = 1;
    
    BEGIN
        CALL public.usp_calculate_employee_bonus(1, 2025, v_bonus);
        SELECT COUNT(*) INTO v_count_after FROM public.bonuses WHERE employee_id = 1;
        RAISE EXCEPTION 'Intentional rollback';
    EXCEPTION WHEN OTHERS THEN
        -- Rollback occurred
        NULL;
    END;
    
    SELECT COUNT(*) INTO v_count_final FROM public.bonuses WHERE employee_id = 1;
    
    RAISE NOTICE 'Test Case 12: count_before=%, count_after=%, count_final=%, result=%',
        v_count_before, v_count_after, v_count_final,
        CASE WHEN v_count_final = v_count_before THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ================================================================================
-- TEST CASE 13: 副作用 - 複数給与レコードがある場合、最新を使用
-- ================================================================================
INSERT INTO public.employees (employee_id, department_id, first_name, last_name, hire_date, is_active, email, created_at)
VALUES (9004, 4, 'MultiSalary', 'Test', '2020-01-01', true, 'multisalary@example.com', '2020-01-01 09:00:00');

INSERT INTO public.salaries (salary_id, employee_id, base_salary, effective_from, effective_to)
VALUES 
    (9004, 9004, 50000.00, '2020-01-01', '2021-12-31'),
    (9005, 9004, 60000.00, '2022-01-01', '2023-12-31'),
    (9006, 9004, 75000.00, '2024-01-01', NULL);  -- 最新

DO $$
DECLARE
    v_bonus NUMERIC(19,4);
BEGIN
    v_bonus := NULL;
    CALL public.usp_calculate_employee_bonus(9004, 2024, v_bonus);
    
    -- DATEDIFF(yy, '2020-01-01', '2024-12-31') = 4
    -- Expected: 75000 * 0.10 * (1 + 4 * 0.05) = 75000 * 0.10 * 1.20 = 9000.00
    RAISE NOTICE 'Test Case 13: output_bonus=%, expected=9000.00, result=%', 
        v_bonus, 
        CASE WHEN v_bonus = 9000.00 THEN 'PASS' ELSE 'FAIL' END;
END $$;

-- ================================================================================
-- CLEANUP: テストデータ削除
-- ================================================================================
DELETE FROM public.bonuses WHERE employee_id >= 9000;
DELETE FROM public.salaries WHERE employee_id >= 9000;
DELETE FROM public.employees WHERE employee_id >= 9000;

-- 既存データに追加したボーナスレコードも削除
DELETE FROM public.bonuses WHERE employee_id IN (1, 2, 3, 4, 5) AND fiscal_year >= 2024;

SELECT 'CLEANUP Complete' AS status;

-- ================================================================================
-- Test Suite Complete
-- ================================================================================
SELECT 'All test cases executed successfully' AS final_status;
