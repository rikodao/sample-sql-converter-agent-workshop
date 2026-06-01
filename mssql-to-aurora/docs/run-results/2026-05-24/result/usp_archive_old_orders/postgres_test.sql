-- ============================================================
-- TEST SUITE: public.usp_archive_old_orders
-- Database: Aurora PostgreSQL (Native)
-- Purpose: Comprehensive test coverage for archive procedure
-- Converted from: MSSQL test suite
-- ============================================================

-- ============= TEST CASE 1: Normal archiving of old completed orders =============
-- SETUP
CREATE TEMPORARY TABLE tmp_test_orders_tc1 (
    order_id INT,
    customer_id INT,
    order_date TIMESTAMP,
    total_amount NUMERIC(19,4),
    status VARCHAR(20)
);

INSERT INTO public.orders (customer_id, order_date, total_amount, status)
VALUES 
    (1001, '2020-01-15', 100.00, 'COMPLETED'),
    (1002, '2020-06-20', 250.50, 'COMPLETED'),
    (1003, '2023-12-01', 500.00, 'COMPLETED');

-- EXEC
DO $$
DECLARE
    v_archived_tc1 INT;
BEGIN
    CALL public.usp_archive_old_orders('2021-01-01', v_archived_tc1);
    
    -- ASSERT
    RAISE NOTICE 'TC1|rows_archived|%', v_archived_tc1;
END $$;

SELECT 'TC1' AS tc, COUNT(*) AS remaining_in_orders FROM public.orders WHERE order_date < '2021-01-01' AND status = 'COMPLETED';
SELECT 'TC1' AS tc, COUNT(*) AS added_to_archive FROM public.orders_archive WHERE order_date < '2021-01-01';
SELECT 'TC1' AS tc, order_id, customer_id, order_date, total_amount, status 
FROM public.orders_archive 
WHERE order_date < '2021-01-01' 
ORDER BY order_id;

-- CLEANUP
DELETE FROM public.orders_archive WHERE order_date < '2021-01-01';
DELETE FROM public.orders WHERE customer_id IN (1003) AND order_date >= '2021-01-01';
DROP TABLE IF EXISTS tmp_test_orders_tc1;

-- ============= TEST CASE 2: Archive with cutoff date matching exact boundary =============
-- SETUP
INSERT INTO public.orders (customer_id, order_date, total_amount, status)
VALUES 
    (2001, '2022-12-31 23:59:59', 150.00, 'COMPLETED'),
    (2002, '2023-01-01 00:00:00', 200.00, 'COMPLETED');

-- EXEC
DO $$
DECLARE
    v_archived_tc2 INT;
BEGIN
    CALL public.usp_archive_old_orders('2023-01-01', v_archived_tc2);
    
    -- ASSERT
    RAISE NOTICE 'TC2|rows_archived|%', v_archived_tc2;
END $$;

SELECT 'TC2' AS tc, order_id, order_date, status 
FROM public.orders 
WHERE customer_id IN (2001, 2002)
ORDER BY order_id;
SELECT 'TC2' AS tc, order_id, order_date 
FROM public.orders_archive 
WHERE customer_id = 2001
ORDER BY order_id;

-- CLEANUP
DELETE FROM public.orders_archive WHERE customer_id = 2001;
DELETE FROM public.orders WHERE customer_id IN (2001, 2002);

-- ============= TEST CASE 3: No orders to archive (all orders are recent) =============
-- SETUP
INSERT INTO public.orders (customer_id, order_date, total_amount, status)
VALUES 
    (3001, '2025-01-01', 300.00, 'COMPLETED'),
    (3002, '2025-06-15', 400.00, 'COMPLETED');

-- EXEC
DO $$
DECLARE
    v_archived_tc3 INT;
BEGIN
    CALL public.usp_archive_old_orders('2020-01-01', v_archived_tc3);
    
    -- ASSERT
    RAISE NOTICE 'TC3|rows_archived|%', v_archived_tc3;
END $$;

SELECT 'TC3' AS tc, COUNT(*) AS orders_still_present FROM public.orders WHERE customer_id IN (3001, 3002);

-- CLEANUP
DELETE FROM public.orders WHERE customer_id IN (3001, 3002);

-- ============= TEST CASE 4: Only COMPLETED orders are archived (PENDING/CANCELLED excluded) =============
-- SETUP
INSERT INTO public.orders (customer_id, order_date, total_amount, status)
VALUES 
    (4001, '2019-05-10', 100.00, 'COMPLETED'),
    (4002, '2019-05-11', 150.00, 'PENDING'),
    (4003, '2019-05-12', 200.00, 'CANCELLED'),
    (4004, '2019-05-13', 250.00, 'COMPLETED');

-- EXEC
DO $$
DECLARE
    v_archived_tc4 INT;
BEGIN
    CALL public.usp_archive_old_orders('2020-01-01', v_archived_tc4);
    
    -- ASSERT
    RAISE NOTICE 'TC4|rows_archived|%', v_archived_tc4;
END $$;

SELECT 'TC4' AS tc, customer_id, status 
FROM public.orders 
WHERE customer_id IN (4001, 4002, 4003, 4004)
ORDER BY customer_id;
SELECT 'TC4' AS tc, customer_id, status 
FROM public.orders_archive 
WHERE customer_id IN (4001, 4004)
ORDER BY customer_id;

