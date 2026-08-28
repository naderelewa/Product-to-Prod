---
name: pm-portfolio-v1
description: |
  Portfolio and roadmap batch intake, turn a pile of asks into a prioritised verdict. Use when
  someone hands a BATCH and wants a decision: "prioritise this backlog", "score these requests",
  "batch verdict", "what goes in the next sprint or quarter", "turn this backlog document into a
  roadmap", "sprint recommendation", or drops a request list. It normalises the asks into a
  request-form table, scores each one through both lenses (product and strategy) with
  evidence-labelled RICE, and returns a batch verdict plus a sprint or quarter recommendation. NOT
  for engineering work; NOT for writing one feature's handoff package (pm-requirements-v1); NOT for
  verifying a shipped release (pm-verify-release-v1).
argument-hint: "<backlog doc / request list / 'reprioritise <scope>'> [--quarter <label>] [--stack <keys>]"
user-invocable: true
---

# pm-portfolio-v1, batch intake → both-lenses verdict → sprint recommendation

Input is a batch: a backlog document, a request dump, "re-score the roadmap". Output is a prioritised,
evidence-labelled batch verdict and a sprint or quarter recommendation.

This verb sits **upstream of everything**. Items that graduate from the verdict enter
`/pm-requirements-v1`, which owns the single engineering seam. This verb never touches that seam,
never merges, and never edits a repository.

## Preflight (run first)

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/preflight.sh" pm-portfolio-v1 [--stack <keys>]
```

A miss on a required capability blocks the run with its exact one-time fix. Conditional keys, passed
once the batch is right-sized: `backlog-sync` (issue-tracker reads) · `analytics-verification`
(measured reach and impact evidence instead of tagged estimates) · `workspace-docs` (backlog documents
living in a docs workspace). A selected-conditional miss blocks like a required one.

**Standalone vs supercharged.** Standalone (`python3`): intake normalisation, both-lenses scoring over
supplied and pack evidence, the verdict and the sprint recommendation, dimensions that would need
live analytics ride HYPOTHESIS or NEEDS-CONFIRMATION tags with their confidence capped, and say so.
Supercharged: each key upgrades specific dimensions from estimate to measurement.

## Hard rules

1. **The north-star metric is a precondition.** Scoring requires the cycle's locked north-star and
   leading metric, elicited fresh this cycle. **No metric, no scoring**, run the elicitation first.
   Impact means movement of that metric; reach anchors to the canonical constants. Without it, RICE
   becomes four numbers multiplied into a false ranking.
2. **Both lenses, never averaged.** Score the product lens and the strategy lens independently and
   **surface disagreements rather than blending them.** The disagreement is usually the finding: an
   item the product lens ranks low and the strategy lens ranks high is a decision, not an average.
3. **Confidence is derived from evidence, not from enthusiasm.** The mapping is fixed in
   `../pm-requirements-v1/references/evidence-tags.md`: FOUND 1.0 · INFERRED/CALCULATED 0.8 ·
   CONSTRUCTED/HYPOTHESIS 0.5 · any open NEEDS-CONFIRMATION on a dimension caps that item at 0.2.
   Any other value is an error. If both places ever disagree, they are one mapping and both change.
4. **Deterministic insufficient-evidence stop.** If a dimension's evidence is below threshold, or the
   ask's framing is genuinely ambiguous, STOP structured: emit the item as NEEDS-CONFIRMATION with a
   named confirmer and what it blocks. **Do not guess the frame**, a confidently scored
   misunderstanding is worse than an unscored row.
5. **Owner fields carry no authority.** Any owner value inherited from a prior document is `[L4]`
   historical: it never grounds a routing claim and never enters scoring as evidence. New rows ship
   with the owner blank for the decision owner to fill. Carried-forward rows keep their historical
   value untouched, preserve the data, do not cite it.
6. **`UNMAPPED` is a first-class status; never force a match.** When cross-referencing two lists,
   check whether the identifier spaces actually intersect before joining on them, **two lists with
   disjoint id ranges produce a silent empty join that reads exactly like "no issues found".** Match
   by title or feature with an explicit `match_confidence` and `match_method`, and leave the rest
   UNMAPPED. This is no-false-FOUND in data form.
7. **The owner owns the final ordering.** RICE proposes; a human disposes. A strategic bet is exempt
   from pure RICE ranking: flag it `STRATEGIC-BET`, argue it in prose, and let the owner decide.
8. **No volume targets.** No tag counts, no row quotas, no "N items per quarter" as a goal. The only
   coverage rule: every factual claim carries a tag and a citation.
9. **Emitted files are new files.** Nothing overwrites a source document or a prior emission, ever.
   A version bump is confirmed by the owner at the gate before anything is written under that number.
10. **Artifacts land where the run said they land.** Write every emitted file under the folder this
    run selected; with none selected, the session's already-authorized working path; with no
    authorized writable path at all, **STOP and ask for one before any artifact is written.** The
    harness enforces that boundary either way, the ask is what turns a refusal into a decision.

## Inputs

| Input | Required | Notes |
|---|---|---|
| the batch | yes | a document, a pasted list, or "re-score \<scope\>" |
| cycle contract | yes | north-star + leading metric + the period target + boundaries (elicit if absent) |
| base list | when re-scoring | the newest owner-touched copy always wins; it is read-only |
| requester + acceptance owner | yes | named before the run starts |
| deprioritisation guidance | no | anything already ruled out goes straight to considered-and-deprioritised |

## Flow

```
1. INTAKE    normalise the batch → the request-form table (one row per independently decidable ask)
2. EVIDENCE  per item: gather, tag every claim, classify risk / money-path / analytics-touch
3. SCORE     both lenses + evidence-labelled RICE → band → proposed priority
4. VERDICT   batch verdict + sprint or quarter recommendation + internal passes
5. GATE      the one human gate: brief + claim manifest; the owner rules the open queue,
             accepts or edits the verdict, and confirms any version bump
