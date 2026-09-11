-- Step 0 probe: read-only facts about s3pIntegrate for the Q3-2026 digest.
-- Window: (published AT TIME ZONE 'Europe/Moscow')::date BETWEEN 2026-07-01 AND 2026-09-11.
SELECT version();

SELECT extname, extversion FROM pg_extension ORDER BY extname;

SELECT current_user, current_setting('default_transaction_read_only') AS ro,
       current_setting('timezone') AS tz, now() AS now_msk;

SELECT (SELECT count(*) FROM documents.document) AS documents,
       (SELECT count(*) FROM score.score) AS scores,
       (SELECT count(*) FROM sources.source) AS sources,
       (SELECT min(published) FROM documents.document) AS min_published,
       (SELECT max(published) FROM documents.document) AS max_published,
       (SELECT count(*) FROM documents.document WHERE published > now()) AS future_published;

SELECT count(*) AS in_window,
       count(*) FILTER (WHERE abstract IS NOT NULL AND abstract <> '') AS with_abstract,
       count(*) FILTER (WHERE text IS NOT NULL AND text <> '') AS with_text,
       min(published) AS first, max(published) AS last
FROM documents.document
WHERE (published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND published <= now();

SELECT count(*) AS loaded_in_window_but_published_before
FROM documents.document
WHERE loaded >= TIMESTAMP '2026-07-01'
  AND (published AT TIME ZONE 'Europe/Moscow')::date < DATE '2026-07-01';

SELECT id, name FROM users.role ORDER BY id;

SELECT to_regclass('documents.embeddings') AS embeddings,
       to_regclass('analytics.monthly_scores_stats') AS monthly_scores_stats,
       to_regclass('score.parsed_score') AS parsed_score,
       to_regclass('ml.score') AS ml_score;

SELECT r.id AS role_id, r.name AS role,
       count(*) AS scores,
       count(*) FILTER (WHERE (s.score->>'score')::numeric = 1) AS interesting,
       count(DISTINCT s.user_id) AS experts
FROM score.score s
JOIN users.role r ON r.id = s.role_id
JOIN documents.document d ON d.id = s.document_id
WHERE (d.published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
GROUP BY r.id, r.name ORDER BY r.id;

SELECT tag, count(*) AS documents
FROM documents.document d
JOIN sources.source s ON s.id = d.sourceid
CROSS JOIN LATERAL unnest(string_to_array(coalesce(s.sphere, ''), '::')) AS tag
WHERE (d.published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND d.published <= now()
GROUP BY tag ORDER BY documents DESC;
