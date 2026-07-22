-- Migration: Database Webhooks for Push Notifications
--
-- Sets up PostgreSQL trigger functions that automatically invoke the
-- `send-push-notification` Edge Function when new rows are inserted into:
--   1. messages     — notify the conversation recipient
--   2. jobs         — notify nearby matched workers
--   3. applications — notify the employer about a new applicant
--
-- Each trigger also INSERTS into the `notifications` table so the in-app
-- notification feed (NotificationsView) shows the event immediately.
--
-- Edge Function calls use net.http_post() (from the pg_net extension) for
-- async, non-blocking HTTP — the INSERT completes without waiting for FCM.
--
-- Requires: pg_net extension (pre-installed on all Supabase projects).

-- =============================================================================
-- 1. Enable pg_net for async HTTP POST (idempotent)
-- =============================================================================
-- pg_net is pre-installed on all Supabase projects; it creates its own `net`
-- schema so the async HTTP function is callable as `net.http_post()`.
CREATE EXTENSION IF NOT EXISTS pg_net;

-- =============================================================================
-- 2. Helper: resolve the send-push-notification Edge Function URL
-- =============================================================================
--
-- In production the Supabase edge-runtime is reachable at the standard URL;
-- locally (supabase start) it lives on port 54321.  We sniff the project ref
-- from the Supabase-managed GUC, falling back to localhost when unset.
--
CREATE OR REPLACE FUNCTION public.get_send_push_url()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  project_ref text;
BEGIN
  BEGIN
    project_ref := NULLIF(
      current_setting('supabase_project_ref', true),
      ''
    );
  EXCEPTION
    WHEN OTHERS THEN
      project_ref := NULL;
  END;

  IF project_ref IS NULL THEN
    -- Local dev (supabase start).  When PostgreSQL runs inside Docker
    -- (standard `supabase start`), `localhost` resolves to the container,
    -- not the host.  On macOS/Windows use `host.docker.internal`; on
    -- Linux the Docker gateway IP (172.17.0.1) is needed.  If the webhook
    -- calls fail locally, override this URL in your `.env` / `config.toml`
    -- or use `supabase_functions.http_request()` (see Supabase docs).
    RETURN 'http://localhost:54321/functions/v1/send-push-notification';
  ELSE
    RETURN format(
      'https://%s.supabase.co/functions/v1/send-push-notification',
      project_ref
    );
  END IF;
END;
$$;

-- =============================================================================
-- 3. Trigger function: notify on message INSERT
-- =============================================================================
--
-- Determines the conversation recipient (the other party):
--   - If the sender is the employer → notify the hired worker
--   - If the sender is a worker     → notify the employer
--
CREATE OR REPLACE FUNCTION public.notify_on_message_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job_employer_id uuid;
  v_job_title       text;
  v_recipient_id    uuid;
  v_sender_name     text;
  v_notif_type      text := 'Messages';
