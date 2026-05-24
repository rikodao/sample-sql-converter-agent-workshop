-- ============================================================
-- Target DDL: public.usp_archive_old_orders
-- Database: Aurora PostgreSQL (Native)
-- Converted from: T-SQL (dbo.usp_archive_old_orders)
-- Conversion Date: 2026-05-23
-- ============================================================

CREATE OR REPLACE PROCEDURE public.usp_archive_old_orders(
    p_cutoff_date DATE,
    INOUT p_rows_archived INT DEFAULT 0
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
BEGIN
    -- T-SQL の SET NOCOUNT ON は PG では不要（デフォルトで行数を返さない）
    p_rows_archived := 0;

    BEGIN
        -- DELETE ... OUTPUT ... INTO を WITH CTE + INSERT で実現
        WITH deleted_orders AS (
            DELETE FROM public.orders
            WHERE order_date < p_cutoff_date 
              AND status = 'COMPLETED'
            RETURNING order_id, customer_id, order_date, total_amount, status
        )
        INSERT INTO public.orders_archive(order_id, customer_id, order_date, total_amount, status)
        SELECT order_id, customer_id, order_date, total_amount, status
        FROM deleted_orders;
        
        -- @@ROWCOUNT の代替: GET DIAGNOSTICS で行数を取得
        GET DIAGNOSTICS p_rows_archived = ROW_COUNT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- エラーメッセージを取得
            GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
            
            -- エラーを再スロー
            RAISE EXCEPTION '%', v_error_message
                USING ERRCODE = 'P0001';
    END;
END;
$$;

-- ============================================================
-- CONVERSION NOTES
-- ============================================================
-- 1. OUTPUT パラメータ → INOUT パラメータ
--    T-SQL: @rows_archived INT OUTPUT
--    PG:    INOUT p_rows_archived INT
--
-- 2. 変数名の変換
--    T-SQL: @cutoff_date, @rows_archived
--    PG:    p_cutoff_date, p_rows_archived (@ は使用不可)
--
-- 3. DELETE ... OUTPUT ... INTO の変換
--    T-SQL: DELETE ... OUTPUT DELETED.* INTO target_table
--    PG:    WITH cte AS (DELETE ... RETURNING *) INSERT INTO target_table SELECT * FROM cte
--
-- 4. @@ROWCOUNT の変換
--    T-SQL: SET @var = @@ROWCOUNT
--    PG:    GET DIAGNOSTICS var = ROW_COUNT
--
-- 5. トランザクション制御
--    T-SQL: BEGIN TRAN / COMMIT TRAN / ROLLBACK TRAN
--    PG:    明示的な COMMIT/ROLLBACK は不要（自動管理）
--        - DO ブロック内から呼び出す場合、明示的な COMMIT/ROLLBACK は使用不可
--        - トランザクションは呼び出し元で管理される
--        - エラー時は自動的にロールバックされる
--
-- 6. エラーハンドリング
--    T-SQL: BEGIN TRY ... BEGIN CATCH ... THROW
--    PG:    BEGIN ... EXCEPTION WHEN OTHERS THEN ... RAISE EXCEPTION
--
-- 7. ERROR_MESSAGE() の変換
--    T-SQL: ERROR_MESSAGE()
--    PG:    GET STACKED DIAGNOSTICS ... MESSAGE_TEXT
--
-- 8. NVARCHAR → VARCHAR/TEXT
--    PostgreSQL では NVARCHAR と VARCHAR の区別なし（すべて UTF-8）
--
-- 9. SET NOCOUNT ON
--    PostgreSQL では不要（PROCEDURE/FUNCTION はデフォルトで行数を返さない）
--
-- 10. DATETIME2 → TIMESTAMP
--     PostgreSQL の TIMESTAMP 型はマイクロ秒精度（6桁）をサポート
--     MSSQL の DATETIME2(7) は 100ナノ秒精度だが、実用上は問題なし
-- ============================================================
