#!/usr/bin/env bash
# tag-lint.sh — lint an EMITTED artifact against the evidence-tag grammar.
#
# The tag system is the engine's honesty mechanism: every factual claim carries exactly one of six
# tags and a citation, FOUND never appears without a pinned locator, and speculation never survives
# into a delivered document. Those rules are enforced by discipline while a run is being written;
# this script is the mechanical check afterwards, so a slip is caught by a machine instead of by a
# reader who trusted the document.
#
# WHAT IT IS NOT: it does not judge whether a claim is TRUE, and it does not decide which sentences
# are claims. It checks GRAMMAR — tag tokens, their count per line, their required payload, and the
# citation shape next to them. A verdict on substance is a human's job (and a reviewer's), never a
# string match.
#
# Grammar (from skills/pm-requirements-v1/references/evidence-tags.md — that file is the source of
# truth; this script is derived from it and must never invent a rule it does not state):
#   tag tokens   FOUND · INFERRED · CONSTRUCTED · CALCULATED · HYPOTHESIS · NEEDS-CONFIRMATION
#   inline form  [<TAG>] or [<TAG>: <payload>]  (a table's Tag column may hold the bare token)
#   citation     [L<0-5>: <path-or-date>] — orthogonal to the tag, on the citation itself
#   locator      file:line · a URL · a §anchor · a quoted snippet
#
# WHAT THE RECOGNISER READS is deliberately wider than the documented form, and this is not a new
# rule: real artifacts also carry a tag in parentheses, with a comma before its payload, two tags
# side by side, and a tag split across a line break. A recogniser that sees only one spelling
# reports "clean" over every other one, which is a linter believed and half-blind. So all four
# spellings are READ, and then the same rules below decide them. The documented form is still the
# one above, and the parenthesised spelling is admitted ONLY for the six known tags — an all-caps
# word in ordinary parentheses is prose, and a linter that cries wolf on prose gets switched off.
#
# Rules checked (each violation prints file:line + the rule id):
#   T1 unknown-tag        a bracketed token in tag position that is not one of the six (a typo, a
#                         spaced "NEEDS CONFIRMATION", or an invented seventh tag)
#   T2 multi-tag          two different tags on one claim line — the status is then undefined
#                         (legal on mapping/projection rows: mark them, see MARKERS)
#   T3 found-no-anchor    a FOUND line with no locator: no anchor, no claim
#   T4 found-only-l4      a FOUND line whose citations are all [L4] — historical/superseded evidence
#                         never grounds a new claim, so this is either INFERRED or a fresh read
#   T5 hypothesis-in-final  a HYPOTHESIS tag in a file marked delivery-final: speculation is
#                         stripped at delivery, and its only legal residues are the assumptions log
#                         and the open-questions queue
#   T6 table-untagged     a row of a table that has a Tag column, whose tag cell is empty or is not
#                         one of the six
#   T7 nc-no-payload      a NEEDS-CONFIRMATION tag with no payload — it must name its confirmer and
#                         what it blocks, or it is not actionable
#
# MARKERS (in the artifact, for the legitimate exceptions):
#   <!-- tag-lint:ignore-start -->  …  <!-- tag-lint:ignore-end -->   skip a block (e.g. a doc that
#                                     quotes the grammar itself)
#   <!-- tag-lint:allow-multi -->     on a line, or as a fence like ignore-start/end: mapping and
#                                     projection tables that legitimately list several tags
#   <!-- delivery-final -->           marks the file delivery-final (so does front-matter
#                                     `delivery: final`, or the --delivery-final flag)
#
# Usage:
#   tag-lint.sh <file> [<file>…] [--delivery-final] [--quiet] [--rules]
#     --delivery-final  treat every named file as delivery-final (T5 becomes active)
#     --quiet           print only violations and the verdict
#     --rules           print the rule table and exit 0
#
# Exit: 0 = clean · 1 = violations (all listed) · 2 = unreadable input / usage error
# Dependencies: python3 only. Read-only: it never edits the artifact it lints.

set -u
command -v python3 >/dev/null 2>&1 || {
  echo "tag-lint: python3 not available — cannot lint (nothing was changed)" >&2
  exit 2
}
exec python3 - "$@" <<'PY'
import os
import re
import sys

