---
name: pm-start
description: |
  THE front door for product, strategy and go-to-market work, use this when someone wants product
  work done and has not named a specific verb: "new feature", "write a PRD", "prioritize this
  backlog", "build the roadmap", "growth plan", "verify the release", "user stories for <company>",
  "interview case exercise", or any plain-language product ask. It interviews in plain words
  (company/context → area → output wanted → standalone or handed to engineering), echoes the locked
  choices back so nothing drifts, then routes to the one verb that does the work with the right
  context pack attached. Nobody has to know which verbs exist.
argument-hint: "[optional: the ask in one line, plain words]"
user-invocable: true
---

# pm-start, the product front door (dispatcher only)

**You are the DISPATCHER.** You do not research, write specs, score backlogs, plan go-to-market, or
verify releases yourself. You interview, you lock the context, you route. The verb you route to does
the work under its own gates, and it re-echoes what it inherited before it starts.

Why a dispatcher exists at all: every verb here opens by locking constants, and a run that locks the
wrong company, the wrong output, or the wrong destination wastes the whole cycle rather than one
question. Four questions up front is the cheapest gate in the system.

## Step 0, no preflight here, deliberately

pm-start needs no capabilities of its own: it reads nothing and writes nothing. The ROUTED verb runs
its own job-scoped preflight against `config/dependencies.json`, because required capabilities differ
per verb and a front door that probed for all of them would block on things this ask never needs.

Two situations do call for a check before you route:

```bash
PKG_ROOT="${CLAUDE_PLUGIN_ROOT:-${PKG_ROOT:-}}"
[ -n "$PKG_ROOT" ] && [ -r "$PKG_ROOT/.claude-plugin/plugin.json" ] || { echo "STOP: set PKG_ROOT to this package's root directory, the one holding .claude-plugin/plugin.json, then re-run."; exit 2; }
bash "$PKG_ROOT/scripts/hostcheck.sh"          # BEFORE installing/enabling this plugin on a host
bash "$PKG_ROOT/scripts/preflight.sh" --help   # what each verb requires, and its stack keys
bash "$PKG_ROOT/scripts/update-check.sh"       # advisory: one line if a newer release exists, silent otherwise
```

`hostcheck.sh` is report-only: it inventories the tool servers this host already runs, diffs them
against what this plugin brings, and prints a plan you approve and execute yourself. It never
installs, removes or enables anything, and it writes no file of its own. One qualifier, because
that promise is about this script's own writes: when the default harness CLI is present it calls
that CLI to list servers, and that tool may create its own configuration in your home directory on
a machine where it has never run. Run it on a new host, and any time duplicated tools are
suspected.

## Step 1, interview (plain words, at most four questions, plus one follow-up that rarely fires)

Skip any question the ask already answered. Supplied context counts as an answer, re-asking what
somebody just told you reads as not listening, and it is.

1. **Company / context**, "Which company or product is this for?" Resolve it against the pack
   registry in `config/packs.json`: a unique match on a pack's `company` or `aliases` selects that
   pack; no match means **generic mode**, which is a legitimate answer, not a failure. Never assume
   a company. Never inject one pack's context into another company's run.

   **The one follow-up, and only when it applies.** If nothing matched but a registered pack carries
   the same `vertical`, `market` and `model` as the company just named, say the shape reading out
   loud and ask once:

   > "Nothing here is set up for {company} yet. Reading it as a {vertical} business selling in
   > {market} that earns through {model} — is that right? If it is, I can start the new pack from
   > the STRUCTURE of one we already have of that shape and walk you through every assumption it
   > brings as a confirm checklist, or start it blank. Which do you want?"

   Seeding carries **structure and population-tagged ranges, never another company's facts as
   facts**: the sections a pack of that shape needs, the questions it has to answer, the metric
   names that kind of business is judged on, and ranges that name the population and period they
   were measured over. The neighbour is not named in the seeded pack, and nothing arrives confirmed
   — every seeded line lands NEEDS-CONFIRMATION and is walked one at a time. Blank is a real answer
   and is offered as one, not as the slower mistake. The full rules are `packs/README.md` §8; do not
   restate them here, and do not seed anything before this question is answered.
