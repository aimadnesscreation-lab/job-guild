-- Migration: Auto-create public.users rows when auth.users sign up
--
-- Problem:
--   Phone OTP signup creates a row in `auth.users` but NOT in `public.users`.
--   The FK constraint `worker_profiles.id REFERENCES public.users(id)` then
--   prevents inserting worker profiles.  The INSERT returns 409 (FK violation
--   23503), the fallback UPDATE affects 0 rows, and nothing persists.
--
-- Solution:
--   1. Backfill any existing auth.users that lack a public.users row.
--   2. Create a trigger on auth.users INSERT that auto-creates public.users rows.

-- ─── 1. Backfill existing auth users ──────────────────────────
INSERT INTO public.users (id, phone_number, full_name)
SELECT
  au.id,
  au.phone,
  COALESCE(au.raw_user_meta_data->>'full_name', '')
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- ─── 2. Trigger function ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
  SECURITY DEFINER
  SET search_path = public
  LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (id, phone_number, full_name)
  VALUES (
    NEW.id,
    NEW.phone,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ─── 3. Attach trigger to auth.users ──────────────────────────
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();
