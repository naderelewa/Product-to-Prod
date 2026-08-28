---
name: pm-requirements-v1
description: |
  The requirements cycle, turn a strategy statement, a release target and a set of affected
  surfaces into an evidence-tagged, gated HANDOFF PACKAGE: spec.md, plan.md, data-model.md,
  contracts/, slices.json, a design gate and a case contract, plus the record that makes all of it
  auditable. Five phases: P0 context lock (the north-star metric elicited fresh every cycle) → P1
  research → P2 strategy → P3 product spec → P4 handoff. Use when someone says "run the
  requirements cycle", "write the PRD / handoff package for <feature>", "prep the design gate",
  "requirements for the next release", or hands a strategy statement that needs to become buildable
  work. NOT for writing code, running CI, deploying or merging, an engineering toolchain owns
  those; NOT for release verification (pm-verify-release-v1); NOT for scoring a backlog batch
  (pm-portfolio-v1).
argument-hint: "<strategy statement> --release <target> --surfaces <a,b,c> [--pack <id>] [--stack <keys>]"
user-invocable: true
---

# pm-requirements-v1, strategy statement → handoff package

Build a rigorous, evidence-tagged requirements case for ONE release scope and close it as a
**handoff package**: a directory a sceptical reviewer can verify in minutes and an engineering
toolchain can consume without a single paste.

This verb is the product-and-strategy half of the loop. It produces documents and the design-gate
scaffold. It **writes no code, runs no tests, merges nothing, and authors no engineering records.**

**The boundary is hard.** Downstream of the final gate, everything belongs to whoever builds it.
Where an engineering toolchain is configured, its surface registry is READ-ONLY ground truth, read
surface names from it, never edit it, never hardcode its values. Where none is configured this verb
runs in standalone mode and says so; see `references/eng-handoff-adapter.md` at the plugin root.

## Preflight (run first)

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/preflight.sh" pm-requirements-v1 [--stack <keys>]
```

A job-scoped capability check against `config/dependencies.json`. Run it BEFORE P0 with no `--stack`.
A **miss on a required capability blocks the run**, and every miss prints its exact one-time fix
(`--setup` performs the installable ones; authentication flows print instructions and are never
auto-run). Conditional capabilities are resolved at right-sizing: once the stack is locked, re-run
with the matching keys. A selected-conditional miss blocks exactly like a required one. **A missing
capability notifies and blocks, it never silently degrades into a quieter, wronger answer.**

**What a run delivers, standalone vs supercharged** (projected from `config/dependencies.json`;
the miss discipline above is unchanged):

- **STANDALONE** (required only, `python3`, and `shasum` or `sha256sum`): the full P0→P4 cycle over run-supplied and
  pack evidence: locked constants, a tagged evidence ledger, the classified spec, the assembled
  handoff package. Claims that would need live analytics or a docs workspace ride
  NEEDS-CONFIRMATION rows instead of being measured. This is a complete deliverable, not a stub.
- **SUPERCHARGED**, each locked `--stack` key adds its capability rows, one or more:
  `eng-handoff` (the downstream registry + contract check) · `analytics-verification` (measured
  funnel and behaviour claims instead of NEEDS-CONFIRMATION rows) · `design-extraction` (design-kit
  parity reads) · `backlog-sync` (issue-tracker cross-checks) · `workspace-docs` (workspace pages as
  citable sources) · `repo-state` (repository and change-request state reads).

## What you elicit, echo, and lock

Elicited at cycle open, echoed back, then frozen as P0 constants:

| Constant | Notes |
|---|---|
| `{company}` `{product}` | who and what the cycle is for. Resolved from the selected pack, or elicited. Never assumed. |
| `{strategy statement}` | the strategic intent this cycle serves, one paragraph, with its source cited |
| `{release target}` | which release or train these requirements are for |
| `{surfaces}` | the affected surfaces. From the downstream registry when configured; otherwise from the answer, marked unverified |
| `{period}` `{geography}` | cycle window and market scope |
| `{nsm}` + `{leading metric}` | **elicited fresh EVERY cycle, never defaulted from a prior one** |
| `{owner}` | the named person who accepts this work, written down before the run starts |
| `{decision shape}` | who holds decision RIGHTS: `solo` (one person decides) · `domains` (named domain owners) · `squads` (layered approval). Identified by rights, never by headcount |

When a prior cycle exists, open with the **delta question**, "last cycle the north-star metric was
X and the scope was Y; still true?", and confirm the delta instead of re-eliciting from zero.
Supplied context counts as an answer. Stop and ask only at real boundaries: a weak or stale source,
two genuinely valid framings, an invalidated metric assumption, an irreversible or external action.
Never stop to ask for context you could go and read.

## The phase spine

```
P0 context lock ─→ right-sizing lock ─→ P1 research ─→ P2 strategy ─→ ■ GATE 1
   ─→ P3 product spec ─→ P4 handoff package ─→ ■ GATE 2 ─→ finalisation ─→ ■ GATE 3 (seal + ship)
