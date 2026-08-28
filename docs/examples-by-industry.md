[Back to the README](../README.md) · every example run, at four sizes, across five industries.

# Example scenarios by industry

Every example below uses the dummy form **[Put Your Company Name]** in place of a real one, and every excerpt is **reconstructed**: the flows are battle-tested on real production companies, those runs stay private, so what lands here carries placeholders where client specifics were. Numbers inside excerpts are there to show the arithmetic, not to be borrowed, and ids, file names and locators are placeholders for yours. One engagement built with this method is public end to end: [Netflix Engagement Intelligence](https://naderelewa.com/HS_Case).

**The sizing vocabulary**

| Size | What it is | Usual route | Usual result |
|---|---|---|---|
| **Small** | one feature PRD, or one pricing question | `/pm-start` | a short answer plus tagged rows, or one small package |
| **Medium** | a release's requirements plus its handoff | `/pm-requirements-v1` | one package directory, three human gates |
| **Large** | a 50+ item backlog scored into a roadmap | `/pm-portfolio-v1` | verdict, request-form table, sprint or quarter recommendation |
| **XLarge** | the full cycle: strategy lock, requirements, handoff, post-release verification, go-to-market plan | `/pm-start`, then three verbs in order | three packages, each feeding the next |

One honest note on Large. The intake can be 50+ items, but scoring is capped at ten to fifteen candidates per recommendation: more than that means the intake was not filtered, so the batch is split or part of it is deferred, and the split is stated rather than hidden.

<details>
<summary><b>Marketplace</b> · [Put Your Company Name], a two-sided marketplace</summary>

#### Small · one pricing question

**You type**

```text
/pm-start "should [Put Your Company Name] charge sellers a listing fee or a take rate?"
```

**What lands.** No files, unless you ask for them. `/pm-start` locks the context and sees a pricing decision; the verb it routes to opens one section of the framework library (`skills/gtm-domain-library/references/pricing-value-metric.md`) and answers with the value-metric tree plus the rows it cannot fill from your own instrumentation. The library never supplies your numbers.

**Reconstructed excerpt**

```text
Value metric candidates, ranked
1. per completed order      [INFERRED: scales with the value the seller receives]
2. per active listing       [CONSTRUCTED: easier to bill, weaker link to value]
Your take-rate elasticity   [NEEDS-CONFIRMATION → pricing owner: blocks the free-line decision]
Market benchmark            [HYPOTHESIS: no durable market source found]
```

#### Medium · a release's requirements and handoff

**You type**

```text
/pm-start "requirements for saved payment methods at checkout, next release"
→ routed: /pm-requirements-v1 "cut checkout drop-off for returning buyers"
          --release <target> --surfaces web,api
```

**What lands.** One package directory: `HANDOFF.md`, `spec.md`, `plan.md`, `data-model.md`, `contracts/`, `slices.json`, `case-contract.md`, `design-gate.json`, `inference-confirmed.json`, `retro.md`.

**Reconstructed excerpt** (from `spec.md`)

```text
### REQ-3.2  A returning buyer sees a saved card at checkout
risk_class: RED · money_path: true · analytics_touch: true
Given a buyer with one saved card
When they reach the payment step
Then the saved card is offered and no card number is re-entered
Trace: REQ-3 → REQ-3.2 → SLICE-2
Success threshold [NEEDS-CONFIRMATION → product owner: blocks the measurement plan]
```

#### Large · a seller backlog scored

**You type**

```text
/pm-portfolio-v1 seller-backlog.md --quarter <label>
```

**What lands.** Verdict document, verdict JSON, request-form table, `retro.md`. A spreadsheet only if your pack declares a workbook form.

**Reconstructed excerpt** (from the request-form table)

<!-- illustrative only · tag-lint:allow-multi start -->

| id | Ask (verbatim gist) | Type | Lens split | R / I / C / E | RICE | Band |
|---|---|---|---|---|---|---|
| REQ-04-07 | "sellers cannot edit a listing after the first order" | fix | product: trust-breaking · strategy: blocks supply retention | 8 [FOUND: intake-notes.md §supply] / 3 [INFERRED: support volume] / 0.8 / 2 [CONSTRUCTED] | 9.6 | P0 |
| REQ-04-19 | "add a seller community feed" | feature | product: new surface · strategy: adjacent, unvalidated | 4 [HYPOTHESIS] / 2 [HYPOTHESIS] / 0.5 / 5 [CONSTRUCTED] | 0.8 | P3 + STRATEGIC-BET |
<!-- tag-lint:allow-multi end -->

The second row is the point: the score says P3 and the strategy lens says adjacent-and-interesting. Both are shown, nothing is averaged, and a human decides.

#### XLarge · the full cycle

**You type**

```text
/pm-start "plan and ship the seller subscription for [Put Your Company Name]"
/pm-requirements-v1 "<the locked strategy statement>" --release <target> --surfaces web,api
/pm-verify-release-v1 <package-dir> --tier staging
/pm-gtm-v1 "launch the seller subscription" --channels propose --budget-posture direction-only
```

**What lands.** Three packages in order, each feeding the next: the handoff package, then the acceptance report with its `feedback-pack.md`, then the plan package with its own fresh gate-state snapshot. The feedback pack becomes the first reading-list input of the next requirements cycle.
</details>

<details>
<summary><b>FoodTech</b> · [Put Your Company Name], food ordering and delivery</summary>

#### Small · one feature PRD

**You type**

```text
/pm-start "one-tap reorder of last week's basket for [Put Your Company Name]"
```

**What lands.** A single-feature package, right-sized: the same artifact set, with the drops recorded. Every exclusion goes in an explicit drops-with-rationale section, because the filter is the value.

**Reconstructed excerpt** (from `HANDOFF.md`)

```text
Done receipt
what changed   : one feature specified, one scenario per user-visible rule
where it is    : <package-dir>
what we checked: tags linted clean, open items ruled, package sealed
what needs you : the delivery-window assumption below
Assumption     [HYPOTHESIS] a repeat basket is still available at the same store
```

#### Medium · a release's requirements and handoff

**You type**

```text
/pm-requirements-v1 "make delivery windows honest at the point of order"
    --release <target> --surfaces ios,android,api --stack repo-state
```

**What lands.** The full package. With `--stack repo-state` selected, repository and change-request state can ground claims about what actually shipped; without it, those claims ride open-question rows and say so.

**Reconstructed excerpt** (from the success-metrics section of `HANDOFF.md`)

```text
metric        : share of orders whose delivered time falls inside the quoted window
tool          : <your product-analytics capability>
exact query   : <the pre-declared query, environment named explicitly>
window        : week 1 · month 1 · quarter 1
threshold     : success <value> · stretch <value>   [NEEDS-CONFIRMATION → owner: blocks verification]
```

That section is written so the verification verb can execute it later without re-deriving intent. "Monitor engagement" is not a plan.

#### Large · an operations backlog scored

**You type**

```text
/pm-portfolio-v1 ops-and-rider-backlog.md --quarter <label> --stack backlog-sync
```

**What lands.** Verdict document, verdict JSON, request-form table, `retro.md`. With `backlog-sync` connected the intake is cross-checked against your tracker's item types, read-only.

**Reconstructed excerpt** (the cross-check, honestly)

```text
matched   : <n> rows  (match_method: title · match_confidence: high)
UNMAPPED  : <n> rows  left unmatched on purpose; the id ranges do not intersect
note      : a forced join here would read exactly like "no issues found"
```

**XLarge, the full cycle.** The cycle reads as in the Marketplace example. Specific here: with `--budget-posture capped`, only a number you named enters the plan as a locked constant, and a stated cap is never treated as a pool to allocate: per-spend approval survives every posture.
</details>

<details>
<summary><b>EdTech</b> · [Put Your Company Name], a homework practice app</summary>

#### Small · one feature PRD

**You type**

```text
/pm-start "practice reminders for [Put Your Company Name]"
```

**What lands.** A single-feature package. Learners sit in the category the framework library flags as raising the trust bar above the convenience bar, alongside money movement, health, children and identity, so reliability and honesty about limits are positioning rather than compliance overhead.

**Reconstructed excerpt** (from `spec.md`)

```text
### REQ-1.4  A reminder never fires for a learner whose record was deleted
risk_class: AMBER · money_path: false · analytics_touch: true
Given a deleted learner record
When the reminder job runs
Then no notification is produced and the schedule row is closed
Trace: REQ-1 → REQ-1.4 → SLICE-1
```

Failure paths get their own scenarios. One scenario per user-visible rule, success path and failure paths both.

#### Medium · a release's requirements and handoff

**You type**

```text
/pm-requirements-v1 "make the progress report worth opening weekly"
    --release <target> --surfaces ios,android --stack design-extraction
```

**What lands.** The full package. `design-extraction` adds design-kit parity reads; without it, design claims are open-question rows rather than measured ones.

**Reconstructed excerpt** (from `slices.json`)

```text
SLICE-2  weekly progress digest
  depends_on : SLICE-1
  surfaces   : ios, android          (unverified against a registry: standalone mode)
  invariant  : a digest never contains a record the owner has since deleted
```

The invariant is required on every slice. Writing the slice graph is what exposes the invariant nobody had named.

#### Large · a post-beta backlog scored

**You type**

```text
/pm-portfolio-v1 beta-feedback-backlog.md --quarter <label>
```

**What lands.** Verdict document, verdict JSON, request-form table, `retro.md`.

**Reconstructed excerpt** (the confidence rule doing its job)

<!-- illustrative only · tag-lint:allow-multi start -->

| id | Ask (verbatim gist) | R / I / C / E | RICE | Band |
|---|---|---|---|---|
| REQ-07-02 | "the app forgets which learner I selected" | 9 [CALCULATED: session share, chain shown] / 3 [INFERRED: benchmark] / 0.8 / 3 | 7.2 | P0 |
| REQ-07-15 | "add a tutor video call" | 4 [HYPOTHESIS] / 2 [HYPOTHESIS] / 0.5 / 5 [CONSTRUCTED] | 0.8 | P3 |
<!-- tag-lint:allow-multi end -->

Confidence comes from the evidence, not from enthusiasm: read this cycle scores 1.0, reasoned scores 0.8, synthesised or speculative scores 0.5, and any open question on a dimension caps that item at 0.2 until it is ruled.

**XLarge, the full cycle.** As in the Marketplace example. Specific here: verification is graded against the deployed build on the named tier, never against the repository, and the report is stamped with the tier and the build it actually probed.
</details>

<details>
<summary><b>FinTech</b> · [Put Your Company Name], consumer payments</summary>

#### Small · one pricing question

**You type**

```text
/pm-start "where should the free line sit for [Put Your Company Name]?"
```

**What lands.** No files unless you ask. The pricing framework, the value-metric tree, and a visible gap where a market benchmark would be if a durable source existed.

**Reconstructed excerpt**

```text
Free line candidates
1. free below a monthly transfer volume   [INFERRED: the value metric is volume]
2. free for the first month               [CONSTRUCTED: time-boxed, weak link to value]
Free-to-paid conversion benchmark         [HYPOTHESIS: no durable market source found]
Your own conversion                       [NEEDS-CONFIRMATION → owner: comes from your instrumentation]
```

Visibly empty beats quietly invented. A reader who sees the gap can go and close it; a reader who sees a confident wrong number cannot.

#### Medium · a release's requirements and handoff

**You type**

```text
/pm-requirements-v1 "give people spending limits they can trust"
    --release <target> --surfaces web,api --stack analytics-verification
```

**What lands.** The full package. Money-path items classify `money_path: true` and usually `risk_class: RED`, which changes what the gates ask for rather than what the document says.

**Reconstructed excerpt** (from `case-contract.md`)

```text
Invariant     : a limit change never applies retroactively to a settled transaction
Kill criteria : if limit changes cannot be made reversible within the release, stop
Seal          : sha256 over the sealed set the seal loop enumerates (HANDOFF.md, spec.md,
                plan.md, data-model.md, slices.json, case-contract.md, contracts/*), written
                before the approval flip
Approval      : design-gate.json ships approved:false; only a human flips it
```

The seal is written before the flip so that the approval covers the exact bytes that were reviewed.

#### Large · a compliance and product backlog scored

**You type**

```text
/pm-portfolio-v1 q-backlog.md --quarter <label> --stack workspace-docs
```

**What lands.** Verdict document, verdict JSON, request-form table, `retro.md`.

**Reconstructed excerpt** (the structured stop)

```text
REQ-09-24  "make onboarding faster"
  status : NEEDS-CONFIRMATION → product owner
  why    : two valid framings (fewer steps vs fewer documents) score differently
  blocks : the band, and therefore the sprint recommendation
```

A confidently scored misunderstanding is worse than an unscored row, so the run stops in a structured way rather than guessing the frame.

**XLarge, the full cycle.** As in the Marketplace example. Specific here: every analytics read names its environment explicitly, because an unnamed project answers from whichever one is default, and that is the single most common source of a confidently wrong number.
</details>

<details>
<summary><b>AI</b> · [Put Your Company Name], an AI feature inside an existing product</summary>

#### Small · one feature PRD

**You type**

```text
/pm-start "an assistant answer that cites its sources, for [Put Your Company Name]"
```

**What lands.** A single-feature package, plus one differentiation question the framework library will insist on asking.

**Reconstructed excerpt**

```text
Headline test: delete the technology word from the pitch.
  with it    : "AI-powered answers for your account"
  without it : "answers about your account, with the source shown"   ← still says what and for whom
Position on the problem. The capability is the how, never the headline.
```

#### Medium · a release's requirements and handoff

**You type**

```text
/pm-requirements-v1 "ship the assistant behind a flag, with citations on every answer"
    --release <target> --surfaces web,api
```

**What lands.** The full package. An analytics-touch item implies an instrumentation receipt in the definition of done on the building side, which is recorded here and executed there.

**Reconstructed excerpt** (from `spec.md`)

```text
### REQ-2.1  Every answer shows at least one reopenable source
risk_class: AMBER · money_path: false · analytics_touch: true
Given a question the assistant can answer
When the answer renders
Then each claim carries a source the user can open
Trace: REQ-2 → REQ-2.1 → SLICE-3
### REQ-2.2  An answer with no source is not shown
(the failure path gets its own scenario, always)
```

#### Large · an AI backlog scored

**You type**

```text
/pm-portfolio-v1 ai-backlog.md --quarter <label>
```

**What lands.** Verdict document, verdict JSON, request-form table, `retro.md`.

**Reconstructed excerpt** (the differentiation question surfacing inside a score)

```text
REQ-11-06  "add a chat assistant to the home screen"
  strategy lens : anyone can rent the same capability tomorrow
  question      : why do we win when the model is a commodity?
  status        : STRATEGIC-BET · argued in prose, ranked by a human, not by the score
```

**XLarge, the full cycle.** As in the Marketplace example. Specific here: the go-to-market plan opens the differentiation and launch-anatomy sections of the library, and any technical work it turns up leaves as classified candidate rows routed back to the requirements verb, never auto-inserted into anybody's backlog.
</details>
