-- Migration: Atomic complete_job RPC to avoid partial updates when marking a job complete.
--
-- When a job is marked completed, two tables must be updated together:
--   - jobs.status -> 'completed'
--   - applications.status -> 'completed' for the hired worker
--
-- Doing this in two separate client calls leaves a window where the first
-- write may succeed and the second fail. This function wraps both writes in
-- a single transaction and enforces that only the employer who owns the job
-- can invoke it, and only when the job is in a valid pre-completion state.

CREATE OR REPLACE FUNCTION public.complete_job(p_job_id UUID)
RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  -- Verify the caller owns this job AND that it's in 'hired' status.
  -- A job in 'open' status has no worker assigned and cannot be completed.
  -- Already-completed, cancelled, or expired jobs cannot be completed again.
  IF NOT EXISTS (
    SELECT 1 FROM public.jobs
    WHERE id = p_job_id
      AND employer_id = auth.uid()
      AND status = 'hired'
  ) THEN
    RAISE EXCEPTION 'Not authorized to complete this job or job is not in a valid state';
  END IF;

  -- Mark the job as completed
  UPDATE public.jobs
  SET status = 'completed'
  WHERE id = p_job_id;

  -- Mark the hired worker's application as completed
  UPDATE public.applications
  SET status = 'completed'
  WHERE job_id = p_job_id AND status = 'hired';
END;
$$;

-- Only authenticated users (who still must pass the ownership check) may
-- execute this function. Revoke the default PUBLIC grant first.
REVOKE EXECUTE ON FUNCTION public.complete_job(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_job(UUID) TO authenticated;
