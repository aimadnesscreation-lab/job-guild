-- Migration: Fix column reference in notify_on_job_insert trigger
--
-- The worker_profiles table uses `id` (REFERENCES users.id) as its primary
-- key, NOT a `user_id` column. The original trigger function referenced
-- `wp.user_id` which caused ERROR 42703 on INSERT.

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
  -- Resolve employer display name
  SELECT COALESCE(u.full_name, 'An employer')
    INTO v_employer_name
    FROM users u
   WHERE u.id = NEW.employer_id;

  -- Loop over eligible nearby workers
  FOR v_worker_record IN
    SELECT DISTINCT wp.id AS worker_id
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
    -- 4a. In-app notification record
    INSERT INTO notifications (user_id, type, payload)
    VALUES (
      v_worker_record.worker_id,
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

    -- 4b. Push notification via Edge Function (async)
    PERFORM net.http_post(
      url   := public.get_send_push_url(),
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body  := jsonb_build_object(
        'user_id', v_worker_record.worker_id,
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

-- The trigger itself does not need to be re-created — it still references
-- the same function name, which we've just replaced.
