-- Migration: SECURITY DEFINER RPC for user account deletion
--
-- Problem:
--   The `deleteUserData()` Dart method issued individual DELETE queries for
--   7 application tables (messages, reviews, notifications, reports,
--   applications, worker_profiles, jobs) that have no RLS DELETE policies
--   for regular users. Every delete was rejected with HTTP 403, leaving
--   user data behind.
--
-- Solution:
--   A single SECURITY DEFINER RPC function that performs ALL deletes with
--   elevated privileges in one transaction. Access is controlled by the
--   function itself (only allows auth.uid() = p_user_id).
--
--   This matches the existing pattern established by `upsert_worker_profile`
--   (see migration 20260720000002).

-- ─── SECURITY DEFINER delete_user_data function ────────────────
CREATE OR REPLACE FUNCTION delete_user_data(p_user_id UUID)
RETURNS VOID
  SECURITY DEFINER
  SET search_path = public
  LANGUAGE plpgsql
AS $$
BEGIN
  -- Only allow the user to delete their own data.
  -- Note: `auth.uid()` can be NULL in edge cases (e.g. stale session).
  -- In PostgreSQL, `NULL <> uuid` evaluates to NULL (not TRUE), so we
  -- must also explicitly check `auth.uid() IS NULL` to prevent the
  -- function from proceeding when auth context is missing.
  IF p_user_id <> auth.uid() OR auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Cannot delete another user''s data';
  END IF;

  -- Delete in dependency order to avoid FK constraint violations.
  --
  -- Note: Several tables have `REFERENCES public.users(id) ON DELETE CASCADE`
  -- on their FK columns, but those cascades only fire when the `users` row
  -- itself is deleted (which requires the Admin API — this RPC does not
  -- delete from `users`). Therefore every table is deleted explicitly.
  --
  -- For `applications.job_id` and `messages.job_id`, the CASCADE does
  -- matter here because deleting jobs (step 10) cascades to applications
  -- and messages that reference those specific jobs — those cascades
  -- ARE the intended cleanup for job-scoped records.

  -- 1. Messages: sender_id has no CASCADE to users.
  DELETE FROM public.messages WHERE sender_id = p_user_id;

  -- 2. Reviews: reviewer_id/reviewee_id have no CASCADE to users.
  DELETE FROM public.reviews
    WHERE reviewer_id = p_user_id OR reviewee_id = p_user_id;

  -- 3. Notifications.
  DELETE FROM public.notifications WHERE user_id = p_user_id;

  -- 4. Favorites: user may have favorited others OR been favorited.
  DELETE FROM public.favorites
    WHERE user_id = p_user_id OR favorited_user_id = p_user_id;

  -- 5. Reports: user may be reporter OR the reported party.
  DELETE FROM public.reports
    WHERE reporter_id = p_user_id OR reported_user_id = p_user_id;

  -- 6. Applications where user is the worker.
  --    Applications where user is the employer are handled by the
  --    jobs CASCADE at step 10.
  DELETE FROM public.applications WHERE worker_id = p_user_id;

  -- 7. Worker categories (junction table).
  DELETE FROM public.worker_categories WHERE worker_id = p_user_id;

  -- 8. Worker profile.
  DELETE FROM public.worker_profiles WHERE id = p_user_id;

  -- 9. FCM device tokens.
  DELETE FROM public.fcm_tokens WHERE user_id = p_user_id;

  -- 10. Jobs where user is the employer. Also cascades via FK to
  --     clean up applications.job_id and messages.job_id for these jobs,
  --     covering the employer side of applications and messages.
  DELETE FROM public.jobs WHERE employer_id = p_user_id;
END;
$$;

-- ─── RPC permission ───────────────────────────────────────────
-- Grant execute permission to authenticated users (the function
-- itself checks auth.uid() matches, so this is safe).
GRANT EXECUTE ON FUNCTION delete_user_data TO authenticated;
