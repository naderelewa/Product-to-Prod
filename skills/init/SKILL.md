---
name: init
description: |
  Set up this plugin on this machine, the one-time, gated setup for the only thing here that
  writes anything outside your project (an optional local event log), plus the one optional
  integration this plugin can be connected to (read-only issue-tracker reads). Use when the user
  says "set up the plugin", "run the setup", "turn on the usage log", "is telemetry on?", "what
  does this record about me?", "stop logging", "delete the log", "remove the config", "connect my
  issue tracker", "connect Jira", "hook this up to our backlog", or has just installed the plugin.
  Also handles --verify (re-prove everything, ask nothing) and --uninstall (remove the log and the
  config, dry-run first). It asks in plain words, walks 5 numbered telemetry gates plus 1 numbered
  integration offer, verifies each one by running a real command and quoting its real output,
  defaults every answer to NO, and ends with a proof report that says what is on, what is off, and
  what it could not verify.
argument-hint: "[--verify | --uninstall | nothing]"
user-invocable: true
---

# init, the consent gate, the receipts, and the removal path

You are the INSTALLER. You ask, you verify, you record. **Three hard rules:**

1. **Never assert a gate passed. Run its command and quote the real output.** A gate with no
   receipt is a FAIL, not a pass.
2. **Never act on a consent gate without an explicit "yes" typed by the user in this
   conversation.** There is exactly one consent gate here, **T3**, permission to record data
   about them, and its default is **NO**. Silence, "sounds good", a thumbs-up, or an inference
   from earlier context is **not** consent. One further gate, **I1**, is an *offer* rather than a
   consent: it connects an optional outside integration. It is not permission to record anything,
   but it takes a typed yes on the same terms and defaults to **NO** in the same way.
3. **Fail loudly, never silently.** A gate that could not run is printed as FAILED or SKIPPED with
   its reason. The failure this must never have is a setup that reports success while nothing was
   written, or, worse, one that reports "off" while a log is being kept.

`$ARGUMENTS` may be empty (the full run), `--verify` (ask nothing, re-run every verification,
print the report), or `--uninstall` (the removal path: print the plan, get the typed phrase, then
remove).

**What this skill is NOT.** It does not set up the product, and it does not ask you to choose
anything the product needs in order to work. Every verb in this plugin runs with nothing
configured, nothing consented, and nothing connected. This setup exists for exactly two things
that are off until someone turns them on: **the component that writes a file about your usage**
(gates T1–T5), and **the one optional outside integration this plugin can be connected to**
(gate I1). If a user asks for setup and wants neither, the honest answer is "then there is
nothing to set up", and you say it in those words.

---

## The numbers, derived, never typed

**6 labelled gates in two series: `T1 · T2 · T3 · T4 · T5` and `I1`.**

- **T, the local event log**, 5 gates. By class: `HARD 2 (T1, T2) + CONSENT 1 (T3) +
  RECEIPT 1 (T4) + INFO 1 (T5) = 5`.
- **I, optional integrations**, 1 gate. By class: `ELICIT 1 (I1) = 1`.
- Total: `T 5 + I 1 = 6`.

The two series are kept apart on purpose, and the reason is not tidiness: T3 asks permission to
**record something about the user**, while I1 offers to **connect something to the outside**.
Collapsing them into one list would make the second look like the first, and a user skimming a
consent list is entitled to know which question is which.

Recount from the lists above whenever this file changes; **never carry a previous version's number
forward.** Two totals computed from two different readings of the same list must agree, and if
they ever do not, the fix is to recount both, not to edit a number until they match.

---

## One root, one namespace, one writer

- **The plugin root** is `$PKG_ROOT`. In Claude Code the harness sets `CLAUDE_PLUGIN_ROOT` and
  every block below reads it. **In any other harness, set `PKG_ROOT` yourself, once, to this
  package's root directory, the one that holds `.claude-plugin/plugin.json`**, then the blocks
  below run unchanged.
- **The config** is machine-local, outside this plugin, and never committed anywhere. Its location
  is resolved, in this order, from the environment: `PKG_CONFIG`, else
  `$XDG_CONFIG_HOME/product2prod/config.json`, else `$HOME/.config/product2prod/config.json`.
