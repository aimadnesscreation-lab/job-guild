-- Migration: Fix get_nearby_workers to return ALL worker categories as an array
-- (2026-07-28)
--
-- Bug fix: The original get_nearby_workers RPC only returned a single category
-- per worker (LIMIT 1). Workers with multiple categories were unfindable by
-- their secondary categories. This migration replaces the function to return
-- all categories as a Postgres array, and updates the search_workers_view
-- client code to handle the new format.
--
-- The new function returns:
--   - categories: TEXT[] — array of all category names for this worker
--   - Removes the old single 'category' TEXT column

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
    COALESCE(
      st_distance(u.current_location, st_setsrid(st_makepoint(lng, lat), 4326)::geography),
      999999
    ) as distance_meters,
    wp.availability_status,
    ARRAY(
      SELECT c.name_en
      FROM worker_categories wc
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