argv = sys.argv[1:]
USAGE = "usage: tag-lint.sh <file> [<file>…] [--delivery-final] [--quiet] [--rules]"

TAGS = ["FOUND", "INFERRED", "CONSTRUCTED", "CALCULATED", "HYPOTHESIS", "NEEDS-CONFIRMATION"]
RULES = [
    ("T1", "unknown-tag", "a bracketed token in tag position that is not one of the six tags"),
    ("T2", "multi-tag", "two different tags on one claim line (mark mapping rows allow-multi)"),
    ("T3", "found-no-anchor", "a FOUND line with no locator (file:line, URL, §anchor, or quote)"),
    ("T4", "found-only-l4", "a FOUND line citing only [L4] — historical evidence cannot ground it"),
    ("T5", "hypothesis-in-final", "a HYPOTHESIS tag in a delivery-final file"),
    ("T6", "table-untagged", "a row of a Tag-column table with an empty or invalid tag cell"),
    ("T7", "nc-no-payload", "NEEDS-CONFIRMATION with no confirmer/blocks payload"),
]

files, force_final, quiet = [], False, False
for a in argv:
    if a in ("-h", "--help"):
        print("tag-lint.sh — lint an emitted artifact against the evidence-tag grammar")
        print(USAGE)
        sys.exit(0)
    elif a == "--rules":
        for rid, name, desc in RULES:
            print("%s  %-20s %s" % (rid, name, desc))
        sys.exit(0)
    elif a == "--delivery-final":
        force_final = True
    elif a == "--quiet":
        quiet = True
    elif a.startswith("-"):
        sys.stderr.write("unknown flag %r\n%s\n" % (a, USAGE))
        sys.exit(2)
    else:
        files.append(a)

if not files:
    sys.stderr.write(USAGE + "\n")
    sys.exit(2)

# Any bracketed span; the leading word is then parsed as a possible tag. Payload separators vary in
# real artifacts (":", ",", "→", "—", ">", "|"), so the parse never assumes one.
BRACKET = re.compile(r"\[([^\[\]\n]{2,300})\]")
# The parenthesised spelling of the same thing. Admitted only for the six known tags (see below),
# because bracketed caps in tag position are a typo worth naming while parenthesised caps are prose.
PAREN = re.compile(r"\(([^()\n]{2,300})\)")
LEAD = re.compile(r"\s*([A-Za-z][A-Za-z _-]*?)\s*(?:$|[:,→—>|]\s*(.*)$)", re.DOTALL)
CITATION = re.compile(r"\[L([0-5])\s*:?[^\]]*\]")
BARE_L = re.compile(r"\[L([0-5])\]")
URL = re.compile(r"https?://\S+")
FILELINE = re.compile(r"[\w./-]+\.[A-Za-z0-9]+:\d+")
ANCHOR = re.compile(r"§\s*\S+")
QUOTED = re.compile(r"[\"“'][^\"”']{6,}[\"”']")
# The six tags keyed without their dashes, so a spelling variant can be recognised and named
# instead of being silently accepted or silently missed.
CANON = {k.replace("-", ""): k for k in TAGS}
# All-caps bracketed words that are legitimately NOT tags. Anything else in caps is a typo or an
# invented seventh tag, and both are worth naming.
NOT_TAGS = ("TODO", "NOTE", "WARNING", "EXAMPLE", "TEMPLATE", "OPTIONAL", "REQUIRED", "FIXTURE",
            "PASS", "PARTIAL", "GAP", "UNVERIFIED", "STRATEGIC-BET", "CONFIG-PLANNED",
            "GREEN", "AMBER", "RED", "REVISE", "BLOCKED", "STANDALONE", "SUPERCHARGED")
IGNORE_START = "tag-lint:ignore-start"
IGNORE_END = "tag-lint:ignore-end"
ALLOW_MULTI = "tag-lint:allow-multi"
FINAL_MARKERS = ("<!-- delivery-final -->", "delivery: final")


def norm_tag(raw):
    return re.sub(r"[\s_]+", "-", raw.strip().upper())


def tag_cell_col(header_cells):
    for idx, cell in enumerate(header_cells):
        if cell.strip().strip("*").lower() in ("tag", "tags", "evidence tag"):
            return idx
    return None


