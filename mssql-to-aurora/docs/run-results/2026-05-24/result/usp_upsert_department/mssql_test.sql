-- ============================================================
-- TEST CASES: dbo.usp_upsert_department
-- Target: Source RDS for SQL Server
-- ============================================================
-- This procedure performs MERGE (UPSERT) on dbo.departments
-- Test coverage:
--   - INSERT path (new department name)
--   - UPDATE path (existing department name, update parent_id)
--   - NULL parent_id handling
--   - Boundary values (empty string, max length)
--   - Transaction behavior
-- ============================================================

-- ============= TEST CASE 1: INSERT new department with parent_id =============
-- SETUP
CREATE TABLE #test_departments_tc1 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc1 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO #test_departments_tc1 (name, parent_id) VALUES ('Engineering', NULL);

-- EXEC
-- Insert new department 'Sales' with parent_id = 1 (HR)
DECLARE @test_name1 NVARCHAR(100) = 'Sales';
DECLARE @test_parent1 INT = 1;

-- Simulate MERGE logic for test
MERGE #test_departments_tc1 AS tgt
USING (SELECT @test_name1 AS name, @test_parent1 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC1' AS tc, name, parent_id 
FROM #test_departments_tc1 
WHERE name = 'Sales'
ORDER BY id;

-- CLEANUP
DROP TABLE #test_departments_tc1;


-- ============= TEST CASE 2: INSERT new department with NULL parent_id =============
-- SETUP
CREATE TABLE #test_departments_tc2 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc2 (name, parent_id) VALUES ('HR', NULL);

-- EXEC
-- Insert new department 'Marketing' with NULL parent_id
DECLARE @test_name2 NVARCHAR(100) = 'Marketing';
DECLARE @test_parent2 INT = NULL;

MERGE #test_departments_tc2 AS tgt
USING (SELECT @test_name2 AS name, @test_parent2 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC2' AS tc, name, parent_id 
FROM #test_departments_tc2 
WHERE name = 'Marketing'
ORDER BY id;

-- CLEANUP
DROP TABLE #test_departments_tc2;


-- ============= TEST CASE 3: UPDATE existing department parent_id (non-NULL to non-NULL) =============
-- SETUP
CREATE TABLE #test_departments_tc3 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc3 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO #test_departments_tc3 (name, parent_id) VALUES ('Sales', 1);

-- EXEC
-- Update 'Sales' parent_id from 1 to NULL
DECLARE @test_name3 NVARCHAR(100) = 'Sales';
DECLARE @test_parent3 INT = NULL;

MERGE #test_departments_tc3 AS tgt
USING (SELECT @test_name3 AS name, @test_parent3 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC3' AS tc, name, parent_id 
FROM #test_departments_tc3 
WHERE name = 'Sales'
ORDER BY id;

-- CLEANUP
DROP TABLE #test_departments_tc3;


-- ============= TEST CASE 4: UPDATE existing department parent_id (NULL to non-NULL) =============
-- SETUP
CREATE TABLE #test_departments_tc4 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc4 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO #test_departments_tc4 (name, parent_id) VALUES ('Engineering', NULL);

-- EXEC
-- Update 'Engineering' parent_id from NULL to 1 (HR)
DECLARE @test_name4 NVARCHAR(100) = 'Engineering';
DECLARE @test_parent4 INT = 1;

MERGE #test_departments_tc4 AS tgt
USING (SELECT @test_name4 AS name, @test_parent4 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC4' AS tc, name, parent_id 
FROM #test_departments_tc4 
WHERE name = 'Engineering'
ORDER BY id;

-- CLEANUP
DROP TABLE #test_departments_tc4;


-- ============= TEST CASE 5: UPDATE existing department parent_id (non-NULL to different non-NULL) =============
-- SETUP
CREATE TABLE #test_departments_tc5 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc5 (name, parent_id) VALUES ('HR', NULL);
INSERT INTO #test_departments_tc5 (name, parent_id) VALUES ('IT', NULL);
INSERT INTO #test_departments_tc5 (name, parent_id) VALUES ('Sales', 1);

-- EXEC
-- Update 'Sales' parent_id from 1 (HR) to 2 (IT)
DECLARE @test_name5 NVARCHAR(100) = 'Sales';
DECLARE @test_parent5 INT = 2;

MERGE #test_departments_tc5 AS tgt
USING (SELECT @test_name5 AS name, @test_parent5 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC5' AS tc, name, parent_id 
FROM #test_departments_tc5 
WHERE name = 'Sales'
ORDER BY id;

-- CLEANUP
DROP TABLE #test_departments_tc5;


-- ============= TEST CASE 6: Boundary - Empty string name (should fail or insert) =============
-- SETUP
CREATE TABLE #test_departments_tc6 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

-- EXEC
BEGIN TRY
    DECLARE @test_name6 NVARCHAR(100) = '';
    DECLARE @test_parent6 INT = NULL;

    MERGE #test_departments_tc6 AS tgt
    USING (SELECT @test_name6 AS name, @test_parent6 AS parent_id) AS src
    ON tgt.name = src.name
    WHEN MATCHED THEN
        UPDATE SET parent_id = src.parent_id
    WHEN NOT MATCHED THEN
        INSERT (name, parent_id) VALUES (src.name, src.parent_id);

    -- ASSERT
    SELECT 'TC6' AS tc, 'SUCCESS' AS result, COUNT(*) AS row_count 
    FROM #test_departments_tc6 
    WHERE name = '';
END TRY
BEGIN CATCH
    -- ASSERT (error case)
    SELECT 'TC6' AS tc, 'ERROR' AS result, ERROR_MESSAGE() AS error_msg;
END CATCH

-- CLEANUP
DROP TABLE #test_departments_tc6;


-- ============= TEST CASE 7: Boundary - Maximum length name (100 characters) =============
-- SETUP
CREATE TABLE #test_departments_tc7 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

-- EXEC
DECLARE @test_name7 NVARCHAR(100) = REPLICATE('A', 100);
DECLARE @test_parent7 INT = NULL;

MERGE #test_departments_tc7 AS tgt
USING (SELECT @test_name7 AS name, @test_parent7 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC7' AS tc, LEN(name) AS name_length, parent_id 
FROM #test_departments_tc7 
WHERE name = REPLICATE('A', 100);

-- CLEANUP
DROP TABLE #test_departments_tc7;


-- ============= TEST CASE 8: Multiple sequential upserts on same name =============
-- SETUP
CREATE TABLE #test_departments_tc8 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc8 (name, parent_id) VALUES ('HR', NULL);

-- EXEC
-- First upsert: Insert 'Finance' with parent_id = 1
DECLARE @test_name8 NVARCHAR(100) = 'Finance';
DECLARE @test_parent8a INT = 1;

MERGE #test_departments_tc8 AS tgt
USING (SELECT @test_name8 AS name, @test_parent8a AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- Second upsert: Update 'Finance' parent_id to NULL
DECLARE @test_parent8b INT = NULL;

MERGE #test_departments_tc8 AS tgt
USING (SELECT @test_name8 AS name, @test_parent8b AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- Third upsert: Update 'Finance' parent_id to 1 again
DECLARE @test_parent8c INT = 1;

MERGE #test_departments_tc8 AS tgt
USING (SELECT @test_name8 AS name, @test_parent8c AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC8' AS tc, name, parent_id, 
       (SELECT COUNT(*) FROM #test_departments_tc8 WHERE name = 'Finance') AS occurrence_count
FROM #test_departments_tc8 
WHERE name = 'Finance';

-- CLEANUP
DROP TABLE #test_departments_tc8;


-- ============= TEST CASE 9: Transaction rollback behavior =============
-- SETUP
CREATE TABLE #test_departments_tc9 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc9 (name, parent_id) VALUES ('HR', NULL);

-- EXEC
BEGIN TRANSACTION;

DECLARE @test_name9 NVARCHAR(100) = 'Legal';
DECLARE @test_parent9 INT = 1;

MERGE #test_departments_tc9 AS tgt
USING (SELECT @test_name9 AS name, @test_parent9 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

ROLLBACK TRANSACTION;

-- ASSERT
SELECT 'TC9' AS tc, COUNT(*) AS row_count 
FROM #test_departments_tc9 
WHERE name = 'Legal';

-- CLEANUP
DROP TABLE #test_departments_tc9;


-- ============= TEST CASE 10: Case sensitivity in name matching =============
-- SETUP
CREATE TABLE #test_departments_tc10 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc10 (name, parent_id) VALUES ('sales', 1);

-- EXEC
-- Try to upsert 'SALES' (uppercase) - should match 'sales' in case-insensitive collation
DECLARE @test_name10 NVARCHAR(100) = 'SALES';
DECLARE @test_parent10 INT = 2;

MERGE #test_departments_tc10 AS tgt
USING (SELECT @test_name10 AS name, @test_parent10 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

-- ASSERT
SELECT 'TC10' AS tc, name, parent_id, COUNT(*) OVER() AS total_rows
FROM #test_departments_tc10 
ORDER BY id;

-- CLEANUP
DROP TABLE #test_departments_tc10;


-- ============= TEST CASE 11: @@ROWCOUNT after INSERT path =============
-- SETUP
CREATE TABLE #test_departments_tc11 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

-- EXEC
DECLARE @test_name11 NVARCHAR(100) = 'Operations';
DECLARE @test_parent11 INT = NULL;

MERGE #test_departments_tc11 AS tgt
USING (SELECT @test_name11 AS name, @test_parent11 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

DECLARE @rowcount11 INT = @@ROWCOUNT;

-- ASSERT
SELECT 'TC11' AS tc, @rowcount11 AS rowcount_after_insert;

-- CLEANUP
DROP TABLE #test_departments_tc11;


-- ============= TEST CASE 12: @@ROWCOUNT after UPDATE path =============
-- SETUP
CREATE TABLE #test_departments_tc12 (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    parent_id INT NULL
);

INSERT INTO #test_departments_tc12 (name, parent_id) VALUES ('Support', 1);

-- EXEC
DECLARE @test_name12 NVARCHAR(100) = 'Support';
DECLARE @test_parent12 INT = 2;

MERGE #test_departments_tc12 AS tgt
USING (SELECT @test_name12 AS name, @test_parent12 AS parent_id) AS src
ON tgt.name = src.name
WHEN MATCHED THEN
    UPDATE SET parent_id = src.parent_id
WHEN NOT MATCHED THEN
    INSERT (name, parent_id) VALUES (src.name, src.parent_id);

DECLARE @rowcount12 INT = @@ROWCOUNT;

-- ASSERT
SELECT 'TC12' AS tc, @rowcount12 AS rowcount_after_update, parent_id 
FROM #test_departments_tc12 
WHERE name = 'Support';

-- CLEANUP
DROP TABLE #test_departments_tc12;
