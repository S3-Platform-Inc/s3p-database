-- Step 2: counts for 00-analytics.md. Printed as text; redirect to work/03-counts.txt.
-- Window: (published AT TIME ZONE 'Europe/Moscow')::date BETWEEN 2026-07-01 AND 2026-09-11.

-- 2.1 total and coverage
SELECT count(*) AS total,
       count(*) FILTER (WHERE abstract IS NOT NULL AND abstract <> '') AS with_abstract,
       count(*) FILTER (WHERE text IS NOT NULL AND text <> '') AS with_text,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM score.score s WHERE s.document_id = d.id)) AS with_any_score,
       count(*) FILTER (WHERE EXISTS (
         SELECT 1 FROM score.score s JOIN users.role r ON r.id = s.role_id
         WHERE s.document_id = d.id AND r.name = 'FINTECH'
           AND s.score->>'score' ~ '^[0-9.]+$' AND (s.score->>'score')::numeric = 1)) AS fintech_interesting,
       count(*) FILTER (WHERE loaded > published + INTERVAL '7 days') AS loaded_late_7d
FROM documents.document d
WHERE (published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND published <= now();

-- 2.2 per ISO week
SELECT to_char(date_trunc('week', published AT TIME ZONE 'Europe/Moscow'), 'IYYY-"W"IW') AS iso_week,
       min((published AT TIME ZONE 'Europe/Moscow')::date) AS week_from,
       max((published AT TIME ZONE 'Europe/Moscow')::date) AS week_to,
       count(*) AS documents
FROM documents.document
WHERE (published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND published <= now()
GROUP BY 1 ORDER BY 1;

-- 2.3 per source (all; top 20 are the first rows)
SELECT s.id AS source_id, s.name AS source_name, s.sphere, count(*) AS documents
FROM documents.document d
LEFT JOIN sources.source s ON s.id = d.sourceid
WHERE (d.published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND d.published <= now()
GROUP BY s.id, s.name, s.sphere ORDER BY documents DESC, s.id;

-- 2.4 per sphere tag
SELECT tag, count(*) AS documents
FROM documents.document d
JOIN sources.source s ON s.id = d.sourceid
CROSS JOIN LATERAL unnest(string_to_array(coalesce(s.sphere, ''), '::')) AS tag
WHERE (d.published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND d.published <= now()
GROUP BY tag ORDER BY documents DESC;

-- 2.5 documents published before the window but loaded inside it (goes to Caveats)
SELECT count(*) AS published_before_loaded_inside
FROM documents.document
WHERE loaded >= TIMESTAMP '2026-07-01'
  AND (published AT TIME ZONE 'Europe/Moscow')::date < DATE '2026-07-01';
