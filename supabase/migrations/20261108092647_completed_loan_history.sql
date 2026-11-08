-- Read-only history; repayment, account balances, schedules and cron are unchanged.
CREATE INDEX IF NOT EXISTS user_loan_contracts_completed_history_idx
  ON public.user_loan_contracts(user_id, updated_at DESC, id DESC)
  WHERE status = 'repaid';
CREATE INDEX IF NOT EXISTS user_loan_payments_receipt_history_idx
  ON public.user_loan_payments(loan_id, user_id, created_at DESC, id DESC);
CREATE OR REPLACE FUNCTION public.get_my_repaid_loans(
  p_limit integer DEFAULT 20,
  p_before_updated_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
  v_result jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.' USING ERRCODE = '42501';
  END IF;
  IF (p_before_updated_at IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION '조회 기준이 올바르지 않습니다.' USING ERRCODE = '22023';
  END IF;

  WITH candidates AS MATERIALIZED (
    SELECT c.id, c.product_id, c.principal_amount, c.terms_snapshot,
           c.updated_at
    FROM public.user_loan_contracts c
    WHERE c.user_id = v_user AND c.status = 'repaid'
      AND (p_before_updated_at IS NULL OR
           (c.updated_at, c.id) < (p_before_updated_at, p_before_id))
    ORDER BY c.updated_at DESC, c.id DESC
    LIMIT v_limit + 1
  ), visible AS MATERIALIZED (
    SELECT * FROM candidates ORDER BY updated_at DESC, id DESC LIMIT v_limit
  ), items AS (
    SELECT c.id, p.product_name,
           coalesce(c.terms_snapshot->>'loan_type', p.loan_type) AS loan_type,
           c.principal_amount, c.updated_at,
           payments.principal_paid, payments.interest_paid, payments.fee_paid,
           payments.total_paid, payments.payment_count, payments.last_payment_at
    FROM visible c
    LEFT JOIN public.loan_products p ON p.id = c.product_id
    CROSS JOIN LATERAL (
      SELECT sum(r.principal_paid) AS principal_paid,
             sum(r.interest_paid) AS interest_paid,
             sum(r.fee_paid) AS fee_paid,
             sum(r.principal_paid + r.interest_paid + r.fee_paid) AS total_paid,
             count(*) AS payment_count,
             max(r.created_at) AS last_payment_at
      FROM public.user_loan_payments r
      WHERE r.loan_id = c.id AND r.user_id = v_user
    ) payments
  )
  SELECT jsonb_build_object(
    'items', coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY i.updated_at DESC, i.id DESC) FROM items i), '[]'::jsonb),
    'has_more', (SELECT count(*) > v_limit FROM candidates),
    'next_cursor', CASE WHEN (SELECT count(*) > v_limit FROM candidates)
      THEN (SELECT jsonb_build_object('updated_at', updated_at, 'id', id)
            FROM visible ORDER BY updated_at ASC, id ASC LIMIT 1)
      ELSE NULL END
  ) INTO v_result;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_loan_payment_history(
  p_loan_id uuid,
  p_limit integer DEFAULT 20,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 50));
  v_result jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.user_loan_contracts c
    WHERE c.id = p_loan_id AND c.user_id = v_user
  ) THEN
    RAISE EXCEPTION '조회할 수 있는 대출 계약이 없습니다.' USING ERRCODE = '42501';
  END IF;
  IF (p_before_created_at IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION '조회 기준이 올바르지 않습니다.' USING ERRCODE = '22023';
  END IF;

  WITH candidates AS MATERIALIZED (
    SELECT r.id, r.payment_type, r.principal_paid, r.interest_paid, r.fee_paid,
           r.principal_paid + r.interest_paid + r.fee_paid AS total_paid,
           r.created_at
    FROM public.user_loan_payments r
    WHERE r.loan_id = p_loan_id AND r.user_id = v_user
      AND (p_before_created_at IS NULL OR
           (r.created_at, r.id) < (p_before_created_at, p_before_id))
    ORDER BY r.created_at DESC, r.id DESC
    LIMIT v_limit + 1
  ), visible AS MATERIALIZED (
    SELECT * FROM candidates ORDER BY created_at DESC, id DESC LIMIT v_limit
  )
  SELECT jsonb_build_object(
    'items', coalesce((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at DESC, r.id DESC) FROM visible r), '[]'::jsonb),
    'has_more', (SELECT count(*) > v_limit FROM candidates),
    'next_cursor', CASE WHEN (SELECT count(*) > v_limit FROM candidates)
      THEN (SELECT jsonb_build_object('created_at', created_at, 'id', id)
            FROM visible ORDER BY created_at ASC, id ASC LIMIT 1)
      ELSE NULL END
  ) INTO v_result;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_repaid_loans(integer,timestamptz,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_loan_payment_history(uuid,integer,timestamptz,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_repaid_loans(integer,timestamptz,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_loan_payment_history(uuid,integer,timestamptz,uuid) TO authenticated;