- **The log** lives in a directory resolved from `PKG_DATA_DIR`, else
  `$XDG_STATE_HOME/product2prod`, else
  `$HOME/.local/state/product2prod`, and once consent is given, **the directory that was used is
  recorded in the config**, which is what makes it removable by rule later.
- **`scripts/telemetry.sh` is the only writer of the log, the only writer of these config keys,
  and the only remover of either.** You call it; you do not hand-roll a `rm`, an edit, or a JSON
  write of your own. Two implementations of "remove the log" drift, and the one that drifts is the
  one that deletes something.

**Every block below re-derives `$PKG_ROOT` on its own first line.** Shell state does not survive
between tool calls, so a block that inherited it from an earlier one would run `bash /scripts/...`
and report a missing writer one line after another block proved it was there.

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/scripts/telemetry.sh" ] \
  && echo "root: $PKG_ROOT" \
  || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding"; \
       echo "      .claude-plugin/plugin.json, then re-run."; \
       echo "      Recovery: a skills-only copy has no such root to point the package root at, so"; \
       echo "      move to install option 3, which runs from the whole package on disk."; }
```

---

## PART 1, THE ASK (plain words, no jargon)

There are **two** questions, T3 and I1, and they are asked at different moments, not as a
questionnaire up front. Say what this is in two sentences, then ask the first:

> *"This plugin can keep a small log of what it did, one line per event, on this machine. It is
> off right now, and everything works with it off. Want it on?"*

Then run the gates in order. T1 and T2 come first because there is no point offering something
that cannot work. **I1 is asked last**, after the log question is settled, because it is a
different kind of question and running them together invites one answer to cover both.

**Both default to NO, and NO is a complete answer to either.** Nothing in this plugin works less
well for a user who declines both; say so once, plainly, rather than implying a fuller setup
exists somewhere.

---

## PART 2, THE GATES (5, in dependency order)

A **HARD** gate that fails **stops the run**, nothing after it can produce a real receipt.

### T1 · a usable interpreter, and the writer on disk · HARD

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
command -v python3 >/dev/null 2>&1 && python3 -V || echo "NO-PYTHON3-ON-PATH"
[ -r "$PKG_ROOT/scripts/telemetry.sh" ] && echo "writer: readable" || echo "writer: MISSING"
bash -n "$PKG_ROOT/scripts/telemetry.sh" && echo "writer: parses"
```

PASS iff a `3.x` version prints **and** the writer is readable **and** it parses. On
`NO-PYTHON3-ON-PATH`, stop and say it plainly: *"The log needs a Python 3 on your PATH. Without
it, nothing here can record anything, which is a working configuration, just not the one you
asked for."* Offer no workaround, and **do not** offer to install anything.

On `writer: MISSING`, stop. A setup that cannot find its own writer must not go on to ask for
consent, that is asking permission for something it cannot do.

