#!/usr/bin/env bash
# inference-gate.sh — the PRE-EMIT guard: a package refuses to ship until its open items are ruled.
#
# The mechanical edge of the evidence system's gated-closure rule: every INFERRED item a
# recommendation leans on, and every NEEDS-CONFIRMATION item, is either resolved or EXPLICITLY
# accepted by the named decision owner — and the acceptance is RECORDED, not implied — before
# anything ships. On refusal you present the queue; you never guess the frame to get past the gate.
#
# Usage: inference-gate.sh <package-dir>
#        inference-gate.sh --help
#
# <package-dir>/inference-confirmed.json — written only after the owner rules on the queue:
#   { "confirmed": true, "confirmer": "<role or name>", "at": "<iso timestamp>",
#     "case": "<case slug>",
#     "items": [ { "id": "NC-1", "tag": "NEEDS-CONFIRMATION|INFERRED", "claim": "…",
#                  "ruling": "confirmed|accepted-open|dropped", "note": "…" } ] }
#
# `confirmer` is a ROLE LABEL by default ("product owner", "decision owner"). It ends up in a
# shipped artifact, so it should be a label you are happy to publish rather than a personal name.
#
# 4 branches (the first two are two different problems, so they print two different lines — a
# reader who cannot tell them apart goes looking in the wrong place; the verdict and the exit code
# are deliberately the same refusal):
#   missing directory   → REFUSE, exit 1 (the package folder itself is not there)
#   missing file        → REFUSE, exit 1 (present the queue to the decision owner)
#   confirmed !== true  → REFUSE, exit 1 (unreadable or invalid JSON refuses too — fail-closed)
#   confirmed === true  → print the confirmed set, exit 0
#
# Exit: 0 = gate passed · 1 = REFUSED · 2 = usage error
# Dependencies: python3 only. It reads one file, prints, and changes nothing.

set -u

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "usage: inference-gate.sh <package-dir>   (checks <package-dir>/inference-confirmed.json)"
  echo "The pre-emit guard: exit 0 once the owner's ruling is recorded as confirmed, 1 while it is"
  echo "not (present the queue), 2 on a usage error. It reads one file, prints, and changes nothing."
  exit 0
fi

if [ $# -ne 1 ] || [ -z "${1:-}" ]; then
  echo "usage: inference-gate.sh <package-dir>   (checks <package-dir>/inference-confirmed.json)" >&2
  exit 2
fi

PKGDIR="$1"
GATE="$PKGDIR/inference-confirmed.json"

# ── branch 0: the package directory itself is not there ──────────────────────────────────────
# A folder that does not exist and a package whose ruling was never recorded are two different
# problems. Same verdict, same exit code, different sentence.
if [ ! -d "$PKGDIR" ]; then
  echo "inference-gate: REFUSE — there is no package directory at $PKGDIR, so no ruling could be"
  echo "  read. This is a path problem, not a governance one: point the gate at the emitted"
  echo "  package's own directory (the one that holds inference-confirmed.json)."
  exit 1
fi

# ── branch 1: missing ────────────────────────────────────────────────────────────────────────
if [ ! -f "$GATE" ]; then
  echo "inference-gate: REFUSE — the gate was not passed: $GATE does not exist."
  echo "  Present the NEEDS-CONFIRMATION review queue to the decision owner. Each item carries: a"
  echo "  named confirmer · what it blocks · the ONE question that closes it (one question per"
  echo "  blocker, on the same thread — never a forked side conversation). The lifecycle is in"
  echo "  skills/pm-requirements-v1/references/evidence-tags.md."
  echo "  Record the ruling as {\"confirmed\": true, \"confirmer\": \"<role>\", \"at\": \"<iso>\", \"items\": [...]}"
  echo "  in inference-confirmed.json. Nothing emits before the gate."
  exit 1
fi

# ── branch 2: exists but confirmed !== true (unreadable/invalid JSON also refuses) ────────────
if ! python3 - "$GATE" <<'PY' 2>/dev/null
import json, sys
g = json.load(open(sys.argv[1]))
sys.exit(0 if (isinstance(g, dict) and g.get("confirmed") is True) else 1)
PY
then
  echo "inference-gate: REFUSE — $GATE exists but \"confirmed\" is not true (or the file is not valid JSON)."
  echo "  The package emits only after the owner's ruling on the queue is recorded as confirmed:true —"
  echo "  acceptance is recorded, not implied. Zero unresolved items, or each remaining one"
  echo "  explicitly accepted at the gate."
  exit 1
fi

# ── branch 3: confirmed — print the confirmed set ─────────────────────────────────────────────
python3 - "$GATE" <<'PY'
import json, sys
g = json.load(open(sys.argv[1]))
who = g.get("confirmer") or "<unrecorded>"
at = g.get("at") or "<unrecorded>"
case = g.get("case") or ""
print("inference-gate: CONFIRMED ✓   by %s at %s%s" % (who, at, ("   case: %s" % case) if case else ""))
items = g.get("items") or []
if not items:
    print("  confirmed set: (empty — zero open INFERRED / NEEDS-CONFIRMATION items this cycle)")
else:
    print("  confirmed set (%d item%s):" % (len(items), "" if len(items) == 1 else "s"))
    for it in items:
        if isinstance(it, dict):
            note = (" — %s" % it["note"]) if it.get("note") else ""
            print("    - [%s] (%s) %s -> ruling: %s%s" % (
                it.get("id", "?"), it.get("tag", "?"), it.get("claim", "?"),
                it.get("ruling", "?"), note))
        else:
            print("    - %s" % it)
PY
exit 0
