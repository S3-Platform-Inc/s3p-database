#!/usr/bin/env python3
"""Assemble 04-proposal.md, a single management-facing document, from the four
deliverables (00-analytics, 01-digest, 02-material, 03-method).

Steps: unwrap the one-sentence-per-line formatting, apply the ru-report-style
terminology map (outside verbatim expert quotes), demote headings for the
appendices, and add the framing sections. Facts, numbers and citations are
copied verbatim. Output: 04-proposal.md beside the sources.
"""
import os
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ru-report-style §1: one language per term, no hybrids. Order matters.
TERMS = [
    ("Примечания лейнов", "Примечания по каждому lane"),
    ("Лейны отбора", "Lane отбора"),
    ("лейнам", "lane"), ("лейнов", "lane"), ("лейна", "lane"), ("лейну", "lane"),
    ("лейне", "lane"), ("лейн ", "lane "), ("лейн:", "lane:"), ("Лейн", "Lane"),
    ("Драфт-агент", "Агент-составитель"), ("драфт-агента", "агента-составителя"),
    ("драфт-агент", "агент-составитель"), ("драфтам", "черновикам"),
    ("драфты", "черновики"), ("драфте", "черновике"), ("драфт", "черновик"),
    ("чанка", "chunk"), ("чанки", "chunk"), ("чанк", "chunk"),
    ("Шорт-листы", "Короткие списки"), ("Шорт-лист", "Короткий список"),
    ("шорт-листы", "короткие списки"), ("шорт-листа", "короткого списка"),
    ("шорт-лист", "короткий список"),
    ("фреймворку", "framework"), ("фреймворка", "framework"), ("фреймворк", "framework"),
    ("эксплойта", "exploit"), ("эксплойт", "exploit"),
    ("хакер Coldcard", "злоумышленник, взломавший Coldcard,"), ("из-за хака", "из-за взлома"),
    ("дипфейк-мошенничества", "deepfake-мошенничества"), ("дипфейк", "deepfake"),
    ("после дедлайна", "после крайнего срока"), ("дедлайна", "крайнего срока"),
    ("дедлайн", "крайний срок"),
    ("кастодиан Taurus", "компания Taurus (хранение цифровых активов)"),
    ("ончейн", "on-chain"),
    ("Caveats", "Ограничения и оговорки"),
]


def read(name):
    with open(os.path.join(BASE, name), encoding="utf-8") as fh:
        return fh.read()


def unwrap(text):
    """Invert the one-sentence-per-line reflow: join indented continuation lines."""
    out = []
    in_code = False
    for line in text.splitlines():
        if line.strip().startswith("```"):
            in_code = not in_code
            out.append(line)
            continue
        if (not in_code and line.startswith("  ") and out and out[-1].strip()
                and not out[-1].lstrip().startswith(("#", "|", "```"))
                and not re.match(r"^\s*[-*+]\s", line)):
            out[-1] = out[-1].rstrip() + " " + line.strip()
        else:
            out.append(line)
    return "\n".join(out)


def terms(text, skip_expert=False):
    out = []
    for line in text.splitlines():
        if skip_expert and line.startswith("- Эксперт:"):
            out.append(line)
            continue
        # keep verbatim expert quotes in «...» untouched
        parts = re.split(r"(«[^»]*»)", line)
        for i, p in enumerate(parts):
            if p.startswith("«"):
                continue
            for a, b in TERMS:
                p = p.replace(a, b)
            parts[i] = p
        out.append("".join(parts))
    return "\n".join(out)