BEGIN
  -- Look up the job's employer and title
  SELECT j.employer_id, j.title
    INTO v_job_employer_id, v_job_title
    FROM jobs j
   WHERE j.id = NEW.job_id;

  IF v_job_employer_id IS NULL THEN
    RETURN NEW;  -- orphan message, skip
  END IF;

  -- Determine who should receive the notification
  IF NEW.sender_id = v_job_employer_id THEN
    -- Employer sent → notify the *hired* worker (fall back to any applicant)
    SELECT a.worker_id
      INTO v_recipient_id
      FROM applications a
     WHERE a.job_id = NEW.job_id
       AND a.status = 'hired'
     LIMIT 1;

    IF v_recipient_id IS NULL THEN
      -- No hired worker yet — skip (don't spam all applicants)
      RETURN NEW;
    END IF;
  ELSE
    -- Worker sent → notify the employer
    v_recipient_id := v_job_employer_id;
  END IF;

  -- Resolve sender display name
  SELECT COALESCE(u.full_name, 'Someone')
    INTO v_sender_name
    FROM users u
   WHERE u.id = NEW.sender_id;

  -- 3a. In-app notification record (content-type-aware body)
  INSERT INTO notifications (user_id, type, payload)
  VALUES (
    v_recipient_id,
    v_notif_type,
    jsonb_build_object(
      'title', 'New message from ' || v_sender_name,
      'body',  CASE NEW.content_type
                WHEN 'image' THEN '📷 Sent an image'
                WHEN 'voice' THEN '🎤 Sent a voice message'
                WHEN 'location' THEN '📍 Shared a location'
                ELSE LEFT(NEW.content, 120)
              END,
      'type', 'new_message',
      'id',    NEW.job_id,
      'sender_id', NEW.sender_id
    )
  );

  -- 3b. Push notification via Edge Function (async, non-blocking)
  PERFORM net.http_post(
    url   := public.get_send_push_url(),
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body  := jsonb_build_object(
      'user_id', v_recipient_id,
      'title',   'New message from ' || v_sender_name,
      'body',    CASE NEW.content_type
                  WHEN 'image' THEN '📷 Sent an image'
                  WHEN 'voice' THEN '🎤 Sent a voice message'
                  WHEN 'location' THEN '📍 Shared a location'
                  ELSE LEFT(NEW.content, 120)
                END,
      'data',    jsonb_build_object(
                    'type', 'new_message',
                    'id',   NEW.job_id
                  )
    )::text
  );

  RETURN NEW;
END;
$$;

-- Create / replace the trigger on messages
DROP TRIGGER IF EXISTS trg_notify_on_message_insert ON messages;
CREATE TRIGGER trg_notify_on_message_insert
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_message_insert();

-- =============================================================================
-- 4. Trigger function: notify on job INSERT
-- =============================================================================
--
-- Finds workers who:
--   - Offer the job's category (via worker_categories)
--   - Are not offline
--   - Are within their own service radius of the job
-- Notifies each matching worker about the new job opportunity.
--
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
    SELECT DISTINCT wp.user_id
      FROM worker_profiles wp
      JOIN worker_categories wc ON wc.worker_id = wp.id
      JOIN users u ON u.id = wp.user_id
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
      v_worker_record.user_id,
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
        'user_id', v_worker_record.user_id,
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

-- Create / replace the trigger on jobs
DROP TRIGGER IF EXISTS trg_notify_on_job_insert ON jobs;
CREATE TRIGGER trg_notify_on_job_insert
  AFTER INSERT ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_job_insert();

-- =============================================================================
-- 5. Trigger function: notify on application INSERT
-- =============================================================================
--
-- Notifies the job's employer that a worker has applied / is interested.
--
CREATE OR REPLACE FUNCTION public.notify_on_application_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_employer_id uuid;
  v_job_title   text;
  v_worker_name text;
BEGIN
  -- Look up the job's employer and title
  SELECT j.employer_id, j.title
    INTO v_employer_id, v_job_title
    FROM jobs j
   WHERE j.id = NEW.job_id;

  IF v_employer_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Resolve worker display name
  SELECT COALESCE(u.full_name, 'A worker')
    INTO v_worker_name
    FROM users u
   WHERE u.id = NEW.worker_id;

  -- 5a. In-app notification record
  INSERT INTO notifications (user_id, type, payload)
  VALUES (
    v_employer_id,
    'Jobs',
    jsonb_build_object(
      'title',      'New applicant for ' || v_job_title,
      'body',       v_worker_name || ' is interested in your job',
      'type',       'application',
      'id',         NEW.job_id,
      'worker_id',  NEW.worker_id
    )
  );

  -- 5b. Push notification via Edge Function (async)
  PERFORM net.http_post(
    url   := public.get_send_push_url(),
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body  := jsonb_build_object(
      'user_id', v_employer_id,
      'title',   'New applicant for ' || v_job_title,
      'body',    v_worker_name || ' is interested in your job posting',
      'data',    jsonb_build_object(
                   'type', 'application',
                   'id',   NEW.job_id
                 )
    )::text
  );

  RETURN NEW;
END;
$$;

-- Create / replace the trigger on applications
DROP TRIGGER IF EXISTS trg_notify_on_application_insert ON applications;
CREATE TRIGGER trg_notify_on_application_insert
  AFTER INSERT ON applications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_application_insert();
