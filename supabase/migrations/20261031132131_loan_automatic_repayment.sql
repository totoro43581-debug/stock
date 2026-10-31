-- All existing and new supported loans are automatically repaid by their existing terms.
-- This migration does not execute the worker. Scheduling takes effect after commit.
CREATE SCHEMA stock_loan_internal;
REVOKE ALL ON SCHEMA stock_loan_internal FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE public.user_loan_auto_repayment_status (
  loan_id uuid PRIMARY KEY REFERENCES public.user_loan_contracts(id) ON DELETE CASCADE,
  last_attempt_at timestamptz NOT NULL,
  last_game_day bigint NOT NULL CHECK (last_game_day>=0),
  last_result text NOT NULL CHECK (last_result IN ('paid','insufficient_funds','no_bank_account','error')),
  amount_paid numeric NOT NULL DEFAULT 0 CHECK (amount_paid>=0)
);
ALTER TABLE public.user_loan_auto_repayment_status ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_loan_auto_repayment_status FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_loan_auto_repayment_status TO authenticated;
CREATE POLICY loan_auto_repayment_read_own ON public.user_loan_auto_repayment_status
 FOR SELECT TO authenticated USING (EXISTS (
   SELECT 1 FROM public.user_loan_contracts c
   WHERE c.id=loan_id AND c.user_id=(SELECT auth.uid())
 ));

CREATE INDEX user_loan_contracts_auto_repayment_due_idx
 ON public.user_loan_contracts ((CASE WHEN terms_snapshot->>'loan_type'='credit'
   THEN coalesce(next_payment_game_day,maturity_game_day) ELSE maturity_game_day END),id)
 WHERE status IN ('active','overdue') AND outstanding_principal>0
   AND terms_snapshot->>'loan_type' IN ('credit','deposit_secured');


