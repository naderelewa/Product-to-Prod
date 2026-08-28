# Context Packs, the mechanism

This plugin is a **general** product/strategy engine. A company is never wired into it; a company is
a **pack**. A pack swaps **CONTEXT, never PROCESS**.

- **Layer A, the engine (never varies by pack):** the phase spine, right-sizing, the 6-tag evidence
  system + the L0–L5 citation axis + no-false-FOUND, the three human gates, the internal passes and
  scripts (`preflight.sh`, `hostcheck.sh`, `tag-lint.sh`, `inference-gate.sh`), the retro mechanism.
  These apply to ANY pack and are not pack content.
- **Layer B, this directory:** per-company/industry context, whose facts ground the run, what
  FOUND means, whether an engineering handoff exists, how analytics claims are grounded, which
  design kit (if any) the optional deck lane may use.
- **Layer C, the machine:** `config/local.template.json` + `config/dependencies.json`, paths,
  ids, and capability probes. Pack-independent by design.

**The engine hardcodes no company.** With no pack selected it runs in GENERIC MODE and says so.

---

## 1. Layout + registry

```
config/packs.json          ← the registry: default pack + id → {manifest, company, aliases, status}
packs/README.md            ← this mechanism doc
packs/<id>/pack.json       ← one manifest per pack (POINTERS ONLY, a pack never owns/moves content)
packs/<id>/README.md       ← optional orientation card; the manifest is authoritative
```

Shipped registry:

| id | status | what it points at | seam |
|---|---|---|---|
| `template-streaming` | template | a FICTIONAL streaming-engagement case under `${local:corpus_base}` | none |

`default` ships as `"none"`. That is a decision, not an omission: injecting a stranger's context into
your run would be worse than asking you one question.

## 2. Manifest schema (`packs/<id>/pack.json`)

| Key | Required | Meaning |
|---|---|---|
| `name` | yes | pack id, MUST equal its registry key |
| `display` / `company` / `industry` | yes | human labels; `company` + registry `aliases` drive matching |
| `status` | yes | `active` (live product work) · `exemplar` (replay/history corpus) · `template` (fixture + authoring base) |
| `context_files[]` | yes | the pack's standing context: `{role, path, level, consult}`, pointers, read-only, never moved. `level` = evidence posture: `standing-truth` (grounds claims per `found_sources`) · `corpus-FOUND-universe` (corpus facts ARE the run's FOUND source) · `L4-history` (prior-cycle output: consultable, **never grounds a new claim**) |
| `found_sources` | yes | what FOUND means under this pack, in one holdable sentence |
| `quarantine` | template/exemplar packs | comparison-only files; `default_deny: true` = anything absent from `context_files` is quarantined |
| `ledger_classes[]` | yes | which learnings classes this pack's history seeded, the consult-first hint |
| `seam` | yes | `{target: "<engineering handoff>"}` → full handoff artifacts, resolved through `${local:eng_plugin.*}` · `{target: "none"}` → artifacts emitted FIXTURE-marked as a schema exercise; nothing ships |
| `analytics` | yes | `{grounding: "live"}` (probes allowed; ids from `${local:analytics_*}`) · `{grounding: "corpus-pinned"}` (named corpus files only; live capabilities not selectable) |
| `deck_kit` | yes | `locked` (a named kit exists) · `owner-queued` (a kit exists but is unruled, **the deck lane refuses**, with the pointer) · `none` (deck lane unavailable) |
| `workbook_form` | optional | spreadsheet form for portfolio emission; absent = verdict table only, no spreadsheet |
| `org_shape_default` | optional | pre-answers the org-shape question; the elicitation still owns it |
| `provenance` | yes | where this pack's content and history came from |

**Path convention:** in-plugin pointers are plugin-root-relative; corpus pointers are written
`${local:corpus_base}/…` and resolve per `config/local.template.json`. **No secrets in any
manifest**, pointers only.

## 3. Selection (deterministic, recorded)

Runs at context-lock open, BEFORE the standing-context load:

1. **Explicit `--pack <id>` wins.** Unknown id = STOP and list the registry, never guess.
2. Else match the elicited `{company}` (case-insensitive) against every registry entry's `company`
   and `aliases`; a **unique** match selects that pack. Two matches = STOP and ask.
