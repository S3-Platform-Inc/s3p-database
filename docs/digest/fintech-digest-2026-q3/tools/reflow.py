#!/usr/bin/env python3
"""Reflow Markdown prose: one sentence per line, wrapped at 80 columns with a
two-space continuation indent. Headings, tables, code fences, HTML comments,
blank lines and link-reference lines are left untouched. Bracketed citations
such as [coindesk, 80312, 21.07; theblock, 80331, 21.07] are never split.

Usage: reflow.py FILE [FILE ...]   (rewrites in place)
"""
import re
import sys

WIDTH = 80
ABBR = {"vs.", "e.g.", "i.e.", "т.е.", "т.д.", "т.п.", "г.", "гг.", "млн.", "млрд.",
        "тыс.", "руб.", "ст.", "п.", "ул.", "св.", "U.S.", "Inc.", "Ltd.", "Co."}


def tokens(text):
    """Split on spaces but keep [...] groups as single tokens."""
    out = []
    buf = []
    depth = 0
    for ch in text:
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth = max(0, depth - 1)
        if ch == " " and depth == 0:
            if buf:
                out.append("".join(buf))
                buf = []
        else:
            buf.append(ch)
    if buf:
        out.append("".join(buf))
    return out


def sentences(text):
    toks = tokens(text)
    sents = []
    cur = []
    for i, t in enumerate(toks):
        cur.append(t)
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        if nxt is None:
            break
        end = t[-1] in ".!?" or (len(t) > 1 and t[-1] in "»)*" and t[-2] in ".!?")
        if not end:
            continue
        if t in ABBR or re.fullmatch(r"[A-ZА-Я]\.", t) or re.fullmatch(r"\d+\.", t):
            continue
        if re.match(r"[A-ZА-ЯЁ«\[\*\d(]", nxt):
            sents.append(" ".join(cur))
            cur = []
    if cur:
        sents.append(" ".join(cur))
    return sents


def wrap(sentence, first_indent, cont_indent):
    lines = []
    line = first_indent
    fresh = True
    for t in tokens(sentence):
        if fresh:
            line = line + t
            fresh = False
        elif len(line) + 1 + len(t) <= WIDTH:
            line = line + " " + t
        else:
            lines.append(line)
            line = cont_indent + t
    lines.append(line)
    return lines


def reflow_paragraph(line):
    m = re.match(r"^(\s*(?:[-*+]|\d+\.)\s+)(.*)$", line)
    if m:
        prefix, body = m.group(1), m.group(2)
        cont = " " * (len(prefix) + 2)
    else:
        m2 = re.match(r"^(\s*)(.*)$", line)
        prefix, body = m2.group(1), m2.group(2)
        cont = prefix + "  "
    out = []
    for n, s in enumerate(sentences(body)):
        out.extend(wrap(s, prefix if n == 0 else cont, cont))
    return out


def reflow(text):
    out = []
    in_code = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("```"):
            in_code = not in_code
            out.append(line)
            continue
        skip = (in_code or not s or s.startswith("#") or s.startswith("|")
                or s.startswith("<!--") or s.startswith("---")
                or re.match(r"^\[[^\]]+\]:\s", s) or line.startswith("    ")
                or (line.startswith("  ") and not re.match(r"^\s*[-*+]\s", line)))
        if skip:
            out.append(line)
            continue
        out.extend(reflow_paragraph(line))
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        new = reflow(text)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(new)
        print(f"{path}: {len(text.splitlines())} -> {len(new.splitlines())} lines")
