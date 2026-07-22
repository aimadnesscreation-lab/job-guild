-- Migration: Atomic complete_job RPC to avoid partial updates when marking a job complete.
--
-- When an job is marked completed, two tables must be updated together:
--   - jobs.status -> 'completed'
--   - applications.status -> 'completed' for the hired worker
--
-- Doing this in two separate client calls leaves a window where the first
-- write may succeed and the second fail. This function wraps both writes in
-- a single transaction and enforces that only the employer who owns the job
-- can invoke it.

CREATE OR REPLACE FUNCTION public.complete_job(p_job_id UUID)
RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  -- Verify the caller owns this job
  IF NOT EXISTS (
    SELECT 1 FROM public.jobs
    WHERE id = p_job_id AND employer_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized to complete this job';
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

GRANT EXECUTE ON FUNCTION public.complete_job(UUID) TO authenticated;