### T2 · where the log would live, and whether the config location resolves · HARD

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/telemetry.sh" status
```

PASS iff the block prints and **neither** the config line **nor** the log-directory line says
`(unresolved)`. Quote the whole block, it is eight lines and the user is entitled to all of them.

**Read the receipt out loud, in their words**, because this is the moment they learn where things
would go:

- `mode : off`, *"nothing is being recorded right now."* On a first run this is the expected line
  and you say so, rather than presenting it as a problem to fix.
- `config : <path> [absent]`, *"no config file exists yet. Nothing has been written."*
- `log directory : <path> (not recorded — nothing is removable by rule)`, *"this is where a log
  would go if you say yes. Nothing is there, and nothing has been created."*

**This gate creates nothing of this plugin's.** `status` reads; it never makes a directory and
never writes a config. One thing outside this plugin can still appear: a stock macOS interpreter
mirrors its own bytecode cache into `$HOME/Library/Caches/com.apple.python`, which is the
interpreter's file, not this package's, and the suite's own footprint check excuses that path by
name for the same reason. If the config line says `malformed`, that is a FAIL of this gate: stop, print the path,
and say *"there is a config file there that I cannot read. I will not overwrite it, it holds
settings for the rest of this plugin. Repair or move it, then run this again."*

### T3 · CONSENT: the local event log · CONSENT GATE · default NO

Say this first, in these plain words:

> *"This plugin can keep a small log of what it did, one line per event, like 'a cycle started',
> 'a gate passed', 'a lint found three problems'. It records **what kind of thing** happened and
> how long it took. It never records what you wrote, what your files are called, or where they
> live. **It stays on this machine**, this version has no way to send anything anywhere at all,
> and it is capped at about a megabyte, with old lines dropped rather than grown into. Want it on?
> [y/N]"*

**The default answer is NO, and NO is a complete answer.** Nothing about the product changes.

State all of it, in this order, **before** you ask a second time:

- **the exact file**, `telemetry.jsonl`, inside the log directory T2 just printed. There is one
  more file, `telemetry.jsonl.1`, which is the single previous generation of the same log.
- **the cap**, 512 KiB per generation, 2 generations, so about 1 MB, **forever**. The check runs
  on every write, so it cannot grow past that between cleanups; there is no cleanup job, because
  there is nothing to clean up. It is one config key (`telemetry.max_bytes`) if they want more
  history, and `status` always prints the number in force rather than the number in this file.
- **what a line contains**, a UTC timestamp, an event name, and class words like `result=ok`,
  `phase=p2`, `findings=3`. Offer to show them a real line; it is plain text and they can read the
  file themselves at any time.
- **what a line can never contain**, file contents, document titles, and real paths. **This is
  enforced by the writer, not promised by it:** a value is stored only if it is a bare
  `[A-Za-z0-9_.:-]` token of at most 64 characters, and `/` is not in that set, so a path cannot
  be written even by a call site that passes one in error. A value that fails the test is stored
  as `?`, **whole**: the length limit rejects, it never truncates, so a long path can never land
  as a shortened-but-real path prefix.
- **grouping ids are digests**, if a run passes an id so its events can be grouped, what lands on
  disk is a 12-character digest of it (`9f2c41ab7de0`), not the id.
- **there are no background processes.** Nothing is installed here, nothing runs on a timer, and
  nothing watches anything. One short-lived write per event, and only while you are using the
  plugin.
- **nothing leaves this machine, and there is no setting that would change that.** This build
  ships no transmission path of any kind: no mode to switch, no destination to name. If a future
  version can send anything anywhere, it will be its own feature with its own gate, not a value
  you could flip in a config file.
- **how to stop, and how to delete**, both commands, now, before the yes: T5 prints them.

**On a typed yes**, record it, and the basis is the user's own words, quoted, never a paraphrase:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/telemetry.sh" consent local "<the user's typed yes, quoted>"
```

That one call writes three things and prints all of them back **read off disk**: the setting
(`telemetry.mode: local`), the directory it recorded (`telemetry.dir`, the ledger the removal
path reads), and the consent record (`acknowledged.telemetry_local`, an ISO timestamp with the
basis). **Quote its output as the receipt.** A record you did not read back is the same defect as
a gate you did not verify.

The writer **refuses** with exit `4` if you give it no basis. That is correct and it is not a bug
to work around: a consent record that cannot say what was agreed to is not a record.

**On a NO, the default:** run nothing. Write nothing. Not the mode, not an empty consent record,
nothing, writing anything at all would record a decision the user did not make. Say it plainly:
*"Nothing recorded, nothing written, no file created. The plugin works exactly the same."* Then
report T3 as `DECLINED` in the report, which is a **PASS** of the gate, not a failure of it.

### T4 · RECEIPT: prove what just happened · RECEIPT

**On a yes**, emit one real line in front of them and show it:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/telemetry.sh" emit init_consent result=recorded || true
bash "$PKG_ROOT/scripts/telemetry.sh" status
```

Then print the line itself, so they see the shape rather than a description of it, the path comes
from the `log directory` line `status` just printed:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
tail -1 "<the log directory from status>/telemetry.jsonl"
```

Expect one line of this shape, and say what each field is:

```
{"event":"init_consent","result":"recorded","ts":"2026-01-01T00:00:00Z"}
```

T4 is a **FAIL** if `status` still says `mode : off` after a yes · the log file does not exist ·
or the line is described instead of quoted.

