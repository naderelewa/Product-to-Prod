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
config/packs.json          ← the registry: default pack + id → {manifest, company, aliases, status, shape}
packs/README.md            ← this mechanism doc
packs/<id>/pack.json       ← one manifest per pack (POINTERS ONLY, a pack never owns/moves content)
packs/<id>/README.md       ← optional orientation card; the manifest is authoritative
packs/ref-<id>/facts.md    ← a benchmark pack's public figures, every one tagged (§7)
```

Shipped registry:

| id | status | what it points at | seam |
|---|---|---|---|
| `template-streaming` | template | a FICTIONAL streaming-engagement case under `${local:corpus_base}` | none |
| `ref-notion` | benchmark | public figures on a horizontal workspace product, self-serve first | none |
| `ref-chatbase` | benchmark | public figures on a small-team AI support product, sold self-serve | none |
| `ref-clay` | benchmark | public figures on a go-to-market data product priced by consumption | none |
| `ref-nawy` | benchmark | public figures on a property marketplace that earns on the transaction | none |
| `ref-thndr` | benchmark | public figures on a mobile-first retail brokerage | none |

**The shape triple.** Every registry row also carries `vertical` (what the company sells), `market`
(where it sells) and `model` (how it earns). They live on the ROW rather than inside the manifest
because the question they answer — "which registered pack does this company resemble?" — is asked
before any manifest is opened, over the index alone. They describe the company and nothing else: no
verb reads them as evidence, and none of them may be cited as a fact about anybody.

| id | vertical | market | model |
|---|---|---|---|
| `template-streaming` | subscription video streaming / consumer media | invented, multi-market | consumer subscription |
| `ref-notion` | AI workspace / productivity SaaS | global | freemium subscription SaaS |
| `ref-chatbase` | AI customer support | global | bootstrapped self-serve SaaS |
| `ref-clay` | GTM / sales infrastructure | global | usage-based B2B SaaS |
| `ref-nawy` | real-estate marketplace | Egypt and GCC | marketplace with transaction services |
| `ref-thndr` | retail investing / fintech | Egypt and MENA | consumer brokerage app |

`default` ships as `"none"`. That is a decision, not an omission: injecting a stranger's context into
your run would be worse than asking you one question.

## 2. Manifest schema (`packs/<id>/pack.json`)

| Key | Required | Meaning |
|---|---|---|
| `name` | yes | pack id, MUST equal its registry key |
| `display` / `company` / `industry` | yes | human labels; `company` + registry `aliases` drive matching |
| `status` | yes | `active` (live product work) · `exemplar` (replay/history corpus) · `template` (fixture + authoring base) · `benchmark` (public figures on a named real company, read for shape, never the run's own company — §7) |
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
   Pack corpora are CASE INPUTS, not machine dependencies, `preflight.sh` stays out of it (§9).

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
   `vertical`, `market`, `model`, `summary`). All three shape fields are required on every row,
   including the template's: a row whose shape is blank is a row §8 cannot read, so the pack is
   invisible to the seeding question the moment somebody with a similar company shows up.
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

## 7. Benchmark packs (`status: "benchmark"`)

A benchmark pack holds **public figures about a named real company**, shipped so a run can see how a
comparable business is actually built rather than reasoning from an average nobody measured. The
companies are named openly, because a benchmark whose subject is hidden is a number with no referent.

- **Never the run's own company.** A benchmark pack is read for STRUCTURE and for ranges. Selecting
  one as `{company}` would make somebody else's business the subject of your spec.
- **Every figure carries a source class and a year, never a link.** A benchmark write-up lives at
  `packs/ref-<id>/facts.md`, and every line that states a number is tagged with the year that figure
  describes plus exactly one of these three source classes:
  - `public company reporting`
  - `public filings`
  - `founder interviews as publicly reported`

  A bare number in one of those files is a defect, not a shortcut: the class is what tells a reader
  how much weight the number carries, and the year is what tells them whether it is still true. The
  classes are deliberately CLASSES rather than addresses, so a figure ages into staleness visibly
  instead of rotting quietly behind a dead link. The shape a tagged figure takes, and the one the
  benchmark-facts check reads:

  | Metric | Value | Tag | Source class and year |
  |---|---|---|---|
  | paying customers | 1,200 | FOUND | [L1: public company reporting, 2024] |

  A bare number on any other line of one of those files is a failure with the line named.
- **The fictional-content guards skip this status, on purpose and by name.** Those guards exist to
  stop a shipped pack from carrying a real company's private data behind an invented label: they
  require `template` and `exemplar` packs to declare themselves fictional, and they hold a pack's
  corpus filenames to a reviewed neutral vocabulary so the STRUCTURE cannot fingerprint somebody's
  internal exercise. A benchmark pack is the opposite case in both halves — its subject is real and
  named on the record, and its content is public — so demanding a fictional flag would force a
  false declaration, and holding its filenames to the fixture vocabulary would police nothing. What
  guards a benchmark pack instead is the tagging rule above, checked mechanically.
- **Seam `none`, and no deck kit.** Nothing about a benchmark company is shipped anywhere, and a
  visual identity is never borrowed.

## 8. Seeding a new pack from a similar case

When the elicited `{company}` matches no pack and a registered pack shares its shape triple (§1),
the run may offer to seed the NEW pack from that neighbour. The offer is a question, never a default.

1. **Confirm the shape reading first.** State the reading back in plain words — vertical, market,
   model — and name the pack that matches it. A wrong shape seeds a wrong skeleton, and the operator
   is the only one who can see that in one second.
2. **Two options, both legitimate.** Seed the structure from the neighbour, or start blank. Blank is
   never described as the worse answer: it is slower and it carries no borrowed assumptions.
3. **Structure travels. Facts do not.** What may be seeded is the SHAPE of a pack of this kind — the
   sections it needs, the questions it has to answer, the metric NAMES a business of that model is
   judged on — plus ranges that are explicitly tagged with the population they were measured over.
   Another company's figures never travel as facts about this company.
4. **Identity withheld, population never withheld.** A seeded range does not carry the neighbour's
   name: one company's number set beside yours reads as a target, and it is not one. It does carry
   the population and period it describes, always — a range with no population is a number nobody
   can argue with, which is worse than no range at all.
5. **Everything seeded lands NEEDS-CONFIRMATION.** Nothing arrives confirmed. The run walks the
   seeded assumptions as a confirm checklist, one line at a time, and every line the operator does
   not confirm stays open and travels as an open question rather than quietly becoming a premise.
6. **The seeded pack is still authored, not generated.** §5 still applies: one manifest, one registry
   row, every required key filled, and the shape triple written from the operator's own answers.

The one consent question that opens all of this is asked in `pm-start` step 1, and nowhere else — a
second place to ask it is a second place for it to be skipped.

## 9. Deliberate non-wirings

- **No dependency row or preflight probe for pack corpora**, they are per-case INPUTS, and
  input-readiness owns the named miss. Preflight stays job-scoped to machine capabilities.
- **No pack-selection script**, selection is the four deterministic rules above, executed at
  context-lock. The benchmark packs that landed with §7 did not change that: they are read by id or
  by the shape question, never by a resolver, and the registry-resolution check already fails on a
  dead pointer or a mismatched id. A linter earns its place when selection stops being four rules.
- **No per-pack machine wiring**, Layer C is pack-independent; a corpus-pinned pack simply never
  selects a live-analytics capability.
- **No seeding script**, and no automatic seeding. §8 is a conversation with a checklist at the end
  of it. A tool that seeded a pack without the confirm walk would be the one failure mode §8 exists
  to prevent, delivered faster.
