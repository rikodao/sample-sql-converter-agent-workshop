-- ============================================================================
-- Target: Aurora PostgreSQL (Native)
-- Object: public.usp_archive_old_orders
-- Type: STORED PROCEDURE
-- Converted from: T-SQL (SQL Server)
-- ============================================================================

CREATE OR REPLACE PROCEDURE public.usp_archive_old_orders(
    p_cutoff_date TIMESTAMP,
    INOUT p_archived_count INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
    v_error_state TEXT;
    v_row_count INT;
BEGIN
    -- Initialize output parameter
    p_archived_count := 0;
    
    -- Validate input parameter
    IF p_cutoff_date IS NULL THEN
        RAISE EXCEPTION 'Parameter p_cutoff_date cannot be NULL';
    END IF;
    
    -- Insert old orders into archive table
    INSERT INTO public.orders_archive (
        order_id,
        order_date,
        customer_id,
        total_amount,
        status,
        archived_date
    )
    SELECT 
        order_id,
        order_date,
        customer_id,
        total_amount,
        status,
        now() AS archived_date
    FROM public.orders
    WHERE order_date < p_cutoff_date;
    
    -- Get count of archived records
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    p_archived_count := v_row_count;
    
    -- Delete archived records from active table
    DELETE FROM public.orders
    WHERE order_date < p_cutoff_date;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Capture error information
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_state = RETURNED_SQLSTATE;
        
        -- Re-raise the error with context
        RAISE EXCEPTION 'Archive procedure failed: % (SQLSTATE: %)', 
            v_error_message, v_error_state;
END;
$$;
