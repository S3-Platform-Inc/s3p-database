-- Step 1a: extract every document in the window with its source.
-- Output: work/documents.csv (last statement is written to CSV).
-- Window: (published AT TIME ZONE 'Europe/Moscow')::date BETWEEN 2026-07-01 AND 2026-09-11.
SELECT count(*) AS expected_rows
FROM documents.document d
WHERE (d.published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND d.published <= now();

SELECT d.id,
       d.sourceid,
       s.name AS source_name,
       s.sphere,
       d.title,
       d.weblink,
       d.published,
       (d.published AT TIME ZONE 'Europe/Moscow')::date AS published_date,
       d.abstract,
       left(d.text, 1500) AS text_head,
       d.loaded
FROM documents.document d
LEFT JOIN sources.source s ON s.id = d.sourceid
WHERE (d.published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-11'
  AND d.published <= now()
ORDER BY d.published, d.id;
