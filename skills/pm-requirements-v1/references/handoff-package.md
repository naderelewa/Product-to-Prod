# The handoff package, items, seam artifacts, and the seal

The package is the cycle's one deliverable: a directory a sceptical reviewer can verify in minutes,
and that an engineering toolchain can consume without a paste. Load this file when entering P4, when
assembling any seam artifact, and when sealing.

Two halves, and they answer different questions. **The record** answers *why should anyone believe
this?* **The seam kit** answers *what exactly gets built?* A package with a strong seam kit and a
weak record is a specification nobody can audit; the reverse is an essay.

```
<package-dir>/
  HANDOFF.md                  the record (the eight sections below)
  spec.md                     what is being built + the acceptance scenarios
  plan.md                     how it is sequenced
  data-model.md               entities, fields, states, constraints
  contracts/                  one file per interface contract
  slices.json                 the dependency graph of work units
  case-contract.md            locked constants · invariants · kill criteria · the seal numbers
  design-gate.json            the approval flag (approved:false until a human flips it) + the seal
  inference-confirmed.json    the recorded ruling on the open-items queue
  retro.md                    written at close-out, after the final gate
```

---

## Part 1, the record (`HANDOFF.md`)

1. **Seven-part task record**, requester · desired outcome · sources · acceptance criteria ·
   boundaries · the blocker rule · the receipt. The blocker rule is the one-question convention: one
   question per blocker, on the same thread, never a forked side conversation.
2. **Done receipt**, what changed · where the output is · what was checked · what still needs a
   human. Four lines, no adjectives.
3. **Assumptions and judgment-call log**, every ambiguous call, the decision taken, and the source
   that justified it. This is where a reader looks when they disagree with a conclusion.
4. **NEEDS-CONFIRMATION review queue**, each open item with its named confirmer, what it blocks, and
   the ONE question that closes it. The queue is what converts a sceptic: a document with no open
   questions is either trivial or dishonest.
5. **Considered and deprioritised, with reasons**, the filter is the value. What was cut, and why,
   in one line each.
6. **Self-assessment close**, strongest section · weakest section · the top assumptions with their
   risk-if-wrong and a proposed validation · the single recommended next step. Name the weakest
   section honestly; a reviewer who finds it before you named it discounts everything else.
7. **Citation map and evidence checklist**, generated from the P1 evidence ledger, with an
   exists/missing column, plus the explicit questions for the decision owner.
8. **Machine-actionable success metrics**, per metric: the tool · the exact query · the time window ·
   the evaluation dates (week 1 / month 1 / quarter 1) · the north-star link · the success and stretch
   thresholds. Write these so `pm-verify-release-v1` can EXECUTE them later without re-deriving
   intent. A measurement plan that says "monitor engagement" is not a plan.

---

## Part 2, the seam kit

### `spec.md`

Nine fields, scope, out of scope, users affected, the change in behaviour, data touched, interfaces
touched, risks, rollout notes, open items, followed by the **acceptance scenarios**.

An acceptance scenario is machine-checkable and phrased so that an independent observer can verify it
with **zero further questions**. One scenario per user-visible rule, covering both the success path
and the failure paths. Each carries: an id `<requirement-id>.<n>`, the classification
(`risk_class`, `money_path`, `analytics_touch`), and a Trace line naming its requirement and slice.

Whoever builds the work runs these red-to-green. Test identifiers, commit references, and fidelity
records are **theirs**, never author them here. Pre-declaring a test id you do not own is the
fastest way to make a handoff wrong on arrival.

### `plan.md`, `data-model.md`, `contracts/`

Sequencing, the entities and their constraints, and one file per interface contract. Keep contracts
in the form the receiving side actually reads; a contract nobody can diff is decoration.

### `slices.json`

The dependency graph skeleton: each slice is an independently shippable unit with its dependencies,
its affected surfaces, and, required, **the business invariant it must not break.**

Surfaces come from `${local:eng_plugin.surfaces_registry}` when the adapter is configured, and from
the run's own answers, marked *unverified against a registry*, when it is not. Never hardcode a
surface list into this skill or into a pack: one operator's architecture in everybody else's spec is
exactly the leak this package was extracted to stop.