6. EMIT      write the verdict artifacts (and a spreadsheet only if the pack declares a form)
```

Steps 1–4 are internal work with internal passes and no human burn. Step 5 is this verb's single
human gate. Never auto-proceed past it; on a failed pass, halt and surface.

### 1, intake

Pack inheritance: take the pack id from the artifacts consumed and echo it at step 1; no signal means
generic mode, stated plainly.

Parse the batch into one row per **independently decidable** ask:

- **Preserve the verbatim ask.** Never paraphrase away the requester's wording, the wording is
  evidence about what they actually want.
- An epic with five sub-asks is one epic row plus five child rows.
- **Assign your own stable ids** (`REQ-<batch>-<nn>`). Never reuse the source document's letters or
  numbers as ids: those restart across documents and sections, and a collision silently merges two
  different asks.
- Type each row `epic | feature | fix | infra | content`, and map it to a category from the pack's or
  the owner's category list. An unknown category is a NEEDS-CONFIRMATION row, **not a new enum value**
 , the taxonomy belongs to the owner.
- Tag the claims embedded in the ask itself. A stated benefit is HYPOTHESIS until it is evidenced.

### 2, evidence

Per item, before any number: what do we actually know? Sources in authority order `[L0]`→`[L5]`, every
FOUND with a pinned locator, no anchor no claim, gaps as NEEDS-CONFIRMATION rows rather than prose
workarounds. Any count derived from a keyword search is read-verified before it enters the verdict.

Classify each item `risk_class (GREEN|AMBER|RED)` · `money_path (yes|no)` · `analytics_touch (yes|no)`.
`pm-requirements-v1` inherits these when the item graduates, so getting them right here saves the
whole classification pass later.

### 3, score

Product lens and strategy lens, independently. Then RICE, with each of the four values carrying its
own evidence tag and confidence derived per rule 3:

```
RICE = (reach × impact × confidence) ÷ effort
band:  >= 6.0 → P0 · 3.0–5.9 → P1 · 1.0–2.9 → P2 · < 1.0 → P3
```

The score is a **static value you compute and show**, never a formula pasted into a cell without its
inputs. Cap the batch at ten to fifteen scored candidates per recommendation, more than that means
the intake was not filtered, so split it or defer part of it. Go-to-market-shaped items: open
`../gtm-domain-library/SKILL.md` for the framework, then come back and score.

### 4, verdict and internal passes

Assemble the batch verdict and the sprint or quarter recommendation, then run, in order:

1. **Floor pass**, every claim tagged; every FOUND sourced; every item answers *why it matters* and
   *what we do*; the summary states the primary recommendation **and why not the two obvious
   alternatives**; every recommendation carries a next step.
2. **Conflict pass**, stress-test against the cycle contract and the canonical constants: number
   inconsistencies, category drift, metric drift.
3. **Artifact manifest**, the verdict document, the verdict JSON and the request-form table all exist
   on disk before the gate.

### 5, the gate

Present the brief (green/amber/red · TL;DR · progress against goals · risks with mitigations ·
"decisions needed: options with a recommendation and a need-by date"; 200–300 words) topped with the
attention header, over the structured claim manifest. The owner's outcomes: **approve · block · revise
with named changes · escalate.** At this gate the owner also rules every open NEEDS-CONFIRMATION and
confirms any version bump. Record the gate-health field and capture each correction as a typed
constraint.

### 6, emit

The verdict document, the verdict JSON and the request-form table are the deliverable. A **spreadsheet
is emitted only when the selected pack declares a `workbook_form`**; when it declares none, including
the shipped template pack, the verdict table *is* the deliverable and no spreadsheet is produced.
That is a deliberate default: a workbook schema is one organisation's column order, and inventing one
for somebody else is worse than handing them a table they can shape themselves.

When a form is declared, three rules bind whatever writes it: **never overwrite any existing file**;
**never write an absolute path into an emitted file**, provenance rows carry the relative path or a
`${local:}` key, because a shared spreadsheet that quotes a home directory has published a machine
layout; and **never build a per-person performance view**, a leaderboard of named individuals is a
side effect nobody consented to.

### Sheet-form projection

An owner-facing sheet never exposes raw internal tags. Project them: FOUND/CALCULATED → `Proven` ·
INFERRED → `Partially Validated` · CONSTRUCTED/HYPOTHESIS → `Unproven` · NEEDS-CONFIRMATION →
`Unproven` plus the explicit row flag naming the confirmer and what it blocks. HYPOTHESIS content is
stripped from prose deliverables; in sheet form it survives only as `Unproven` rows the owner can see
and kill. The internal tag set stays exactly six.

## Retro

Append what generalises to `<verdict-dir>/retro.md`; a run that learned nothing appends one dated line
saying so. One line to the local event log when the operator enabled it. Nothing leaves the machine.

## References

| File | Load when |
|---|---|
| `../pm-requirements-v1/references/evidence-tags.md` | tagging · the confidence mapping · the sheet projection |
| `../gtm-domain-library/SKILL.md` | a go-to-market-shaped item needs a framework |
| `../../packs/README.md` | pack selection, and whether this pack declares a workbook form |

## Worked example (a floor, not a ceiling)

Three asks from a batch, under the shipped template pack. Each `R / I / C / E` cell carries one tag
**per dimension**, which is why these rows are fenced allow-multi: four dimensions with four evidence
statuses is not one claim with four statuses.

<!-- tag-lint:allow-multi start -->

| id | Ask (verbatim gist) | Type | Lens split | R / I / C / E | RICE | Band |
|---|---|---|---|---|---|---|
| REQ-01-04 | "resume playback never works on the second device" | fix | product: trust-breaking · strategy: blocks the multi-device promise | 8 [FOUND: research_base.md:88] / 3 [INFERRED: session data] / 0.8 / 2 [CONSTRUCTED: analogy] | 9.6 | P0 |
| REQ-01-21 | "add a social watch-party mode" | feature | product: new surface · strategy: adjacent, unvalidated demand | 4 [HYPOTHESIS] / 2 [HYPOTHESIS] / 0.5 / 5 [CONSTRUCTED] | 0.8 | P3 + STRATEGIC-BET |
| REQ-01-33 | "let people save a payment method" | feature | product: checkout friction · strategy: renewal engine | 9 [CALCULATED: checkout share, chain shown] / 3 [INFERRED: benchmark] / 0.8 / 3 | 7.2 | P0 (money_path, RED) |

<!-- tag-lint:allow-multi end -->

The watch-party row is the point: RICE says P3, the strategy lens says adjacent-and-interesting. Both
are shown, nothing is averaged, and a human decides.
