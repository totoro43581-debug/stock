-- Existing contracts retain their original dates, balances and real-time rules.
-- Only new contracts use the shared virtual clock.
ALTER TABLE public.user_bank_accounts
  ADD COLUMN time_model text NOT NULL DEFAULT 'real'
    CHECK (time_model IN ('real', 'virtual')),
  ADD COLUMN installment_interval_game_days integer
    CHECK (installment_interval_game_days > 0);

CREATE OR REPLACE FUNCTION public.get_game_clock()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'game_day', floor(
      greatest(0,extract(epoch from (now() - s.real_epoch)))
      * s.game_seconds_per_real_second / 86400
    )::bigint,
    'game_datetime', (
      s.virtual_epoch +
      (greatest(0,extract(epoch from (now() - s.real_epoch)))
        * s.game_seconds_per_real_second)::double precision
        * interval '1 second'
    ),
    'game_seconds_per_real_second',s.game_seconds_per_real_second,
    'real_seconds_per_game_day',
      (86400/s.game_seconds_per_real_second),
    'game_time_model','virtual',
    'legacy_bank_products_time_model','real',
    'bank_products_time_model','virtual'
  )
  from public.game_clock_settings s where s.singleton_id = true
$function$;

CREATE OR REPLACE FUNCTION public.open_bank_deposit(p_product_id uuid, p_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_game_now timestamptz;
  v_product record;
  v_bank_account record;
  v_expected_interest numeric;
  v_expected_maturity numeric;
  v_new_balance numeric;
  v_user_bank_account_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_amount <= 0 then
    raise exception '가입 금액이 올바르지 않습니다.';
  end if;

  select *
  into v_product
  from public.bank_products
  where id = p_product_id
    and product_type = 'deposit'
    and is_active = true;

  if not found then
    raise exception '가입 가능한 예금 상품이 아닙니다.';
  end if;

  if p_amount < v_product.min_amount then
    raise exception '최소 가입 금액보다 작습니다.';
  end if;

  if v_product.max_amount is not null and p_amount > v_product.max_amount then
    raise exception '최대 가입 금액보다 큽니다.';
  end if;

  select *
  into v_bank_account
  from public.user_asset_accounts
  where user_id = v_user_id
    and account_type = 'bank'
    and is_active = true
  for update;

  if not found then
    raise exception '생활 현금 계좌가 없습니다.';
  end if;

  if v_bank_account.cash_balance < p_amount then
    raise exception '생활 현금 계좌 잔액이 부족합니다.';
  end if;

  v_expected_interest :=
    floor(p_amount * (v_product.annual_rate / 100) * (v_product.term_days::numeric / 365));

  v_expected_maturity := p_amount + v_expected_interest;
  v_new_balance := v_bank_account.cash_balance - p_amount;

  v_game_now := (public.get_game_clock()->>'game_datetime')::timestamptz;
  if v_game_now is null or v_product.term_days is null or v_product.term_days <= 0 then
    raise exception '게임 시간 또는 상품 기간을 확인할 수 없습니다.';
  end if;

  update public.user_asset_accounts
  set cash_balance = v_new_balance
  where id = v_bank_account.id;

  insert into public.user_bank_accounts (
    user_id,
    product_id,
    product_name_snapshot,
    product_type,
    annual_rate_snapshot,
    principal_amount,
    installment_amount,
    total_installments,
    paid_installments,
    expected_interest_amount,
    expected_maturity_amount,
    start_at,
    maturity_at,
    next_payment_due_at,
    time_model,
    installment_interval_game_days,
    status,
    created_at,
    updated_at
  )
  values (
    v_user_id,
    v_product.id,
    v_product.product_name,
    'deposit',
    v_product.annual_rate,
    p_amount,
    0,
    0,
    0,
    v_expected_interest,
    v_expected_maturity,
    v_game_now,
    v_game_now + make_interval(days => v_product.term_days),
    null,
    'virtual',
    null,
    'active',
    now(),
    now()
  )
  returning id into v_user_bank_account_id;

  insert into public.asset_account_transactions (
    user_id,
    type,
    reason,
    amount,
    balance_after,
    title,
    memo,
    created_at
  )
  values (
    v_user_id,
    'withdraw',
    'asset_to_deposit',
    p_amount,
    v_new_balance,
    '예금 가입',
    v_product.product_name,
    now()
  );

  return jsonb_build_object(
    'success', true,
    'account_id', v_user_bank_account_id,
    'balance_after', v_new_balance
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.open_bank_savings(p_product_id uuid, p_installment_amount numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_game_now timestamptz;
  v_product record;
  v_bank_account record;
  v_total_principal numeric;
  v_expected_interest numeric;
  v_expected_maturity numeric;
  v_new_balance numeric;
  v_interval_days integer;
  v_user_bank_account_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if p_installment_amount <= 0 then
    raise exception '납입 금액이 올바르지 않습니다.';
  end if;

  select *
  into v_product
  from public.bank_products
  where id = p_product_id
    and product_type = 'savings'
    and is_active = true;

  if not found then
    raise exception '가입 가능한 적금 상품이 아닙니다.';
  end if;

  if v_product.installment_count is null or v_product.installment_count <= 0 then
    raise exception '적금 납입 회차가 올바르지 않습니다.';
  end if;

  if p_installment_amount < v_product.min_amount then
    raise exception '최소 납입 금액보다 작습니다.';
  end if;

  if v_product.max_amount is not null and p_installment_amount > v_product.max_amount then
    raise exception '최대 납입 금액보다 큽니다.';
  end if;

  select *
  into v_bank_account
  from public.user_asset_accounts
  where user_id = v_user_id
    and account_type = 'bank'
    and is_active = true
  for update;

  if not found then
    raise exception '생활 현금 계좌가 없습니다.';
  end if;

  if v_bank_account.cash_balance < p_installment_amount then
    raise exception '생활 현금 계좌 잔액이 부족합니다.';
  end if;

  v_total_principal := p_installment_amount * v_product.installment_count;

  v_expected_interest :=
    floor(v_total_principal * (v_product.annual_rate / 100) * (v_product.term_days::numeric / 365));

  v_expected_maturity := v_total_principal + v_expected_interest;

  v_new_balance := v_bank_account.cash_balance - p_installment_amount;

  v_interval_days := coalesce(
    v_product.installment_interval_days,
    greatest(1, floor(v_product.term_days::numeric / v_product.installment_count)::integer)
  );

  v_game_now := (public.get_game_clock()->>'game_datetime')::timestamptz;
  if v_game_now is null or v_product.term_days is null or v_product.term_days <= 0 then
    raise exception '게임 시간 또는 상품 기간을 확인할 수 없습니다.';
  end if;

  if v_interval_days is null or v_interval_days <= 0 then
    raise exception '적금 납입 주기가 올바르지 않습니다.';
  end if;

  update public.user_asset_accounts
  set cash_balance = v_new_balance
  where id = v_bank_account.id;

  insert into public.user_bank_accounts (
    user_id,
    product_id,
    product_name_snapshot,
    product_type,
    annual_rate_snapshot,
    principal_amount,
    installment_amount,
    total_installments,
    paid_installments,
    expected_interest_amount,
    expected_maturity_amount,
    start_at,
    maturity_at,
    next_payment_due_at,
    time_model,
    installment_interval_game_days,
    status,
    created_at,
    updated_at
  )
  values (
    v_user_id,
    v_product.id,
    v_product.product_name,
    'savings',
    v_product.annual_rate,
    p_installment_amount,
    p_installment_amount,
    v_product.installment_count,
    1,
    v_expected_interest,
    v_expected_maturity,
    v_game_now,
    v_game_now + make_interval(days => v_product.term_days),
    v_game_now + make_interval(days => v_interval_days),
    'virtual',
    v_interval_days,
    'active',
    now(),
    now()
  )
  returning id into v_user_bank_account_id;

  insert into public.asset_account_transactions (
    user_id,
    type,
    reason,
    amount,
    balance_after,
    title,
    memo,
    created_at
  )
  values (
    v_user_id,
    'withdraw',
    'asset_to_savings',
    p_installment_amount,
    v_new_balance,
    '적금 가입',
    v_product.product_name || ' 1회차 납입',
    now()
  );

  return jsonb_build_object(
    'success', true,
    'account_id', v_user_bank_account_id,
    'balance_after', v_new_balance
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.pay_bank_savings_installment(p_account_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_contract_now timestamptz;
  v_account record;
  v_bank_account record;
  v_new_paid_installments integer;
  v_new_principal numeric;
  v_new_balance numeric;
  v_next_payment_due_at timestamptz;
  v_interval_days integer;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select *
  into v_account
  from public.user_bank_accounts
  where id = p_account_id
    and user_id = v_user_id
    and product_type = 'savings'
    and status = 'active'
  for update;

  if not found then
    raise exception '납입 가능한 적금 계좌가 없습니다.';
  end if;

  if v_account.total_installments is null or v_account.total_installments <= 0 then
    raise exception '적금 총 납입 회차가 올바르지 않습니다.';
  end if;

  if v_account.paid_installments >= v_account.total_installments then
    raise exception '이미 모든 회차 납입이 완료되었습니다.';
  end if;

  if v_account.installment_amount is null or v_account.installment_amount <= 0 then
    raise exception '납입 금액이 올바르지 않습니다.';
  end if;

  select *
  into v_bank_account
  from public.user_asset_accounts
  where user_id = v_user_id
    and account_type = 'bank'
    and is_active = true
  for update;

  if not found then
    raise exception '생활 현금 계좌가 없습니다.';
  end if;

  if v_bank_account.cash_balance < v_account.installment_amount then
    raise exception '생활 현금 계좌 잔액이 부족합니다.';
  end if;

  v_new_paid_installments := v_account.paid_installments + 1;
  v_new_principal := v_account.principal_amount + v_account.installment_amount;
  v_new_balance := v_bank_account.cash_balance - v_account.installment_amount;

  v_contract_now := now();
  if v_account.time_model = 'virtual' then
    v_contract_now := (public.get_game_clock()->>'game_datetime')::timestamptz;
    v_interval_days := v_account.installment_interval_game_days;
    if v_contract_now is null or v_interval_days is null or v_interval_days <= 0 then
      raise exception '게임 시간 또는 적금 납입 주기를 확인할 수 없습니다.';
    end if;
  else
    v_interval_days := greatest(
      1,
      floor(
        extract(day from (v_account.maturity_at - v_account.start_at))::numeric
        / v_account.total_installments
      )::integer
    );
  end if;

  if v_new_paid_installments >= v_account.total_installments then
    v_next_payment_due_at := null;
  else
    v_next_payment_due_at := v_contract_now + make_interval(days => v_interval_days);
  end if;

  update public.user_asset_accounts
  set cash_balance = v_new_balance
  where id = v_bank_account.id;

  update public.user_bank_accounts
  set
    principal_amount = v_new_principal,
    paid_installments = v_new_paid_installments,
    next_payment_due_at = v_next_payment_due_at,
    updated_at = now()
  where id = v_account.id;

  insert into public.asset_account_transactions (
    user_id,
    type,
    reason,
    amount,
    balance_after,
    title,
    memo,
    created_at
  )
  values (
    v_user_id,
    'withdraw',
    'asset_to_savings',
    v_account.installment_amount,
    v_new_balance,
    '적금 납입',
    v_account.product_name_snapshot || ' ' || v_new_paid_installments || '회차 납입',
    now()
  );

  return jsonb_build_object(
    'success', true,
    'account_id', v_account.id,
    'paid_installments', v_new_paid_installments,
    'balance_after', v_new_balance
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.claim_bank_product_account(p_account_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid;
  v_contract_now timestamptz;
  v_account record;
  v_bank_account record;
  v_claim_amount numeric;
  v_new_balance numeric;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select *
  into v_account
  from public.user_bank_accounts
  where id = p_account_id
    and user_id = v_user_id
    and status = 'active'
  for update;

  if not found then
    raise exception '수령 가능한 금융상품 계좌가 없습니다.';
  end if;

  v_contract_now := now();
  if v_account.time_model = 'virtual' then
    v_contract_now := (public.get_game_clock()->>'game_datetime')::timestamptz;
    if v_contract_now is null then
      raise exception '게임 시간을 확인할 수 없습니다.';
    end if;
    if v_account.product_type = 'savings'
       and (v_account.total_installments is null or v_account.total_installments <= 0
            or v_account.paid_installments < v_account.total_installments) then
      raise exception '모든 회차를 납입한 뒤 만기 금액을 수령할 수 있습니다.';
    end if;
  end if;

  if v_contract_now < v_account.maturity_at then
    raise exception '아직 만기일이 지나지 않았습니다.';
  end if;

  select *
  into v_bank_account
  from public.user_asset_accounts
  where user_id = v_user_id
    and account_type = 'bank'
    and is_active = true
  for update;

  if not found then
    raise exception '생활 현금 계좌가 없습니다.';
  end if;

  v_claim_amount := coalesce(
    v_account.expected_maturity_amount,
    v_account.principal_amount + v_account.expected_interest_amount
  );

  v_new_balance := v_bank_account.cash_balance + v_claim_amount;

  update public.user_asset_accounts
  set cash_balance = v_new_balance
  where id = v_bank_account.id;

  update public.user_bank_accounts
  set
    status = 'claimed',
    updated_at = now()
  where id = v_account.id;

  insert into public.asset_account_transactions (
    user_id,
    type,
    reason,
    amount,
    balance_after,
    title,
    memo,
    created_at
  )
  values (
    v_user_id,
    'deposit',
    case
      when v_account.product_type = 'deposit' then 'deposit_to_asset'
      when v_account.product_type = 'savings' then 'savings_to_asset'
      else 'bank_product_to_asset'
    end,
    v_claim_amount,
    v_new_balance,
    '금융상품 만기수령',
    v_account.product_name_snapshot,
    now()
  );

  return jsonb_build_object(
    'success', true,
    'account_id', v_account.id,
    'claim_amount', v_claim_amount,
    'balance_after', v_new_balance
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_loan_offers()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  WITH viewer AS (
    SELECT (select auth.uid()) AS user_id
  ),
  user_profile AS (
    SELECT
      (i.income->>'annual_income')::numeric AS annual_income,
      (public.get_my_credit_assessment()->>'credit_score')::integer AS credit_score,
      COALESCE((i.income->>'income_verified')::boolean,false) AS income_verified
    FROM viewer v
    CROSS JOIN LATERAL (
      SELECT public.get_my_verified_income() AS income
    ) i
    WHERE v.user_id IS NOT NULL
  ),
  deposits AS (
    SELECT bp.bank_id,
      COALESCE(SUM(ub.principal_amount), 0) AS total
    FROM public.user_bank_accounts ub
    JOIN public.bank_products bp ON bp.id=ub.product_id
    JOIN viewer v ON ub.user_id=v.user_id
    WHERE ub.status='active' AND ub.product_type='deposit'
      AND ub.maturity_at > CASE WHEN ub.time_model='virtual'
        THEN (public.get_game_clock()->>'game_datetime')::timestamptz
        ELSE now() END
      AND NOT EXISTS (
        SELECT 1 FROM public.user_loan_collaterals col
        WHERE col.asset_reference_id=ub.id
          AND col.collateral_type='deposit'
          AND col.released_at IS NULL
      )
    GROUP BY bp.bank_id
  ),
  debt AS (
    SELECT
      COALESCE(SUM(c.outstanding_principal),0) AS principal,
      COALESCE(SUM(c.outstanding_principal)
        FILTER (WHERE p.loan_type='deposit_secured'),0) AS deposit_secured
    FROM public.user_loan_contracts c
    JOIN public.loan_products p ON p.id = c.product_id
    JOIN viewer v ON c.user_id=v.user_id
    WHERE c.status IN ('active','overdue')
  ),
  offers AS (
    SELECT p.*,b.bank_name,
      u.annual_income, u.credit_score, u.income_verified,
      COALESCE(d.total,0) AS deposit_total,
      debt.principal AS existing_principal,
      debt.deposit_secured AS existing_deposit_secured,
      GREATEST(1,CEIL(p.max_term_game_days / 30.0)) AS months,
      p.annual_rate / 1200 AS monthly_rate
    FROM public.loan_products p
    JOIN public.banks b ON b.id=p.bank_id
    CROSS JOIN viewer v
    LEFT JOIN deposits d ON d.bank_id=p.bank_id
    CROSS JOIN debt
    LEFT JOIN user_profile u ON true
    WHERE v.user_id IS NOT NULL
      AND p.catalog_visible = true
  ),
  assessed AS (
    SELECT o.*,
      CASE
        WHEN o.product_code='LOAN_CREDIT_BASIC' AND o.is_active=true
          THEN (public.get_my_credit_loan_quote(o.id,o.max_term_game_days)->>'approval_limit')::numeric
        WHEN o.loan_type = 'deposit_secured'
          THEN GREATEST(0, FLOOR(LEAST(o.max_amount,
            o.deposit_total * COALESCE(o.max_ltv,0))))
        WHEN o.loan_type IN ('credit','overdraft','business')
         AND o.income_verified IS TRUE
         AND o.annual_income > 0
         AND o.credit_score IS NOT NULL
         AND o.credit_score >= COALESCE(o.min_credit_score,0)
        THEN GREATEST(0, FLOOR(LEAST(o.max_amount,
          (
            o.annual_income * 0.4 / 12
          ) / (
            CASE WHEN o.monthly_rate = 0
              THEN 1 / o.months
              ELSE o.monthly_rate * POWER(1+o.monthly_rate,o.months)
                   / (POWER(1+o.monthly_rate,o.months)-1)
            END
          ) - o.existing_principal
        )))
        ELSE null
      END AS indicative_limit
    FROM offers o
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id',a.id,
      'product_code',a.product_code,
      'product_name',a.product_name,
      'bank_name',a.bank_name,
      'loan_type',a.loan_type,
      'collateral_type',a.collateral_type,
      'annual_rate',a.annual_rate,
      'min_amount',a.min_amount,
      'max_amount',a.max_amount,
      'min_credit_score',a.min_credit_score,
      'max_ltv',a.max_ltv,
      'min_term_game_days',a.min_term_game_days,
      'max_term_game_days',a.max_term_game_days,
      'repayment_method',a.repayment_method,
      'early_repayment_policy',a.early_repayment_policy,
      'early_repayment_fee_rate',a.early_repayment_fee_rate,
      'fee_period_game_days',a.fee_period_game_days,
      'lock_period_game_days',a.lock_period_game_days,
      'partial_repayment_limit_ratio',a.partial_repayment_limit_ratio,
      'advance_notice_game_days',a.advance_notice_game_days,
      'is_active',a.is_active,
      'indicative_limit',a.indicative_limit,
      'precheck_status',
        CASE
          WHEN a.product_code='LOAN_CREDIT_BASIC' AND a.is_active=true
             THEN CASE public.get_my_credit_loan_quote(a.id,a.max_term_game_days)->>'status'
                WHEN 'eligible' THEN 'precheck_possible'
                WHEN 'low_credit_score' THEN 'low_credit_score'
                WHEN 'delinquent' THEN 'delinquent'
                WHEN 'existing_credit_loan' THEN 'existing_credit_loan'
                WHEN 'credit_cooldown' THEN 'credit_cooldown'
                ELSE 'limit_below_minimum'
             END
          WHEN a.loan_type IN ('home_purchase','home_equity','land_secured',
                               'commercial_secured','building_secured')
             THEN 'property_not_connected'
          WHEN a.loan_type = 'business'
             THEN 'business_not_connected'
          WHEN a.loan_type='deposit_secured'
             AND COALESCE(a.indicative_limit,0) < a.min_amount
             THEN 'insufficient_collateral'
          WHEN a.income_verified IS DISTINCT FROM TRUE
             AND a.loan_type IN ('credit','overdraft')
             THEN 'income_not_verified'
          WHEN a.credit_score IS NULL
             AND a.loan_type IN ('credit','overdraft')
             THEN 'credit_not_set'
          WHEN a.credit_score < COALESCE(a.min_credit_score,0)
             AND a.loan_type IN ('credit','overdraft')
             THEN 'low_credit_score'
          WHEN COALESCE(a.indicative_limit,0) < a.min_amount
             THEN 'limit_below_minimum'
          ELSE 'precheck_possible'
        END
    ) ORDER BY a.loan_type,a.annual_rate
  ),'[]'::jsonb)
  FROM assessed a;
$function$;

CREATE OR REPLACE FUNCTION public.issue_deposit_secured_loan(p_product_id uuid, p_deposit_account_id uuid, p_amount numeric, p_term_game_days integer, p_request_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_product public.loan_products%ROWTYPE;
  v_deposit public.user_bank_accounts%ROWTYPE;
  v_bank public.user_asset_accounts%ROWTYPE;
  v_clock jsonb;
  v_day bigint;
  v_seconds_per_day numeric;
  v_limit numeric;
  v_contract_id uuid;
  v_existing public.user_loan_contracts%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_product_id IS NULL OR p_deposit_account_id IS NULL OR p_request_key IS NULL
     OR p_amount IS NULL OR p_term_game_days IS NULL
     OR p_amount <= 0 OR p_amount <> trunc(p_amount)
  THEN RAISE EXCEPTION '대출 신청 정보가 올바르지 않습니다.'; END IF;

  SELECT * INTO v_existing FROM public.user_loan_contracts
    WHERE issue_request_key=p_request_key AND user_id=v_user;
  IF FOUND THEN
    RETURN jsonb_build_object('success',true,'contract_id',v_existing.id,
      'principal_amount',v_existing.principal_amount,'duplicate_request',true);
  END IF;

  SELECT * INTO STRICT v_product FROM public.loan_products
    WHERE id=p_product_id AND is_active=true
      AND catalog_visible=true
      AND loan_type='deposit_secured'
      AND collateral_type='deposit';

  IF p_amount < v_product.min_amount OR p_amount > v_product.max_amount THEN
    RAISE EXCEPTION '상품의 대출 가능 금액을 벗어났습니다.';
  END IF;
  IF p_term_game_days < v_product.min_term_game_days
     OR p_term_game_days > v_product.max_term_game_days THEN
    RAISE EXCEPTION '상품의 대출 기간을 벗어났습니다.';
  END IF;

  SELECT * INTO v_deposit
    FROM public.user_bank_accounts
    WHERE id=p_deposit_account_id AND user_id=v_user
      AND status='active' AND product_type='deposit'
    FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '이용 가능한 예금담보가 없습니다.'; END IF;

  -- A bank can pledge only its own deposits, including server-side requests.
  IF NOT EXISTS (
    SELECT 1 FROM public.bank_products bp
    WHERE bp.id=v_deposit.product_id AND bp.bank_id=v_product.bank_id
  ) THEN
    RAISE EXCEPTION '해당 은행의 예금만 이 대출상품에 담보로 사용할 수 있습니다.';
  END IF;

  IF EXISTS(
    SELECT 1 FROM public.user_loan_collaterals col
    WHERE col.asset_reference_id=v_deposit.id
      AND col.collateral_type='deposit'
      AND col.released_at IS NULL
  ) THEN
    RAISE EXCEPTION '이미 담보로 사용 중인 예금입니다.';
  END IF;

  v_limit := LEAST(v_product.max_amount,
      floor(v_deposit.principal_amount*COALESCE(v_product.max_ltv,0)));
  IF p_amount > v_limit THEN
    RAISE EXCEPTION '예금 담보 인정 한도를 초과했습니다. 최대 %원',v_limit;
  END IF;

  v_clock := public.get_game_clock();
  v_day := (v_clock->>'game_day')::bigint;
  v_seconds_per_day := (v_clock->>'real_seconds_per_game_day')::numeric;
  IF v_seconds_per_day IS NULL OR v_day IS NULL
     OR (v_deposit.time_model='virtual' AND v_clock->>'game_datetime' IS NULL) THEN
    RAISE EXCEPTION '게임 시간 설정을 불러오지 못했습니다.';
  END IF;

  IF v_deposit.maturity_at < (CASE WHEN v_deposit.time_model='virtual'
      THEN (v_clock->>'game_datetime')::timestamptz
        + make_interval(days => p_term_game_days)
      ELSE now() + (p_term_game_days*v_seconds_per_day)*interval '1 second'
      END) THEN
    RAISE EXCEPTION '예금 만기보다 대출 만기가 늦습니다. 대출 기간을 줄여주세요.';
  END IF;

  SELECT * INTO v_bank FROM public.user_asset_accounts
    WHERE user_id=v_user AND account_type='bank' AND is_active=true
    FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '생활계좌가 없습니다.'; END IF;

  INSERT INTO public.user_loan_contracts(
    user_id,product_id,principal_amount,outstanding_principal,
    accrued_interest,annual_rate_snapshot,terms_snapshot,
    start_game_day,maturity_game_day,next_payment_game_day,
    collateral_required,status,issue_request_key
  ) VALUES (
    v_user,v_product.id,p_amount,p_amount,0,v_product.annual_rate,
    jsonb_build_object(
      'loan_type','deposit_secured',
      'deposit_account_id',v_deposit.id,
      'interest_accrual_day',v_day,
      'repayment_method','bullet',
      'early_repayment_policy',v_product.early_repayment_policy,
      'fee_rate',v_product.early_repayment_fee_rate,
      'time_basis','virtual_game_day'
    ),
    v_day,v_day+p_term_game_days,v_day+p_term_game_days,
    true,'active',p_request_key
  ) RETURNING id INTO v_contract_id;

  INSERT INTO public.user_loan_collaterals(
    loan_id,user_id,collateral_type,asset_reference_id,
    appraised_value,senior_claims,lease_deposits,lien_priority
  ) VALUES (
    v_contract_id,v_user,'deposit',v_deposit.id,
    v_deposit.principal_amount,0,0,1
  );

  UPDATE public.user_asset_accounts SET
    cash_balance=cash_balance+p_amount,updated_at=now()
    WHERE id=v_bank.id;

  INSERT INTO public.asset_account_transactions(
    user_id,account_type,type,reason,amount,balance_after,title,memo
  ) VALUES (
    v_user,'bank','in','loan_disbursement',p_amount,
    v_bank.cash_balance+p_amount,
    '예금담보대출 실행',v_contract_id::text
  );

  RETURN jsonb_build_object(
    'success',true,'contract_id',v_contract_id,
    'principal_amount',p_amount,'balance_after',v_bank.cash_balance+p_amount,
    'maturity_game_day',v_day+p_term_game_days,
    'duplicate_request',false);
END;
$function$;
