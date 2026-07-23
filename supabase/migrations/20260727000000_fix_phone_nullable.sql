-- Migration: Make phone_number nullable for email-only signup support
-- (2026-07-27)
--
-- Problem: The users.phone_number column has NOT NULL, but email-only
-- signups (via supabase.auth.signUp with email+password) pass NEW.phone
-- as NULL, causing the handle_new_auth_user trigger INSERT to fail with
-- a NOT NULL violation. This silently fails, leaving no public.users row.
--
-- Fix: Make phone_number nullable. The UNIQUE constraint already handles
-- NULL correctly (PostgreSQL treats NULLs as distinct for unique checks,
-- so multiple users without phone numbers is fine).

ALTER TABLE public.users
  ALTER COLUMN phone_number DROP NOT NULL;

COMMENT ON COLUMN public.users.phone_number IS
  'User phone number (nullable for email-only signups). Must be unique when set.';
