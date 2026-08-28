[Back to the README](../README.md) · what each of the four verbs leaves on disk.

# Outputs available

What a run actually leaves on disk, per verb.

<details open>
<summary><b>/pm-requirements-v1</b> · the handoff package</summary>

Two halves in one directory. The record answers *why should anyone believe this?* The seam kit answers *what exactly gets built?*

| Artifact | What it is |
|---|---|
| `HANDOFF.md` | the record: seven-part task record, done receipt, assumptions and judgment-call log, the open-questions queue with named confirmers, considered-and-deprioritised with reasons, a self-assessment close, the citation map, and a machine-actionable success-metrics section (tool, exact query, window, evaluation dates, thresholds) |
| `spec.md` | scope, out of scope, users affected, behaviour change, data touched, interfaces touched, risks, rollout notes, open items, then the acceptance scenarios |
| `plan.md` | how the work is sequenced |
| `data-model.md` | entities, fields, states, constraints |
| `contracts/` | one file per interface contract |
| `slices.json` | the dependency graph of independently shippable units, each carrying the business invariant it must not break |
| `case-contract.md` | locked constants, invariants, kill criteria, and the seal numbers in human-readable form |
| `design-gate.json` | the approval flag, always emitted `approved: false`, plus the integrity seal |
| `inference-confirmed.json` | the recorded ruling on the open-items queue |
| `retro.md` | written at close-out, after the final gate |

Phase outputs (`p1_research_base.md`, `p2_strategy_rationale.md`, `p3_product_spec.md`) are canonical too: if context is lost, the run re-grounds from those files rather than from the conversation.

The **machine-checkable engineering handoff is optional**. With no adapter configured the seam kit is still written, marked as a fixture with no downstream configured, and the package path is printed for a human to move. That is standalone mode, and it is a first-class mode: writing the slice graph is what exposes the invariant nobody had named.
</details>

<details>
<summary><b>/pm-portfolio-v1</b> · the batch verdict</summary>

| Artifact | What it is |
|---|---|
| verdict document | the batch verdict, the sprint or quarter recommendation, and the primary recommendation with the reason the two obvious alternatives lost |
| verdict JSON | the same verdict, machine-readable |
| request-form table | one row per independently decidable ask, with its own stable id, its verbatim gist, both lens scores, evidence-labelled RICE, band and classification |
| `retro.md` | what generalises from the run; a run that learned nothing writes one dated line saying exactly that |

**On the workbook, honestly.** A spreadsheet is emitted only when the selected pack declares a `workbook_form`. When a pack declares none, including the shipped template pack, the verdict table *is* the deliverable and no spreadsheet is produced. A workbook schema is one organisation's column order, and inventing one for somebody else is worse than handing them a table they can shape themselves.
</details>

<details>
<summary><b>/pm-verify-release-v1</b> · the acceptance evidence</summary>

| Artifact | What it is |
|---|---|
| acceptance report vN | tier and build stamp, attention header, TL;DR, the verdict split with the open-items queue before and after, the scenario results table, the executed receipts (tool, exact query, window, result against threshold), blockers with owners and unblock criteria, and the acceptance block the owner fills in, left empty by this verb, always |
| `feedback-pack.md` | four sections: tag movements, the PARTIAL and GAP register with cause classes, gotchas harvested, gate health. This is the first reading-list input of the next requirements cycle |
| `retro.md` | as above |

Verdicts are `PASS`, `PARTIAL`, `GAP` or `UNVERIFIED`. UNVERIFIED is first class and is never forced into one of the others. Reports are versioned, never overwritten.
</details>

<details>
<summary><b>/pm-gtm-v1</b> · the plan package</summary>

| Artifact | What it is |
|---|---|
| `gate-state-snapshot.md` | one row per gate: the state the plan assumed, the state now, the receipt, the verdict. Taken fresh before the first planning sentence, and it expires when the run closes |
| the plan | built phase by phase: intro shell, research, strategy, rollout |
| campaign architecture | per channel, per persona, gate-aware, with creative-brief pointers |
| channel rows | channel, objective, persona track, creative-brief pointer, tracking requirement, gate precondition, owner, state |
| tracking rows | platform, asset, exists-today, configuration target, verification method, `state: CONFIG-PLANNED`, and what blocks it |
| handoff record | the package plus the register the decision shape calls for, and the routed technical-candidate list |
| `retro.md` | as above |

Every row is a configuration proposal. This verb never spends, never posts, never configures a platform and never touches a tag container. There is deliberately no advertising-platform capability anywhere in the package, which is precisely why the rows are proposals.
</details>
