-- Dynamic capacity forecast helper for QNAP collector volume tables.
--
-- This script discovers tables matching public.volume_% and computes
-- days-to-95%-used per table and host.
--
-- Notes:
-- - qnap-collector currently emits empty total_size_unit for volume_*.
--   The query falls back to free_size_unit in that case.
-- - Host is normalized to short form via split_part(host, '.', 1)
--   so TVS-h674 and TVS-h674.np.dotnot.pl are treated as one host.
-- - Only rows with positive total/free sizes are used.
-- - Forecast is set to NULL for non-growing or near-flat trends
--   (< 0.01 percent/day), because those estimates are not actionable.

DROP TABLE IF EXISTS tmp_capacity_forecast;

CREATE TEMP TABLE tmp_capacity_forecast (
  source text,
  table_name text,
  object_id text,
  host text,
  latest_ts timestamptz,
  latest_description text,
  latest_status text,
  latest_total_gib double precision,
  latest_free_gib double precision,
  latest_used_percent double precision,
  slope_per_day_percent double precision,
  days_to_95_percent double precision,
  points_used bigint
);

DO
$$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT t.table_schema, t.table_name
    FROM information_schema.tables t
    WHERE t.table_schema = 'public'
      AND t.table_type = 'BASE TABLE'
      AND t.table_name ~ '^volume_[0-9]+$'
      AND EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.table_schema = t.table_schema
          AND c.table_name = t.table_name
          AND c.column_name = 'host'
      )
      AND EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.table_schema = t.table_schema
          AND c.table_name = t.table_name
          AND c.column_name = 'time'
      )
      AND EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.table_schema = t.table_schema
          AND c.table_name = t.table_name
          AND c.column_name = 'total_size'
      )
      AND EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.table_schema = t.table_schema
          AND c.table_name = t.table_name
          AND c.column_name = 'free_size'
      )
      AND EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.table_schema = t.table_schema
          AND c.table_name = t.table_name
          AND c.column_name = 'free_size_unit'
      )
    ORDER BY t.table_name
  LOOP
    EXECUTE format(
      $sql$
      INSERT INTO tmp_capacity_forecast (
        source,
        table_name,
        object_id,
        host,
        latest_ts,
        latest_description,
        latest_status,
        latest_total_gib,
        latest_free_gib,
        latest_used_percent,
        slope_per_day_percent,
        days_to_95_percent,
        points_used
      )
      WITH src AS (
        SELECT
          "time" AS ts,
          split_part(host, '.', 1) AS host,
          description,
          status,
          total_size::double precision AS total_size,
          free_size::double precision AS free_size,
          upper(coalesce(nullif(total_size_unit, ''), nullif(free_size_unit, ''))) AS unit,
          extract(epoch FROM "time") AS t
        FROM %I.%I
        WHERE "time" >= now() - interval '14 days'
      ),
      normalized AS (
        SELECT
          ts,
          host,
          description,
          status,
          t,
          CASE unit
            WHEN 'TB' THEN total_size * 1024^4
            WHEN 'GB' THEN total_size * 1024^3
            WHEN 'MB' THEN total_size * 1024^2
            WHEN 'KB' THEN total_size * 1024
            WHEN 'B' THEN total_size
            ELSE NULL
          END AS total_bytes,
          CASE unit
            WHEN 'TB' THEN free_size * 1024^4
            WHEN 'GB' THEN free_size * 1024^3
            WHEN 'MB' THEN free_size * 1024^2
            WHEN 'KB' THEN free_size * 1024
            WHEN 'B' THEN free_size
            ELSE NULL
          END AS free_bytes
        FROM src
      ),
      prepared AS (
        SELECT
          ts,
          host,
          description,
          status,
          t,
          total_bytes,
          free_bytes,
          (1 - (free_bytes / NULLIF(total_bytes, 0))) * 100.0 AS used_percent
        FROM normalized
        WHERE total_bytes IS NOT NULL
          AND free_bytes IS NOT NULL
          AND total_bytes > 0
          AND free_bytes >= 0
          AND free_bytes <= total_bytes
      ),
      latest AS (
        SELECT DISTINCT ON (host)
          ts,
          host,
          description,
          status,
          total_bytes,
          free_bytes,
          used_percent
        FROM prepared
        ORDER BY host, ts DESC
      ),
      fit AS (
        SELECT
          host,
          regr_slope(used_percent, t) AS slope_per_sec,
          regr_intercept(used_percent, t) AS intercept,
          max(t) AS t_now,
          count(*) AS points_used
        FROM prepared
        GROUP BY host
      )
      SELECT
        'volume' AS source,
        %L AS table_name,
        %L AS object_id,
        l.host,
        l.ts AS latest_ts,
        l.description AS latest_description,
        l.status AS latest_status,
        l.total_bytes / 1024^3 AS latest_total_gib,
        l.free_bytes / 1024^3 AS latest_free_gib,
        l.used_percent AS latest_used_percent,
        f.slope_per_sec * 86400.0 AS slope_per_day_percent,
        CASE
          WHEN f.slope_per_sec IS NULL THEN NULL
          WHEN (f.slope_per_sec * 86400.0) < 0.01 THEN NULL
          WHEN f.points_used < 2 THEN NULL
          ELSE ((95.0 - (f.slope_per_sec * f.t_now + f.intercept)) / f.slope_per_sec) / 86400.0
        END AS days_to_95_percent,
        f.points_used
      FROM latest l
      JOIN fit f
        ON f.host = l.host
      $sql$,
      r.table_schema,
      r.table_name,
      r.table_name,
      r.table_name
    );
  END LOOP;
END
$$;

SELECT
  source,
  table_name,
  object_id,
  host,
  latest_ts,
  latest_description,
  latest_status,
  round(latest_total_gib::numeric, 2) AS latest_total_gib,
  round(latest_free_gib::numeric, 2) AS latest_free_gib,
  round(latest_used_percent::numeric, 3) AS latest_used_percent,
  round(slope_per_day_percent::numeric, 4) AS slope_per_day_percent,
  round(days_to_95_percent::numeric, 2) AS days_to_95_percent,
  points_used
FROM tmp_capacity_forecast
ORDER BY
  days_to_95_percent NULLS LAST,
  table_name;
