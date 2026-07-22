-- Migration: Fix get_nearby_workers to return ALL categories per worker,
-- add notifications INSERT policy, and exclude null-location workers from
-- distance filtering (2026-07-23).
--
-- Bug #7: get_nearby_workers used LIMIT 1 for categories, silently dropping
--          workers whose matching category wasn't first in the DB ordering.
--          Changed to array_agg so all categories are returned.
-- Bug #17: notifications table had SELECT and UPDATE RLS policies but no
--          INSERT policy. While notifications are inserted via SECURITY DEFINER
--          triggers (bypassing RLS), adding the policy makes the schema
--          self-documenting and safe for potential future client-side inserts.
-- Bug #18: Workers with NULL current_location were included at 999999m.
--          Now only workers with a valid location are returned, since the
--          Dart-side distance filter already excludes 999999m phantom results.

-- ─── Fix get_nearby_workers: return ALL categories as array ────────────────
DROP FUNCTION IF EXISTS get_nearby_workers(float, float, float);
CREATE OR REPLACE FUNCTION get_nearby_workers(lat float, lng float, radius_km float)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    profile_photo_url TEXT,
    headline TEXT,
    bio TEXT,
    average_rating DECIMAL,
    total_jobs_completed INTEGER,
    distance_meters FLOAT,
    availability TEXT,
    categories TEXT[],
    is_verified BOOLEAN,
    hourly_rate_pkr INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.full_name,
    u.profile_photo_url,
    wp.headline,
    wp.bio,
    wp.average_rating,
    wp.total_jobs_completed,
    st_distance(u.current_location, st_setsrid(st_makepoint(lng, lat), 4326)::geography) as distance_meters,
    wp.availability_status as availability,
    ARRAY(
      SELECT c.name_en FROM worker_categories wc
      JOIN categories c ON wc.category_id = c.id
      WHERE wc.worker_id = wp.id
    ) as categories,
    u.is_verified,
    wp.hourly_rate_pkr
  FROM users u
  JOIN worker_profiles wp ON u.id = wp.id
  WHERE u.current_location IS NOT NULL
    AND st_dwithin(
      u.current_location,
      st_setsrid(st_makepoint(lng, lat), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;

-- ─── Add notifications INSERT policy ─────────────────────────────────────
CREATE POLICY "System can insert notifications"
  ON public.notifications
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
