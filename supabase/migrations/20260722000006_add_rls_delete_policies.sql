-- Migration: Add RLS DELETE policies for 7 tables (defense-in-depth)
--
-- Context:
--   The `delete_user_data` SECURITY DEFINER RPC (migration 20260722000005)
--   handles user data deletion with elevated privileges. These policies
--   add a defense-in-depth layer so that direct DELETE queries also work
--   for authenticated users deleting their own data, even if the RPC is
--   unavailable or there's a bug in the Dart client fallback path.
--
--   Three tables already have DELETE policies:
--   - favorites  (migration 20260719000001)
--   - worker_categories  (migration 20260720000002)
--   - fcm_tokens  (migration 20260722000002)
--
--   These seven do not:
--   - messages, reviews, notifications, reports
--   - applications, worker_profiles, jobs

-- ─── 1. Messages ──────────────────────────────────────────────
-- Senders can delete their own messages.
CREATE POLICY "Users can delete own messages"
  ON public.messages FOR DELETE
  USING (auth.uid() = sender_id);

-- ─── 2. Reviews ───────────────────────────────────────────────
-- Reviewers can delete their own reviews.
CREATE POLICY "Users can delete own reviews"
  ON public.reviews FOR DELETE
  USING (auth.uid() = reviewer_id);

-- ─── 3. Notifications ─────────────────────────────────────────
-- Users can delete their own notifications (e.g. dismiss/clear all).
-- Matches existing SELECT/UPDATE policies.
CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

-- ─── 4. Reports ───────────────────────────────────────────────
-- Reporters can delete their own reports.
-- Matches existing SELECT/INSERT policies.
CREATE POLICY "Users can delete own reports"
  ON public.reports FOR DELETE
  USING (auth.uid() = reporter_id);

-- ─── 5. Applications ──────────────────────────────────────────
-- Workers can withdraw their own applications.
CREATE POLICY "Workers can delete own applications"
  ON public.applications FOR DELETE
  USING (auth.uid() = worker_id);

-- Employers can delete/reject applications for their own jobs.
-- Matches the existing SELECT policy pattern.
CREATE POLICY "Employer can delete applications for own job"
  ON public.applications FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.jobs
      WHERE id = job_id AND employer_id = auth.uid()
    )
  );

-- ─── 6. Worker Profiles ───────────────────────────────────────
-- Workers can delete their own profile.
-- Matches existing UPDATE policy.
CREATE POLICY "Workers can delete own profile"
  ON public.worker_profiles FOR DELETE
  USING (auth.uid() = id);

-- ─── 7. Jobs ──────────────────────────────────────────────────
-- Employers can delete their own jobs.
-- Matches existing UPDATE/INSERT policies.
CREATE POLICY "Employers can delete own jobs"
  ON public.jobs FOR DELETE
  USING (auth.uid() = employer_id);
