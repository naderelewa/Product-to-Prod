[Back to the README](../README.md) · the anatomy of the package, and every wizard behaviour in full.

# What it is, and how the wizard works

## What it is

| Piece | What it does |
|---|---|
| **A front door** | [`pm-start`](../skills/pm-start/SKILL.md) interviews you in plain words (which company, which area, which output, standalone or handed to engineering), echoes the locked answers back so nothing drifts, then routes to exactly one verb. Nobody has to know which verbs exist. |
| **Four verbs** | [requirements](../skills/pm-requirements-v1/SKILL.md), [portfolio](../skills/pm-portfolio-v1/SKILL.md), [release verification](../skills/pm-verify-release-v1/SKILL.md), [go-to-market](../skills/pm-gtm-v1/SKILL.md). Each opens with a context lock, runs its own phases, and stops at human gates it will not walk past. |
| **An evidence discipline** | Six tags on every factual claim, a [linter](../scripts/tag-lint.sh) that checks the grammar mechanically, and a [gate](../scripts/inference-gate.sh) that refuses to emit while a confirmation question is still open. |
| **A framework library** | [Seven go-to-market frameworks](../skills/gtm-domain-library/). Every market number in it was filled from a sourced record and carries its evidence inline: the source, the population it was measured on and the year. Where no durable source was found, the gap is shown rather than filled with a plausible number. |
| **Company context as packs** | The engine hardcodes no company. Context arrives as a [pack you author](../packs/) (one manifest, one [registry row](../config/packs.json)). No pack means generic mode, stated plainly. |
| **Local by construction** | Optional integrations record pointers, never credential values. The usage log is off until you turn it on, and this build ships no transmission path at all. |

What it deliberately does not do: engineering work. Bug fixes, deploys, CI and merges are out of scope for every verb here. See [the full comparison](comparison.md) for the rest of the limits, stated in the same place as the strengths.

## Wizard features

### First run: the consent gate

[`init`](../skills/init/SKILL.md) is **the only thing here that writes anything outside your project**, and it governs exactly two things that are off until you turn them on: a local usage log, and one optional outside integration. Six labelled gates in two series, deliberately kept apart, because permission to record something about you is a different question from permission to connect you to something outside.

| Gate | What it does | Default |
|---|---|---|
| T1 | proves an interpreter and the writer script are actually there | hard stop if not |
| T2 | prints where a log would live and whether the config path resolves | hard stop if unresolved |
| T3 | **the one consent question**, in plain words, with the file, the cap and the contents stated before it asks | **NO** |
| T4 | the receipt: on a yes it emits one real line and shows it to you; on a no it proves there is no file at all | either way, real output |
| T5 | how to stop and how to delete, said out loud whatever you answered | always printed |
| I1 | **the integration offer**: connect a read-only issue tracker | **NO** |

Three rules bind the whole flow. A gate never asserts it passed: it runs its command and quotes the real output, and a gate with no receipt is a fail. Silence, "sounds good" and a thumbs-up are not consent; only a typed yes is. And a decline is reported as a pass, never as a warning or an incomplete setup, because a plugin that nags about something you already declined has turned its own default into a defect.

**Turning it off, and deleting it.** Both destructive commands are dry run by default, so you can read the plan before anything changes. The exact commands, what they remove, and what they never touch are in [The usage log](the-usage-log.md).

### The elicited integration, in its own words

Nothing about a tracker is preconfigured: no vendor, no instance, no project, no company. The wizard asks two questions in this order, and the exact wording lives in [`config/dependencies.json`](../config/dependencies.json) so that a reviewer can audit what the wizard is allowed to say:

> **(a)** Do you want to connect an issue tracker (Jira, or whatever you use) so this plugin can READ item types, stories and tickets, when it cross-checks a backlog?
>
> **(b)** *(only if yes to (a))* Do you have API access to it, a base URL, a project key, and a credential file you can point at?

Yes to both records three values and flips one switch. What it records is a **path** to your credential file. The token itself is never asked for, never accepted, never echoed and never written anywhere. If you paste one into the chat, the correct behaviour is to refuse to store it and ask where the file is instead.

