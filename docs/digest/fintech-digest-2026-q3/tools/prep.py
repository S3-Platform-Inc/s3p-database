#!/usr/bin/env python3
"""Steps 1-3 of the digest pipeline on the extracted CSVs.

Validates work/documents.csv and work/scores.csv, computes the counts
for 00-analytics.md, clusters same-story documents by trigram similarity
of normalised titles (>= 0.6, published within +-2 days) and writes
200-row chunks for the theme classifier.

Outputs: work/counts.json, work/02-counts.md, work/clusters.csv,
work/clusters-summary.json, work/chunks/chunk-NNN.csv. Read-only on the inputs.
"""
import csv
import json
import os
import re
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(BASE, "work")
W_START, W_END = date(2026, 7, 1), date(2026, 9, 11)
SIM_THRESHOLD = 0.6
DAY_SPAN = 2
CHUNK = 200
ABSTRACT_MAX = 700

csv.field_size_limit(10**8)


def load():
    with open(f"{WORK}/documents.csv", encoding="utf-8") as fh:
        docs = list(csv.DictReader(fh))
    with open(f"{WORK}/scores.csv", encoding="utf-8") as fh:
        scores = {r["document_id"]: r for r in csv.DictReader(fh)}
    return docs, scores


def naive(ts):
    if not ts:
        return None
    return datetime.fromisoformat(ts).replace(tzinfo=None)


def validate(docs, scores):
    ids = [d["id"] for d in docs]
    problems = []
    if len(ids) != len(set(ids)):
        problems.append("duplicate ids in documents.csv")
    outside = [d["id"] for d in docs
               if not (W_START <= date.fromisoformat(d["published_date"]) <= W_END)]
    if outside:
        problems.append(f"{len(outside)} ids outside the window: {outside[:10]}")
    idset = set(ids)
    orphan = [k for k in scores if k not in idset]
    if orphan:
        problems.append(f"{len(orphan)} score rows without a document: {orphan[:10]}")
    return problems


def counts(docs, scores):
    c = {}
    c["total"] = len(docs)
    weeks = Counter()
    week_range = {}
    for d in docs:
        pd = date.fromisoformat(d["published_date"])
        iso = pd.isocalendar()
        key = f"{iso[0]}-W{iso[1]:02d}"
        weeks[key] += 1
        lo, hi = week_range.get(key, (pd, pd))
        week_range[key] = (min(lo, pd), max(hi, pd))
    c["per_week"] = [
        {"week": k, "from": week_range[k][0].isoformat(),
         "to": week_range[k][1].isoformat(), "documents": v}
        for k, v in sorted(weeks.items())
    ]
    src = Counter((d["sourceid"], d["source_name"], d["sphere"]) for d in docs)
    c["per_source"] = [
        {"source_id": k[0], "source_name": k[1], "sphere": k[2], "documents": v}
        for k, v in src.most_common()
    ]
    tags = Counter()
    for d in docs:
        for t in (d["sphere"] or "").split("::"):
            tags[t or "(none)"] += 1
    c["per_sphere_tag"] = [{"tag": k, "documents": v} for k, v in tags.most_common()]
    c["with_abstract"] = sum(1 for d in docs if (d["abstract"] or "").strip())
    c["with_text"] = sum(1 for d in docs if (d["text_head"] or "").strip())
    c["with_any_score"] = sum(1 for d in docs if d["id"] in scores)
    c["interesting_any"] = sum(1 for d in docs
                               if d["id"] in scores and int(scores[d["id"]]["interesting_n"]) > 0)
    c["fintech_interesting"] = sum(1 for d in docs
                                   if d["id"] in scores and int(scores[d["id"]]["fintech_interesting"]) > 0)
    c["with_comments"] = sum(1 for d in docs
                             if d["id"] in scores and (scores[d["id"]]["comments"] or "").strip())
    late = 0
    for d in docs:
        p, l = naive(d["published"]), naive(d["loaded"])
        if p and l and l > p + timedelta(days=7):
            late += 1
    c["loaded_late_7d"] = late
    psw = defaultdict(Counter)
    for d in docs:
        iso = date.fromisoformat(d["published_date"]).isocalendar()
        psw[d["source_name"]][f"{iso[0]}-W{iso[1]:02d}"] += 1
    c["per_source_week"] = {k: dict(sorted(v.items())) for k, v in psw.items()}
    assert sum(weeks.values()) == c["total"], "weekly sums do not match the total"
    return c


