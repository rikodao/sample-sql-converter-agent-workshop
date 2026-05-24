-- ============================================================
-- TEST SUITE: dbo.usp_recursive_org_chart
-- Description: Comprehensive test cases for recursive org chart procedure
-- Target: Babelfish for Aurora PostgreSQL
-- ============================================================

-- ============= TEST CASE 1: Normal - Root with children =============
-- SETUP
IF OBJECT_ID('tempdb..#tc1_result') IS NOT NULL DROP TABLE #tc1_result;
CREATE TABLE #tc1_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

-- EXEC
INSERT INTO #tc1_result
EXEC dbo.usp_recursive_org_chart @root_id = 1;

-- ASSERT
SELECT 'TC1' AS tc, department_id, name, depth, path 
FROM #tc1_result 
ORDER BY path;

-- CLEANUP
DROP TABLE #tc1_result;

-- ============= TEST CASE 2: Normal - Leaf node (no children) =============
-- SETUP
IF OBJECT_ID('tempdb..#tc2_result') IS NOT NULL DROP TABLE #tc2_result;
CREATE TABLE #tc2_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

-- EXEC
INSERT INTO #tc2_result
EXEC dbo.usp_recursive_org_chart @root_id = 2;

-- ASSERT
SELECT 'TC2' AS tc, department_id, name, depth, path 
FROM #tc2_result 
ORDER BY path;

-- CLEANUP
DROP TABLE #tc2_result;

-- ============= TEST CASE 3: Normal - Different root department =============
-- SETUP
IF OBJECT_ID('tempdb..#tc3_result') IS NOT NULL DROP TABLE #tc3_result;
CREATE TABLE #tc3_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

-- EXEC
INSERT INTO #tc3_result
EXEC dbo.usp_recursive_org_chart @root_id = 4;

-- ASSERT
SELECT 'TC3' AS tc, department_id, name, depth, path 
FROM #tc3_result 
ORDER BY path;

-- CLEANUP
DROP TABLE #tc3_result;

-- ============= TEST CASE 4: Boundary - Non-existent department ID =============
-- SETUP
IF OBJECT_ID('tempdb..#tc4_result') IS NOT NULL DROP TABLE #tc4_result;
CREATE TABLE #tc4_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

-- EXEC
INSERT INTO #tc4_result
EXEC dbo.usp_recursive_org_chart @root_id = 99999;

-- ASSERT (should return empty result set)
SELECT 'TC4' AS tc, COUNT(*) AS row_count 
FROM #tc4_result;

-- CLEANUP
DROP TABLE #tc4_result;

-- ============= TEST CASE 5: Boundary - NULL input =============
-- SETUP
-- EXEC & ASSERT
BEGIN TRY
    EXEC dbo.usp_recursive_org_chart @root_id = NULL;
    SELECT 'TC5' AS tc, 'NO_ERROR' AS result;
END TRY
BEGIN CATCH
    SELECT 'TC5' AS tc, ERROR_MESSAGE() AS result;
END CATCH

-- CLEANUP
-- (none needed)

-- ============= TEST CASE 6: Boundary - Zero as input =============
-- SETUP
IF OBJECT_ID('tempdb..#tc6_result') IS NOT NULL DROP TABLE #tc6_result;
CREATE TABLE #tc6_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

-- EXEC
INSERT INTO #tc6_result
EXEC dbo.usp_recursive_org_chart @root_id = 0;

-- ASSERT (should return empty result set)
SELECT 'TC6' AS tc, COUNT(*) AS row_count 
FROM #tc6_result;

-- CLEANUP
DROP TABLE #tc6_result;

-- ============= TEST CASE 7: Exception - Negative ID =============
-- SETUP
IF OBJECT_ID('tempdb..#tc7_result') IS NOT NULL DROP TABLE #tc7_result;
CREATE TABLE #tc7_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

-- EXEC
INSERT INTO #tc7_result
EXEC dbo.usp_recursive_org_chart @root_id = -1;

-- ASSERT (should return empty result set, not error)
SELECT 'TC7' AS tc, COUNT(*) AS row_count 
FROM #tc7_result;

-- CLEANUP
DROP TABLE #tc7_result;

