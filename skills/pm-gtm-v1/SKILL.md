---
name: pm-gtm-v1
description: |
  Go-to-market and growth planning, GTM here means go-to-market, never a tag-manager container. Use
  when a growth plan needs building or refreshing: "build the go-to-market plan", "growth plan for
  <period or launch>", "campaign architecture", "channel plan", "media plan", "tracking planning
  rows", "update the growth plan after <release>". It resolves which plan document is actually
  current, takes a FRESH gate-state snapshot before planning a single sentence, builds the plan phase
  by phase, narrates the campaign architecture per channel and per persona, and emits channel and
  tracking rows CONFIG-ONLY, no credentials, no platform writes, no spend. NOT for executing
  campaigns or buying media; NOT for implementing tracking (that is engineering work, routed through
  pm-requirements-v1); NOT for writing a handoff package or scoring a backlog.
argument-hint: "<gtm goal / 'refresh the growth plan'> [--channels <list|propose>] [--budget-posture <direction-only|capped|none>] [--stack <keys>]"
user-invocable: true
---

# pm-gtm-v1, source of truth → fresh gate state → phase-gated plan → config-only rows

Input is a go-to-market goal: a launch, a period, a plan refresh. Output is a **plan package**: a
fresh gate-state snapshot, a plan built phase by phase, a campaign-architecture narrative, channel and
tracking **planning** rows, and a handoff record for the owner and whoever runs marketing operations.

**This verb plans. It never spends, never posts, never configures a platform, and never touches a
tag container.** Execution stays human; implementation stays engineering's.

**Seam discipline:** this verb emits no engineering seam artifacts. When technical work emerges from
planning, a pixel install, a container change, instrumentation, landing pages, it leaves as
**classified candidate rows** routed to `/pm-requirements-v1` (a single item) or `/pm-portfolio-v1` (a
batch). One seam, one owner.

## Preflight (run first)

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/preflight.sh" pm-gtm-v1 [--stack <keys>]
```

Conditional keys: `gate-state-snapshot` (the read-only analytics reads that let a gate state be
*measured* rather than asserted) · `workspace-docs` · `backlog-sync`. A selected-conditional miss
blocks like a required one.

**Standalone vs supercharged.** Standalone (`python3`): the full chain resolve, the phase-gated plan,
the campaign narrative and the config-only rows, with **every unprobeable gate state written
NEEDS-CONFIRMATION with a named confirmer, never guessed.** Supercharged: `gate-state-snapshot`
turns those rows into measured states.

**There is deliberately no advertising-platform capability.** Nothing here holds or requests ad-account
credentials, which is precisely why the rows in step 4 are configuration proposals rather than changes.

## Hard rules

1. **Resolve the source-of-truth chain first, and never plan from stale content.** Plan documents
   accumulate: an update note usually rides on top of an older attested canonical. **Start from the
   newest update document; use the canonical for constants and structure only.** Every gate state
   embedded in an older plan is frozen to the date that plan was written, treating those as current is
   the specific failure this verb exists to prevent.
2. **A fresh gate-state snapshot precedes the first planning sentence.** The snapshot is written and
   presented at gate 1, it is the ONLY gate-state source for the whole run, and **it expires when the
   run closes.** The next run re-snapshots; it never inherits.
3. **Budget language is posture-bound.** `direction-only` is the default and never invents a
   per-channel cap. `capped` uses only a number the owner named, entered as an `[L0]` constant. `none`
   means planning without spend. **Never convert direction into numbers**, and never treat a stated cap
   as a pool to allocate, per-spend approval survives every posture.
4. **The rows are config-only.** No credential file is read (pointers and names only), no platform API
   is called, no pixel, tag, container or campaign is created or edited, and nothing is verified against
   a live ad account. Every row carries `state: CONFIG-PLANNED` and, where it applies, what blocks it.
5. **No seam artifacts from this verb.** Emerging technical work becomes candidate rows pre-classified
   `risk_class` / `money_path` / `analytics_touch`, routed to the verb that owns the seam. **Go-to-market
   is not tag-manager work:** container changes are engineering, and the shared acronym must never pull
   them in here.
6. **Customer-facing claim safety.** Build the unsupportable-claims list at lock, one row per claim the
   business cannot substantiate, with a named reviewer per locale, and bind it to every headline and
   hero surface **from the first draft**, not just at the final audit. Planning rows and creative-brief
   pointers are customer-facing-adjacent surfaces.
7. **Honesty on gates.** A red gate stays red until its owner reports it unblocked. A gate that cannot
   be probed is NEEDS-CONFIRMATION with a named confirmer, never a guessed state, and never quietly
   softened at handoff.
8. **No volume targets.** No channel quotas, no row counts as goals. Deliverables are versioned
   forward, never overwritten; prior plan epochs are read-only `[L4]` archive.
9. **Artifacts land where the run said they land.** Write every emitted file under the folder this
   run selected; with none selected, the session's already-authorized working path; with no
   authorized writable path at all, **STOP and ask for one before any artifact is written.** The
   harness enforces that boundary either way, the ask is what turns a refusal into a decision.

## Inputs

| Input | Required | What it is |
|---|---|---|
| the goal | yes | the outcome the plan serves plus its period, stated with its metric link, how the goal moves the cycle's north-star or leading metric |
| channels in scope | yes | an explicit list, or `propose`. Every channel beyond the confirmed set is NEEDS-CONFIRMATION, not an assumption |
| budget posture | yes | `direction-only` (default) · `capped` (the owner names the number) · `none` |
| decision shape | yes | `solo` · `domains` · `squads`, decides who executes and which register the handoff uses |
| prior-plan pointer / pack | no | overrides where the chain starts; default is pack-resolved |
| scope filter | no | a subset of channels, personas or phases for a partial refresh |

## Flow

```
0. SNAPSHOT  resolve the chain, then take the FRESH gate-state snapshot
1. LOCK      the contract: goal + metric link · channels · posture · decision shape · pack ·
     │       plan version proposal · the unsupportable-claims list · the right-sized method stack
     ├─ GATE 1  contract echo + snapshot audit