def section(text, heading_regex):
    """Return the body of the first '## <heading>' matching the regex, up to the next '## '."""
    m = re.search(r"^## " + heading_regex + r".*$", text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    n = re.search(r"^## ", rest, re.M)
    return rest[: n.start()].strip("\n") if n else rest.strip("\n")


def demote(text, drop_title=True):
    lines = []
    for line in text.splitlines():
        if drop_title and line.startswith("# "):
            continue
        if line.startswith("### "):
            line = "#" + line
        elif line.startswith("## "):
            line = "#" + line
        lines.append(line)
    return "\n".join(lines)


def strip_numbers(text):
    return re.sub(r"^(#+) \d+[а-я]?\. ", r"\1 ", text, flags=re.M)


def main():
    digest = terms(unwrap(read("01-digest.md")))
    material = terms(read("02-material.md"), skip_expert=True)
    analytics = terms(read("00-analytics.md"))
    method = terms(unwrap(read("03-method.md")))

    header_lines = [l for l in digest.splitlines()[:6] if l.startswith("**")]
    through = next((l for l in header_lines if l.startswith("**Через-линия")), "")
    tldr = section(digest, r"TL;DR")
    trends = []
    for n in range(1, 9):
        m = re.search(r"^## " + str(n) + r"\. (.*)$", digest, re.M)
        title = m.group(1).strip()
        body = section(digest, str(n) + r"\. ")
        trends.append((title, body))
    regional = section(digest, r"Региональный блок")
    wow = section(digest, r"Wow-фактор")
    caveats = section(digest, r"Ограничения и оговорки")
    sources = section(digest, r"Источники")

    doc = []
    doc.append("""---
title: "Предложение материалов для дайджеста: финтех и финансовая индустрия, Q3 2026"
subtitle: "1 июля – 11 сентября 2026 · мир, ЕС, СНГ, Россия · по корпусу базы s3pIntegrate"
author: "Аналитика платформы s3p"
date: "11 сентября 2026"
lang: ru-RU
---
""")
    doc.append("# О документе\n")
    doc.append(
        "Документ предлагает набор материалов для квартального дайджеста по финтеху и "
        "финансовой индустрии за третий квартал 2026 года. Тезис квартала: банковская "
        "инфраструктура догоняет крипторынок на его же поле — токенизированные депозиты, "
        "стейблкоины и платежи ИИ-агентов переходят из пилотов в боевые расчёты, а регуляторы "
        "ЕС, США и России расходятся в темпе. Конкретные истории ниже иллюстрируют этот тезис; "
        "куратор выбирает из них состав выпуска.\n")
    doc.append(
        "Источник данных — корпус новостей базы s3pIntegrate: 4268 документов из 8 источников "
        "за окно с 1 июля по 11 сентября 2026 года (по московскому времени), 4196 историй после "
        "объединения дублей, 78 историй отобраны в карточки. Каждая цифра и цитата сопровождается "
        "ссылкой вида [источник, id, дата]; id — идентификатор документа в базе, полные ссылки "
        "собраны в приложении Г. Факты и мнения даны отдельными предложениями; пересказ помечен "
        "*(перефраз)*.\n")
    doc.append(
        "Структура: резюме и восемь трендов (разделы 2–10), региональный блок (11), "
        "wow-факты (12), ограничения корпуса (13) и предлагаемые следующие шаги (14). "
        "Приложения: А — карточки всех 78 историй с id, ссылками и комментариями экспертов "
        "платформы; Б — аналитика корпуса; В — метод сборки и проверки; Г — источники.\n")
    doc.append(
        "Вне охвата документа: веб-исследование российского платёжного рынка (СБП, НСПК, "
        "универсальный QR-код, детали цифрового рубля) — этих сюжетов нет в источниках базы за "
        "окно; проверка доступности ссылок; выбор итогового состава выпуска.\n")

    doc.append("# Резюме\n")
    doc.append(through + "\n")
    doc.append("**Восемь трендов квартала**\n")
    doc.append(tldr + "\n")

    for title, body in trends:
        doc.append(f"# {title}\n")
        doc.append(body + "\n")

    doc.append("# Региональный блок\n")
    doc.append(regional + "\n")
    doc.append("# Wow-фактор\n")
    doc.append(wow + "\n")
    doc.append("# Ограничения и оговорки\n")
    doc.append(caveats + "\n")

    doc.append("# Предлагаемые следующие шаги\n")
    doc.append(
        "1. Подтвердить рамку блока «Россия»: корпус показывает Россию глазами coindesk, "
        "theblock и ленты ФНС; для полноценного блока о платёжном рынке нужен отдельный "
        "веб-проход по СБП, НСПК и цифровому рублю, как в дайджесте за второй квартал.\n"
        "2. Решить, относить ли Украину к блоку «СНГ» (так сделано сейчас) или к «Глобально».\n"
        "3. Оставить обе оценки лимита 300 000 рублей в долларах (около $3 800 на 21.07 и около "
        "$3 600 на 12.08) или выбрать одну.\n"
        "4. Тренд «Консолидация» не имеет мнений в корпусе — оставить как есть или сократить до "
        "событий.\n"
        "5. Проверить доступность ссылок выбранных историй перед публикацией (в корпусе они не "
        "проверялись).\n"
        "6. Выбрать состав выпуска из приложения А: карточки помечены типом (event, trend, wow), "
        "темой, регионом и датой.\n")

    doc.append("# Приложение А. Карточки материалов\n")
    mat = demote(material)
    mat = re.sub(r"^\*\*Составлен:\*\*.*$", "", mat, flags=re.M)
    doc.append(mat.strip("\n") + "\n")

    doc.append("# Приложение Б. Аналитика корпуса\n")
    doc.append(strip_numbers(demote(analytics)).strip("\n") + "\n")

    doc.append("# Приложение В. Метод сборки и проверки\n")
    doc.append(strip_numbers(demote(method)).strip("\n") + "\n")

    doc.append("# Приложение Г. Источники\n")
    doc.append(sources + "\n")

    text = "\n".join(doc)
    text = re.sub(r"\n{3,}", "\n\n", text)
    with open(os.path.join(BASE, "04-proposal.md"), "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"04-proposal.md: {len(text.splitlines())} lines, {len(text)} chars, "
          f"{len(re.findall(r'^# ', text, re.M))} top-level sections")


if __name__ == "__main__":
    main()
