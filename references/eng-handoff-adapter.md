# The engineering-handoff adapter (optional)

This plugin produces product artifacts. Whether those artifacts are then **picked up by an
engineering toolchain** is a local configuration question, not a built-in assumption. The adapter
described here is the only seam between the two, it is off by default, and everything the plugin
does works without it.

## The two modes

| | `eng_plugin.name` unset (**default**) | `eng_plugin.name` set |
|---|---|---|
| Requirements cycle | runs in full: research, strategy, spec, package | runs in full |
| Seam artifacts (`spec.md`, `plan.md`, `data-model.md`, `contracts/`, `slices.json`, `design-gate.json`) | still written, marked **FIXTURE, no downstream configured** | written for real and handed off |
| Surface names | come from the run's own answers, marked *unverified against a registry* | read from `eng_plugin.surfaces_registry` as read-only ground truth |
| Contract-drift check | recorded as *no seam verification available*, never a silent pass | `eng_plugin.seam_check_cmd` runs; non-zero stops the handoff |
| Where the package lands | stays where the run wrote it; the path is printed for a human to move | copied to `eng_plugin.handoff_dir` |
| Release verification | grades scenarios against the deployed build using probes the run can reach | may additionally read the toolchain's own run records |

**Standalone is a first-class mode, not a degraded one.** The requirements cycle's value, locked
constants, a tagged evidence ledger, a classified spec, pre-declared acceptance scenarios, is
entirely produced here. What standalone mode does not do is pretend a downstream exists: a wizard
that says "handed off to engineering" when nothing received it is the exact dishonesty this plugin's
gates exist to prevent.

## The four keys

All four live in `config/local.json` (copied from `config/local.template.json`, gitignored, never
shipped with values). Any unset key is a **named miss**: the affected step says which key is unset
and what filling it would unlock, then continues on what it can prove.

```
eng_plugin.name              a label, e.g. "our build toolchain". Presence of THIS key is what
                             switches handoff mode on. Nothing else does.
eng_plugin.surfaces_registry path to the toolchain's surface/repo registry, READ-ONLY. The engine
                             reads surface names and repositories from it and never writes it.
eng_plugin.seam_check_cmd    a command that verifies the contract versions still match.
                             Exit 0 = proceed. Any other exit = stop the handoff and show the output.
eng_plugin.handoff_dir       the directory the toolchain collects packages from.
```

## Rules the adapter never bends

1. **One direction only.** This plugin reads the downstream registry and writes into the handoff
   directory. It never edits the downstream toolchain's files, records, tickets, or configuration, not its run records, not its gate files, not its ledgers. Those are inputs.
2. **The approval flag is a human's.** `design-gate.json` is emitted with `approved: false`, always.
   Only the named approver flips it, at the final gate, after seeing the package. No code path in
   this plugin writes `approved: true`.
3. **Surfaces are never hardcoded.** With a registry configured, surface names come from it. Without
   one, they come from the run's answers and are labelled unverified. A surface list baked into a
   skill file is one operator's architecture leaking into everybody else's run.
4. **A missing seam check is recorded, not assumed.** No `seam_check_cmd` means the handoff record
   says drift could not be checked. That is honest. Treating absence as a pass is how a contract
   mismatch reaches a build.
5. **The adapter carries no credentials.** Every key is a path, a label, or a command. Nothing here
   reads a secret, and nothing echoes one.

## For the verbs

- `pm-requirements-v1`, reads this at the handoff phase. Standalone: emit the seam artifacts
  FIXTURE-marked, print the package path, stop. Configured: run the seam check first, then hand off.
- `pm-verify-release-v1`, the deployed build is the subject either way. The adapter only decides
  whether the toolchain's own records are also available as inputs.
- `pm-portfolio-v1`, `pm-gtm-v1`, never touch the seam. Work that needs engineering leaves them as
  classified candidate rows routed to `pm-requirements-v1`, which owns the single seam.

A pack may also declare `seam: {target: "none"}`, which forces standalone for runs under that pack
even when the local keys are set, a fictional or exemplar company has no real downstream, and
`packs/template-streaming/pack.json` ships that way on purpose.
