-- Migration: Fix critical audit bugs (2026-07-23)
--
-- 1. complete_job RPC references updated_at on jobs/applications, but the
--    columns did not exist in the original schema. Add them now.
-- 2. Messages SELECT policy only allowed workers to read messages when their
--    application was 'hired'. This broke pre-hire negotiation chat. Replace
--    the policy to allow any worker who has applied to the job.
-- 3. reports.reported_user_id was NOT NULL, but the app supports anonymous
--    problem reports from Settings. Make the column nullable.

-- ─── Add updated_at to jobs and applications ───────────────────────────────

ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill existing rows so the columns are non-null.
UPDATE public.jobs SET updated_at = created_at WHERE updated_at IS NULL;
UPDATE public.applications SET updated_at = applied_at WHERE updated_at IS NULL;

-- ─── Relax messages SELECT policy for pre-hire chat ────────────────────────

DROP POLICY IF EXISTS "Participants can view messages" ON public.messages;

CREATE POLICY "Participants can view messages" ON public.messages FOR SELECT USING (
    auth.uid() = sender_id
    OR EXISTS (SELECT 1 FROM public.jobs WHERE id = job_id AND employer_id = auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.applications
        WHERE job_id = public.messages.job_id
          AND worker_id = auth.uid()
    )
);

-- ─── Make reports.reported_user_id nullable ───────────────────────────────

ALTER TABLE public.reports
  ALTER COLUMN reported_user_id DROP NOT NULL;