**On a NO**, T4 is the receipt for the *decline*, and it is just as real:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/telemetry.sh" status
```

PASS iff `mode : off`, the consent record prints as `(none — declined, or never asked)`, and both
log generations print `absent`. Say the one sentence that matters: *"That is the proof there is no
log: not a setting that suppresses it, there is no file."*

**Note the honest asymmetry, and say it once.** `emit` is silent and always exits 0 by design, so
it can never break the thing that called it. That means **its exit code proves nothing**, the
receipt is always `status` plus the file itself, never a successful-looking command.

### T5 · how to stop, and how to remove · INFO, must be said out loud

Print all three, whatever the answer at T3 was, because a user deciding whether to say yes is
entitled to see the exit before they take the entrance:

```bash
# stop recording; keep the log file and the consent record
bash "$PKG_ROOT/scripts/telemetry.sh" consent off

# delete the log and clear this feature's own keys; every other setting is left alone
bash "$PKG_ROOT/scripts/telemetry.sh" purge --apply

# delete the log AND the whole config file for this plugin
bash "$PKG_ROOT/scripts/telemetry.sh" uninstall --apply --confirm "apply uninstall"
```

Say the difference in one line each: *"`consent off` stops it. `purge` also deletes what was
already written, and forgets that you ever said yes. `uninstall` additionally removes the config
file, which is where the rest of this plugin keeps your other answers too."*

Both `purge` and `uninstall` are **dry-run by default**: without `--apply` they print exactly what
they would remove and change nothing. Say that too, it is what makes the command safe to try.

---

## PART 2b, THE OPTIONAL INTEGRATION (1 gate)

### I1 · CONNECT: an issue tracker, read-only · ELICIT · default NO

**Nothing about a tracker is preconfigured in this plugin.** No vendor, no instance, no project,
no company. This gate exists because the alternative, shipping a ready-made integration id
pointed at whichever tracker the author happened to use, hands every other user a stranger's
tooling choice, and hands every reader of the source that stranger's identity. So the plugin asks
instead, and it asks **two** questions in this order. The first is about appetite, the second is
about reality, and the second exists because "yes, I'd like that" and "yes, I can actually do
that" are different answers:

> **(a)** *"Do you want to connect an issue tracker, Jira, or whatever you use, so this plugin
> can read item types, meaning your stories and tickets, when it cross-checks a backlog? It is
> read-only: it never creates, edits, moves, or closes anything."*
>
> **(b)** *(only if they said yes to (a))* *"Do you have API access to it, a base URL, a project
> key, and a credential file you can point me at?"*

The exact wording of both lives in `config/dependencies.json` under the `issue-tracker` row's
`elicit` block. Read it from there rather than inventing a phrasing: the manifest is what a
reviewer audits, and a wizard that asks something other than what the manifest documents is the
drift this whole layer exists to prevent.

**On yes to (a) AND yes to (b)**, record three values, and only these three:

| What | Local key | Note |
|---|---|---|
| Base URL of their tracker | `issue_tracker.base_url` | the workspace root they would type into a browser |
| Project key to cross-check | `issue_tracker.project_key` | one project, named, so a cross-check can never quietly answer from a different backlog |
| **Path to** their credential file | `issue_tracker.auth_pointer` | a **POINTER**, never the token |

Then set `issue_tracker.enabled` to `true`. All four go in **`config/local.json`** (machine-local
and gitignored), never in the plugin's own config file, and never in any file inside the plugin
that a repository sync could carry off this machine. `config/local.template.json` documents each
key; copy it to `config/local.json` if it does not exist yet, and fill only these four.

**One file holds this decision, and it is the file the engine reads.** `scripts/preflight.sh`
resolves `${local:...}` from `config/local.json`, so recording the answer anywhere else would
create a second version of the same fact, and the copy the code ignores is the copy that goes
stale without anyone noticing.

> ⛔ **Never ask for, accept, paste, echo, or store the token itself.** If the user offers one in
> the conversation, do not write it anywhere: say plainly that this plugin stores only a *path* to
> the file holding it, ask where that file is, and record the path. A credential typed into a chat
> is already somewhere it should not be, do not make a second copy of that mistake on disk.

**On yes to (a) but no to (b)**, this is a real and common answer, and it is not a failure. Record
nothing. Say that the integration needs API access to do anything, that they can run this setup
again the moment they have it, and that every verb works meanwhile with backlog cross-checks simply
not offered. Report I1 as `PASS-DEFERRED`.

**On a NO to (a), the default:** write **no** URL, **no** project key and **no** credential
pointer. Record only the decline itself, by setting the one switch key to `false`:

```json
{ "local": { "issue_tracker.enabled": false } }
```

That key is deliberately **three-state**, and the third state is the point: **unset** means never
asked, **false** means asked and declined, **true** means connected. A wizard that could not tell
"declined" from "never asked" would re-ask a question the user already answered, so `false` is
what makes a no *stick*. Report I1 as `PASS-DECLINED`.

**What a decline actually means, and say this out loud once:** the integration is *absent*, not
*broken*. The capability row is not probed, no fix is printed, and nothing is ever named as
missing on account of it. Prove it rather than asserting it, this is I1's receipt:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/preflight.sh" pm-portfolio-v1 --stack backlog-sync
```

