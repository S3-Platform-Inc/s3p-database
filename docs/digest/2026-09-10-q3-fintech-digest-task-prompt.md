# Q3 2026 fintech digest — optimized task prompt

Prepared 2026-09-10 from the original draft:
  "connect to s3pIntegrate, take all news since 1 July 2026 by
  `published::date`, sort by themes, group by events, trends and
  wow-factors for fintech across Global, CIS, EU and Russia".
Schema facts below were verified against the checked-in DDL
  (`scripts/startup.sql`), the saved queries, the Telegram client,
  the backup inventory of 2026-09-07 and the frozen source registry.
Live values (row counts in the window, role ids, presence of the
  embeddings table) must be re-checked in step 0 of the prompt.

## 1. Prompt diagnosis

**Strengths.**
The draft names the exact database, both tables, the date field,
  the cast to use, the time window and the four regions.
It separates two outputs, analytics and digest material, and names
  three grouping lenses: events, trends and wow-factors.

**Issues.**

| Issue | Impact | Fix applied in the optimized prompt |
|---|---|---|
| "1 Jull 2026" is a typo and no end date is given | Window is ambiguous; a rolling end changes counts on every run | Window fixed to 2026-07-01 .. 2026-09-10, Moscow time, future-dated rows excluded |
| `published::date` depends on the session time zone | Rows near midnight land in the wrong day, weekly counts drift | Cast written as `(published AT TIME ZONE 'Europe/Moscow')::date` and `SET timezone` at connect |
| "Sort by themes" assumes a theme column | `documents.document` has no theme field; only `sources.source.sphere` carries `::`-delimited tags per source | Theme becomes a per-document classification with `sphere` as prior; fixed 11-label taxonomy |
| Regions are not defined and no column holds them | Global / CIS / EU / Russia cannot be counted without rules | Region rules fixed by story subject, with explicit CIS and EU member lists and a UK flag |
| No credentials or access mode stated | Executor may guess a host or open a writable session | Points to `cloud/backup/.env`, forces `default_transaction_read_only = on`, forbids inserts into `analytics.digest` |
| `score.score` is not mentioned in the analysis | Expert grading (35k rows, 1 = interesting) is the strongest wow signal and would be ignored | Expert scores joined per document and used for ranking and wow selection |
| Same story from many sources counted many times | Trends inflate, digest repeats itself | Story clustering with pg_trgm and embeddings, one cluster = one line |
| "Events, trends, wow" have no definitions | Different runs label the same item differently | Testable definitions: dated single occurrence; same direction in ≥3 docs from ≥2 sources; first-ever/record/expert-flagged |
| No output format or location | Result lands in chat and is lost | Six named files under `notions/fintech-digest-2026-q3/`, format copied from the Q2 2026 digest |
| No acceptance criteria | Impossible to know when the task is done | Per-step checks plus a mandatory citation and reconciliation pass |
| No model or cost plan | Corpus of tens of thousands of docs through one model is slow and expensive | Haiku for classification, Sonnet for drafting, Opus for synthesis; full text only for the shortlist |

**Needs clarification (assumptions used until answered).**

1. Window end: assumed 2026-09-10 (run date).
  Alternative: through 2026-09-30 once the quarter closes.
2. Digest language: assumed Russian, like the Q2 2026 digest in `notions/`.
3. EU scope: assumed EU-27 plus EEA, UK and Switzerland, with UK flagged.
4. Analytics scope: assumed all themes;
  the digest narrative keeps a fintech lens.
5. Registering the digest in `analytics.digest`: assumed no,
  the run stays read-only.
6. Expert role id for FINTECH on production: seed says 3,
  must be confirmed live.

## 2. Recommended components

| Type | Component | Purpose |
|---|---|---|
| Command | `/everything-claude-code:plan` | Confirm the nine steps and the six deliverables before touching the DB |
| Skill | `everything-claude-code:postgres-patterns` | Read-only session, window predicate, trigram clustering, `unnest(string_to_array(sphere, '::'))` |
| Skill | `everything-claude-code:cost-aware-llm-pipeline` | Route ~20k classifications to Haiku, shortlist to Opus |
| Skill | `s3p` | Tier S–D of Russian payment sources; prefer S/A originators for Russia citations |
| Skill | `ru-report-style` | Russian management-report wording for `01-digest.md` |
| Skill | `dataviz` | Theme × region and weekly-volume charts in `00-analytics.md` |
| Skill | `everything-claude-code:verification-loop` | Citation and reconciliation pass in step 8 |
| Agent | `everything-claude-code:database-reviewer` | Review the SQL in `sql/` before the full extract |
| Agent | `general-purpose` subagents | Parallel classification batches and the fresh-eyes verification |
| Model | Opus 5 (session) + Sonnet 5 + Haiku 4.5 | Synthesis / drafting / bulk classification |