2. BUILD     the plan, phase by phase: intro shell → research → strategy → rollout
3. NARRATE   the campaign architecture: per channel · per persona · gate-aware
4. ROWS      channel rows + tracking rows, CONFIG-ONLY
     ├─ GATE 2  plan + narrative + rows draft
5. PACKAGE   assemble + internal passes
6. HANDOFF   to the owner and marketing operations; technical work leaves as routed candidates
     ├─ GATE 3  finalisation: ADOPT / ADOPT-WITH-EDITS / PARK
7. RETRO     close-out
```

Three human gates; everything else is an internal pass. No auto-proceed, no auto-retry. A thin
refresh may *propose* folding gate 2 into gate 3 at gate 1, only an explicit yes folds it, and gates
never multiply silently in the other direction either.

### 0, snapshot

Resolve the chain (newest update document → attested canonical → `[L4]` archive), then probe every hard
gate, channel state and tracking asset by probe class:

- **M, measurable:** a read-only analytics read. Name the environment explicitly on every read, and
  budget quota-limited queries before spending the first one.
- **C, asset state from a dated scan:** cite the scan and its date. A live re-scan of a tag container
  is engineering work, not a self-serve probe.
- **O, operational or ruling gates:** elicited from the owner at gate 1 and recorded `[L0]`.

Output: `gate-state-snapshot.md`, one row per gate, the state the plan assumed · the state now · the
receipt · the verdict. **Unprobeable means NEEDS-CONFIRMATION.**

### 1, lock, and gate 1

Build the working set (never compiled into the deliverable): canonical constants including the budget
posture, the source-authority map holding the resolved chain, the unsupportable-claims list with its
named locale reviewers, and the private-information exclusions. Declare the audience, ranked. Lock the
contract paragraph and **propose the plan version, the owner confirms the number at gate 1.**

Right-size the method stack: open `../gtm-domain-library/SKILL.md` and take in only the frameworks this
plan actually needs, sharpening the customer profile until it excludes someone, the interview method,
the differentiation questions, launch anatomy, the value-metric pricing tree, the deal test, stage
metrics. It is a menu, not a mandate, and every exclusion carries a one-line reason.

**Gate 1 input:** the locked paragraph · the snapshot table · the right-sized stack with its drops ·
the claim manifest · a 200–300 word brief. The owner confirms the contract, rules the snapshot's open
items, and confirms the version.

### 2, build

The spine, right-sized at lock: a progressive intro shell built from the constants that fills at each
phase close and locks at gate 3 → research (competitive grounding through the locked stack) → strategy,
where **the pillars emerge from the completed chain and are never stated up front** → rollout.

Each phase carries the same kit: the shape skeleton · one anchored sample · named milestones · the
five-question stress test. Each phase runs the internal two-pass build-then-conflict cycle. Keep the
open-items register always; add an event-typed changelog and a sign-off ledger only for multi-day or
flagship builds.

### 3, narrate

The campaign architecture: the core posture carried from strategy → per-channel specifications, each
citing its market evidence → per-persona variants → creative-brief pointers → **gate-aware spend
posture**, its language bound verbatim to the snapshot states (a red gate's channel gets ramp
conditions, never spend) → campaign quality-assurance and operations notes → the acquisition-funnel
sequence per persona → a closing section: open items · what this plan is not · the handoff.

### 4, rows, and gate 2

Two row sets, both config-only:

- **Channel rows**, channel · objective · persona track · creative-brief pointer · tracking
  requirement · gate precondition · owner · state.
- **Tracking rows**, platform · asset · exists-today (per a dated scan, or NEEDS-CONFIRMATION) ·
  configuration target · verification method · `state: CONFIG-PLANNED` · what blocks it.

Grounding rules: analytics identifiers resolve from configuration, never retyped into a row; a row that
needs a container or code change is flagged `tech-work` and routed at step 6.

### 5, package and internal passes

Floor pass (every claim tagged and cited; every row complete; **every gate quote matches the snapshot
verbatim**) · conflict pass (constants, naming, timeline, gate-state drift) · artifact manifest ·
**claim-safety audit** over every customer-facing surface, with each partial named · honesty audit (no
softened red, no invented spend, no stale-state citation).

### 6, handoff, and gate 3

The handoff record: the package · the register the decision shape calls for (solo → an executive
register with per-spend approval hooks; squads → the full case with owner columns) · the routed
technical-candidate list, each row pre-classified and **never auto-inserted** into anybody's backlog ·
and the optional deck lane, on request only and only when the pack declares a design kit.

**Gate 3**, cross-document consistency · HYPOTHESIS strip · open-items closure with
`scripts/inference-gate.sh <package-dir>` exiting 0. Note the seam boundary here: that gate reads a
package directory this verb owns, which is fine, but **never mint a `design-gate.json` just to satisfy
a tool**, this verb does not emit one. Package integrity rests on the step-5 passes and the
never-overwrite discipline. The owner rules **ADOPT / ADOPT-WITH-EDITS / PARK** and confirms the routed
candidates.

## Retro

Append what generalises to `<package-dir>/retro.md`; a run that learned nothing appends one dated line
saying exactly that. One line to the local event log when the operator enabled it. Nothing leaves the
machine.

## References

| File | Load when |
|---|---|
| `../gtm-domain-library/SKILL.md` (+ its `references/`) | at lock, the framework menu this verb executes |
| `../pm-requirements-v1/references/evidence-tags.md` | tagging · the L-axis · the open-items lifecycle |
| `../../packs/README.md` | pack selection · whether a design kit exists for the deck lane |

## Gotchas

- **The acronym collision.** A request to "change GTM" that means the tag-manager container is
  engineering work. Route it. Never let the homonym drag container work into a planning verb.
- **The stale-canonical trap is the number-one failure mode.** An attested plan document stays the
  canonical *structure*, but every state it embeds is frozen to its own date. Cite it for structure and
  constants; never for a current gate, channel or baseline claim.
- **An update note is not an executed plan.** A document describing a rebuild that never ran is a
  working delta, not history. Re-confirm its status at gate 1 until the owner settles it.
- **Asset state is scan-dated.** The newest read-only scan is the ground truth; anything time-sensitive
  is NEEDS-CONFIRMATION or a routed re-scan, never "probably still true".
- **Hero copy leaks early.** Planning rows and creative-brief pointers are customer-facing-adjacent, so
  the claim-safety list binds from the first draft.
- **The first run has no history.** A missing learnings trail is expected on run one. Consult the
  framework library alone and seed the trail at close-out; never create a ledger at lock to make a
  consult step look satisfied.