CREATE FUNCTION stock_loan_internal.repay_credit(p_user uuid, p_loan_id uuid, p_mode text, p_request_key uuid, p_amount numeric, p_automatic boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid:=p_user;
  v_loan public.user_loan_contracts%ROWTYPE;
  v_bank public.user_asset_accounts%ROWTYPE;
  v_existing public.user_loan_payments%ROWTYPE;
  v_game_day bigint;
  v_last bigint;
  v_interest_due numeric;
  v_total numeric;
  v_payment numeric;
  v_interest_paid numeric;
  v_principal_paid numeric;
  v_principal_left numeric;
  v_interest_left numeric;
  v_new_due bigint;
  v_status text;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
 IF p_loan_id IS NULL OR p_request_key IS NULL
    OR p_mode IS NULL OR p_mode NOT IN ('scheduled','partial_early','full_early') THEN
   RAISE EXCEPTION '상환 요청이 올바르지 않습니다.';
 END IF;

 SELECT * INTO v_existing FROM public.user_loan_payments
 WHERE user_id=v_uid AND loan_id=p_loan_id AND request_key=p_request_key;
 IF FOUND THEN
   RETURN jsonb_build_object('success',true,'duplicate_request',true,
      'payment_id',v_existing.id,
      'payment',v_existing.principal_paid+v_existing.interest_paid+v_existing.fee_paid);
 END IF;

 SELECT * INTO v_loan FROM public.user_loan_contracts
 WHERE id=p_loan_id AND user_id=v_uid AND status IN ('active','overdue') FOR UPDATE;
 SELECT * INTO v_existing FROM public.user_loan_payments
 WHERE user_id=v_uid AND loan_id=p_loan_id AND request_key=p_request_key;
 IF FOUND THEN
   RETURN jsonb_build_object('success',true,'duplicate_request',true,
      'payment_id',v_existing.id,
      'payment',v_existing.principal_paid+v_existing.interest_paid+v_existing.fee_paid);
 END IF;
 IF v_loan.id IS NULL OR v_loan.terms_snapshot->>'loan_type' IS DISTINCT FROM 'credit' THEN
   RAISE EXCEPTION '상환할 수 있는 신용대출 계약이 없습니다.';
 END IF;
 IF v_loan.outstanding_principal<=0 THEN
   RAISE EXCEPTION '미상환 원금이 없습니다.';
 END IF;

 v_game_day:=(public.get_game_clock()->>'game_day')::bigint;
 IF v_game_day IS NULL OR v_game_day<0 THEN RAISE EXCEPTION '게임 시계를 확인할 수 없습니다.'; END IF;
 IF v_loan.next_payment_game_day IS NULL THEN RAISE EXCEPTION '상환일을 확인할 수 없습니다.'; END IF;
 v_last:=coalesce((v_loan.terms_snapshot->>'last_interest_game_day')::bigint,
                   v_loan.start_game_day);
 v_interest_due:=v_loan.accrued_interest+
     ceil(v_loan.outstanding_principal*v_loan.annual_rate_snapshot/100
          *greatest(0,v_game_day-v_last)::numeric/365);
 v_total:=v_loan.outstanding_principal+v_interest_due;

 IF p_mode='scheduled' THEN
    IF v_game_day<v_loan.next_payment_game_day THEN
      RAISE EXCEPTION '정기 상환일까지 게임 %일 남았습니다.',
          v_loan.next_payment_game_day-v_game_day;
    END IF;
    v_payment:=CASE WHEN v_game_day>=v_loan.maturity_game_day
      THEN v_total
      ELSE least(v_total,greatest(v_interest_due+1,
          (v_loan.terms_snapshot->>'scheduled_payment')::numeric))
      END;
 ELSEIF p_mode='full_early' THEN
    v_payment:=v_total;
 ELSE
    v_payment:=p_amount;
    IF v_payment IS NULL OR v_payment<>trunc(v_payment)
       OR v_payment<=0 OR v_payment>=v_total THEN
      RAISE EXCEPTION '일부상환 금액은 1원 이상 전체상환액 미만이어야 합니다.';
    END IF;
 END IF;

 SELECT * INTO v_bank FROM public.user_asset_accounts
 WHERE user_id=v_uid AND account_type='bank' AND is_active=true FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '생활계좌가 없습니다.' USING ERRCODE=CASE WHEN p_automatic THEN 'P2002' ELSE 'P0001' END; END IF;
 IF v_bank.cash_balance<v_payment THEN
   RAISE EXCEPTION '생활계좌에 상환할 현금이 부족합니다.' USING ERRCODE=CASE WHEN p_automatic THEN 'P2001' ELSE 'P0001' END;
 END IF;

 v_interest_paid:=least(v_payment,v_interest_due);
 v_principal_paid:=v_payment-v_interest_paid;
 v_principal_left:=v_loan.outstanding_principal-v_principal_paid;
 v_interest_left:=v_interest_due-v_interest_paid;

 v_new_due:=CASE WHEN p_mode='scheduled'
   THEN least(v_loan.maturity_game_day,v_loan.next_payment_game_day+30)
   ELSE v_loan.next_payment_game_day END;
 v_status:=CASE WHEN v_principal_left=0 AND v_interest_left=0 THEN 'repaid'
   WHEN v_game_day>v_new_due THEN 'overdue'
   ELSE 'active' END;

 UPDATE public.user_asset_accounts SET
  cash_balance=v_bank.cash_balance-v_payment,updated_at=now()
 WHERE id=v_bank.id;
 UPDATE public.user_loan_contracts SET
  outstanding_principal=v_principal_left,
  accrued_interest=v_interest_left,
  next_payment_game_day=v_new_due,
  terms_snapshot=jsonb_set(v_loan.terms_snapshot,
      '{last_interest_game_day}',to_jsonb(v_game_day)),
  status=v_status,updated_at=now()
 WHERE id=v_loan.id;

 INSERT INTO public.user_loan_payments(
   user_id,loan_id,payment_type,principal_paid,interest_paid,
   fee_paid,game_day,request_key
 ) VALUES(
   v_uid,v_loan.id,
   CASE WHEN v_game_day>v_loan.next_payment_game_day THEN 'overdue'
        ELSE p_mode END,
   v_principal_paid,v_interest_paid,0,v_game_day,p_request_key
 );

 INSERT INTO public.asset_account_transactions(
   user_id,account_type,type,reason,amount,balance_after,title,memo
 ) VALUES(
   v_uid,'bank','withdraw','credit_loan_repayment',
   v_payment,v_bank.cash_balance-v_payment,CASE WHEN p_automatic THEN '신용대출 자동상환' ELSE '신용대출 상환' END,
   '원금 '||v_principal_paid::text||'원 / 이자 '||v_interest_paid::text||'원'
 );

 RETURN jsonb_build_object('success',true,'duplicate_request',false,
   'payment',v_payment,'principal_paid',v_principal_paid,
   'interest_paid',v_interest_paid,'remaining_principal',v_principal_left,
   'remaining_interest',v_interest_left,'next_payment_game_day',v_new_due,
   'status',v_status,'balance_after',v_bank.cash_balance-v_payment);
END;
$function$;

CREATE FUNCTION stock_loan_internal.repay_secured(p_user uuid, p_loan_id uuid, p_payment_amount numeric, p_request_key uuid, p_automatic boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := p_user;
  v_existing public.user_loan_payments%ROWTYPE;
  v_loan public.user_loan_contracts%ROWTYPE;
  v_bank public.user_asset_accounts%ROWTYPE;
  v_day bigint;
  v_last_day bigint;
  v_interest_new numeric;
  v_interest_due numeric;
  v_total_due numeric;
  v_payment numeric;
  v_interest_paid numeric;
  v_principal_paid numeric;
  v_remaining numeric;
  v_status text;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_loan_id IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION '상환 요청이 올바르지 않습니다.'; END IF;
 SELECT * INTO v_existing FROM public.user_loan_payments
 WHERE user_id=v_user AND loan_id=p_loan_id AND request_key=p_request_key;
 IF FOUND THEN
   RETURN jsonb_build_object('success',true,'duplicate_request',true,
      'payment_id',v_existing.id,
      'payment',v_existing.principal_paid+v_existing.interest_paid+v_existing.fee_paid);
 END IF;

  SELECT * INTO v_loan FROM public.user_loan_contracts
    WHERE id=p_loan_id AND user_id=v_user
      AND status IN ('active','overdue')
    FOR UPDATE;
 SELECT * INTO v_existing FROM public.user_loan_payments
 WHERE user_id=v_user AND loan_id=p_loan_id AND request_key=p_request_key;
 IF FOUND THEN
   RETURN jsonb_build_object('success',true,'duplicate_request',true,
      'payment_id',v_existing.id,
      'payment',v_existing.principal_paid+v_existing.interest_paid+v_existing.fee_paid);
 END IF;
  IF v_loan.id IS NULL THEN RAISE EXCEPTION '상환 가능한 대출계약이 없습니다.'; END IF;
  IF v_loan.terms_snapshot->>'loan_type' IS DISTINCT FROM 'deposit_secured' THEN
    RAISE EXCEPTION '지원하지 않는 대출 유형입니다.';
  END IF;

  v_day := (public.get_game_clock()->>'game_day')::bigint;
  IF v_day IS NULL OR v_day<0 THEN RAISE EXCEPTION '게임 시계를 확인할 수 없습니다.'; END IF;
  v_last_day := COALESCE(
    (v_loan.terms_snapshot->>'interest_accrual_day')::bigint,
    v_loan.start_game_day
  );
  v_interest_new := CEIL(
    v_loan.outstanding_principal *
    (v_loan.annual_rate_snapshot/100) *
    GREATEST(0,v_day-v_last_day)::numeric / 365
  );
  v_interest_due := v_loan.accrued_interest + v_interest_new;
  v_total_due := v_loan.outstanding_principal + v_interest_due;

  v_payment := COALESCE(p_payment_amount,v_total_due);
  IF v_payment <= 0 OR v_payment <> trunc(v_payment)
    OR v_payment > v_total_due
  THEN RAISE EXCEPTION '상환금액이 올바르지 않습니다. 상환 필요액: %원',v_total_due;
  END IF;

  SELECT * INTO v_bank FROM public.user_asset_accounts
    WHERE user_id=v_user AND account_type='bank' AND is_active=true
    FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '생활계좌가 없습니다.' USING ERRCODE=CASE WHEN p_automatic THEN 'P2002' ELSE 'P0001' END; END IF;
  IF v_bank.cash_balance < v_payment THEN
    RAISE EXCEPTION '생활계좌의 상환 잔액이 부족합니다.' USING ERRCODE=CASE WHEN p_automatic THEN 'P2001' ELSE 'P0001' END;
  END IF;

  v_interest_paid := LEAST(v_payment,v_interest_due);
  v_principal_paid := v_payment-v_interest_paid;
  v_remaining := v_loan.outstanding_principal-v_principal_paid;
  v_status := CASE WHEN v_remaining=0 AND v_interest_due=v_interest_paid
               THEN 'repaid'
               WHEN v_day > v_loan.maturity_game_day THEN 'overdue'
               ELSE 'active' END;

  UPDATE public.user_asset_accounts SET
    cash_balance=cash_balance-v_payment,
    updated_at=now()
    WHERE id=v_bank.id;

  UPDATE public.user_loan_contracts SET
    outstanding_principal=v_remaining,
    accrued_interest=v_interest_due-v_interest_paid,
    terms_snapshot=jsonb_set(terms_snapshot,
      '{interest_accrual_day}',to_jsonb(v_day)),
    status=v_status,
    updated_at=now()
    WHERE id=v_loan.id;

  INSERT INTO public.user_loan_payments(
    user_id,loan_id,payment_type,principal_paid,
    interest_paid,fee_paid,game_day,request_key
  ) VALUES (
    v_user,v_loan.id,
    CASE
      WHEN v_day>v_loan.maturity_game_day THEN 'overdue'
      WHEN v_status='repaid' THEN 'full_early'
      ELSE 'partial_early'
    END,
    v_principal_paid,v_interest_paid,0,v_day,p_request_key
  );

  INSERT INTO public.asset_account_transactions(
    user_id,account_type,type,reason,amount,balance_after,title,memo
  ) VALUES (
    v_user,'bank','out','loan_repayment',v_payment,
    v_bank.cash_balance-v_payment,
    CASE WHEN p_automatic THEN '예금담보대출 자동상환' ELSE '예금담보대출 상환' END,
    '원금 '||v_principal_paid::text||'원 / 이자 '||v_interest_paid::text||'원'
  );

  IF v_status='repaid' THEN
    UPDATE public.user_loan_collaterals SET released_at=now()
    WHERE loan_id=v_loan.id AND collateral_type='deposit' AND released_at IS NULL;
  END IF;

  RETURN jsonb_build_object(
    'success',true,'contract_id',v_loan.id,
    'payment',v_payment,
    'principal_paid',v_principal_paid,
    'interest_paid',v_interest_paid,
    'remaining_principal',v_remaining,
    'remaining_interest',v_interest_due-v_interest_paid,
    'status',v_status,
    'balance_after',v_bank.cash_balance-v_payment
  );
END;
$function$;


-- Client entry points keep their signatures and authenticated ownership checks.
CREATE OR REPLACE FUNCTION public.repay_basic_credit_loan(
 p_loan_id uuid,p_mode text,p_request_key uuid,p_amount numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
 RETURN stock_loan_internal.repay_credit(v_user,p_loan_id,p_mode,p_request_key,p_amount,false);
END;
$$;

CREATE OR REPLACE FUNCTION public.repay_deposit_secured_loan(
 p_loan_id uuid,p_payment_amount numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
 RETURN stock_loan_internal.repay_secured(v_user,p_loan_id,p_payment_amount,gen_random_uuid(),false);
END;
$$;


CREATE OR REPLACE FUNCTION public.get_my_credit_loans()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH viewer AS (SELECT (SELECT auth.uid()) AS uid),
clock AS (SELECT (public.get_game_clock()->>'game_day')::bigint AS day_number)
SELECT CASE WHEN viewer.uid IS NULL THEN NULL ELSE coalesce((
 SELECT jsonb_agg(jsonb_build_object(
  'id',c.id,
  'automatic_repayment_enabled',true,
  'automatic_repayment_result',ap.last_result,
  'automatic_repayment_attempted_at',ap.last_attempt_at,'product_id',c.product_id,
  'product_name',p.product_name,'status',
   CASE WHEN clock.day_number>c.next_payment_game_day
         AND c.status='active' THEN 'overdue'
       ELSE c.status END,
  'annual_rate',c.annual_rate_snapshot,
  'outstanding_principal',c.outstanding_principal,
  'interest_due',c.accrued_interest+
    ceil(c.outstanding_principal*c.annual_rate_snapshot/100*
       greatest(0,clock.day_number-
        coalesce((c.terms_snapshot->>'last_interest_game_day')::bigint,
          c.start_game_day))::numeric/365),
  'total_repayment_amount',c.outstanding_principal+c.accrued_interest+
    ceil(c.outstanding_principal*c.annual_rate_snapshot/100*
       greatest(0,clock.day_number-
        coalesce((c.terms_snapshot->>'last_interest_game_day')::bigint,
          c.start_game_day))::numeric/365),
  'scheduled_payment',(c.terms_snapshot->>'scheduled_payment')::numeric,
  'next_payment_game_day',c.next_payment_game_day,
  'maturity_game_day',c.maturity_game_day,
  'game_day',clock.day_number
 ) ORDER BY c.created_at DESC)
 FROM public.user_loan_contracts c
 JOIN public.loan_products p ON p.id=c.product_id
 LEFT JOIN public.user_loan_auto_repayment_status ap ON ap.loan_id=c.id
 WHERE c.user_id=viewer.uid AND c.status IN ('active','overdue')
   AND c.terms_snapshot->>'loan_type'='credit'
 ),'[]'::jsonb) END
FROM viewer CROSS JOIN clock;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_deposit_secured_loans()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  WITH current_day AS (
    SELECT (public.get_game_clock()->>'game_day')::bigint AS today
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',c.id,
  'automatic_repayment_enabled',true,
  'automatic_repayment_result',ap.last_result,
  'automatic_repayment_attempted_at',ap.last_attempt_at,
    'product_name',p.product_name,
    'principal_amount',c.principal_amount,
    'outstanding_principal',c.outstanding_principal,
    'annual_rate',c.annual_rate_snapshot,
    'start_game_day',c.start_game_day,
    'maturity_game_day',c.maturity_game_day,
    'status', CASE
      WHEN c.status='active' AND cd.today>c.maturity_game_day THEN 'overdue'
      ELSE c.status END,
    'deposit_account_id',c.terms_snapshot->>'deposit_account_id',
    'accrued_interest',c.accrued_interest +
      CEIL(c.outstanding_principal*(c.annual_rate_snapshot/100)*
        GREATEST(0,cd.today-COALESCE(
          (c.terms_snapshot->>'interest_accrual_day')::bigint,c.start_game_day
        ))::numeric/365),
    'full_repayment_amount',c.outstanding_principal+c.accrued_interest+
      CEIL(c.outstanding_principal*(c.annual_rate_snapshot/100)*
        GREATEST(0,cd.today-COALESCE(
          (c.terms_snapshot->>'interest_accrual_day')::bigint,c.start_game_day
        ))::numeric/365)
  ) ORDER BY c.created_at DESC), '[]'::jsonb)
  FROM public.user_loan_contracts c
  JOIN public.loan_products p ON p.id=c.product_id
  CROSS JOIN current_day cd
  LEFT JOIN public.user_loan_auto_repayment_status ap ON ap.loan_id=c.id
 WHERE c.user_id=(select auth.uid())
    AND c.terms_snapshot->>'loan_type'='deposit_secured'
    AND c.status IN ('active','overdue');
$function$;


CREATE FUNCTION stock_loan_internal.process_due_loans(p_batch_size integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 v_day bigint;
 v_loan public.user_loan_contracts%ROWTYPE;
 v_result jsonb;
 v_key uuid;
 v_outcome text;
 v_amount numeric;
 v_code text;
 v_processed integer:=0;
 v_paid integer:=0;
 v_limit integer:=greatest(1,least(coalesce(p_batch_size,100),500));
BEGIN
 IF NOT pg_try_advisory_xact_lock(hashtextextended('stock_loan_automatic_repayment',0)) THEN
   RETURN jsonb_build_object('processed',0,'paid',0,'worker_busy',true);
 END IF;
 v_day:=(public.get_game_clock()->>'game_day')::bigint;
 IF v_day IS NULL OR v_day<0 THEN RAISE EXCEPTION '게임 시계를 확인할 수 없습니다.'; END IF;
 FOR v_loan IN
   SELECT c.* FROM public.user_loan_contracts c
   LEFT JOIN public.user_loan_auto_repayment_status ap ON ap.loan_id=c.id
   WHERE c.status IN ('active','overdue') AND c.outstanding_principal>0
     AND c.terms_snapshot->>'loan_type' IN ('credit','deposit_secured')
     AND v_day >= CASE WHEN c.terms_snapshot->>'loan_type'='credit'
       THEN coalesce(c.next_payment_game_day,c.maturity_game_day) ELSE c.maturity_game_day END
   ORDER BY ap.last_attempt_at NULLS FIRST,c.id
   LIMIT v_limit FOR UPDATE OF c SKIP LOCKED
 LOOP
   -- Row locks plus atomic due-date advancement provide exactly-once cycle execution.
   -- Do not use a predictable key that a client could pre-seed in a manual payment.
   v_key:=gen_random_uuid();
   v_amount:=0;
   -- A failed payment rolls back every account/contract/ledger write for this loan.
   BEGIN
     IF v_loan.terms_snapshot->>'loan_type'='credit' THEN
       v_result:=stock_loan_internal.repay_credit(v_loan.user_id,v_loan.id,'scheduled',v_key,NULL,true);
     ELSE
       v_result:=stock_loan_internal.repay_secured(v_loan.user_id,v_loan.id,NULL,v_key,true);
     END IF;
     v_amount:=(v_result->>'payment')::numeric;
     IF v_amount IS NULL OR v_amount<=0 THEN RAISE EXCEPTION '상환 결과를 확인할 수 없습니다.'; END IF;
     v_outcome:='paid';
     v_paid:=v_paid+1;
   EXCEPTION WHEN OTHERS THEN
     GET STACKED DIAGNOSTICS v_code=RETURNED_SQLSTATE;
     v_outcome:=CASE v_code WHEN 'P2001' THEN 'insufficient_funds'
                            WHEN 'P2002' THEN 'no_bank_account' ELSE 'error' END;
     v_amount:=0;
     IF v_outcome='error' THEN
       RAISE LOG 'Automatic loan repayment failed, loan %, SQLSTATE %',v_loan.id,v_code;
     END IF;
   END;
   -- Existing grace boundary: overdue only when today is AFTER the due game day.
   UPDATE public.user_loan_contracts SET status='overdue',updated_at=now()
    WHERE id=v_loan.id AND status='active' AND outstanding_principal>0
      AND v_day>CASE WHEN terms_snapshot->>'loan_type'='credit'
        THEN coalesce(next_payment_game_day,maturity_game_day) ELSE maturity_game_day END;
   INSERT INTO public.user_loan_auto_repayment_status
     (loan_id,last_attempt_at,last_game_day,last_result,amount_paid)
    VALUES(v_loan.id,clock_timestamp(),v_day,v_outcome,v_amount)
    ON CONFLICT(loan_id) DO UPDATE SET
      last_attempt_at=EXCLUDED.last_attempt_at,last_game_day=EXCLUDED.last_game_day,
      last_result=EXCLUDED.last_result,amount_paid=EXCLUDED.amount_paid;
   v_processed:=v_processed+1;
 END LOOP;
 RETURN jsonb_build_object('processed',v_processed,'paid',v_paid,'worker_busy',false);
END;
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA stock_loan_internal FROM PUBLIC, anon, authenticated, service_role;

SELECT cron.schedule('loan_automatic_repayment_every_minute','* * * * *',
 'SELECT stock_loan_internal.process_due_loans(100);');