-- ============= TEST CASE 8: Deep hierarchy - Multi-level recursion =============
-- SETUP
IF OBJECT_ID('tempdb..#tc8_dept') IS NOT NULL DROP TABLE #tc8_dept;
IF OBJECT_ID('tempdb..#tc8_result') IS NOT NULL DROP TABLE #tc8_result;

CREATE TABLE #tc8_dept (department_id INT, name NVARCHAR(100), parent_id INT);
CREATE TABLE #tc8_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (1001, N'TC8_Root', NULL, GETDATE()),
    (1002, N'TC8_L1', 1001, GETDATE()),
    (1003, N'TC8_L2', 1002, GETDATE()),
    (1004, N'TC8_L3', 1003, GETDATE()),
    (1005, N'TC8_L4', 1004, GETDATE());
SET IDENTITY_INSERT dbo.departments OFF;

-- EXEC
INSERT INTO #tc8_result
EXEC dbo.usp_recursive_org_chart @root_id = 1001;

-- ASSERT
SELECT 'TC8' AS tc, department_id, name, depth, path 
FROM #tc8_result 
ORDER BY depth, department_id;

-- CLEANUP
DELETE FROM dbo.departments WHERE department_id BETWEEN 1001 AND 1005;
DROP TABLE #tc8_dept;
DROP TABLE #tc8_result;

-- ============= TEST CASE 9: Multiple children at same level =============
-- SETUP
IF OBJECT_ID('tempdb..#tc9_result') IS NOT NULL DROP TABLE #tc9_result;
CREATE TABLE #tc9_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (2001, N'TC9_Root', NULL, GETDATE()),
    (2002, N'TC9_Child1', 2001, GETDATE()),
    (2003, N'TC9_Child2', 2001, GETDATE()),
    (2004, N'TC9_Child3', 2001, GETDATE());
SET IDENTITY_INSERT dbo.departments OFF;

-- EXEC
INSERT INTO #tc9_result
EXEC dbo.usp_recursive_org_chart @root_id = 2001;

-- ASSERT
SELECT 'TC9' AS tc, department_id, name, depth, path 
FROM #tc9_result 
ORDER BY path;

-- CLEANUP
DELETE FROM dbo.departments WHERE department_id BETWEEN 2001 AND 2004;
DROP TABLE #tc9_result;

-- ============= TEST CASE 10: Verify depth calculation =============
-- SETUP
IF OBJECT_ID('tempdb..#tc10_result') IS NOT NULL DROP TABLE #tc10_result;
CREATE TABLE #tc10_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (3001, N'TC10_L0', NULL, GETDATE()),
    (3002, N'TC10_L1', 3001, GETDATE()),
    (3003, N'TC10_L2', 3002, GETDATE());
SET IDENTITY_INSERT dbo.departments OFF;

-- EXEC
INSERT INTO #tc10_result
EXEC dbo.usp_recursive_org_chart @root_id = 3001;

-- ASSERT (verify depth values: 0, 1, 2)
SELECT 'TC10' AS tc, name, depth 
FROM #tc10_result 
ORDER BY depth;

-- CLEANUP
DELETE FROM dbo.departments WHERE department_id BETWEEN 3001 AND 3003;
DROP TABLE #tc10_result;

-- ============= TEST CASE 11: Verify path construction =============
-- SETUP
IF OBJECT_ID('tempdb..#tc11_result') IS NOT NULL DROP TABLE #tc11_result;
CREATE TABLE #tc11_result (department_id INT, name NVARCHAR(100), depth INT, path NVARCHAR(MAX));

SET IDENTITY_INSERT dbo.departments ON;
INSERT INTO dbo.departments (department_id, name, parent_id, created_at)
VALUES 
    (4001, N'A', NULL, GETDATE()),
    (4002, N'B', 4001, GETDATE()),
    (4003, N'C', 4002, GETDATE());
SET IDENTITY_INSERT dbo.departments OFF;

-- EXEC
INSERT INTO #tc11_result
EXEC dbo.usp_recursive_org_chart @root_id = 4001;

-- ASSERT (verify path format: "A", "A > B", "A > B > C")
SELECT 'TC11' AS tc, path 
FROM #tc11_result 
ORDER BY depth;

-- CLEANUP
DELETE FROM dbo.departments WHERE department_id BETWEEN 4001 AND 4003;
DROP TABLE #tc11_result;
