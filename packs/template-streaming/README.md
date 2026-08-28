# Lumina Streaming, the shipped template pack (fictional)

Orientation card. `pack.json` is authoritative; this file just says out loud what the pack is for.

## What it is

A **fictional** subscription-streaming company and a fictional engagement case. Nothing in it is
real: no real company, no real corpus, no real numbers. That is the point, a template that
strangers copy must be safe to read and safe to publish.

It does two jobs:

1. **Authoring template.** Copy `pack.json`, fill every required key for your own company, add one
   row to `config/packs.json`. One manifest + one registry row = one addition.
2. **Fixture for the checks that exist.** The suite's pack checks read it, and that is the whole of
   it: `packs_registry_resolves` and `fictional_pack_content` are exercised against this pack, and
   `fictional_pack_guard` reads the same registry row, so the row and the manifest have to agree
   and the content has to stay fictional. Pack selection, the quarantine rule and the named-miss
   behaviour on a dead pointer are rules this pack declares and the verbs follow in prose; no check
   in the suite covers them.

## The shape it demonstrates

| Key | What it teaches |
|---|---|
| `context_files[]` | pointers with an evidence `level`, `corpus-FOUND-universe` (these facts ARE the run's FOUND source) vs `standing-truth` vs `L4-history` (consultable, never grounds a new claim) |
| `found_sources` | what FOUND *means* under this pack, in one sentence a reviewer can hold you to |
| `quarantine.default_deny` | the default rule: anything not listed is comparison-only, and reading it is leakage |
| `seam.target: "none"` | standalone mode, seam artifacts are a fixture-marked schema exercise; nothing ships |
| `analytics.grounding: "corpus-pinned"` | live-analytics capabilities are not selectable, so a corpus-only run cannot quietly pretend it measured something |
| `deck_kit.status: "none"` | the deck lane refuses instead of improvising a visual identity |
| `workbook_form: null` | no spreadsheet emission for this pack, the verdict table is the deliverable |

## Pointers resolve, they do not travel

Corpus paths are written `${local:corpus_base}/lumina-case/…`. Set `corpus_base` in
`config/local.json` if you want to materialise the case locally; leave it unset and a run that
selects this pack reports each file as a **named input-readiness miss** and continues on what it can
prove. A dead pointer is never a crash, and never silent.

## When you copy it

- Date your corpus. Anything that is a prior cycle's *output* is `L4-history`, not evidence.
- Only a genuine data corpus earns `corpus-FOUND-universe`. If fresh work would need a new data
  pull, say so in `found_sources`, that sentence is what stops an invented FOUND later.
- Ship a design kit as `owner-queued` with a pointer until its owner rules; the deck lane refusing
  is the correct behaviour, not a bug.
- Keep `fictional: true` only while the content is invented. Delete it the moment real facts land.