Expect exit `0`, the row listed under **"optional integrations not connected"**, and **no MISS line
and no FIX line naming it**. I1 is a **FAIL** if that command exits non-zero, or if the row appears
as a MISS, either would mean a declined integration is being reported as a gap in the user's setup.

---

## PART 3, THE PROOF REPORT

Print this table, with the real (trimmed) output in the last column. **Print it even when a gate
failed**, especially then.

| # | Gate | Verdict | Command | Real output (trimmed) |
|---|------|---------|---------|-----------------------|
| T1 | interpreter + writer | PASS | `python3 -V` | `Python 3.x.y` |
| T2 | where it would live | PASS | `telemetry.sh status` | `mode : off` … |
| T3 | CONSENT: local log | PASS-CONSENTED / PASS-DECLINED | `telemetry.sh consent local "…"` | the three keys, read back |
| T4 | receipt | PASS | `telemetry.sh status` + `tail -1` | the emitted line, or the absent log |
| T5 | stop and remove | SAID | `telemetry.sh consent off` · `telemetry.sh purge --apply` · `telemetry.sh uninstall --apply --confirm "apply uninstall"` | the three commands |
| I1 | CONNECT: issue tracker | PASS-CONNECTED / PASS-DEFERRED / PASS-DECLINED | `preflight.sh pm-portfolio-v1 --stack backlog-sync` | exit 0 + the not-connected line, or the row passing |

Then, in plain words: **1.** what is on now and what is off, the specific thing, not an adjective
· **2.** the consent record, **read back from the config** rather than from this conversation ·
**3.** where the log is and how big it is right now · **4.** whether the issue-tracker integration
is connected, deferred or declined, **read back from `config/local.json`**, not from this
conversation · **5.** the one-line next step.

**All three I1 verdicts are passes.** Never report a declined or deferred integration as a
failure, a warning, or an incomplete setup: a plugin that nags about an optional integration the
user already said no to has turned its own default into a defect.

**Never end with an unqualified "setup complete" while any gate is FAILED or SKIPPED.** Say which,
and what it costs the user. A decline is not a failure and must never be reported as one.

---

## `--verify`

Ask nothing. Re-run T1, T2 and T4's `status` block, and print the report with T3 read **off disk**
rather than re-asked:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/telemetry.sh" status
```

- consent record present and `mode : local` → `PASS-CONSENTED`, and quote the stamp.
- consent record empty and `mode : off` → `PASS-DECLINED`. **Do not take this as an invitation to
  ask again.** If they want it on, the full run is where that happens, and they can say so.
- `mode : local` with an **empty** consent record → this is the one real FAIL of a verify: the
  setting is on and nothing records that anyone agreed to it. Say exactly that, and offer
  `purge --apply` (stop and delete) or a fresh consent, and let them choose.
- config `malformed` → report it, change nothing, and never overwrite the file.

Then re-verify **I1 off disk too**, by reading `issue_tracker.enabled` from `config/local.json`:
`true` → `PASS-CONNECTED` · `false` → `PASS-DECLINED` · absent → report it as **never asked**, which
is a true statement and not a gap. **Do not re-ask at any of the three.** `--verify` asks nothing;
that is its whole contract, and an integration offer is exactly the kind of question that feels
harmless to slip in and is not.

One real FAIL exists here, and it mirrors T3's: `issue_tracker.enabled` is `true` while any of the
three values is missing. That is an integration switched on with nothing behind it, say exactly
that, show the preflight MISS, and offer either filling the keys or setting the switch back to
`false`. Let them choose; do not pick.

## `--uninstall`

**Print both plans, ask which, and do not pick.** They differ in one thing that matters:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/telemetry.sh" purge          # dry run: the log + this feature's keys
bash "$PKG_ROOT/scripts/telemetry.sh" uninstall      # dry run: the log + the whole config file
```