def split_row(line):
    s = line.strip()
    if not (s.startswith("|") and s.count("|") >= 2):
        return None
    return [c.strip() for c in s.strip("|").split("|")]


violations = []   # (path, lineno, rule_id, rule_name, detail)
summary = []      # (path, n_tag_lines, is_final, skipped)
rc_unreadable = False

for path in files:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except Exception as e:  # noqa: BLE001 — an artifact we cannot read is never "clean"
        sys.stderr.write("tag-lint: cannot read %s (%s)\n" % (path, e))
        rc_unreadable = True
        continue

    head = "\n".join(lines[:40])
    is_final = force_final or any(m in head for m in FINAL_MARKERS)
    in_ignore = False
    allow_multi_block = False
    tag_lines = 0
    skipped = 0
    tag_col = None            # active Tag-column index while inside a table
    table_row_index = 0

    for n, line in enumerate(lines, 1):
        has_start, has_end = IGNORE_START in line, IGNORE_END in line
        if has_start and has_end:
            continue          # one line naming both markers documents them; it is not a fence
        if has_start:
            in_ignore = True
            continue
        if has_end:
            in_ignore = False
            continue
        if ALLOW_MULTI in line and ("start" in line or "begin" in line):
            allow_multi_block = True
        if ALLOW_MULTI in line and "end" in line:
            allow_multi_block = False
        if in_ignore:
            skipped += 1
            continue

        allow_multi = allow_multi_block or (ALLOW_MULTI in line)

        # ── table state: a header row naming a Tag column opens a tagged table ──
        cells = split_row(line)
        if cells is not None:
            if all(re.fullmatch(r":?-{2,}:?", c or "") for c in cells if c != ""):
                table_row_index = 0                     # the |---|---| separator
                continue
            if tag_col is None:
                col = tag_cell_col(cells)
                if col is not None:
                    tag_col = col
                    table_row_index = 0
                    continue
            else:
                table_row_index += 1
        else:
            tag_col = None
            table_row_index = 0

        # A tag SPLIT ACROSS A LINE BREAK is still one tag. When a bracket opens on this line and
        # closes on the next, the two are read as one span, reported at the line the tag opens on.
        # The continuation carries no opening bracket of its own, so nothing is counted twice.
        scan_line = line
        if n < len(lines):
            open_at = line.rfind("[")
            if open_at != -1 and "]" not in line[open_at:]:
                nxt = lines[n]                           # n is 1-based: lines[n] is the NEXT line
                if "]" in nxt:
                    scan_line = line + " " + nxt[:nxt.index("]") + 1]

        found_tags = []
        for rx, opener in ((BRACKET, "["), (PAREN, "(")):
            for m in rx.finditer(scan_line):
                lead = LEAD.match(m.group(1))
                if lead is None:
                    continue      # e.g. "[L2: research_base.md]" — a citation, parsed below
                raw = (lead.group(1) or "").strip()
                payload = lead.group(2) or ""
                # Tags are WRITTEN IN CAPS. Bracketed prose is not a claim status, and treating it
                # as one would make this linter fire on ordinary writing — the fastest way to get a
                # linter switched off.
                if not raw or raw != raw.upper():
                    continue
                t = norm_tag(raw)
                if re.fullmatch(r"L[0-5]", t):
                    continue                             # citation level, not a tag
                key = t.replace("-", "")
                is_tag = t in TAGS and " " not in raw and "_" not in raw
                # A markdown link or reference is not a tag position: "[the plan](plan.md)". A span
                # that IS one of the six is a tag wherever it sits, including hard against another
                # one: "[FOUND: …][INFERRED: …]" is two tags on one claim, not a reference link.
                if not is_tag and scan_line[m.end():m.end() + 1] in ("(", "["):
                    continue
                if is_tag:
                    found_tags.append((t, payload))
                elif opener == "(":
                    continue      # parenthesised caps that are not one of the six are prose
                elif key in CANON:
                    violations.append((path, n, "T1", "unknown-tag",
                                       "%r is a spelling variant of a tag — write it exactly as %s"
                                       % (m.group(0), CANON[key])))
                elif re.fullmatch(r"[A-Z][A-Z-]{2,}", t) and len(t) >= 5 and t not in NOT_TAGS:
                    violations.append((path, n, "T1", "unknown-tag",
                                       "%r is not one of the six tags (%s) — either use one, or drop "
                                       "the bracket so it is not read as a tag"
                                       % (m.group(0), "/".join(TAGS))))

        # ── a Tag-column row must carry exactly one valid tag in that cell, unless the table is ──
        # ── marked allow-multi: a projection/mapping table's Tag cell legitimately lists several ──
        if tag_col is not None and cells is not None and table_row_index >= 1 and not allow_multi:
            if tag_col < len(cells):
                cell = cells[tag_col].strip().strip("*`")
                cell_tag = norm_tag(re.sub(r"^\[|\]$", "", cell)) if cell else ""
                if not cell or cell in ("-", "—", "n/a", "N/A"):
                    violations.append((path, n, "T6", "table-untagged",
                                       "the Tag cell is empty — every row of a tagged table carries "
                                       "one of %s" % "/".join(TAGS)))
                elif cell_tag not in TAGS:
                    violations.append((path, n, "T6", "table-untagged",
                                       "Tag cell %r is not one of %s" % (cell, "/".join(TAGS))))

        if not found_tags:
            continue
        tag_lines += 1
        distinct = sorted({t for t, _ in found_tags})
        if len(distinct) > 1 and not allow_multi:
            violations.append((path, n, "T2", "multi-tag",
                               "tags %s on one line — one claim, one status (mark a mapping row "
                               "with <!-- %s --> if it legitimately lists several)"
                               % (", ".join(distinct), ALLOW_MULTI)))

        for t, payload in found_tags:
            if t == "FOUND":
                has_locator = bool(URL.search(scan_line) or FILELINE.search(scan_line)
                                   or ANCHOR.search(scan_line) or QUOTED.search(scan_line)
                                   or CITATION.search(scan_line))
                if not has_locator:
                    violations.append((path, n, "T3", "found-no-anchor",
                                       "FOUND with no pinned locator — add file:line, a URL, a "
                                       "§anchor, or the quoted words; if you cannot cite it, it is "
                                       "not FOUND"))
                else:
                    levels = set(CITATION.findall(scan_line)) | set(BARE_L.findall(scan_line))
                    if levels and levels == {"4"}:
                        violations.append((path, n, "T4", "found-only-l4",
                                           "FOUND grounded only in [L4] historical/superseded "
                                           "material — re-read the live source or re-tag INFERRED"))
            elif t == "HYPOTHESIS" and is_final and not allow_multi:
                violations.append((path, n, "T5", "hypothesis-in-final",
                                   "HYPOTHESIS in a delivery-final file — strip it at delivery; its "
                                   "only legal residues are the assumptions log and the "
                                   "open-questions queue"))
            elif t == "NEEDS-CONFIRMATION":
                body = payload.lstrip(":").strip()
                if not body or not re.search(r"[→:>-]|blocks", body):
                    violations.append((path, n, "T7", "nc-no-payload",
                                       "NEEDS-CONFIRMATION with no payload — name the confirmer and "
                                       "what it blocks, e.g. [NEEDS-CONFIRMATION → product owner: "
                                       "blocks the pricing section]"))

    summary.append((path, tag_lines, is_final, skipped))

if not quiet:
    print("== tag-lint ==")
    for path, tag_lines, is_final, skipped in summary:
        print("  %s — %d tagged line(s)%s%s"
              % (path, tag_lines, " · DELIVERY-FINAL (HYPOTHESIS not allowed)" if is_final else "",
                 " · %d line(s) inside ignore fences" % skipped if skipped else ""))

if violations:
    print("-- violations --")
    for path, n, rid, name, detail in violations:
        print("  %s:%d  [%s %s] %s" % (path, n, rid, name, detail))
    print("== TAG-LINT FAILED: %d violation(s) across %d file(s) =="
          % (len(violations), len({v[0] for v in violations})))
    sys.exit(1)

if rc_unreadable:
    print("== TAG-LINT ERROR: one or more inputs were unreadable (see stderr) ==")
    sys.exit(2)

print("== TAG-LINT CLEAN: 0 violations across %d file(s) ==" % len(summary))
sys.exit(0)
PY
