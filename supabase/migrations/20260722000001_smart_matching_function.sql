-- Migration: Smart matching — weighted scoring function for worker-job matching
--
-- Scores eligible workers for a given job by combining:
--   - Distance match (max 40 points — within radius = full, then decays)
--   - Rating (max 25 points — 5 pts per star)
--   - Completed jobs in category (max 15 points — 1 pt per job, cap 15)
--   - Availability match (max 10 points — full if available, 5 if busy, 0 if offline)
--   - Response speed (max 10 points — <5 min = 10, <15 = 7, <30 = 5, <60 = 3)
--
-- Returns: TABLE with worker_id, score, and breakdown fields for transparency.

-- Migration: Smart matching — weighted scoring function for worker-job matching
--
-- Scores eligible workers for a given job by combining:
--   - Category match (required — 0 score if not matched)
--   - Distance match (max 40 points — within radius = full, then decays)
--   - Rating (max 25 points — 5 pts per star)
--   - Completed jobs in category (max 15 points — 1 pt per job, cap 15, min 2 for new workers)
--   - Availability match (max 10 points — full if available, 5 if busy, 0 if offline)
--   - Response speed (max 10 points — <5 min = 10, <15 = 7, <30 = 5, <60 = 3)
--
-- Returns: TABLE with worker_id, score breakdown, and human-readable match_reason.

CREATE OR REPLACE FUNCTION match_workers_for_job(
  p_job_id UUID
) RETURNS TABLE (
  worker_id UUID,
  total_score NUMERIC,
  distance_score NUMERIC,
  rating_score NUMERIC,
  experience_score NUMERIC,
  availability_score NUMERIC,
  response_score NUMERIC,
  distance_km NUMERIC,
  match_reason TEXT
)
  LANGUAGE plpgsql
  STABLE
AS $$
DECLARE
  v_job_lat DOUBLE PRECISION;
  v_job_lng DOUBLE PRECISION;
  v_job_category_id INTEGER;
  v_employer_id UUID;
  v_job_point GEOGRAPHY;
BEGIN
  -- Get job location and category; support both PostGIS geography and legacy columns
  SELECT
    COALESCE(
      ST_Y(j.location_coords::geometry),
      j.location_lat,
      31.5204  -- Lahore default
    ),
    COALESCE(
      ST_X(j.location_coords::geometry),
      j.location_lng,
      74.3587
    ),
    j.category_id,
    j.employer_id
  INTO v_job_lat, v_job_lng, v_job_category_id, v_employer_id
  FROM jobs j
  WHERE j.id = p_job_id AND j.status = 'open';

  IF v_job_lat IS NULL THEN
    RETURN;
  END IF;

  v_job_point := ST_SetSRID(ST_MakePoint(v_job_lng, v_job_lat), 4326);

  RETURN QUERY
  WITH workers_with_distance AS (
    SELECT
      wp.id AS user_id,
      wp.service_radius_km,
      wp.average_rating,
      wp.total_jobs_completed,
      wp.availability_status,
      wp.response_time_avg_minutes,
      -- Compute distance inline using the user's PostGIS current_location
      COALESCE(
        ST_Distance(u.current_location, v_job_point) / 1000.0,
        999999
      ) AS distance_km,
      -- Check if worker offers the job's category
      EXISTS (
        SELECT 1 FROM worker_categories wc
        JOIN categories c ON wc.category_id = c.id
        WHERE wc.worker_id = wp.id AND c.id = v_job_category_id
      ) AS has_category
    FROM worker_profiles wp
    JOIN public.users u ON wp.id = u.id
    WHERE wp.id IS NOT NULL
      AND wp.id <> v_employer_id
  ),
  worker_scores AS (
    SELECT
      wd.user_id,
      -- Category match: 0 score if worker doesn't offer this category
      CASE WHEN wd.has_category THEN 1 ELSE 0 END AS category_match,
      -- Distance score: full points (40) if within radius, linear decay after
      GREATEST(0, 40 * (1.0 - GREATEST(0, wd.distance_km - wd.service_radius_km) / GREATEST(wd.service_radius_km, 1))) AS raw_distance_score,
      -- Rating score: 5 pts per star, max 25
      LEAST(25, COALESCE(wd.average_rating, 0) * 5) AS raw_rating_score,
      -- Experience score: 1 pt per completed job in this category, cap 15; min 2 for new workers
      GREATEST(2, LEAST(15, COALESCE((
        SELECT COUNT(*) FROM applications a
        JOIN jobs j ON a.job_id = j.id
        WHERE a.worker_id = wd.user_id
          AND a.status = 'completed'
          AND j.category_id = v_job_category_id
      ), 0))) AS raw_experience_score,
      -- Availability score
      CASE
        WHEN wd.availability_status = 'offline' THEN 0
        WHEN wd.availability_status = 'busy' THEN 5
        ELSE 10
      END AS raw_availability_score,
      -- Response speed score
      CASE
        WHEN wd.response_time_avg_minutes IS NULL THEN 5
        WHEN wd.response_time_avg_minutes < 5 THEN 10
        WHEN wd.response_time_avg_minutes < 15 THEN 7
        WHEN wd.response_time_avg_minutes < 30 THEN 5
        WHEN wd.response_time_avg_minutes < 60 THEN 3
        ELSE 1
      END AS raw_response_score,
      wd.distance_km,
      wd.average_rating,
      wd.total_jobs_completed,
      wd.availability_status
    FROM workers_with_distance wd
  )
  SELECT
    ws.user_id,
    -- If no category match, score is 0 (worker doesn't offer this service)
    CASE WHEN ws.category_match = 1
      THEN ROUND((ws.raw_distance_score + ws.raw_rating_score + ws.raw_experience_score + ws.raw_availability_score + ws.raw_response_score)::NUMERIC, 1)
      ELSE 0
    END AS total,
    ROUND(ws.raw_distance_score::NUMERIC, 1),
    ROUND(ws.raw_rating_score::NUMERIC, 1),
    ROUND(ws.raw_experience_score::NUMERIC, 1),
    ROUND(ws.raw_availability_score::NUMERIC, 1),
    ROUND(ws.raw_response_score::NUMERIC, 1),
    ws.distance_km,
    CASE
      WHEN ws.category_match = 0 THEN 'Does not offer this category'
      WHEN ws.availability_status = 'offline' THEN 'Worker is offline'
      WHEN ws.distance_km > (SELECT service_radius_km FROM worker_profiles WHERE id = ws.user_id) THEN 'Outside service radius'
      ELSE
        CONCAT(
          'Match score ', ROUND((ws.raw_distance_score + ws.raw_rating_score + ws.raw_experience_score + ws.raw_availability_score + ws.raw_response_score)::NUMERIC, 0),
          '/100 — ',
          ROUND(ws.distance_km::NUMERIC, 1), 'km away, ',
          COALESCE(ROUND(ws.average_rating::NUMERIC, 1), 0)::TEXT, '★ rating, ',
          ws.total_jobs_completed, ' jobs done'
        )
    END AS match_reason
  FROM worker_scores ws
  ORDER BY total DESC, ws.distance_km ASC;
END;
$$;
