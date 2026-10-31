-- The shared game clock is public, read-only information, independent of login.
-- Keep SECURITY INVOKER and RLS; permit only the fields used by the clock RPC.
GRANT SELECT (singleton_id, real_epoch, virtual_epoch, game_seconds_per_real_second)
  ON public.game_clock_settings TO anon;

CREATE POLICY game_clock_public_read
  ON public.game_clock_settings
  FOR SELECT TO anon
  USING (singleton_id = true);

GRANT EXECUTE ON FUNCTION public.get_game_clock() TO anon;
