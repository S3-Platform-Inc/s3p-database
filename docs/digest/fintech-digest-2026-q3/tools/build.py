#!/usr/bin/env python3
"""Steps 4-6 support for the digest pipeline.

Usage:
  build.py items      merge labels, write items.csv, 00-analytics.md,
                      work/lanes/<lane>.md shortlists and the agreement sample
  build.py agreement  compare work/agreement-mine.jsonl with the Haiku labels
  build.py finalize   apply work/selection.json (cluster_id -> item_type)
                      to items.csv (selected, item_type)
"""
import csv
import glob
import json
import os
import random
import re
import sys
from collections import Counter, defaultdict
from datetime import date

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(BASE, "work")
ITEMS = os.path.join(BASE, "items.csv")
csv.field_size_limit(10**8)

THEMES = ["fintech-payments", "banking-finance", "crypto-dlt", "regulation-policy",
          "security-fraud", "identity-biometrics", "ai", "it-software",
          "hardware-infra", "business-markets", "other"]
LENS = {"fintech-payments", "banking-finance", "crypto-dlt", "regulation-policy",
        "security-fraud", "identity-biometrics"}
REGIONS = ["global", "eu", "cis", "russia"]
ITEM_COLS = ["id", "published_date", "source_id", "source_name", "sphere", "theme",
             "theme_secondary", "region", "in_lens", "cluster_id", "expert_scores_n",
             "expert_interesting_n", "fintech_role_interesting", "selected", "item_type"]
LANE_CAP = {"global-crypto": 70, "global-fin": 70, "eu": 60, "russia-cis": 120}


