-- Migration: Harden the complete_job RPC.
--
-- The initial version of this function allowed any authenticated user to call
-- it and did not verify that the job was in a valid pre-completion state.
-- This migration replaces it with a hardened implementation that:
--   1. Verifies the caller is the job's employer.
--   2. Allows completion only when the job is in the 'hired' state.
--   3. Updates the completion timestamp on both tables.
--   4. Revokes PUBLIC execution rights and grants only to authenticated users.

CREATE OR REPLACE FUNCTION public.complete_job(p_job_id UUID)
RETURNS VOID
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
AS $$
BEGIN
  -- Verify the caller owns this job and that it's in the 'hired' state.
  -- Only a job with a hired worker should be completable.
  IF NOT EXISTS (
    SELECT 1 FROM public.jobs
    WHERE id = p_job_id
      AND employer_id = auth.uid()
      AND status = 'hired'
  ) THEN
    RAISE EXCEPTION 'Not authorized to complete this job or job is not in a valid state'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Mark the job as completed and record the completion time.
  UPDATE public.jobs
  SET status = 'completed', updated_at = NOW()
  WHERE id = p_job_id;

  -- Mark the hired worker's application as completed and record the time.
  UPDATE public.applications
  SET status = 'completed', updated_at = NOW()
  WHERE job_id = p_job_id AND status = 'hired';
END;
$$;

-- Ensure only authenticated users can execute, not PUBLIC.
REVOKE EXECUTE ON FUNCTION public.complete_job(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_job(UUID) TO authenticated;