Read the plans out, then one summary line of consequence: *"`purge` deletes the log and forgets
the consent; your other settings stay. `uninstall` also deletes the config file those other
settings live in."*

Then the gate, and it is the only one:

1. For `purge`, a plain yes is enough, it removes only what this feature wrote.
2. For `uninstall`, ask for the exact words **`apply uninstall`**, typed by the user in the
   conversation. That phrase is the writer's own; you pass the same string to `--confirm`, never a
   friendlier paraphrase of your own. *A gate with two phrasings is a gate where the user types
   the right thing and is then told they did not confirm what they just confirmed.*
3. **Anything else is a no.** Ask again, once, quoting the words you need.

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/telemetry.sh" uninstall --apply --confirm "apply uninstall"
```

**Read its exit code and say what it obliges you to say:** `0` done (a dry run is also a `0`) ·
`1` one or more steps **FAILED**, name them first and never say "complete" · `2` you invoked it
wrongly, fix the invocation, do not retry with different flags hoping one lands · `4` **REFUSED
by a rule** and **nothing was touched**, the two causes are a missing or wrong confirmation
phrase, and a config file that cannot be parsed. Route to the right one and say why the refusal
was correct.

Close with what remains, in their words: *"The log is gone and nothing records that you ever
turned it on. The plugin itself is removed by your harness when you uninstall it, this does not
do that, and it never touched anything else on your machine."*

**Say what was deliberately left alone.** Neither path touches `config/local.json`, so an
issue-tracker integration stays connected and its four keys stay as they were. That is correct, those are this machine's settings, not this feature's data, but it must be **said**, not assumed:
*"Your issue-tracker settings are untouched; to disconnect that, set `issue_tracker.enabled` to
`false` in `config/local.json`, or delete the four `issue_tracker.*` keys."* A removal path that
quietly leaves something behind is the one thing a removal path may never do.

The same rule covers one empty directory. `uninstall --apply` removes the config file and the log,
and leaves the directory that held the config, `$HOME/.config/product2prod/` under the default
resolution, in place and empty. Say so rather than letting them find it: *"the folder that held
the config is still there and empty; delete it yourself if you want the last trace gone."*

---

## Never

- **Never write the log, the plugin's own config, or a removal by hand.** `scripts/telemetry.sh` is
  the one implementation of all three. If it is missing, that is a FAIL you report, not a thing you
  improvise around. *(`config/local.json` is a different file with a different owner: it is the
  user's machine-local settings, it is plain JSON they are expected to edit themselves, and I1
  writes its four keys directly. The rule above is about the file `telemetry.sh` owns.)*
- **Never write a credential value anywhere**, not into `config/local.json`, not into the plugin's
  config, not into the log, not into a shell command that lands in a history file. Integrations
  record a **path** to a credential file and nothing else. If a user pastes a token into the
  conversation, do not store it, do not echo it back, and say plainly that a path is what is needed.
- **Never preconfigure an integration**, and never guess a vendor, an instance, a workspace, a
  project key, or a URL because it seemed likely from context. Every one of those is asked for at
  I1 and recorded from the answer. An integration id or endpoint that names a specific company or a
  specific customer must never appear anywhere in this package.
- **Never turn recording on without a typed yes**, and never write an empty consent record on a
  no. An empty record is a true statement; a fabricated one is not.
- **Never report the log as off without reading `status`**, and never report it as on without
  quoting a real line from the file.
- **Never treat a decline as a problem**, a partial answer, or something to re-open later in the
  same run.
- **Never claim anything is sent anywhere, or could be.** There is no such path in this build, and
  hedging about it invents a doubt the code does not support.
- **Never overwrite a config file you could not parse.** It holds the rest of this plugin's
  settings; a refusal costs one repair, an overwrite costs the user every other answer they gave.