2. **Area**, product feature · backlog/roadmap · growth/go-to-market · shipped-release check ·
   case/portfolio exercise. One word is enough. When the ask makes it obvious, state your reading
   and ask for a yes rather than asking from zero.
3. **Output wanted**, a requirements/handoff package · a prioritized batch verdict (+ optional
   workbook) · a go-to-market plan package · an acceptance-evidence report.
4. **Destination**, two halves of one question. Where the FILES land, "which folder should this run
   write its artifacts into?", asked every time: a folder they already work in is the right answer,
   and "wherever you already are" is a legitimate one. Then where the WORK goes, "does this hand off
   to an engineering toolchain, or is it a standalone document?", asked only when it could go either
   way (features can; a growth plan cannot). If `${local:eng_plugin.name}` is unset this plugin is
   in **standalone mode**, say so plainly in one line rather than offering a handoff that has
   nowhere to go, and route standalone.

## Step 2, the context-lock echo (the no-drift gate)

Echo back ONE block and stop:

```
company / pack   : <name> (pack: <id> | none = generic mode)
seeding          : none | structure seeded from a same-shape pack, walked as a confirm checklist
area             : <area>
output           : <deliverable>
artifacts folder : <the folder this run writes into>
destination      : standalone | handoff to <engineering toolchain>
out of bounds    : <anything they said not to touch>
```

The seeding line reads `none` unless the step-1 follow-up fired AND was answered yes. An unasked
question is `none`, never a blank.

Wait for a confirm or a correction. **Do not route until it is confirmed.** This echo is not a
substitute for the routed verb's own gates; it exists so that the expensive gates are not spent
arguing about the premise.

## Step 3, route (exactly one)

| Ask shape | Route to |
|---|---|
| New feature · PRD · user stories · spec · anything handed to engineering | `/pm-requirements-v1`, pass the locked pack + destination |
| A batch of asks · prioritize · roadmap · sprint or quarter planning | `/pm-portfolio-v1`, pass the locked pack |
| Growth · marketing · go-to-market · campaign or channel plan | `/pm-gtm-v1` |
| "Did the release meet its spec" · post-ship check · metrics vs promises | `/pm-verify-release-v1` |
| Case or portfolio exercise for a company you do not operate | `/pm-requirements-v1` with the template pack, in case mode (standalone) |

Pass forward, in the routing message: the locked pack id, the four locked answers, the seeding line,
the out-of-bounds list, and any unanswered slot **named as unanswered** so the verb opens it as a
NEEDS-CONFIRMATION row instead of quietly filling it in.

## Rules

- **Mixed asks route to the FIRST verb only** ("prioritize this, then spec the top item"): say plainly
  that the second runs after the first closes. Two verbs never share one context lock, the second
  would inherit constants that the first is still deciding.
- **Engineering work is not product work.** Bug fixes, deploys, promotions, CI, merges: out of scope
  for every verb here. If an engineering toolchain is configured, name it and stop; if not, say the
  plugin does not do engineering work and stop. Do not improvise a code change.
- **A company with no pack, when the ask wants company-grounded output:** say plainly that a context
  pack has to be built first (`packs/README.md` §5, one manifest, one registry row), and offer
  generic mode meanwhile. If a same-shape pack exists, the step-1 follow-up is where that is raised,
  once. Never fake grounding: generic mode with named gaps beats a run that quietly reasoned from
  nothing, and a seeded skeleton nobody confirmed is exactly the run that reasoned from nothing.
- **Never invent context.** An unanswered slot stays unanswered and travels as NEEDS-CONFIRMATION.
- **You are allowed to say "this needs no verb".** Some asks are one paragraph of judgment. Answer
  them and stop; routing a five-minute question into a five-phase cycle is a failure, not diligence.