### `case-contract.md`

The locked constants, the invariants, the kill criteria (what result would make you stop), and the
seal numbers duplicated for human reading.

### `design-gate.json`

Emitted as:

```json
{ "approved": false, "approver": "<named role or person>", "at": null,
  "spec": "spec.md", "note": "<what the approver is being asked to approve>",
  "seal": { "spec.md": "<sha256>", "…": "<sha256>" } }
```

`approved: false` is not a placeholder, it is the state. Only a human flips it, at the final gate,
after seeing the package. **No code path in this plugin writes `approved: true`**, and the seal is
written before the flip so that the approval covers the exact bytes that were reviewed.

---

## The seal (integrity, and why it is worth the two minutes)

The seal exists so that a package which drifted after approval cannot pass as the approved one. It
needs no service and no network: `shasum`, or `sha256sum` on a host that ships that one instead, is
a required capability of this verb precisely for this.

**Write it, at finalisation, after the last content edit, before the final gate:**

```bash
cd <package-dir>
for f in HANDOFF.md spec.md plan.md data-model.md slices.json case-contract.md contracts/*; do
  [ -f "$f" ] && shasum -a 256 "$f"   # sha256sum "$f" on a host without shasum
done > .seal.txt
```

Then write those pairs into `design-gate.json`'s `seal` block and copy them into `case-contract.md`
under a *seal numbers* heading. Two rules: **never hand-compute a hash**, and **never re-seal a
package whose `approved` flag is already true**, re-sealing an approved package silently replaces
what was approved. A changed package after approval is a new micro-version, sealed fresh.

**Verify it, any time, including long after shipping:**

```bash
cd <package-dir> && shasum -a 256 -c .seal.txt   # sha256sum -c .seal.txt on a host without shasum
```

Any mismatch is a **critical stop**: the copy in hand is not the copy that was approved. Do not ship
it, do not diff it into shape, and do not "fix" the hash. Find out which copy is real.

---

## Assembly order (the part that goes wrong when improvised)

1. Seam preflight, the contract check, when configured. A failure stops here, before any artifact
   is drafted.
2. Draft the seam kit from the locked P3 spec. Classifications and the traceability triple travel
   with each item; nothing is re-derived at this stage.
3. Assemble the record. The citation map is generated from the evidence ledger, never retyped.
4. Internal floor pass: every claim tagged and every FOUND anchored (`scripts/tag-lint.sh`, and
   `--delivery-final` on the delivered body) · every promised artifact exists on disk · every scenario
   independently verifiable · every metric row executable as written.
5. Conflict pass: constants, naming, numbers and timelines consistent across every file.
6. HYPOTHESIS strip. Its only legal residues are the assumptions log and the open-items queue.
7. Open-items closure: `scripts/inference-gate.sh <package-dir>` must exit 0.
8. Seal. Then present at the final gate.
9. On approval: the owner flips the flag. Standalone mode stops here and prints the package path;
   configured mode copies the directory to `${local:eng_plugin.handoff_dir}`.

## Standalone mode

With no engineering adapter configured, every artifact above is still produced, and the seam kit is
marked **FIXTURE, no downstream configured** in `HANDOFF.md` and in `case-contract.md`. The design
gate is still written `approved: false` and the seal is still computed.

This is deliberate. The seam kit is a thinking tool before it is a delivery format: writing the
slice graph is what exposes the invariant nobody had named, and writing acceptance scenarios is what
exposes the rule nobody had decided. What standalone mode must never do is claim a handoff happened.
A package that says "handed off" when nothing received it is the one failure mode this whole record
exists to prevent.

## The deck lane (optional, on request only)

A `deck-brief/` directory is produced only when it is asked for, and only when the selected pack
declares a design kit (`deck_kit.status: locked`). A pack with `owner-queued` means a kit exists but
is unruled: **refuse the deck and name the pointer** rather than improvise styling. A pack with
`none` means the lane is unavailable. Generic styling is never substituted for a visual identity, an off-brand deck costs more to unwind than no deck.
