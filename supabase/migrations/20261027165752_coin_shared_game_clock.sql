-- Server-only coin engine using the shared virtual clock.
-- The existing cron remains unchanged: one poll per real minute as postgres.
CREATE OR REPLACE FUNCTION public.update_coin_market_by_game_time()
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
  v_now timestamptz := now();
  v_virtual_epoch timestamptz;
  v_clock jsonb;
  v_current_tick bigint;
  v_previous_tick bigint;
  v_tick_count integer;
  v_max_tick_count integer := 60;
  v_i integer;
  v_coin record;
  v_direction numeric;
  v_base_move_percent numeric;
  v_spike_percent numeric;
  v_move_percent numeric;
  v_next_price numeric;
  v_next_change_rate numeric;
  v_next_trade_volume numeric;
BEGIN
  -- Different from the stock engine's lock (2026, 10501).
  IF NOT pg_catalog.pg_try_advisory_xact_lock(2026, 10502) THEN
    RETURN;
  END IF;

  SELECT virtual_epoch, public.get_game_clock()
  INTO v_virtual_epoch, v_clock
  FROM public.game_clock_settings
  WHERE singleton_id = true;

  IF v_virtual_epoch IS NULL THEN
    RAISE EXCEPTION '게임 시간 설정을 찾지 못했습니다.';
  END IF;

  IF v_clock IS NULL OR v_clock->>'game_datetime' IS NULL THEN
    RAISE EXCEPTION '게임 시간을 읽을 수 없습니다.';
  END IF;

  -- One tick per 600 shared game seconds (currently 100 real seconds).
  v_current_tick := floor(greatest(0, extract(epoch FROM (
    (v_clock->>'game_datetime')::timestamptz - v_virtual_epoch
  ))) / 600)::bigint;

  SELECT last_game_tick INTO v_previous_tick
  FROM public.market_time_state
  WHERE market_type = 'coin'
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.market_time_state (
      market_type, last_tick_at, updated_at, last_game_tick
    ) VALUES ('coin', v_now, v_now, v_current_tick)
    ON CONFLICT (market_type) DO NOTHING;
    RETURN;
  END IF;

  IF v_previous_tick IS NULL THEN
    -- The old real-time engine used a different scale. Adopt the current
    -- shared tick once, retaining current prices instead of replaying history.
    UPDATE public.market_time_state
    SET last_game_tick = v_current_tick,
        last_tick_at = v_now,
        updated_at = v_now
    WHERE market_type = 'coin';
    RETURN;
  END IF;

  -- Repeated polls, overlapping jobs and a clock moving backwards do not
  -- reapply already processed game ticks.
  IF v_current_tick <= v_previous_tick THEN
    RETURN;
  END IF;

  v_tick_count := least(v_current_tick - v_previous_tick, v_max_tick_count)::integer;

  for v_i in 1..v_tick_count loop
    for v_coin in
      select *
      from public.coin_item
      where is_active = true
    loop
      v_direction := case when random() >= 0.5 then 1 else -1 end;

      -- 기본 변동폭: 0.12% ~ 0.72%
      v_base_move_percent := 0.12 + random() * 0.6;

      -- 급등락 확률 7%, 최대 1.2%
      v_spike_percent := case
        when random() < 0.07 then random() * 1.2
        else 0
      end;

      v_move_percent := v_direction * (v_base_move_percent + v_spike_percent);

      -- 가격대별 변동성 가중치
      if v_coin.current_price >= 1000000 then
        v_move_percent := v_move_percent * 0.7;
      elsif v_coin.current_price >= 100000 then
        v_move_percent := v_move_percent * 0.85;
      elsif v_coin.current_price >= 10000 then
        v_move_percent := v_move_percent * 1.0;
      elsif v_coin.current_price >= 1000 then
        v_move_percent := v_move_percent * 1.15;
      elsif v_coin.current_price >= 100 then
        v_move_percent := v_move_percent * 1.35;
      else
        v_move_percent := v_move_percent * 1.6;
      end if;

      -- 1틱 최대 가격 변동 제한
      if v_move_percent > 2.2 then
        v_move_percent := 2.2;
      elsif v_move_percent < -2.2 then
        v_move_percent := -2.2;
      end if;

      v_next_price := v_coin.current_price * (1 + (v_move_percent / 100));

      if v_next_price < 1 then
        v_next_price := 1;
      end if;

      if v_next_price >= 1000 then
        v_next_price := round(v_next_price);
      elsif v_next_price >= 100 then
        v_next_price := round(v_next_price, 1);
      else
        v_next_price := round(v_next_price, 2);
      end if;

      v_next_change_rate := v_coin.change_rate + v_move_percent;

      if v_next_change_rate > 15 then
        v_next_change_rate := 15;
      elsif v_next_change_rate < -15 then
        v_next_change_rate := -15;
      end if;

      -- 거래량은 상한선 없이 완만하게 변동
      -- 기존: -4% ~ +8%
      -- 변경: -1.5% ~ +1.5%
      v_next_trade_volume :=
        v_coin.trade_volume *
        (0.985 + random() * 0.03);

      if v_next_trade_volume < 1 then
        v_next_trade_volume := 1;
      end if;

      update public.coin_item
      set
        current_price = v_next_price,
        change_rate = v_next_change_rate,
        trade_volume = v_next_trade_volume
      where code = v_coin.code;

      insert into public.coin_price_history (
        coin_code,
        coin_name,
        price,
        change_rate,
        trade_volume
      )
      values (
        v_coin.code,
        v_coin.name,
        v_next_price,
        v_next_change_rate,
        v_next_trade_volume
      );
    end loop;
  end loop;

  -- Advance by processed ticks, not by poll time. A fractional interval
  -- and any backlog beyond this 60-tick batch remain for the next poll.
  UPDATE public.market_time_state
  SET last_game_tick = v_previous_tick + v_tick_count,
      last_tick_at = v_now,
      updated_at = v_now
  WHERE market_type = 'coin';
END;
$function$;

-- Old browser builds must not be able to invoke or duplicate the engine.
-- Keep SECURITY INVOKER and the existing postgres/service_role access.
REVOKE EXECUTE ON FUNCTION public.update_coin_market_by_game_time()
FROM PUBLIC, anon, authenticated;

-- These tables are market data, not holdings, user trades or cash accounts.
-- Preserve SELECT, existing RLS policies, service_role and owner privileges.
-- market_time_state is shared with stock; its postgres cron remains allowed.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
ON public.coin_item, public.coin_price_history, public.market_time_state
FROM PUBLIC, anon, authenticated;