## 3. Optimized prompt — full version

```text
# Task: Q3-2026 fintech digest — analytics + material from s3pIntegrate

## Context (verified 2026-09-10 against the repo; re-verify live in step 0)
- Production Postgres "s3pIntegrate", host 147.45.190.140, PostgreSQL 14.17,
  extensions timescaledb, vector (pgvector), pg_trgm. Role `sppadmin` is not a superuser.
- Connection variables: `cloud/backup/.env` (PGHOST, PGPORT, PGDATABASE, PGUSER).
  PGPASSWORD is blank there on purpose: reuse the password from `experiments/n8n/.env.s3p-api`.
  Never print secrets. Open every session with:
  SET default_transaction_read_only = on; SET statement_timeout = '120s'; SET timezone = 'Europe/Moscow';
- Schema (DDL: `projects/s3p-database/scripts/startup.sql`):
  - documents.document(id, sourceid -> sources.source, title, weblink,
    published timestamptz NOT NULL, abstract, text, storagelink, loaded timestamptz, otherdata json).
    ~76.5k rows in total (2026-09-07).
  - sources.source(id, name, sphere text, created). `sphere` is the only native theme signal:
    a `::`-delimited multi-label string of hierarchical tags such as `tech/ai::tech/fintech::tech/dlt`.
    Unnest with unnest(string_to_array(sphere, '::')).
  - score.score(id, score json, comment, document_id, user_id, role_id -> users.role, date).
    Expert grading, ~35k rows. (score->>'score')::numeric is 1 (interesting) or 0 (not interesting).
    Unique (user_id, role_id, document_id). Seeded roles: 1 ALL, 2 TEST, 3 FINTECH — confirm live.
  - Also present: users.role_source (role -> sources), ml.score (model scores per document, pluginid),
    view score.parsed_score, analytics.digest / analytics.digest_documents (platform digest registry,
    READ ONLY for this task), possibly documents.embeddings (pgvector) and
    analytics.monthly_scores_stats(date) — check in step 0.
- No column holds a document-level theme or region. Both are derived by the rules below.
- Format precedent: `notions/russia-payments-q2-2026-digest.md`
  (Russian; TL;DR of 7 trends -> per trend: События / Мнения / Связь -> Caveats -> Источники [source, id, date]).
  Reuse that structure. Read it before step 7.

## Deliverables (write everything to `notions/fintech-digest-2026-q3/`)
1. 00-analytics.md — counts and tables from step 5, charts optional.
2. 01-digest.md — the digest, Russian, Q2 format, at most 2 pages.
3. 02-material.md — one card per selected cluster (event / trend / wow) with doc ids,
   so a human can rebuild any section of 01 from 02.
4. items.csv — every document in the window: id, published_date, source_id, source_name, sphere,
   theme, theme_secondary, region, in_lens, cluster_id, expert_scores_n, expert_interesting_n,
   fintech_role_interesting (bool), selected (bool), item_type (event | trend | wow | none).
5. sql/ — every query actually executed, runnable as-is under the read-only session above.
6. 03-method.md — how theme / region / type were assigned, model used per step,
   agreement score from step 4, caveats and known gaps.

## Definitions (fixed before any query runs)
- Window: (published AT TIME ZONE 'Europe/Moscow')::date BETWEEN DATE '2026-07-01' AND DATE '2026-09-10'.
  Exclude rows with published > now(). Report separately how many rows were loaded late
  (loaded - published > 7 days) and how many rows in the window have neither abstract nor text.
- Theme taxonomy (one primary, optional secondary): fintech-payments, banking-finance, crypto-dlt, ai,
  it-software, hardware-infra, regulation-policy, security-fraud, identity-biometrics,
  business-markets (deals, M&A, VC, earnings), other.
  Map the source `sphere` tags onto this taxonomy first and use the result as a prior;
  the final theme is per document, classified on title + abstract
  (+ first 1,500 characters of text when abstract is empty).
- Region (exactly one): russia; cis (Kazakhstan, Belarus, Uzbekistan, Armenia, Kyrgyzstan, Tajikistan,
  Azerbaijan, Moldova, EAEU bodies); eu (EU-27 + EEA + UK + Switzerland, flag UK explicitly);
  global (US, Asia, LatAm, Africa, international bodies such as BIS, FATF, SWIFT, IMF, or multi-region).
  Decide by what the story is about, not by where the source sits; source origin is a fallback only.
- Fintech lens: in_lens = true when theme is one of fintech-payments, banking-finance, crypto-dlt,
  regulation-policy, security-fraud, identity-biometrics, OR when theme is ai / it-software /
  hardware-infra / business-markets AND the story states an impact on payments, banks or
  financial infrastructure. Analytics cover ALL documents; the digest narrative covers only in_lens.
- Item types:
  - event: dated single occurrence (launch, law passed, deal closed, outage, sanction, pilot start).
  - trend: the same direction of change seen in >= 3 documents from >= 2 distinct sources in the window.
  - wow: first-ever / record / reversal / surprising number, or expert-scored interesting
    (FINTECH role, score = 1) with a substantive comment.
- Story cluster: documents about the same story. Cluster on normalized title with pg_trgm
  (similarity >= 0.6, same theme, published within +-2 days); then merge by embedding cosine >= 0.85
  if documents.embeddings exists, otherwise by an LLM pairwise check inside the same theme and +-2 days.
  One cluster = one line in the digest; keep every doc id in the cluster.

## Workflow (each step ends with its check; stop and report if a check fails)
0. Connect read-only. Print select version(); count(*) of documents.document and score.score;
   min/max(published); count(*) in the window; live users.role rows; whether documents.embeddings
   and analytics.monthly_scores_stats exist. If permission to run psql is denied, stop and ask —
   do not fabricate. Check: values match the context above, or every discrepancy is listed.
1. Extract the window to a local CSV/Parquet: id, sourceid, source name, sphere, title, weblink,
   published, abstract, left(text, 1500), loaded; plus a per-document join of expert scores
   (count, count of score = 1, FINTECH-role flags, comments) and ml.score if present.
   Check: row count in the file equals count(*) from SQL; no id outside the window.
2. Counts: total; per ISO week; per source (top 20 + long tail); per sphere tag; share with
   abstract/text; share with any expert score; share scored interesting by the FINTECH role.
   Check: weekly counts sum to the total.
3. Deduplicate / cluster as defined. Check: cluster count reported; the 10 largest clusters listed
   with titles; no cluster spans more than 5 days without a stated reason.
4. Classify theme + region + in_lens for every document (one classification per cluster is fine
   when titles match >= 0.9). Use Haiku 4.5 in batches. Sample 40 documents and re-classify with
   Sonnet 5; agreement must be >= 85%, otherwise tighten the rubric and repeat.
   Check: >= 98% of documents have theme and region; `other` <= 15%.
5. Analytics tables for 00-analytics.md: theme x region matrix (documents and clusters);
   weekly volume per theme; top sources per region; expert-score coverage per theme;
   the 30 clusters with the most "interesting" expert scores. Charts optional (dataviz skill),
   saved as PNG/SVG in the folder.
6. Select and type items: for each region x in_lens theme list the clusters, label event / trend /
   wow by the definitions, rank by (expert interesting count, distinct sources, cluster size).
   Use Sonnet 5 for typing; hand the top ~60 clusters to Opus 5 for the trend narrative and the
   wow judgement. Check: every trend cites >= 3 doc ids from >= 2 sources; every event has a date
   and >= 1 doc id.
7. Write 01-digest.md in Russian in the Q2 format (invoke ru-report-style first):
   header (Составлен / Окно / Метод) -> сквозная линия квартала (2–3 sentences) -> TL;DR 7–10 trends
   -> per trend: События / Мнения / Связь -> regional block (Глобально / ЕС / СНГ / Россия:
   3–7 bullets each, or "ничего значимого не зафиксировано") -> Wow-фактор (3–5 items) -> Caveats
   -> Источники [source, id, date]. Keep facts and opinions in separate sentences; mark paraphrases
   *(перефраз)* as the Q2 digest does. For Russian sources prefer S/A-tier originators from the s3p
   sources catalog. Then write 02-material.md: one card per selected cluster with title, type,
   theme, region, date, sources + doc ids + weblinks, 1–2 sentence summary, expert comments if any.
8. Verification pass, run by a fresh subagent that did not write 01/02:
   (a) every doc id cited in 01 and 02 exists in items.csv and is inside the window;
   (b) every number in 01 is traceable to a card in 02 or a table in 00;
   (c) every trend has >= 3 ids from >= 2 sources; (d) all four regional blocks are present;
   (e) every file in sql/ runs without error in a read-only session.
   Output a pass/fail checklist; fix and re-run until every line passes.
9. Final report: what was produced and where; counts (documents, clusters, selected items);
   classification agreement; open caveats; and the 5 items you would ask the curator to confirm.

## Model routing and budget
- Haiku 4.5: theme / region classification and dedup tie-breaks
  (order of 20k documents x ~400 tokens; confirm the real count in step 0).
- Sonnet 5: clustering QA, item typing, analytics narrative, digest drafting.
- Opus 5 (session model): trend synthesis, wow judgement, final verification.
- Full `text` only for shortlisted clusters (<= 300 documents). Never send the whole corpus to a model.

## Boundaries
- Read-only DB. No INSERT / UPDATE anywhere, including analytics.digest. No schema changes.
  No changes to platform code.
- No web fetching except to verify a weblink of a cluster selected for the digest;
  mark each link verified / unverified.
- No numbers, quotes or names that are not in the documents.
- Do not include documents published before 2026-07-01 even if loaded later; count them in Caveats.
- If the DB is unreachable or the volume exceeds 50k documents in the window, stop after step 1
  and report before continuing.
```