-- CLEANUP
DELETE FROM public.orders_archive WHERE customer_id IN (4001, 4004);
DELETE FROM public.orders WHERE customer_id IN (4002, 4003);

-- ============= TEST CASE 5: NULL cutoff_date parameter =============
-- SETUP
-- No setup needed

-- EXEC & ASSERT
DO $$
DECLARE
    v_archived_tc5 INT;
BEGIN
    BEGIN
        CALL public.usp_archive_old_orders(NULL, v_archived_tc5);
        RAISE NOTICE 'TC5|result|NO_ERROR';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TC5|result|%', SQLERRM;
    END;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 6: Archive large batch of orders =============
-- SETUP
DO $$
DECLARE
    v_i INT := 0;
BEGIN
    WHILE v_i < 50 LOOP
        INSERT INTO public.orders (customer_id, order_date, total_amount, status)
        VALUES (5000 + v_i, '2018-01-01', 100.00 + v_i, 'COMPLETED');
        v_i := v_i + 1;
    END LOOP;
END $$;

-- EXEC
DO $$
DECLARE
    v_archived_tc6 INT;
BEGIN
    CALL public.usp_archive_old_orders('2019-01-01', v_archived_tc6);
    
    -- ASSERT
    RAISE NOTICE 'TC6|rows_archived|%', v_archived_tc6;
END $$;

SELECT 'TC6' AS tc, COUNT(*) AS archived_count FROM public.orders_archive WHERE customer_id BETWEEN 5000 AND 5049;

-- CLEANUP
DELETE FROM public.orders_archive WHERE customer_id BETWEEN 5000 AND 5049;

-- ============= TEST CASE 7: Verify transaction rollback on error (constraint violation simulation) =============
-- SETUP
INSERT INTO public.orders (customer_id, order_date, total_amount, status)
VALUES 
    (7001, '2017-01-01', 100.00, 'COMPLETED'),
    (7002, '2017-01-02', 200.00, 'COMPLETED');

-- EXEC
DO $$
DECLARE
    v_archived_tc7 INT;
BEGIN
    BEGIN
        CALL public.usp_archive_old_orders('2018-01-01', v_archived_tc7);
        RAISE NOTICE 'TC7|result|SUCCESS|rows_archived|%', v_archived_tc7;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TC7|result|ERROR|error_msg|%', SQLERRM;
    END;
END $$;

-- ASSERT
SELECT 'TC7' AS tc, COUNT(*) AS remaining_orders FROM public.orders WHERE customer_id IN (7001, 7002);
SELECT 'TC7' AS tc, COUNT(*) AS archived_orders FROM public.orders_archive WHERE customer_id IN (7001, 7002);

-- CLEANUP
DELETE FROM public.orders_archive WHERE customer_id IN (7001, 7002);

-- ============= TEST CASE 8: Archive with zero total_amount =============
-- SETUP
INSERT INTO public.orders (customer_id, order_date, total_amount, status)
VALUES 
    (8001, '2019-03-15', 0.00, 'COMPLETED'),
    (8002, '2019-03-16', -10.00, 'COMPLETED');

-- EXEC
DO $$
DECLARE
    v_archived_tc8 INT;
BEGIN
    CALL public.usp_archive_old_orders('2020-01-01', v_archived_tc8);
    
    -- ASSERT
    RAISE NOTICE 'TC8|rows_archived|%', v_archived_tc8;
END $$;

SELECT 'TC8' AS tc, customer_id, total_amount 
FROM public.orders_archive 
WHERE customer_id IN (8001, 8002)
ORDER BY customer_id;

-- CLEANUP
DELETE FROM public.orders_archive WHERE customer_id IN (8001, 8002);

-- ============= TEST CASE 9: Verify OUTPUT parameter is set correctly when no rows archived =============
-- SETUP
-- No old completed orders exist for this test

-- EXEC
DO $$
DECLARE
    v_archived_tc9 INT := -1; -- Initialize to non-zero to verify it gets set
BEGIN
    CALL public.usp_archive_old_orders('1990-01-01', v_archived_tc9);
    
    -- ASSERT
    RAISE NOTICE 'TC9|rows_archived|%', v_archived_tc9;
END $$;

-- CLEANUP
-- No cleanup needed

-- ============= TEST CASE 10: Archive orders with maximum date precision =============
-- SETUP
INSERT INTO public.orders (customer_id, order_date, total_amount, status)
VALUES 
    (10001, '2019-12-31 23:59:59.999999', 500.00, 'COMPLETED'),
    (10002, '2020-01-01 00:00:00.000000', 600.00, 'COMPLETED');

-- EXEC
DO $$
DECLARE
    v_archived_tc10 INT;
BEGIN
    CALL public.usp_archive_old_orders('2020-01-01', v_archived_tc10);
    
    -- ASSERT
    RAISE NOTICE 'TC10|rows_archived|%', v_archived_tc10;
END $$;

SELECT 'TC10' AS tc, customer_id, order_date 
FROM public.orders_archive 
WHERE customer_id = 10001
ORDER BY customer_id;
SELECT 'TC10' AS tc, customer_id 
FROM public.orders 
WHERE customer_id = 10002;

-- CLEANUP
DELETE FROM public.orders_archive WHERE customer_id = 10001;
DELETE FROM public.orders WHERE customer_id = 10002;