def norm_title(t):
    t = (t or "").lower()
    t = re.sub(r"[^a-zа-яё0-9 ]+", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def trigrams(s):
    g = set()
    for w in s.split():
        w = "  " + w + " "
        for i in range(len(w) - 2):
            g.add(w[i:i + 3])
    return g


def cluster(docs):
    parent = {d["id"]: d["id"] for d in docs}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    by_day = defaultdict(list)
    tg = {}
    for d in docs:
        tg[d["id"]] = trigrams(norm_title(d["title"]))
        by_day[date.fromisoformat(d["published_date"])].append(d["id"])
    days = sorted(by_day)
    pairs = 0
    merges = 0
    for day in days:
        cand = []
        for off in range(0, DAY_SPAN + 1):
            cand.extend(by_day.get(day + timedelta(days=off), []))
        for a in by_day[day]:
            ga = tg[a]
            if not ga:
                continue
            for b in cand:
                if int(b) <= int(a):
                    continue
                gb = tg[b]
                if not gb:
                    continue
                pairs += 1
                inter = len(ga & gb)
                if inter == 0:
                    continue
                sim = inter / len(ga | gb)
                if sim >= SIM_THRESHOLD:
                    union(a, b)
                    merges += 1
    groups = defaultdict(list)
    for d in docs:
        groups[find(d["id"])].append(d)
    ordered = sorted(groups.values(), key=lambda g: min(x["published"] for x in g))
    rows = []
    summary = []
    for n, g in enumerate(ordered, 1):
        g.sort(key=lambda x: (x["published"], int(x["id"])))
        rep = max(g, key=lambda x: (len(x["abstract"] or ""), -int(x["id"])))
        dates = [date.fromisoformat(x["published_date"]) for x in g]
        span = (max(dates) - min(dates)).days
        for x in g:
            rows.append({"id": x["id"], "cluster_id": n, "cluster_size": len(g),
                         "cluster_rep": 1 if x is rep else 0})
        summary.append({"cluster_id": n, "size": len(g), "span_days": span,
                        "sources": sorted({x["source_name"] for x in g}),
                        "title": rep["title"], "ids": [x["id"] for x in g]})
    return rows, summary, pairs, merges


def write_chunks(docs):
    os.makedirs(f"{WORK}/chunks", exist_ok=True)
    os.makedirs(f"{WORK}/labels", exist_ok=True)
    docs = sorted(docs, key=lambda d: int(d["id"]))
    n = 0
    for i in range(0, len(docs), CHUNK):
        n += 1
        path = f"{WORK}/chunks/chunk-{n:03d}.csv"
        with open(path, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["id", "title", "abstract", "sphere", "source_name"])
            for d in docs[i:i + CHUNK]:
                ab = re.sub(r"\s+", " ", d["abstract"] or "").strip()[:ABSTRACT_MAX]
                w.writerow([d["id"], re.sub(r"\s+", " ", d["title"] or "").strip(),
                            ab, d["sphere"], d["source_name"]])
    return n


def main():
    docs, scores = load()
    problems = validate(docs, scores)
    print(f"documents: {len(docs)}  score rows: {len(scores)}")
    print("validation:", "OK" if not problems else problems)

    c = counts(docs, scores)
    with open(f"{WORK}/counts.json", "w", encoding="utf-8") as fh:
        json.dump(c, fh, ensure_ascii=False, indent=1)
    lines = ["# Counts (step 2)", "",
             f"total {c['total']}; with_abstract {c['with_abstract']}; with_text {c['with_text']}; "
             f"with_any_score {c['with_any_score']}; interesting_any {c['interesting_any']}; "
             f"fintech_interesting {c['fintech_interesting']}; with_comments {c['with_comments']}; "
             f"loaded_late_7d {c['loaded_late_7d']}", "",
             "| week | from | to | documents |", "|---|---|---|---|"]
    lines += [f"| {w['week']} | {w['from']} | {w['to']} | {w['documents']} |" for w in c["per_week"]]
    lines += ["", "| source_id | source | sphere | documents |", "|---|---|---|---|"]
    lines += [f"| {s['source_id']} | {s['source_name']} | {s['sphere']} | {s['documents']} |"
              for s in c["per_source"]]
    lines += ["", "| sphere tag | documents |", "|---|---|"]
    lines += [f"| {t['tag']} | {t['documents']} |" for t in c["per_sphere_tag"]]
    with open(f"{WORK}/02-counts.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("weeks:", [(w["week"], w["documents"]) for w in c["per_week"]])

    rows, summary, pairs, merges = cluster(docs)
    with open(f"{WORK}/clusters.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["id", "cluster_id", "cluster_size", "cluster_rep"])
        w.writeheader()
        w.writerows(rows)
    with open(f"{WORK}/clusters-summary.json", "w", encoding="utf-8") as fh:
        json.dump(summary, fh, ensure_ascii=False, indent=1)
    sizes = Counter(s["size"] for s in summary)
    print(f"clusters: {len(summary)} from {pairs} pairs, {merges} merges; "
          f"size distribution {sorted(sizes.items())}")
    print("largest clusters:")
    for s in sorted(summary, key=lambda s: -s["size"])[:10]:
        print(f"  c{s['cluster_id']} size={s['size']} span={s['span_days']}d "
              f"{s['sources']} :: {s['title'][:90]}")
    wide = [s for s in summary if s["span_days"] > 5]
    print(f"clusters spanning more than 5 days: {len(wide)}")

    n = write_chunks(docs)
    print(f"chunks written: {n} x up to {CHUNK} rows in work/chunks/")


if __name__ == "__main__":
    main()
