-- Migration: Add employer/worker role columns to users table
-- (2026-07-26)
--
-- Adds is_employer and is_worker boolean flags so a single account can
-- have both roles (like ride-booking apps where you switch between
-- passenger and driver modes). Default: all existing users are employers.
--
-- Also updates the auth.users trigger to read role metadata from the
-- raw_user_meta_data passed during signup.

-- ─── 1. Add role columns to public.users ────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_employer BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_worker BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.users.is_employer IS 'Whether the user has an employer profile';
COMMENT ON COLUMN public.users.is_worker IS 'Whether the user has a worker profile';

-- ─── 2. Update the auth trigger to read roles from metadata ─────
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
  SECURITY DEFINER
  SET search_path = public
  LANGUAGE plpgsql
AS $$
DECLARE
  v_email TEXT;
  v_is_employer BOOLEAN;
  v_is_worker BOOLEAN;
BEGIN
  -- Email comes from the auth.users email field (for email signup).
  v_email := NEW.email;

  -- Roles come from raw_user_meta_data (passed during signUp).
  v_is_employer := (NEW.raw_user_meta_data->>'is_employer')::BOOLEAN;
  v_is_worker := (NEW.raw_user_meta_data->>'is_worker')::BOOLEAN;

  -- Default to employer only when no role metadata is present
  -- (e.g. OTP signups that haven't been updated yet).
  IF v_is_employer IS NULL AND v_is_worker IS NULL THEN
    v_is_employer := true;
    v_is_worker := false;
  END IF;

  INSERT INTO public.users (
    id,
    phone_number,
    email,
    full_name,
    is_employer,
    is_worker
  )
  VALUES (
    NEW.id,
    NEW.phone,
    v_email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(v_is_employer, false),
    COALESCE(v_is_worker, false)
  )
  ON CONFLICT (id) DO UPDATE SET
    phone_number = COALESCE(EXCLUDED.phone_number, public.users.phone_number),
    email = COALESCE(EXCLUDED.email, public.users.email),
    full_name = CASE
      WHEN public.users.full_name = '' THEN EXCLUDED.full_name
      ELSE public.users.full_name
    END,
    is_employer = COALESCE(EXCLUDED.is_employer, public.users.is_employer),
    is_worker = COALESCE(EXCLUDED.is_worker, public.users.is_worker);
  RETURN NEW;
END;
$$;

-- ─── 3. Add email column to public.users if it doesn't exist ─────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS email TEXT;

-- ─── 4. Backfill roles for existing users ────────────────────────
-- All existing users before this migration default to employer-only.
-- If a user has a worker_profiles row, they probably also want worker access.
UPDATE public.users u
SET is_worker = true
WHERE EXISTS (
  SELECT 1 FROM public.worker_profiles wp
  WHERE wp.id = u.id
)
AND u.is_worker = false;