## 4. Optimized prompt — quick version

```text
/everything-claude-code:plan Q3-2026 fintech digest from s3pIntegrate (read-only, creds in cloud/backup/.env,
password from experiments/n8n/.env.s3p-api; DDL in projects/s3p-database/scripts/startup.sql).
Window (published AT TIME ZONE 'Europe/Moscow')::date 2026-07-01..2026-09-10.
Theme = per-doc classification (11 labels) with sources.source.sphere ('::'-split) as prior;
region = russia | cis | eu | global by story subject. Cluster same-story docs (pg_trgm + embeddings).
Join score.score (score->>'score' = 1, FINTECH role) as wow signal.
Type clusters as event / trend (>=3 docs, >=2 sources) / wow.
Output to notions/fintech-digest-2026-q3/: 00-analytics.md, 01-digest.md (Russian, format of
notions/russia-payments-q2-2026-digest.md), 02-material.md, items.csv, sql/, 03-method.md.
Haiku for classification, Sonnet for drafting, Opus for synthesis.
Finish with a fresh-subagent verification: every cited id exists and is in window, numbers reconcile.
```

## 5. Enhancement rationale

| Enhancement | Reason |
|---|---|
| Explicit read-only session and secret-handling rules | `sppadmin` can write; the expert grades in `score.score` cannot be recreated |
| Time-zone-pinned date cast | `published` is `timestamptz`; a bare `::date` follows the client session time zone |
| Theme derived per document with `sphere` as prior | `sphere` is per source and multi-valued, so a source-level label would mislabel mixed feeds |
| Region rules by story subject | A Russian outlet writing about the ECB is an EU story; source origin alone misfiles it |
| Story clustering before counting | The registry has 251 sources with heavy overlap; trends must count stories, not reprints |
| Expert scores as the wow signal | 35k human grades already encode "interesting for FINTECH"; ignoring them wastes the platform's best data |
| Testable definitions for event / trend / wow | Makes the digest reproducible and lets step 8 verify it mechanically |
| Q2 digest format reused | Leadership already accepted that structure; the curator asked for "findings for the digest", not theory |
| Three-tier model routing | Bulk classification is cheap on Haiku; synthesis quality matters only for ~60 clusters |
| Fresh-subagent verification pass | Citation drift is the usual failure of LLM digests; an independent check catches it |

> Not what you need?
> Tell me what to adjust, or make a normal task request
>   if you want execution instead of prompt optimization.
