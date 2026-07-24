-- Migration: Atomic hire_worker RPC function
-- (2026-07-30)
--
-- Replaces the two-step hireWorker client-side approach with a single
-- SECURITY DEFINER function that atomically updates both the application
-- and the job to 'hired' in one database transaction, eliminating the
-- race condition where only one of the two updates succeeds.

CREATE OR REPLACE FUNCTION public.hire_worker(
    p_job_id UUID,
    p_worker_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_employer_id UUID;
BEGIN
    -- Verify caller is the job's employer
    SELECT employer_id INTO v_employer_id
    FROM public.jobs
    WHERE id = p_job_id;

    IF v_employer_id IS NULL THEN
        RAISE EXCEPTION 'Job not found';
    END IF;

    IF v_employer_id <> auth.uid() THEN
        RAISE EXCEPTION 'Not authorized to hire for this job';
    END IF;

    -- Atomic: update both in one transaction
    UPDATE public.applications
    SET status = 'hired', updated_at = now()
    WHERE job_id = p_job_id
      AND worker_id = p_worker_id
      AND status = 'applied';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No pending application found for this worker';
    END IF;

    UPDATE public.jobs
    SET status = 'hired',
        hired_worker_id = p_worker_id,
        updated_at = now()
    WHERE id = p_job_id
      AND status IN ('open', 'in_progress');

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job is not in a hireable state';
    END IF;

    RETURN TRUE;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.hire_worker(UUID, UUID) TO authenticated;