3. Else select the registry `default`.
4. **`default: "none"` / no registered pack → GENERIC MODE:** zero pack context injected; the
   evidence universe is exactly what the run supplies; seam `none`; deck lane unavailable (a visual
   identity is never improvised). Seeding a real pack for that company is a follow-up addition, one
   manifest, one registry row, never a mid-run improvisation.
5. **Record + echo:** the selected pack id lands in the run's canonical constants and is echoed in
   the contract paragraph confirmed at the first gate. Downstream verbs inherit the pack from the
   artifacts they consume and echo it at their first step.
6. **Missing pointer = named MISS:** every `context_files` path is checked at input-readiness, one
   table row per file. A dead pointer is *Not Available (Accepted Gap)*: surfaced, never silent.
   Pack corpora are CASE INPUTS, not machine dependencies, `preflight.sh` stays out of it (§7).

## 4. Injection points, how the generic engine consumes a pack

Everything not listed here is Layer-A engine and never varies.

| # | Injection point | Pack-driven behaviour |
|---|---|---|
| I1 | `{company}` / `{product}` intake defaults | the selected pack's `company`; generic mode elicits and never defaults |
| I2 | standing-context load | the pack's `context_files` by role; generic mode loads nothing |
| I3 | what FOUND means | `pack.found_sources`; `corpus-FOUND-universe` files behave per the corpus convention |
| I4 | reading list + input-readiness | pack `context_files` (+ the §3.6 named-miss rule); `L4-history` files enter as `[L4]` and never ground constants |
| I5 | right-sized capability stacks | live-analytics stacks are offerable **iff** `pack.analytics.grounding == "live"`; corpus-pinned packs never pass them |
| I6 | handoff seam | `pack.seam.target`: an engineering target → full seam artifacts via `${local:eng_plugin.*}`; `none` → fixture-marked schema exercise, design gate still `approved:false`, nothing ships |
| I7 | learnings auto-consult | unchanged, `pack.ledger_classes` is only the consult-first hint |
| I8 | analytics grounding | `pack.analytics`: live → probes with ids from `${local:analytics_*}`; corpus-pinned → the named corpus files, probes off |
| I9 | deck lane kit | `pack.deck_kit`; any status other than `locked` → the deck lane refuses with the pointer |
| I10 | portfolio spreadsheet emission | `pack.workbook_form` present → emit that form; absent → verdict table only |
| I11 | deployed-build grounding (verify verb) | requires an engineering seam target; a packless or seamless cycle has no deployed build, and the verb says that and stops |

## 5. Authoring a new pack

1. Copy `packs/template-streaming/pack.json` → `packs/<new-id>/pack.json`; fill every required key
   (§2). Pointers only, never copy corpus content into this tree.
2. Add the registry row in `config/packs.json` (`manifest`, `company`, `aliases`, `status`,
   `summary`).
3. Evidence honesty first: date the corpus; anything that is prior-cycle OUTPUT is `L4-history`;
   only a genuine data corpus earns `corpus-FOUND-universe`; if fresh work would need a new data
   pull, say so in `found_sources`.
4. Design kits are owner-ruled: ship `deck_kit.status: "owner-queued"` with the pointer until ruled.
5. Keep your own packs outside this plugin if you prefer them to survive upgrades: set
   `${local:packs_dir_extra}` and put them there.

## 6. What a pack may never do

- Never carry a secret value (pointers only).
- Never move or copy the content it points at.
- Never change the process: no pack adds a gate, removes a gate, or edits the tag rules. A pack that
  needs different *process* is not a pack, it is a fork, and it should say so.
- Never let one pack's context render in another run: generic-mode and setup output contain zero
  company literals, and a pack's names appear only while that pack is selected.

## 7. Deliberate non-wirings

- **No dependency row or preflight probe for pack corpora**, they are per-case INPUTS, and
  input-readiness owns the named miss. Preflight stays job-scoped to machine capabilities.
- **No pack-selection script**, selection is the four deterministic rules above, executed at
  context-lock. A linter earns its place when a third external pack lands, not before.
- **No per-pack machine wiring**, Layer C is pack-independent; a corpus-pinned pack simply never
  selects a live-analytics capability.
