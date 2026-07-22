-- Migration: SECURITY DEFINER upsert function + worker_categories RLS policies
--
-- Problem:
--   PostgREST's upsert with onConflict returns 409 when RLS policies are
--   evaluated against both INSERT and UPDATE paths. The Dart client tried
--   try-insert-then-update, but the intermediate PATCH request can also
--   fail for various RLS-related reasons.
--
-- Solution:
--   1. A SECURITY DEFINER RPC that performs the upsert with elevated
--      privileges, bypassing RLS on worker_profiles entirely. Access is
--      controlled by the function itself (only allows auth.uid() = id).
--   2. Add missing RLS policies for worker_categories (INSERT + DELETE)
--      so the categories join table operations work.

-- ─── 1. SECURITY DEFINER upsert function ───────────────────────
CREATE OR REPLACE FUNCTION upsert_worker_profile(
  p_id UUID,
  p_headline TEXT,
  p_bio TEXT,
  p_years_experience INTEGER,
  p_hourly_rate_pkr INTEGER,
  p_fixed_rate_note TEXT,
  p_availability_status TEXT,
  p_service_radius_km INTEGER,
  p_portfolio_media TEXT[],
  p_is_featured BOOLEAN
) RETURNS VOID
  SECURITY DEFINER
  SET search_path = public
  LANGUAGE plpgsql
AS $$
BEGIN
  -- Only allow the user to upsert their own profile
  IF p_id <> auth.uid() THEN
    RAISE EXCEPTION 'Cannot modify another user''s profile';
  END IF;

  INSERT INTO worker_profiles (
    id, headline, bio, years_experience, hourly_rate_pkr,
    fixed_rate_note, availability_status, service_radius_km,
    portfolio_media, is_featured
  ) VALUES (
    p_id, p_headline, p_bio, p_years_experience, p_hourly_rate_pkr,
    p_fixed_rate_note, p_availability_status, p_service_radius_km,
    p_portfolio_media, p_is_featured
  )
  ON CONFLICT (id) DO UPDATE SET
    headline            = EXCLUDED.headline,
    bio                 = EXCLUDED.bio,
    years_experience    = EXCLUDED.years_experience,
    hourly_rate_pkr     = EXCLUDED.hourly_rate_pkr,
    fixed_rate_note     = EXCLUDED.fixed_rate_note,
    availability_status = EXCLUDED.availability_status,
    service_radius_km   = EXCLUDED.service_radius_km,
    portfolio_media     = EXCLUDED.portfolio_media,
    is_featured         = EXCLUDED.is_featured;
END;
$$;

-- ─── 2. RLS policies for worker_categories ─────────────────────
-- These were missing from the original migration (RLS was enabled but
-- no actual policies were defined), causing every DELETE and INSERT on
-- worker_categories to be blocked.

CREATE POLICY "Users can insert own categories"
    ON public.worker_categories FOR INSERT
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM worker_profiles
        WHERE id = worker_id AND id = auth.uid()
      )
    );

CREATE POLICY "Users can delete own categories"
    ON public.worker_categories FOR DELETE
    USING (
      EXISTS (
        SELECT 1 FROM worker_profiles
        WHERE id = worker_id AND id = auth.uid()
      )
    );
