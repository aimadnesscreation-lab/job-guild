-- Migration: Allow workers to CREATE their own profile
--
-- The original schema (20260718000000_create_tables.sql) only defined SELECT
-- and UPDATE policies for `worker_profiles`. When a user saves a profile for
-- the first time, the app issues an upsert, which becomes an INSERT — and with
-- no INSERT policy, PostgREST returns 403 "new row violates row-level security
-- policy". This migration adds the missing INSERT policy.

-- Workers can create their own profile (the row id must equal their auth id)
CREATE POLICY "Workers can create own profile"
    ON public.worker_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);
