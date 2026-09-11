#!/usr/bin/env python3
"""Assemble deliverables from the lane drafts in work/drafts/.

Usage:
  assemble.py selection  merge the Selection blocks into work/selection.json
                         and apply them to items.csv (selected, item_type)
  assemble.py material   write 02-material.md from the Карточки sections
  assemble.py sources    replace the <!-- SOURCES --> marker in 01-digest.md
                         with a sources block built from its citations
  assemble.py check      verify every id cited in 01/02 exists in items.csv
"""
import csv
import json
import os
import re
import sys
from collections import OrderedDict

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(BASE, "work")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
csv.field_size_limit(10**8)

LANES = [
    ("global-fin", "Глобально: платежи, банки, идентификация, безопасность"),
    ("global-crypto", "Глобально: криптоактивы, стейблкоины, токенизация"),
    ("eu", "Европейский союз и Великобритания"),
    ("russia-cis", "Россия и СНГ"),
]
CIT = re.compile(r"([A-Za-z][\w.\-]*),\s*(\d{4,6}),\s*(\d{2}\.\d{2})")


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def section(text, title):
    """Return the body of '## <title>' up to the next '## ' heading."""
    m = re.search(r"^## " + re.escape(title) + r"\s*$", text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    n = re.search(r"^## ", rest, re.M)
    return rest[: n.start()] if n else rest


def drafts():
    out = []
    for lane, title in LANES:
        path = f"{WORK}/drafts/{lane}.md"
        if os.path.exists(path):
            out.append((lane, title, read(path)))
        else:
            print(f"missing draft: {path}")
    return out


def cmd_selection():
    merged = OrderedDict()
    for lane, _, text in drafts():
        body = section(text, "Selection")
        m = re.search(r"```json\s*(\{.*?\})\s*```", body, re.S)
        if not m:
            print(f"{lane}: no Selection JSON block")
            continue
        sel = json.loads(m.group(1))
        for cid, typ in sel.items():
            if cid in merged and merged[cid] != typ:
                print(f"conflict cluster {cid}: {merged[cid]} vs {typ} ({lane}); keeping first")
                continue
            merged.setdefault(cid, typ)
        print(f"{lane}: {len(sel)} clusters")
    with open(f"{WORK}/selection.json", "w", encoding="utf-8") as fh:
        json.dump(merged, fh, ensure_ascii=False, indent=1)
    print(f"selection.json: {len(merged)} clusters")
    import build
    build.cmd_finalize()


def parse_cards(body):
    cards = []
    for block in re.split(r"^(?=### \[cluster )", body, flags=re.M):
        block = block.strip()
        if not block.startswith("### [cluster"):
            continue
        head = block.splitlines()[0]
        m = re.match(r"### \[cluster (\d+)\]\s*(.*)", head)
        cid, title = m.group(1), m.group(2).strip()

        def field(name):
            mm = re.search(r"^- " + name + r":\s*(.*)$", block, re.M)
            return mm.group(1).strip() if mm else ""
        typ = field("Тип")
        theme_region = field("Тема")
        date = field("Дата")
        ids = sorted(set(re.findall(r"id=(\d+)", block)), key=int)
        cards.append({"cluster": cid, "title": title, "type": typ,
                      "theme_region": theme_region, "date": date, "ids": ids, "text": block})
    return cards


def cmd_material():
    lines = ["# Материалы для дайджеста Q3 2026: карточки историй", "",
             "**Составлен:** 2026-09-11 · **Окно:** 2026-07-01 .. 2026-09-11 (Europe/Moscow) · "
             "**Источник:** s3pIntegrate (documents.document + score.score), выгрузка 2026-09-11 10:56 MSK.",
             "",
             "Одна карточка = один кластер (история). Поле «Эксперт» — дословный комментарий эксперта "
             "платформы к документу, «—» = комментария нет. Идентификаторы id совпадают с items.csv "
             "и documents.document.id. Ссылки не проверялись на доступность (unverified).",
             ""]
    all_cards = []
    per_lane = []
    for lane, title, text in drafts():
        cards = parse_cards(section(text, "Карточки"))
        per_lane.append((lane, title, cards, section(text, "Дубликаты").strip()))
        for c in cards:
            c["lane"] = title
        all_cards.extend(cards)
    lines += [f"Всего карточек: {len(all_cards)}.", "", "## Индекс", "",
              "| № | кластер | тип | тема · регион | дата | заголовок | ids |", "|---|---|---|---|---|---|---|"]
    for n, c in enumerate(all_cards, 1):
        lines.append(f"| {n} | {c['cluster']} | {c['type']} | {c['theme_region']} | {c['date']} | "
                     f"{c['title'].replace('|', '/')} | {', '.join(c['ids'])} |")
    for lane, title, cards, dups in per_lane:
        lines += ["", f"## {title}", ""]
        for c in cards:
            lines += [c["text"], ""]
    lines += ["", "## Примечания лейнов: дубликаты и исключённые кластеры", ""]
    for lane, title, cards, dups in per_lane:
        lines += [f"### {title}", "", dups or "не найдено", ""]
    with open(f"{BASE}/02-material.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"02-material.md: {len(all_cards)} cards")


def load_docs():
    with open(f"{WORK}/documents.csv", encoding="utf-8") as fh:
        return {d["id"]: d for d in csv.DictReader(fh)}


def cmd_sources():
    path = f"{BASE}/01-digest.md"
    text = read(path)
    docs = load_docs()
    out = ["## Источники", "",
           "Формат: [источник, id, дата] — заголовок — ссылка. id = documents.document.id; "
           "ссылки из поля weblink, доступность не проверялась.", ""]
    current = None
    per = OrderedDict()
    for line in text.splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            continue
        if current is None or current.startswith("Источники"):
            continue
        for grp in re.findall(r"\[([^\]\n]+)\]", line):
            for src, i, d in CIT.findall(grp):
                per.setdefault(current, OrderedDict())[(src, i, d)] = True
    for sec, cits in per.items():
        out.append(f"**{sec}.**")
        for src, i, d in cits:
            doc = docs.get(i)
            t = re.sub(r"\s+", " ", doc["title"]).strip() if doc else "(id не найден)"
            u = doc["weblink"] if doc else ""
            out.append(f"- [{src}, {i}, {d}] {t} — {u}")
        out.append("")
    block = "\n".join(out)
    if "<!-- SOURCES -->" in text:
        text = text.replace("<!-- SOURCES -->", block)
    else:
        text = text.rstrip() + "\n\n" + block
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"sources: {sum(len(v) for v in per.values())} citations in {len(per)} sections")


def cmd_check():
    with open(f"{BASE}/items.csv", encoding="utf-8") as fh:
        items = {r["id"]: r for r in csv.DictReader(fh)}
    for name in ("01-digest.md", "02-material.md"):
        path = f"{BASE}/{name}"
        if not os.path.exists(path):
            print(f"{name}: missing")
            continue
        text = read(path)
        ids = set(re.findall(r"id=(\d+)", text))
        for grp in re.findall(r"\[([^\]\n]+)\]", text):
            for _, i, _ in CIT.findall(grp):
                ids.add(i)
        missing = sorted(i for i in ids if i not in items)
        print(f"{name}: {len(ids)} unique cited ids, missing {len(missing)} {missing[:20]}")
    sel_clusters = {r["cluster_id"] for r in items.values() if r["selected"] == "1"}
    cards = len(re.findall(r"^### \[cluster ", read(f"{BASE}/02-material.md"), re.M)) \
        if os.path.exists(f"{BASE}/02-material.md") else 0
    print(f"selected clusters {len(sel_clusters)}; cards {cards}; "
          f"{'OK' if len(sel_clusters) == cards else 'MISMATCH'}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    {"selection": cmd_selection, "material": cmd_material,
     "sources": cmd_sources, "check": cmd_check}[cmd]()
