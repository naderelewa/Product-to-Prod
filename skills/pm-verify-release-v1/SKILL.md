---
name: pm-verify-release-v1
description: |
  Post-release acceptance verification, grade a shipped release against the spec that promised it.
  Use when someone says "verify the release", "did the release meet its acceptance scenarios",
  "post-release verification", "execute the measurement plan", "week-one metrics check", or hands a
  shipped scope that needs product-side evidence. Every pre-declared acceptance scenario is graded
  PASS / PARTIAL / GAP / UNVERIFIED against the DEPLOYED build, never the repository, and the
  pre-declared measurement plan is executed read-only. Returns an acceptance report plus a feedback
  pack that feeds the next requirements cycle. The owner decides acceptance; this verb prepares the
  evidence and never marks anything accepted. NOT for tests, CI, deploys, merges or code fixes; NOT
  for writing a handoff package (pm-requirements-v1); NOT for backlog scoring (pm-portfolio-v1).
argument-hint: "<spec-dir> --tier <dev|staging|prod> [--url <deployed url>] [--scope <ids>] [--stack <keys>]"
user-invocable: true
---

# pm-verify-release-v1, deployed build vs spec → acceptance evidence → feedback pack

Input is a shipped scope: the cycle's handoff package directory and the tier it is deployed on.
Output is a scenario-by-scenario verdict table with receipts, an acceptance report prepared **for**
the owner, and a feedback pack that makes the next cycle smarter.

**Completion is not acceptance.** This verb produces evidence. A named human owns the acceptance
decision. This skill **never marks anything accepted, never flips a gate, and never softens a verdict
to make a release look accepted.**

**Posture: read-only everywhere.** Behavioural probes look; analytics probes query; nothing is
written to any tier, flag, dashboard or repository. Where an engineering toolchain is configured, its
run records are **inputs only**, never authored, never edited, never re-minted.

## Preflight (run first)

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/preflight.sh" pm-verify-release-v1 [--stack <keys>]
```

A miss on a required capability blocks the run and prints its exact one-time fix. Conditional keys
are passed once the scenario scope is assembled: `analytics-verification` (any analytics-touch
scenario in scope) · `eng-handoff` (the downstream registry, for deployed coordinates) ·
`repo-state` (change-request state reads). A selected-conditional miss blocks exactly like a required
one, **never silently degrade into a partial verification that reads like a full one.**

**Standalone vs supercharged.** Standalone (`python3` only): every pre-declared scenario graded
against the deployed build via behavioural probes, plus the report and the feedback pack;
analytics-touch receipts ride NEEDS-CONFIRMATION rows instead of measured values, and say so.
Supercharged: `analytics-verification` executes the pre-declared measurement plan and compares
receipts against the declared thresholds; `eng-handoff` resolves deployed coordinates from the
registry instead of from an answer.

## Hard rules

1. **Grade only against what was pre-declared.** The spec directory's acceptance scenarios are the
   only rubric, and the handoff's machine-actionable success-metrics section is the only query set, **execute it, never re-derive its intent.** A receipt produced from a query nobody pre-declared is
   INFERRED at best, and must say so. If the spec's scenario is wrong, that is a finding about the
   spec, not licence to invent a better scenario mid-verification.
2. **The deployed build, not the repository.** Every verdict is stamped `tier + build`. Web and API
   coordinates come from the registry when configured, otherwise from an explicit `--url`. Mobile
   builds are resolved **live** at probe time, build numbers are counters, never pinned in a report
   drafted earlier. Repository state, diffs and green CI are facts about a repository; by themselves
   they prove nothing about a deployed tier.
3. **Never touch the building side's records.** Run records, gate conclusions and handoff ledgers are
   read-only inputs.
4. **Honesty over neatness.** UNVERIFIED is a first-class verdict, never force one. A red blocker
   stays red until its owner reports it unblocked. A feature behind a flag is graded on the tier where
   the flag is ON, and the production precondition is listed as a follow-up rather than scored as a
   GAP. Quote fidelity as recorded: *measured* outranks *inspected*.
5. **A missing input is a structured stop, not a guess.** Record which input is absent, tag the
   affected scenarios NEEDS-CONFIRMATION, and proceed with the verifiable remainder only.
6. **Analytics: aggregates and metadata only.** Never user-level exports or profiles. Name the
   environment explicitly on every read, **an unnamed project or property answers from whichever one
   is default, and that is the single most common source of a confidently wrong number.** Budget any
   quota-limited query: enumerate the calls you need before making the first one. No secret is ever
   read or echoed; the config holds pointers only.
7. **Reports are versioned, never overwritten.** The owner-edited copy becomes the new canonical base.
8. **No volume targets.** Queue movement is recorded as a measured fact, never as a quota.
9. **Artifacts land where the run said they land.** Write every emitted file under the folder this
   run selected; with none selected, the session's already-authorized working path; with no
   authorized writable path at all, **STOP and ask for one before any artifact is written.** The
   harness enforces that boundary either way, the ask is what turns a refusal into a decision.

## Inputs

| Input | Required | What it is |
|---|---|---|
| `spec-dir` | yes | the handoff package directory: acceptance scenarios with their classifications, the measurement plan, rollout and flag notes |
| tier | yes | `dev` / `staging` / `prod`, plus an explicit url or build when it is off-registry |
| run record | when configured | the building side's record for this scope, read-only, joined to scenarios via each scenario's Trace line |
| scope filter | no | a subset of scenario ids or surfaces for a partial pass |
| prior report | no | re-verification after fixes: grade the delta, and carry every prior UNVERIFIED forward **explicitly**, never silently inherit a PASS |

Arriving with just "verify the release" also works: elicit the three coordinates, then stop structured
if they cannot be named.

## Flow

```
1. ASSEMBLE  inputs + the measurement plan + flag preconditions
      │       any piece missing → structured stop (rule 5)