Yes to (a) and no to (b) is a real answer and not a failure: nothing is recorded, and you can run setup again the moment you have access. A plain no writes no URL, no project key and no pointer. It records only the decline itself, because the switch is three-state on purpose: unset means never asked, false means asked and declined, true means connected. That is what makes a no stick instead of coming back next run.

### The plain-words interview

`pm-start` asks at most four questions, and skips any the ask already answered, because re-asking what somebody just told you reads as not listening.

1. **Company or context.** Resolved against the pack registry. No match means generic mode, which is a legitimate answer.
2. **Area.** Product feature, backlog or roadmap, growth, shipped-release check, case exercise. One word is enough.
3. **Output wanted.** A requirements package, a batch verdict, a go-to-market plan, an acceptance report.
4. **Destination.** Standalone, or handed to an engineering toolchain. Asked only when it could go either way.

Then it echoes one block and stops until you confirm or correct it:

```text
company / pack   : <name> (pack: <id> | none = generic mode)
area             : <area>
output           : <deliverable>
destination      : standalone | handoff to <engineering toolchain>
out of bounds    : <anything you said not to touch>
```

Every slot nobody answered travels forward **named as unanswered**, as an open question with its confirmer attached. An agent that quietly fills a blank has replaced your judgement with its own and hidden the swap.

### Packs and {company}

A pack swaps context, never process. No pack adds a gate, removes a gate or edits the tag rules.

- **The engine** never varies: the phase spine, the tags, the gates, the scripts.
- **A pack** is one manifest plus one registry row, holding pointers only. It never owns, copies or moves the content it points at, and it never carries a secret.
- **Every company-shaped value in every verb is `{company}`**, resolved from the selected pack or elicited. The registry default ships as `none`, which is a decision rather than an omission: injecting a stranger's context into your run would be worse than asking you one question.
- One template pack ships, and it is fictional. It exists to be copied and to be the fixture the pack mechanism is tested against, which the suite's `fictional_pack_content` check enforces.
- Keep your own packs outside the plugin if you want them to survive upgrades, by setting `packs_dir_extra`.

### Evidence tags, the linter, and the inference gate

Six tags. Every factual claim carries exactly one, and the tag decides what the claim is allowed to do.

| Tag | In plain words |
|---|---|
| **FOUND** | somebody actually read this, and here is the pointer to reopen it |
| **INFERRED** | reasoned from evidence, with the reasoning written down |
| **CONSTRUCTED** | built from several sources, such as a persona or a journey map |
| **CALCULATED** | computed, with the arithmetic shown |
| **HYPOTHESIS** | speculation, allowed while thinking, removed before delivery |
| **NEEDS-CONFIRMATION** | an open question waiting on a named person, with what it blocks |

Two rules carry most of the weight. **No false FOUND**: never tag a plausible claim as read, because a reader who finds one false FOUND is right to stop trusting every other one. **No anchor, no claim**: a FOUND without a pointer is a gap, and a gap is written down as a row rather than written around in prose.

**[tag-lint](../scripts/tag-lint.sh)** is the mechanical check, exercised tree-wide by the suite's `tag_grammar_walk`. It checks grammar, never truth: it cannot tell whether a citation is honest, and it does not try. It catches unknown tags, two tags on one claim, a FOUND with no locator, a FOUND resting only on historical sources, speculation left in a delivery-final file, an untagged row in a tagged table, and an open question with no confirmer. The fixtures it is tested against live in [`tests/fixtures/tag-lint/`](../tests/fixtures/tag-lint/), including the planted [`bad-found-no-anchor.md`](../tests/fixtures/tag-lint/bad-found-no-anchor.md) that the proof block at the top of [the README](../README.md) runs.

```bash
bash scripts/tag-lint.sh <artifact.md> [--delivery-final]   # 0 clean · 1 violations listed · 2 unreadable
```

**[The inference gate](../scripts/inference-gate.sh)** is fail-closed. Before a package can be sealed, every open question is either closed or explicitly accepted, with the ruling recorded on disk. The script reads that record and refuses while anything is unruled.

```bash
bash scripts/inference-gate.sh <package-dir>   # must exit 0
```

And the approval itself is a human's. `design-gate.json` is always emitted `approved: false`, and no code path in this package writes `approved: true`.
