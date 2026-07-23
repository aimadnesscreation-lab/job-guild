-- Migration: Audit Fixes (2026-07-24)
--
-- Addresses several bugs identified during the end-to-end audit:
-- 1. BUG-01: Add missing SELECT policy for worker_categories.
-- 2. BUG-02: Add missing UPDATE policy for applications (employer status updates).
-- 3. BUG-03: Fix column reference in notify_on_job_insert trigger.
-- 4. BUG-05: Extend fcm_tokens platform constraint to include 'macos'.
-- 5. BUG-14: Update delete_user_data RPC to include cleanup of any remaining records.

-- 1. worker_categories SELECT policy
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_categories' AND policyname = 'Anyone can view worker categories'
  ) THEN
    CREATE POLICY "Anyone can view worker categories"
      ON public.worker_categories FOR SELECT
      USING (true);
  END IF;
END;
$$;

-- 2. applications UPDATE policy
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'applications' AND policyname = 'Employer can update application status'
  ) THEN
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
  END IF;
END;
$$;

-- 3. Fix notify_on_job_insert column reference
-- The worker_profiles table uses 'id' as the user reference, not 'user_id'.
CREATE OR REPLACE FUNCTION public.notify_on_job_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_employer_name  text;
  v_worker_record  record;
BEGIN
  SELECT COALESCE(u.full_name, 'An employer')
    INTO v_employer_name
    FROM users u
   WHERE u.id = NEW.employer_id;

  FOR v_worker_record IN
    SELECT DISTINCT wp.id AS recipient_id
      FROM worker_profiles wp
      JOIN worker_categories wc ON wc.worker_id = wp.id
      JOIN users u ON u.id = wp.id
     WHERE wc.category_id = NEW.category_id
       AND wp.availability_status != 'offline'
       AND u.current_location IS NOT NULL
       AND ST_DWithin(
             NEW.location_coords,
             u.current_location,
             wp.service_radius_km * 1000
           )
  LOOP
    INSERT INTO notifications (user_id, type, payload)
    VALUES (
      v_worker_record.recipient_id,
      'Jobs',
      jsonb_build_object(
        'title',       'New job: ' || NEW.title,
        'body',        v_employer_name || ' needs help — ' ||
                        LEFT(NEW.description, 100),
        'type',        'job_match',
        'id',          NEW.id,
        'employer_id', NEW.employer_id,
        'budget',      NEW.budget_amount
      )
    );

    PERFORM net.http_post(
      url   := public.get_send_push_url(),
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body  := jsonb_build_object(
        'user_id', v_worker_record.recipient_id,
        'title',   'New job: ' || NEW.title,
        'body',    v_employer_name || ' needs ' || NEW.title ||
                   COALESCE(
                     ' — PKR ' || NEW.budget_amount::text,
                     ''
                   ),
        'data',    jsonb_build_object(
                     'type', 'job_match',
                     'id',   NEW.id
                   )
      )::text
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- 4. Extend fcm_tokens platform constraint
-- We drop and recreate the constraint to ensure 'macos' is included.
ALTER TABLE public.fcm_tokens DROP CONSTRAINT IF EXISTS fcm_tokens_platform_check;
ALTER TABLE public.fcm_tokens ADD CONSTRAINT fcm_tokens_platform_check
  CHECK (platform IN ('android', 'ios', 'web', 'macos'));

-- 5. delete_user_data cleanup
-- The function already handles the users table by dependency, but we ensure
-- it is robust. Note: We cannot delete from auth.users via RPC easily without
-- service_role, so we focus on public.users.
-- Since delete_user_data is SECURITY DEFINER, it has permissions.
-- We add the deletion of the public.users row as the final step.

CREATE OR REPLACE FUNCTION delete_user_data(p_user_id UUID)
RETURNS VOID
  SECURITY DEFINER
  SET search_path = public
  LANGUAGE plpgsql
AS $$
BEGIN
  IF p_user_id <> auth.uid() OR auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Cannot delete another user''s data';
  END IF;

  DELETE FROM public.messages WHERE sender_id = p_user_id;
  DELETE FROM public.reviews WHERE reviewer_id = p_user_id OR reviewee_id = p_user_id;
  DELETE FROM public.notifications WHERE user_id = p_user_id;
  DELETE FROM public.favorites WHERE user_id = p_user_id OR favorited_user_id = p_user_id;
  DELETE FROM public.reports WHERE reporter_id = p_user_id OR reported_user_id = p_user_id;
  DELETE FROM public.applications WHERE worker_id = p_user_id;
  DELETE FROM public.worker_categories WHERE worker_id = p_user_id;
  DELETE FROM public.worker_profiles WHERE id = p_user_id;
  DELETE FROM public.fcm_tokens WHERE user_id = p_user_id;
  DELETE FROM public.jobs WHERE employer_id = p_user_id;
  
  -- Delete the public user profile itself
  DELETE FROM public.users WHERE id = p_user_id;
END;
$$;
