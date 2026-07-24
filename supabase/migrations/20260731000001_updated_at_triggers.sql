-- Migration: Auto-update updated_at on jobs and applications tables
-- (2026-07-31)
--
-- Fixes BUG #22: Auto-update updated_at on jobs and applications tables.
-- Previously, only RPCs manually set updated_at; direct PostgREST updates
-- left the timestamp stale.
--
-- 1. Trigger on jobs BEFORE UPDATE → set updated_at = NOW()
-- 2. Trigger on applications BEFORE UPDATE → set updated_at = NOW()

-- ─── 1. Helper function ───

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ─── 2. Jobs table ───

DROP TRIGGER IF EXISTS trg_jobs_updated_at ON public.jobs;
CREATE TRIGGER trg_jobs_updated_at
    BEFORE UPDATE ON public.jobs
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- ─── 3. Applications table ───

DROP TRIGGER IF EXISTS trg_applications_updated_at ON public.applications;
CREATE TRIGGER trg_applications_updated_at
    BEFORE UPDATE ON public.applications
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