```

Each phase produces exactly ONE canonical output file. If context feels lost, re-ground from those
files rather than from the conversation.

**Where those files land.** Write every phase output under the folder this run selected; with none
selected, the session's already-authorized working path; with no authorized writable path at all,
**STOP and ask for one before any artifact is written.** The harness enforces that boundary either
way, the ask is what turns a refusal into a decision.

**Exactly three human gates.** Every other stop, the P0 stress test, the two-pass build/conflict
cycle, the floor checks, the final audit, is an **internal quality pass**: run it, record it, fix
or halt and surface, but never wait on a human for it. No auto-proceed past a gate; no auto-retry on
a failed phase. Halting and surfacing is the correct behaviour, not a failure.

### The gate protocol (all three gates)

Present, in this order: a one-page substance summary · the structured **claim manifest** (claim ·
tag · source · what depends on it) · a 200–300 word brief (green/amber/red · what changed · risks
with mitigations · "decisions needed: options with a recommendation and a need-by date") · five
numbered confirmation questions. The claim manifest exists so that the writer cannot win the gate
with persuasive prose.

Four outcomes, and only these: **approve · block · revise with named changes · escalate.** Record
which one, and record every correction as a typed constraint (domain · quality · business · factual
· formatting) so the next cycle inherits it.

**Reviewer verdicts are PASS or REVISE.** A REVISE names the failing checks. Even a PASS names the
weakest point in the work. An author never issues a verdict on their own output.

## The evidence system, in one paragraph

Every factual claim carries exactly one of six tags, FOUND · INFERRED · CONSTRUCTED · CALCULATED ·
HYPOTHESIS · NEEDS-CONFIRMATION, and the tag decides what the claim may do. Every FOUND carries a
pinned locator: no anchor, no claim. An orthogonal `[L0]`–`[L5]` axis grades each citation's
authority, and `[L4]` historical material never grounds a new claim. HYPOTHESIS is stripped at
delivery. There are no tag quotas. **Full grammar, the projections, and the linter's rules:
`references/evidence-tags.md`**, load it when tagging, when a tag is disputed, and before sealing.

Check any emitted artifact mechanically:

```bash
bash "$PKG_ROOT/scripts/tag-lint.sh" <artifact.md> [--delivery-final]
```

---

## P0, context lock

**Goal: lock the constants every later phase inherits, before any research runs.**

**Step 0, pack selection** (deterministic, before any standing context loads). Resolve the pack per
`config/packs.json`: an explicit `--pack <id>` wins, and an unknown id STOPS and lists the registry
rather than guessing; else a unique match of the elicited `{company}` against a pack's `company` and
`aliases`; else the registry default. A default of `none` means **generic mode**: zero pack context
injected, the evidence universe is exactly what this run supplies, no handoff seam, no deck lane.
Load ONLY the selected pack's `context_files` as standing context. Record the pack id in the
canonical constants and echo it at gate 1. A dead pack pointer is a **named input-readiness miss**
here, never a capability failure, never silent. Mechanism: `packs/README.md` §3–§4.

**Step 1, decision shape.** Ask who holds decision rights, in one question, and take the pack's
`org_shape_default` as a confirm-only default when it declares one. `solo` adds no further
questions; `domains` and `squads` add at most three, covering only the domains this cycle touches, never census the organisation. Undeclared defaults to `solo`, tagged INFERRED, with a
NEEDS-CONFIRMATION row settled at gate 1. **One blocking boundary:** a `domains`/`squads` shape plus
a plausible money-path item plus no confirmable business approver. A register never holds an invented
owner.

Then, in order:

1. **Input-readiness table**, every input against its source, its status (*available and
   sufficient* / *available but needs processing* / *not available, accepted gap*) and the work
   required. Accepted gaps pre-feed HYPOTHESIS and NEEDS-CONFIRMATION tagging downstream.
2. **North-star metric elicitation**, decided by the owner and this skill together, per cycle:
   candidates table → one decision → numbered reasons anchored to the constants → the leading
   metric → the metric hierarchy → how priority flows from the metric. Test each candidate against
   the anti-proxy question ("could this move while the outcome gets worse?"). **Refuse to proceed
   without a north-star metric**, everything downstream ranks against it.
3. **Decision registers**, seed the locked-decisions register (decision · state · owner · notes) and
   the open-questions register (owner · when · what it blocks).
4. **Data-ownership loop**, the owner owns the internal data: confirm source, freshness
   (modification times) and caveats per input, audit quality, and record per-source notes in a
   source-authority map. Every metrics output carries a context-and-caveats section. Not optional.
5. **Correctness contract**, allowed claim types, evidence required per class, and the wrong-versus-
   silent penalty per output type: for numbers, prefer silence plus a NEEDS-CONFIRMATION row; for
   ideation, speculate freely under HYPOTHESIS.
6. **P0 artifacts**, canonical constants · source-authority map · private-information exclusions ·
   unsupportable-claims list · evidence-labelling spec · assumptions register · contradictions log ·
   narrative spine · a one-page P0 summary.
7. **The contract echo**, close P0 by stating ONE locked paragraph: north-star metric, cycle scope,
   selected pack, decision shape, what "correct" means here, and the explicit deprioritisations. The
   owner confirms it at gate 1. A mid-cycle shift in the bar is logged as a named spec change, never
   absorbed quietly.

P0 exits through a **five-question stress test** as an internal pass: are the constants derived only
from owner-level sources; are personas excluded from constants; is the `[L4]` rule stated; are the
private-information exclusions exhaustive; is any localisation review scoped to a named reviewer.

## Right-sizing lock

Do not run a fixed number of sub-passes. Select a per-case stack on one test: **does it feed the
canonical deliverable?** Real cases converge on ten to fifteen active sub-passes, that is a
*maximum, never a quota*. Every exclusion goes in a mandatory *explicit drops, with rationale*
section, because the filter is the value.

One case = one living playbook that supersedes all prior planning notes for it, with a hard
separation between scratch work and the deliverable. Declare the audience, ranked, next to the locked
stack. Adjust by decision shape: `solo` drops the stakeholder and panel machinery; `domains` adds
domain-owner columns and per-domain question lanes; `squads` adds a layered audience map and a pacing
budget.

Go-to-market-shaped work: open `skills/gtm-domain-library/SKILL.md` for the framework that matches the
decision in front of you (a menu, not a mandate). A full go-to-market plan build routes to
`/pm-gtm-v1` instead.

## P1, research

**Goal: the factual foundation. No strategy yet, only evidence.** Canonical output:
`p1_research_base.md`.

The **evidence ledger** is a first-class P1 output: every claim with its tag, source, L-level and
date. Each finding uses the schema *statement + evidence with source + frequency + impact + tag*, a
quote is evidence, not a finding; behavioural evidence outranks stated intent; ranges beat false
precision. Reading-list discipline: current-cycle inputs only. Prior-cycle outputs are `[L4]` and
never ground a new claim.

## P2, strategy

**Goal: turn research into a strategic bet with formal artifacts.** Canonical output:
`p2_strategy_rationale.md`.

Each step runs a mandatory **two-pass** cycle. Pass 1 (BUILD) produces the artifact and scans it for
conflicts against everything upstream. Pass 2 (CONFLICT) stress-tests it and verifies nothing
upstream was contradicted. The standing catch-list: inconsistent numbers, persona and segment naming
drift, north-star or leading-metric drift, stack and tooling mismatches, gate-state drift.

Annotate each step with its cognitive type, extraction · synthesis · analysis · generation ·
validation, and hold one line: **a generation step never validates itself.**

The strategic-bet synthesis is produced **only after** every upstream step has completed both
passes. Never pre-decide the naming or the framing: each element that emerges carries its name, its
promise, its evidence anchor, the direction-language metric that would falsify it, and its state.

## ■ Gate 1, contract + research + strategy

Opens with the P0 contract paragraph re-echoed for confirmation (constants, north-star metric,
right-sized stack with its drops, correctness contract), then the audit of P1 and P2 over that locked
stack. Gate protocol and the four outcomes as above.

## P3, product spec

**Goal: translate the locked strategy into the requirements and test scenarios the handoff carries.**
Canonical output: `p3_product_spec.md`.

What P3 contains: the requirements themselves, user stories, job stories, and test scenarios. What it
does not contain: a gate apparatus, dashboards, or wave tables, measurement lives in the handoff's
success-metrics section and sequencing lives in the slice graph.

**Every requirements item is classified**: `risk_class: GREEN|AMBER|RED` · `money_path: true|false` ·
`analytics_touch: true|false`. An analytics-touch item implies an instrumentation receipt in the
definition of done on the building side. Every item carries the traceability triple
`requirement-id → scenario-id → slice-id`.

Test scenarios cover the success path **and** the failure paths, one per user-visible rule, and they
seed the spec's acceptance scenarios. Build and conflict passes run internally here, no reviewer
stops inside P3.

## P4, the handoff package

**Goal: assemble the one deliverable.** Full item-by-item specification, the seam artifact shapes,
and the sealing procedure: **`references/handoff-package.md`**.

**Seam preflight, the first action of P4, and blocking when the adapter is configured.** With
`${local:eng_plugin.seam_check_cmd}` set, run it: exit 0 is a precondition for drafting ANY seam
artifact. A non-zero exit STOPS the handoff and surfaces the named contract delta, no package until
the contract is re-verified. With no command configured, the handoff records *contract drift not
checked* and continues: absence is recorded, never treated as a pass.

The package carries two halves. **The record**, a seven-part task record, a done receipt, the
assumptions and judgment-call log, the NEEDS-CONFIRMATION review queue, considered-and-deprioritised
with reasons, a self-assessment close, the citation map, and a machine-actionable success-metrics
section (tool · exact query · time window · evaluation dates · thresholds) that `pm-verify-release-v1`
executes later. **The seam kit**, `spec.md`, `plan.md`, `data-model.md`, `contracts/`, `slices.json`,
`case-contract.md`, `design-gate.json`.

## ■ Gate 2, spec + package draft

Audits the product spec and the assembled package after the internal floor checks have passed. Same
protocol, same four outcomes.

## Finalisation → ■ Gate 3, seal and ship

Cross-document finalisation first: constants, tags, naming, timeline, and the removal of every
unsupported claim. Then the folded final audit, source authority (no `[L4]`/`[L5]` treated as
authoritative for a load-bearing claim) · private-information leak check · inheritance (no artifact
whose only evidence is `[L4]`) · derivation (personas and strategy trace to this cycle's work).
Then **HYPOTHESIS strip-at-delivery**. Then NEEDS-CONFIRMATION closure:

```bash
bash "$PKG_ROOT/scripts/inference-gate.sh" <package-dir>     # must exit 0
```

Zero unresolved items, or each remaining one explicitly accepted, with the ruling recorded in
`<package-dir>/inference-confirmed.json`. Record the confirmer as a **role label**, not a personal
name: it ships inside the artifact.

Then the artifact manifest check (everything promised exists on disk) and the **integrity seal**,
`shasum -a 256` (or `sha256sum`) over the sealed artifact set that the seal loop in
`references/handoff-package.md` enumerates, written into the `seal` block of `design-gate.json` and
duplicated into `case-contract.md` for human eyes (procedure in `references/handoff-package.md`).

Gate 3 approval is the owner's design go: they record `{"approved": true, "approver": "<name>",
"at": "<iso>"}` in `design-gate.json`. **No code path in this plugin writes that flag.** After the
gate, iterate one micro-version per feedback round and never overwrite; when the owner edits a copy,
theirs becomes the new canonical base.

## Retro, the run close-out, never a gate

After gate 3 and the feedback round, append what generalises to `<package-dir>/retro.md`: the
verbatim feedback, numbered, each with its disposition. A run that learned nothing appends one dated
line saying exactly that, a silent retro and a clean retro must not look alike. One line lands in
the local event log if the operator turned it on (`scripts/telemetry.sh emit`, silent and no-op when
consent was never given). Nothing about a retro leaves the machine.

## References

| File | Load when |
|---|---|
| `references/evidence-tags.md` | tagging claims · a tag dispute · before sealing |
| `references/handoff-package.md` | entering P4 · assembling or sealing the seam artifacts |
| `../../references/eng-handoff-adapter.md` | deciding standalone vs handoff; wiring the adapter keys |
| `../../packs/README.md` | pack selection, the injection map, authoring a new pack |
| `../gtm-domain-library/SKILL.md` | a go-to-market-shaped decision needs a framework rather than an opinion |

## Standing taste rules

- **Read the latest source in full**, and check its modification time before citing it.
- **No recommendations before findings are locked.** Never emit a fix list mid-investigation.
- **Verify before claiming.** Never report intent, a plan, or optimism as a verified outcome.
- **Red blockers stay red** until the owner reports them unblocked. Never soften a status to make a
  summary look better; the summary is not the product.
- **An override from the reviewer arrives as a new `[L0]` directive** and becomes a constant.
- **Prefer a named gap to a smooth paragraph.** The gaps are what make the rest believable.