2. PROBE     behavioural: drive each scenario's flow on the deployed tier and build
      │       telemetry:   execute the pre-declared queries, read-only
3. GRADE     one verdict per scenario, with a cause class and per-criterion evidence locators
4. PACK      acceptance report vN + feedback-pack.md
5. PASS      internal quality passes, floor · artifact manifest · honesty audit
6. ACCEPT    the owner rules: ACCEPT / ACCEPT-WITH-EDITS / REJECT. Their decision, recorded.
```

Pack inheritance: take the pack id from the artifacts consumed and echo it at step 1. No pack signal
in the artifacts means generic mode, state that rather than guessing a pack.

### Grading

| Verdict | Means |
|---|---|
| **PASS** | every acceptance criterion observed on the deployed build; an analytics-touch scenario additionally returned the pre-declared signal inside its window |
| **PARTIAL** | the primary path works, and NAMED criteria are unmet, degraded or deferred, each named miss becomes a feedback item |
| **GAP** | not observable, failing, dark where it should be live, or uninstrumented, with a cause class: `build-gap` · `flag-gap` · `data-gap` · `spec-gap` |
| **UNVERIFIED** | could not be probed (a precondition, a flag, or access), carried explicitly, never forced into one of the above |

`spec-gap` routes to the spec, not to the builders: an ambiguous or wrong scenario is a spec-side
feedback item and a correction in the next cycle, never a defect ticket for somebody else.

### The two artifacts

1. **Acceptance report vN**, the tier and build stamp · an attention header (*ran clean* / *changed*
   / *needs judgment* / *stopped on a failed check* / *held: weak source*) · a TL;DR · the verdict
   split with the open-items queue before and after · the scenario results table (id · surface ·
   risk/money/analytics · verdict · evidence locator) · the executed receipts (tool · exact query ·
   window · result against threshold) · blockers with owners and unblock criteria · a
   self-assessment close · and **the acceptance block the owner fills in**, left empty by this verb,
   always.
2. **`feedback-pack.md`**, the next cycle's input, in four sections: **tag movements** (new FOUND
   evidence with live locators; `INFERRED → FOUND`, `→ rejected` as a typed entry,
   `NEEDS-CONFIRMATION → resolved | still open`, a shrinking open queue is the headline) ·
   **the PARTIAL/GAP register** (cause class and owning side; a discovered gap becomes a *candidate*
   for `/pm-portfolio-v1`, never an auto-inserted backlog row) · **gotchas harvested** (one-liners
   routed to the skill that owns them) · **gate health** (accepted unedited / edited / rejected).

### Internal passes before presenting

**Floor pass**, every verdict has an evidence locator; every receipt shows its query, window and
value; every PARTIAL and GAP names its criteria and its owning side; every claim is tagged and every
FOUND anchored (`scripts/tag-lint.sh`). **Artifact manifest**, the report and the feedback pack exist
on disk as promised. **Honesty audit**, no softened red, no forced verdict, and no coverage claim
that spans unprobed scenarios. No auto-retry on a failed pass: halt and surface.

### The human gate

Present the brief (green/amber/red · TL;DR · verdict split · risks with mitigations · "decisions
needed: options with a recommendation and a need-by date"; 200–300 words) over the scenario verdict
table. The owner, and only the owner, rules **ACCEPT / ACCEPT-WITH-EDITS (named) / REJECT (reason,
recorded as a typed constraint)**, and rules every open NEEDS-CONFIRMATION. Record the gate-health
field. Use the one-question convention for escalations; never fork a second thread.

**Feed-forward:** the accepted feedback pack is the first reading-list input of the next
`/pm-requirements-v1` P0. Its new FOUND evidence enters as `[L1]` citations with live locators, its
still-open items seed the next queue, and its gap candidates wait for portfolio scoring.

## Retro

Append what generalises to `<report-dir>/retro.md`; a run that learned nothing appends one dated line
saying exactly that. One line lands in the local event log when the operator enabled it
(`scripts/telemetry.sh emit`, silent no-op otherwise). Nothing leaves the machine.

## References

| File | Load when |
|---|---|
| `../pm-requirements-v1/references/evidence-tags.md` | tagging a finding · a tag dispute · the L-axis |
| `../pm-requirements-v1/references/handoff-package.md` | reading the spec kit and the measurement-plan format you are executing |
| `../../references/eng-handoff-adapter.md` | what the configured adapter does and does not make available |

## Gotchas

- **The default-environment trap** is the most common silent wrong answer: a query that does not name
  its project or property answers from whichever is default, and the number looks fine. Name it every
  time, and prefer a probe that resolves both environments from config over an ad-hoc read.
- **Verifying staging is legal; extrapolating from it is not.** Receipts are stamped with their tier
  and never generalise into production behaviour claims.
- **Green CI is not deployed behaviour.** It tells you where verification is possible; only the probe
  on the deployed tier produces a verdict.
- **Never pin a mobile build number** in a report drafted before probing. Re-resolve at probe time and
  stamp what was actually probed.
- **An empty production dataset is a data-gap explanation, not a PASS.** A metric that cannot yet
  exist has not been met.
- **Re-verification is a new report version graded on the delta.** A fixed GAP needs a fresh receipt,
  not a changelog line.
- **Budget quota-limited queries first.** Enumerate them, then spend them; running out halfway
  produces a partial pass that reads like a full one.