def read_csv(path):
    with open(path, encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def load_all():
    docs = {d["id"]: d for d in read_csv(f"{WORK}/documents.csv")}
    scores = {r["document_id"]: r for r in read_csv(f"{WORK}/scores.csv")}
    clusters = {r["id"]: r for r in read_csv(f"{WORK}/clusters.csv")}
    labels = {}
    dup = 0
    unknown = 0
    bad = 0
    for path in sorted(glob.glob(f"{WORK}/labels/chunk-*.jsonl")):
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    o = json.loads(line)
                except json.JSONDecodeError:
                    bad += 1
                    continue
                i = str(o.get("id"))
                if i not in docs:
                    unknown += 1
                    continue
                if i in labels:
                    dup += 1
                    continue
                if o.get("theme") not in THEMES:
                    o["theme"] = "other"
                if o.get("region") not in REGIONS:
                    o["region"] = "global"
                labels[i] = o
    return docs, scores, clusters, labels, {"dup": dup, "unknown": unknown, "bad": bad}


def cluster_labels(docs, clusters, labels):
    """Majority theme/region per cluster, in_lens if any member is in lens."""
    members = defaultdict(list)
    for i, c in clusters.items():
        members[c["cluster_id"]].append(i)
    out = {}
    for cid, ids in members.items():
        labelled = [labels[i] for i in ids if i in labels]
        rep = next((i for i in ids if clusters[i]["cluster_rep"] == "1"), ids[0])
        if not labelled:
            out[cid] = {"theme": "other", "theme_secondary": None, "region": "global",
                        "in_lens": False, "uk": False, "confidence": "low", "unlabelled": True}
            continue
        th = Counter(l["theme"] for l in labelled).most_common()
        rg = Counter(l["region"] for l in labelled).most_common()
        rep_l = labels.get(rep, labelled[0])
        theme = th[0][0] if len(th) == 1 or th[0][1] > th[1][1] else rep_l["theme"]
        region = rg[0][0] if len(rg) == 1 or rg[0][1] > rg[1][1] else rep_l["region"]
        out[cid] = {"theme": theme, "theme_secondary": rep_l.get("theme_secondary"),
                    "region": region, "in_lens": any(bool(l.get("in_lens")) for l in labelled),
                    "uk": any(bool(l.get("uk")) for l in labelled),
                    "confidence": rep_l.get("confidence", "medium"), "unlabelled": False}
    return members, out


def build_items(docs, scores, clusters, members, clab):
    rows = []
    for i, d in sorted(docs.items(), key=lambda kv: int(kv[0])):
        c = clusters[i]
        cl = clab[c["cluster_id"]]
        s = scores.get(i, {})
        rows.append({
            "id": i, "published_date": d["published_date"], "source_id": d["sourceid"],
            "source_name": d["source_name"], "sphere": d["sphere"], "theme": cl["theme"],
            "theme_secondary": cl["theme_secondary"] or "", "region": cl["region"],
            "in_lens": "true" if cl["in_lens"] else "false", "cluster_id": c["cluster_id"],
            "expert_scores_n": s.get("scores_n", "0"),
            "expert_interesting_n": s.get("interesting_n", "0"),
            "fintech_role_interesting": s.get("fintech_interesting", "0"),
            "selected": "0", "item_type": "",
        })
    return rows


def write_items(rows):
    with open(ITEMS, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=ITEM_COLS)
        w.writeheader()
        w.writerows(rows)


def probe_value(key):
    try:
        with open(f"{WORK}/00-probe.txt", encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except FileNotFoundError:
        return "n/a"
    for n, ln in enumerate(lines):
        if ln.strip() == key and n + 1 < len(lines):
            return lines[n + 1].strip()
    return "n/a"


def md_table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    for r in rows:
        out.append("| " + " | ".join(str(x) for x in r) + " |")
    return out


def cluster_score(cid, members, scores, docs):
    ids = members[cid]
    fi = sum(int(scores[i]["fintech_interesting"]) for i in ids if i in scores)
    it = sum(int(scores[i]["interesting_n"]) for i in ids if i in scores)
    com = sum(1 for i in ids if i in scores and (scores[i]["comments"] or "").strip())
    src = len({docs[i]["source_name"] for i in ids})
    return fi * 10 + it * 5 + com * 3 + src * 2 + len(ids), fi, it, com, src


def write_analytics(rows, docs, scores, clusters, members, clab, labels, stats, counts):
    n_docs = len(rows)
    n_clusters = len(members)
    lines = [
        "# Аналитика корпуса: финтех-дайджест Q3 2026",
        "",
        "Окно: 2026-07-01 .. 2026-09-11 (Europe/Moscow), предикат "
        "`(published AT TIME ZONE 'Europe/Moscow')::date BETWEEN ... AND published <= now()`.",
        "Источник: s3pIntegrate, documents.document + score.score, выгрузка 2026-09-11 10:56 MSK.",
        "",
        "## 1. Объём и покрытие",
        "",
    ]
    cov = [
        ("Документов в окне", n_docs),
        ("Кластеров (историй)", n_clusters),
        ("Источников в окне", len({d["source_name"] for d in docs.values()})),
        ("С abstract", counts["with_abstract"]),
        ("С текстом (text)", counts["with_text"]),
        ("С хотя бы одной экспертной оценкой", counts["with_any_score"]),
        ("Отмечено «интересно» (любая роль)", counts["interesting_any"]),
        ("Отмечено «интересно» ролью FINTECH", counts["fintech_interesting"]),
        ("С комментарием эксперта", counts["with_comments"]),
        ("Загружено позже публикации более чем на 7 дней", counts["loaded_late_7d"]),
        ("Опубликовано до окна, но загружено внутри окна (исключены)",
         probe_value("loaded_in_window_but_published_before")),
        ("Размечено темой/регионом", f"{len(labels)} ({len(labels)/n_docs:.1%})"),
        ("Доля low confidence в разметке",
         f"{sum(1 for l in labels.values() if l.get('confidence') == 'low')/max(1,len(labels)):.1%}"),
        ("Доля темы other", f"{sum(1 for r in rows if r['theme'] == 'other')/n_docs:.1%}"),
        ("Документов in_lens", f"{sum(1 for r in rows if r['in_lens'] == 'true')} "
                               f"({sum(1 for r in rows if r['in_lens'] == 'true')/n_docs:.1%})"),
    ]
    lines += md_table(["Показатель", "Значение"], cov)

    lines += ["", "## 2. Матрица тема × регион", "", "Документы:", ""]
    mat = defaultdict(Counter)
    for r in rows:
        mat[r["theme"]][r["region"]] += 1
    body = []
    for t in THEMES:
        body.append([t] + [mat[t][g] for g in REGIONS] + [sum(mat[t].values())])
    body.append(["**итого**"] + [sum(mat[t][g] for t in THEMES) for g in REGIONS] + [n_docs])
    lines += md_table(["theme"] + REGIONS + ["всего"], body)
    lines += ["", "Кластеры:", ""]
    cmat = defaultdict(Counter)
    for cid, cl in clab.items():
        cmat[cl["theme"]][cl["region"]] += 1
    body = []
    for t in THEMES:
        body.append([t] + [cmat[t][g] for g in REGIONS] + [sum(cmat[t].values())])
    body.append(["**итого**"] + [sum(cmat[t][g] for t in THEMES) for g in REGIONS] + [n_clusters])
    lines += md_table(["theme"] + REGIONS + ["всего"], body)

    lines += ["", "## 3. Недельный объём по темам (документы)", ""]
    wk = defaultdict(Counter)
    for r in rows:
        iso = date.fromisoformat(r["published_date"]).isocalendar()
        wk[f"{iso[0]}-W{iso[1]:02d}"][r["theme"]] += 1
    body = []
    for w in sorted(wk):
        body.append([w] + [wk[w][t] for t in THEMES] + [sum(wk[w].values())])
    body.append(["**итого**"] + [sum(wk[w][t] for w in wk) for t in THEMES] + [n_docs])
    lines += md_table(["week"] + THEMES + ["всего"], body)

    lines += ["", "## 4. Топ источников по регионам (документы)", ""]
    body = []
    for g in REGIONS:
        c = Counter(r["source_name"] for r in rows if r["region"] == g)
        body.append([g, sum(c.values()),
                     ", ".join(f"{s} {n}" for s, n in c.most_common(6)) or "—"])
    lines += md_table(["region", "документов", "источники (top 6)"], body)

    lines += ["", "## 5. Покрытие экспертными оценками по темам", ""]
    body = []
    for t in THEMES:
        rs = [r for r in rows if r["theme"] == t]
        if not rs:
            continue
        body.append([t, len(rs),
                     sum(1 for r in rs if int(r["expert_scores_n"]) > 0),
                     sum(1 for r in rs if int(r["expert_interesting_n"]) > 0),
                     sum(1 for r in rs if int(r["fintech_role_interesting"]) > 0),
                     sum(1 for r in rs if r["id"] in scores and (scores[r["id"]]["comments"] or "").strip())])
    lines += md_table(["theme", "документов", "с оценкой", "«интересно»", "FINTECH «интересно»",
                       "с комментарием"], body)

    lines += ["", "## 6. Кластеры с наибольшим экспертным интересом (top 30)", ""]
    ranked = sorted(members, key=lambda cid: -cluster_score(cid, members, scores, docs)[0])
    body = []
    for cid in ranked[:30]:
        sc, fi, it, com, src = cluster_score(cid, members, scores, docs)
        if it == 0 and com == 0:
            break
        ids = members[cid]
        rep = next((i for i in ids if clusters[i]["cluster_rep"] == "1"), ids[0])
        cl = clab[cid]
        body.append([cid, docs[rep]["published_date"], cl["theme"], cl["region"], it, fi,
                     ", ".join(ids), docs[rep]["title"][:90].replace("|", "/")])
    lines += md_table(["cluster", "дата", "theme", "region", "«интересно»", "FINTECH",
                       "ids", "заголовок"], body)

    lines += ["", "## 7. Распределение по источникам и тегам sphere", ""]
    lines += md_table(["source_id", "source", "sphere", "документов"],
                      [[s["source_id"], s["source_name"], s["sphere"], s["documents"]]
                       for s in counts["per_source"]])
    lines += [""]
    lines += md_table(["sphere tag", "документов"],
                      [[t["tag"], t["documents"]] for t in counts["per_sphere_tag"]])

    lines += ["", "## 8. Недельный объём (всего)", ""]
    lines += md_table(["week", "с", "по", "документов"],
                      [[w["week"], w["from"], w["to"], w["documents"]] for w in counts["per_week"]])

    lines += ["", "## 9. Качество разметки", ""]
    conf = Counter(l.get("confidence", "medium") for l in labels.values())
    lines += md_table(["показатель", "значение"], [
        ["строк с меткой", len(labels)],
        ["дубликаты в labels (отброшены)", stats["dup"]],
        ["неизвестные id в labels (отброшены)", stats["unknown"]],
        ["битые строки JSONL", stats["bad"]],
        ["confidence high / medium / low", f"{conf['high']} / {conf['medium']} / {conf['low']}"],
        ["кластеров без метки", sum(1 for cl in clab.values() if cl["unlabelled"])],
    ])
    lines += ["", "Тема и регион кластера — большинство голосов по членам кластера; "
              "in_lens = true, если хотя бы один член in_lens."]
    with open(f"{BASE}/00-analytics.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def lane_of(cl):
    if cl["region"] in ("russia", "cis"):
        return "russia-cis"
    if not cl["in_lens"]:
        return None
    if cl["region"] == "eu":
        return "eu"
    if cl["theme"] == "crypto-dlt" or cl["theme_secondary"] == "crypto-dlt":
        return "global-crypto"
    return "global-fin"


def write_lanes(docs, scores, clusters, members, clab):
    os.makedirs(f"{WORK}/lanes", exist_ok=True)
    lanes = defaultdict(list)
    for cid, cl in clab.items():
        ln = lane_of(cl)
        if ln:
            lanes[ln].append(cid)
    report = {}
    for ln, cids in lanes.items():
        ranked = sorted(cids, key=lambda c: (-cluster_score(c, members, scores, docs)[0],
                                             docs[members[c][0]]["published"]))
        short = ranked[:LANE_CAP[ln]]
        rest = ranked[LANE_CAP[ln]:]
        out = [f"# Lane {ln}: {len(cids)} clusters, {sum(len(members[c]) for c in cids)} documents",
               "", "## A. Shortlisted clusters (details)", ""]
        for c in short:
            ids = members[c]
            rep = next((i for i in ids if clusters[i]["cluster_rep"] == "1"), ids[0])
            cl = clab[c]
            sc, fi, it, com, src = cluster_score(c, members, scores, docs)
            out.append(f"### cluster {c} | {docs[rep]['published_date']} | {cl['theme']} | "
                       f"{cl['region']}{' | UK' if cl['uk'] else ''} | interesting={it} fintech={fi}")
            for i in sorted(ids, key=int):
                d = docs[i]
                out.append(f"- id={i} | {d['published_date']} | {d['source_name']} | {d['title']} | {d['weblink']}")
                s = scores.get(i)
                if s and (s["comments"] or "").strip():
                    out.append(f"  expert comment ({s['roles']}, interesting={s['interesting_n']}): "
                               f"{s['comments'].strip()[:600]}")
            ab = re.sub(r"\s+", " ", docs[rep]["abstract"] or "").strip()
            if ab:
                out.append(f"  abstract: {ab[:900]}")
            th = re.sub(r"\s+", " ", docs[rep]["text_head"] or "").strip()
            if th:
                out.append(f"  text: {th[:1200]}")
            out.append("")
        out += ["## B. Index of the remaining clusters in this lane (one line each)", ""]
        for c in sorted(rest, key=lambda c: docs[members[c][0]]["published"]):
            ids = members[c]
            rep = next((i for i in ids if clusters[i]["cluster_rep"] == "1"), ids[0])
            d = docs[rep]
            extra = f" (+{len(ids)-1}: {','.join(i for i in ids if i != rep)})" if len(ids) > 1 else ""
            out.append(f"- id={rep}{extra} | {d['published_date']} | {d['source_name']} | "
                       f"{clab[c]['theme']} | {d['title']}")
        with open(f"{WORK}/lanes/{ln}.md", "w", encoding="utf-8") as fh:
            fh.write("\n".join(out) + "\n")
        report[ln] = (len(cids), len(short), sum(len(members[c]) for c in short))
    return report


def write_agreement_sample(docs, labels):
    random.seed(42)
    ids = random.sample(sorted(labels, key=int), 40)
    with open(f"{WORK}/agreement-sample.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["id", "title", "abstract", "sphere", "source_name"])
        for i in ids:
            d = docs[i]
            w.writerow([i, re.sub(r"\s+", " ", d["title"] or "").strip(),
                        re.sub(r"\s+", " ", d["abstract"] or "").strip()[:700],
                        d["sphere"], d["source_name"]])
    with open(f"{WORK}/agreement-haiku.jsonl", "w", encoding="utf-8") as fh:
        for i in ids:
            fh.write(json.dumps(labels[i], ensure_ascii=False) + "\n")


def cmd_items():
    docs, scores, clusters, labels, stats = load_all()
    with open(f"{WORK}/counts.json", encoding="utf-8") as fh:
        counts = json.load(fh)
    n = len(docs)
    print(f"documents {n}; labelled {len(labels)} ({len(labels)/n:.1%}); "
          f"dup {stats['dup']}, unknown {stats['unknown']}, bad {stats['bad']}")
    missing = [i for i in docs if i not in labels]
    if missing:
        print(f"unlabelled ids: {len(missing)} e.g. {missing[:10]}")
    members, clab = cluster_labels(docs, clusters, labels)
    rows = build_items(docs, scores, clusters, members, clab)
    write_items(rows)
    other = sum(1 for r in rows if r["theme"] == "other") / n
    print(f"items.csv: {len(rows)} rows; other share {other:.1%}; "
          f"in_lens {sum(1 for r in rows if r['in_lens'] == 'true')}")
    print("themes:", Counter(r["theme"] for r in rows).most_common())
    print("regions:", Counter(r["region"] for r in rows).most_common())
    write_analytics(rows, docs, scores, clusters, members, clab, labels, stats, counts)
    print("00-analytics.md written")
    rep = write_lanes(docs, scores, clusters, members, clab)
    for ln, (nc, ns, nd) in rep.items():
        print(f"lane {ln}: {nc} clusters, shortlisted {ns} clusters / {nd} documents")
    write_agreement_sample(docs, labels)
    print("agreement sample written (40 rows)")
    checks = []
    if len(labels) / n < 0.98:
        checks.append("FAIL: labelled < 98%")
    if other > 0.15:
        checks.append("FAIL: other > 15%")
    print("checks:", checks or "OK")


def cmd_agreement():
    haiku = [json.loads(l) for l in open(f"{WORK}/agreement-haiku.jsonl", encoding="utf-8") if l.strip()]
    mine = {str(o["id"]): o for o in
            (json.loads(l) for l in open(f"{WORK}/agreement-mine.jsonl", encoding="utf-8") if l.strip())}
    n = t = g = both = lens = 0
    diffs = []
    for h in haiku:
        m = mine.get(str(h["id"]))
        if not m:
            continue
        n += 1
        ta = h["theme"] == m["theme"] or (m.get("theme_secondary") and h["theme"] == m["theme_secondary"]) \
            or (h.get("theme_secondary") and h["theme_secondary"] == m["theme"])
        ga = h["region"] == m["region"]
        la = bool(h.get("in_lens")) == bool(m.get("in_lens"))
        t += bool(ta)
        g += ga
        lens += la
        both += bool(ta and ga)
        if not (ta and ga):
            diffs.append((h["id"], h["theme"], m["theme"], h["region"], m["region"]))
    print(f"rows compared {n}; theme agreement {t/n:.0%}; region agreement {g/n:.0%}; "
          f"in_lens agreement {lens/n:.0%}; theme+region {both/n:.0%}")
    for d in diffs:
        print("  diff id=%s theme haiku=%s mine=%s region haiku=%s mine=%s" % d)


def cmd_finalize():
    with open(f"{WORK}/selection.json", encoding="utf-8") as fh:
        sel = json.load(fh)
    rows = read_csv(ITEMS)
    n = 0
    for r in rows:
        t = sel.get(r["cluster_id"])
        r["selected"] = "1" if t else "0"
        r["item_type"] = t or ""
        n += 1 if t else 0
    write_items(rows)
    print(f"selected rows {n}; selected clusters {len({r['cluster_id'] for r in rows if r['selected']=='1'})}; "
          f"types {Counter(r['item_type'] for r in rows if r['selected']=='1').most_common()}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "items"
    {"items": cmd_items, "agreement": cmd_agreement, "finalize": cmd_finalize}[cmd]()
