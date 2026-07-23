-- Migration: Fix is_featured overwrite on every profile save (2026-07-29)
--
-- Bug: `WorkerProfile.toJson()` intentionally excludes `is_featured` (it's an
-- admin-managed flag). The `upsert_worker_profile` RPC receives NULL for
-- `p_is_featured`, and the `ON CONFLICT ... DO UPDATE` clause sets
-- `is_featured = EXCLUDED.is_featured`, which is NULL, wiping any admin-set
-- featured status on every profile save.
--
-- Fix: Use `COALESCE(EXCLUDED.is_featured, worker_profiles.is_featured)` so
-- the existing value is preserved when NULL is passed.

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
    p_portfolio_media, COALESCE(p_is_featured, false)
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
    is_featured         = COALESCE(EXCLUDED.is_featured, worker_profiles.is_featured);
END;
$$;
