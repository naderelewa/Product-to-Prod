# product2prod

**Product management for AI agents: turn an idea into documents that survive scrutiny. Every claim in what it writes is either sourced or labelled unsourced, and no gate is passed by the agent that wants to pass it.**

one paragraph of intent → a plain-words interview → a locked context → gated phases → a package on disk that names its sources and its gaps

[![version](https://img.shields.io/badge/version-0.1.1-blue)](#license-and-provenance)
[![license](https://img.shields.io/badge/license-MIT-green)](#license-and-provenance)
[![self%20tests](https://img.shields.io/badge/self%20tests-87%20checks-brightgreen)](#tests-and-hygiene)
[![usage%20log](https://img.shields.io/badge/usage%20log-off%20by%20default-lightgrey)](#the-usage-log)

The agent drafts, then stops. Ruling the open questions stays yours, and the record shows what was known when you ruled. It runs inside an agent you already have, and nothing it writes leaves your machine.

**Three plays win most product reviews, and all three are cheating:**

- A number arrives sounding certain, and nobody can say where it came from.
- A gate gets passed by the same agent that wanted it open.
- A handoff cannot show what was known, and what was still open, on the day it shipped.

**They lose at this table.** Every factual claim carries one of six evidence tags, a linter checks that discipline mechanically, and the approval flag ships false with no code path in this plugin that writes it true. What it checks is the discipline, not the truth: a claim can still be wrong, but not quietly wrong. A FOUND must name a place to check; the second command below catches one that does not.

**Get it, then prove it before you read it.** No credentials:

```bash
git clone https://github.com/naderelewa/Product-to-Prod.git && cd Product-to-Prod
bash tests/run-tests.sh                                                  # the suite behind the badge: 87 checks
bash scripts/tag-lint.sh tests/fixtures/tag-lint/bad-found-no-anchor.md  # watch it catch a FOUND with no locator
scripts/telemetry.sh status                                              # confirms the usage log is off and no file exists
```

## One run, start to finish

One small ask, end to end. Bigger asks are the same shape with more phases.

**You type**

```text
/pm-start "should [Put Your Company Name] charge sellers a listing fee or a take rate?"
```

**It locks the context and stops** until you confirm or correct this block:

```text
company / pack   : <name> (pack: <id> | none = generic mode)
area             : <area>
output           : <deliverable>
destination      : standalone | handoff to <engineering toolchain>
out of bounds    : <anything you said not to touch>
```

**What lands.** No files for an ask this small; bigger asks land the package. The routed verb opens one section of the framework library (`skills/gtm-domain-library/references/pricing-value-metric.md`) and answers with the value-metric tree plus the rows only your instrumentation can fill. The library never supplies your numbers.

**Illustrative excerpt**, the shape of what lands rather than a real run:

```text
Value metric candidates, ranked
1. per completed order      [INFERRED: scales with the value the seller receives]
2. per active listing       [CONSTRUCTED: easier to bill, weaker link to value]
Your take-rate elasticity   [NEEDS-CONFIRMATION → pricing owner: blocks the free-line decision]
Market benchmark            [HYPOTHESIS: no durable market source found]
```

The gap rows are the feature. Visibly empty beats quietly invented: a reader who sees the gap can close it, one given a confident wrong number cannot. The same run at four sizes across five industries: [Example scenarios by industry](docs/examples-by-industry.md).

## Install

Prerequisite: python3 on your path, and `shasum` (or `sha256sum`) for the requirements seal. Most scripts embed a python program (preflight, hostcheck, tag-lint, inference-gate, telemetry), as does the test suite; publish-lint and release are pure shell. Runs in Claude Code and any harness reading the Agent Skills spec, whose protocol is [`AGENTS.md`](AGENTS.md).

Four rungs, in rising depth.

**1. Zero setup: one file, one paste, nothing configured. For a first look.** Open any verb's [`SKILL.md`](skills/), paste it into your agent, and say "apply this to my product". Every verb runs with nothing configured, consented or connected.

<details>
<summary><b>2. Skills folder.</b> For day-to-day use in any harness.</summary>

Copy the [`skills/`](skills/) subfolders into your agent's skills directory; your harness picks them up by name and description.
</details>

**3. Claude Code (plugin). For day-to-day use with the full surface.**

```bash
git clone https://github.com/naderelewa/Product-to-Prod.git
claude --plugin-dir Product-to-Prod
```

Then run `init` once only if you want one of the two things it governs: the usage log, or a read-only issue-tracker connection. Want neither and there is nothing to set up, which the wizard says in those words; its gates are in [Wizard features](docs/wizard.md). Some harnesses namespace skills, so use what your harness lists rather than the bare `/pm-start` here.

**4. Marketplace**, when published: install through your harness's plugin marketplace.

Every host-specific key ships null in [`config/local.template.json`](config/local.template.json), explained in [Connections and configuration](docs/configuration.md). **Start with the sentence at the top of the run above.**

## Which verb, when

| Reach for it when | Verb | It gives you |
|---|---|---|
| You do not know which you need | `/pm-start` | four plain-words questions, a locked context block you confirm, a route to one verb |
| A feature or release must become buildable work | `/pm-requirements-v1` | five phases (context lock, research, strategy, spec, handoff), three human gates, one package directory |
| A pile of asks needs an order | `/pm-portfolio-v1` | one row per decidable ask, both lenses scored separately, evidence-labelled RICE, a sprint recommendation |
| Something shipped and somebody asked whether it worked | `/pm-verify-release-v1` | every pre-declared scenario graded against the deployed build, the queries run read-only |
| A launch or a growth period needs a plan | `/pm-gtm-v1` | a fresh gate-state snapshot, a phase-gated plan, a campaign narrative, channel and tracking rows proposed, not changed |

Two boundaries. **Mixed asks route to the first verb only**: "prioritise this, then spec the top item" runs the second only after the first closes; two verbs never share one context lock. And **"this needs no verb" is a valid answer**: five phases on a one-paragraph judgement call is a failure, not diligence. What each verb leaves on disk: [Outputs available](docs/outputs.md).

## Honest comparison

### Doesn't a plain agent already write PRDs?

Yes, and with nothing installed it is the fastest way to draft one. What it lacks is anything that pushes back. Every cell about another tool comes from one grounding file, neither shipped nor published, and nothing beyond it; *not established here* means unverified either way, not a no. Our own worst row is in the same table, in bold.

| | Plain chat, no plugin | A PRD-writing SaaS | A product-coaching SaaS | This plugin |
|---|---|---|---|---|
| **Enforcement** | nothing to lint, nothing to gate | not established here | no lint, no tests, no gates | tag linter, fail-closed inference gate, publish lint, 87 self-checks, three human gates per cycle |
| **Evidence discipline** | whatever the model volunteers | no evidence-tagging discipline | no evidence-tag system | six tags on every factual claim, no false FOUND, no anchor no claim, linted mechanically |
| **Verification against reality** | none | none against analytics | not among its stages | a dedicated verb: pre-declared scenarios graded against the deployed build, queries run read-only |
| **Data custody** | wherever your chat runs | cloud-held | cloud-held | local; usage log off by default; no transmission path in this build |
| **Weakest point** | nothing pushes back | no repository or codebase awareness | the handoff is a prompt, not a contract | **no SaaS UI, single-player, young at v0.1.1, no cloud dashboards, field-proven in one harness only** |

Two further classes and the rows this one omits: [The full comparison](docs/comparison.md). **Reach for something else when** people must work in the document at once, with seats and sharing (a hosted team product); when somebody who will never open an agent harness has to use it (a hosted web tool); or when the ask needs no verb at all (plain chat).

## The usage log

Off by default, local only, bounded at 512 KiB per generation across two generations. This build ships no transmission path, and that is machine-checked rather than promised: a check in the suite reads the whole usage-log surface (the writer script, the config schema, every file of the setup skill) and fails on a transmission call form, a URL literal, a non-local import, or prose telling anyone to send the log somewhere. It finds none. Three commands govern it, both destructive ones dry run by default:

```bash
# stop recording; keep the log file and the record of your consent
scripts/telemetry.sh consent off

# delete the log and clear this feature's own keys, every other setting is left alone
scripts/telemetry.sh purge --apply

# delete the log AND this plugin's whole config file, which holds your other answers too
scripts/telemetry.sh uninstall --apply --confirm "apply uninstall"
```

[The usage log, in full](docs/the-usage-log.md): what it can never contain, where it lives, why off means no file, and the bound needing no cleanup.

## Tests and hygiene

```bash
bash tests/run-tests.sh          # the package's own suite: 87 checks, offline, no credentials
bash scripts/publish-lint.sh     # scans the tree against the 20 patterns in config/denylist.txt
scripts/release.sh vX.Y.Z --overlay FILE   # three gates, then the tag; dry-run supported
```

The [suite](tests/run-tests.sh) is pinned against a written-down list of its own checks, so a deleted check fails rather than shrinking the count. One of the 87 reads your repository's commit history, which no tree scan can see, so a clone whose history carries a banned token fails there while every file on disk is clean.

The [publish scan](scripts/publish-lint.sh) reads [its patterns](config/denylist.txt) from one file you can open before trusting it, and walks every file under the package root but five classes it counts and names on every run: this pattern file, the machine-local `config/local.json` if present, and the three git never publishes. The [release gate](scripts/release.sh) runs the commit-message lint, then that scan, then the suite, and will not tag unless all three are green. No skip flag, and a release runs the scan in maintainer mode: a private overlay from outside the tree is required.

Exit codes are the contract for every script here: `0` clean or pass, `1` real findings or a failed step, `2` usage or could not run, `4` refused by a rule (usage-log script only). A `2` is a failure, never a pass: a gate that could not run has not been passed. One exception: the usage-log script reports an absent interpreter as `1`.

The requirements verb closes with a sha256 seal, so a package that drifted after approval cannot pass as approved. It covers a named set (`HANDOFF.md`, `spec.md`, `plan.md`, `data-model.md`, `slices.json`, `case-contract.md`, everything in `contracts/`), and not `design-gate.json`, which carries the seal numbers, nor the seal file itself. Written before the approval flag flips, so approval covers the bytes reviewed.

### Contributing

- Run [the suite](tests/run-tests.sh) first. A change nobody has run it against is not ready to read.
- Every new check ships with a [fixture](tests/fixtures/), so it can be watched failing on purpose.
- A check that cannot run must fail, or report a skip with its reason. Never pass quietly.

## License and provenance

MIT. See [`LICENSE`](LICENSE). Framework originators (Christensen, Ulwick and Klement for jobs-to-be-done; van Westendorp for price sensitivity) are credited inline where the library uses their methods. Every figure carries its source and tag inline, and the ones filling a slot trace to [the fact registry](skills/gtm-domain-library/references/mf-token-registry.md) too.

## Full documentation

The depth lives in `docs/`, each page opening with a breadcrumb back here.

- [What it is, and how the wizard works](docs/wizard.md) · package anatomy, consent gates, the interview, packs and `{company}`, the tags, linter and inference gate.
- [Outputs available](docs/outputs.md) · what each verb leaves on disk, with the workbook and standalone caveats.
- [Example scenarios by industry](docs/examples-by-industry.md) · every scenario at four sizes across five industries.
- [Connections and configuration](docs/configuration.md) · every capability, what is recorded and never recorded, the resolution order.
- [The full comparison](docs/comparison.md) · every row, where the other classes are stronger, what this package is not.
- [The usage log](docs/the-usage-log.md) · the full data-custody proof.
