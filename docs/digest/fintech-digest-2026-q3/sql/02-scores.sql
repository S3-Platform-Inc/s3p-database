-- Step 1b: expert scores aggregated per document in the window.
-- Output: work/scores.csv (last statement is written to CSV).
-- score.score.score is JSON {"score": 1.0|0.0, "comment": "..."}; 1 = interesting.
SELECT d.id AS document_id,
       count(s.id) AS scores_n,
       count(*) FILTER (
         WHERE s.score->>'score' ~ '^[0-9.]+$' AND (s.score->>'score')::numeric = 1
       ) AS interesting_n,
       count(*) FILTER (
         WHERE s.score->>'score' ~ '^[0-9.]+$' AND (s.score->>'score')::numeric = 1
           AND r.name = 'FINTECH'
       ) AS fintech_interesting,
       string_agg(DISTINCT r.name, ',') AS roles,
       string_agg(
         DISTINCT nullif(trim(coalesce(s.score->>'comment', s.comment)), ''),
         ' || '
       ) AS comments
FROM documents.document d
JOIN score.score s ON s.document_id = d.id
LEFT JOIN users.role r ON r.id = s.role_id
WHERE (d.published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND d.published <= now()
GROUP BY d.id
ORDER BY d.id;
