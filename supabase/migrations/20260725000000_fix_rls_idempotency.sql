-- Migration: Fix RLS Policy Idempotency (2026-07-25)
--
-- Ensures RLS policy creation is idempotent by dropping existing policies
-- before creating new ones.

-- 1. worker_categories SELECT policy
DROP POLICY IF EXISTS "Anyone can view worker categories" ON public.worker_categories;
CREATE POLICY "Anyone can view worker categories"
  ON public.worker_categories FOR SELECT
  USING (true);

-- 2. applications UPDATE policy
DROP POLICY IF EXISTS "Employer can update application status" ON public.applications;
CREATE POLICY "Employer can update application status"
  ON public.applications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.jobs
      WHERE id = job_id AND employer_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.jobs
      WHERE id = job_id AND employer_id = auth.uid()
    )
  );
