-- Migration: Auto-update worker_profile stats from reviews & completions
-- (2026-07-31)
--
-- Fixes BUG #4: worker_profiles.average_rating and total_jobs_completed
-- were never calculated, staying at default 0 forever.
--
-- 1. Trigger on reviews INSERT/UPDATE/DELETE → recalculate average_rating
-- 2. Trigger on applications UPDATE to 'completed' → increment total_jobs_completed

-- ─── 1. Recalculate average_rating on review changes ───

CREATE OR REPLACE FUNCTION public.update_worker_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_worker_id UUID;
BEGIN
    -- Determine the affected reviewee
    IF TG_OP = 'DELETE' THEN
        v_worker_id := OLD.reviewee_id;
    ELSE
        v_worker_id := NEW.reviewee_id;
    END IF;

    -- Only update if the reviewee has a worker_profile
    UPDATE public.worker_profiles
    SET average_rating = (
        SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0)
        FROM public.reviews
        WHERE reviewee_id = v_worker_id
    )
    WHERE id = v_worker_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists (idempotency)
DROP TRIGGER IF EXISTS trg_update_worker_rating ON public.reviews;

CREATE TRIGGER trg_update_worker_rating
    AFTER INSERT OR UPDATE OF rating OR DELETE
    ON public.reviews
    FOR EACH ROW
    EXECUTE FUNCTION public.update_worker_rating();


-- ─── 2. Increment total_jobs_completed on application completion ───

CREATE OR REPLACE FUNCTION public.increment_worker_completed_jobs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only fire when status changes TO 'completed'
    IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
        UPDATE public.worker_profiles
        SET total_jobs_completed = total_jobs_completed + 1
        WHERE id = NEW.worker_id;
    END IF;
    RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists (idempotency)
DROP TRIGGER IF EXISTS trg_increment_completed_jobs ON public.applications;

CREATE TRIGGER trg_increment_completed_jobs
    AFTER UPDATE OF status
    ON public.applications
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_worker_completed_jobs();


-- ─── 3. Backfill existing data ───
-- Calculate average_rating for all workers who already have reviews
UPDATE public.worker_profiles wp
SET average_rating = sub.avg_rating
FROM (
    SELECT reviewee_id,
           COALESCE(ROUND(AVG(rating)::numeric, 2), 0) AS avg_rating
    FROM public.reviews
    GROUP BY reviewee_id
) sub
WHERE wp.id = sub.reviewee_id;

-- Calculate total_jobs_completed for all workers who have completed applications
UPDATE public.worker_profiles wp
SET total_jobs_completed = sub.completed_count
FROM (
    SELECT worker_id, COUNT(*) AS completed_count
    FROM public.applications
    WHERE status = 'completed'
    GROUP BY worker_id
) sub
WHERE wp.id = sub.worker_id;
