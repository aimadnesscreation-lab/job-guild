-- Migration: Fix low-severity audit issues for existing deployments (2026-07-23)
--
-- 1. get_nearby_jobs was returning jobs of all statuses. Restrict it to 'open'.
-- 2. get_nearby_workers excluded workers who had not set their GPS location.
--    Include them, sorting them at the end by a large fallback distance.

-- ─── Filter get_nearby_jobs to open jobs only ──────────────────────────────
DROP FUNCTION IF EXISTS get_nearby_jobs(float, float, float);
CREATE OR REPLACE FUNCTION get_nearby_jobs(lat float, lng float, radius_km float)
RETURNS SETOF jobs AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE status = 'open'
    AND st_dwithin(
      location_coords,
      st_setsrid(st_makepoint(lng, lat), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY location_coords <-> st_setsrid(st_makepoint(lng, lat), 4326)::geography;
END;
$$ LANGUAGE plpgsql;

-- ─── Include workers without a current_location in search results ──────────
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
    category TEXT,
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
    wp.availability_status as availability,
    (SELECT c.name_en FROM worker_categories wc JOIN categories c ON wc.category_id = c.id WHERE wc.worker_id = wp.id LIMIT 1) as category,
    u.is_verified,
    wp.hourly_rate_pkr
  FROM users u
  JOIN worker_profiles wp ON u.id = wp.id
  WHERE u.current_location IS NULL
    OR st_dwithin(
      u.current_location,
      st_setsrid(st_makepoint(lng, lat), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY distance_meters;
END;
$$ LANGUAGE plpgsql;
