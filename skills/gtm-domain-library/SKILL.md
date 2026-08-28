---
name: gtm-domain-library
description: "Go-to-market domain knowledge for consumer marketplace, membership, subscription and AI-feature products: sharpening an ICP until it excludes someone, running a real user-interview panel, differentiating when the capability is rentable, launch-post anatomy, the value-metric pricing tree, the four-part deal test, and stage metrics with cohort-typed retention and the weekend test. Open it as a reference when a product or go-to-market decision needs a framework instead of an opinion. Not a wizard and not company context: it holds no client, account or market-specific facts."
---

# Go-to-market domain library

> A framework is not advice. It is a way of being wrong in public, on purpose, early enough to fix it.

This library holds seven go-to-market frameworks in one place, written so that any product team can use them without knowing anything about the team that assembled them. Each framework lives in its own reference file, and each one is an original write-up that credits the originator of the classic method it draws on inline, so you can always see where an idea came from.

## What this is, and what it is not

It **is** a reference layer: domain knowledge that stays true across companies. Open the section you need, use the mechanism, close it.

It is **not**:
- **A wizard.** Nothing here interviews you or writes files. The verbs that ship alongside this library do that, and they open these sections when a decision needs one.
- **Company context.** There are no client names, no accounts, no internal identifiers and no market data specific to one business anywhere in this library. That separation is deliberate: context belongs to whoever runs the product, frameworks belong here.
- **A number bank.** Every market number here was filled from a sourced record and carries its evidence inline, or is shown as an open gap. See the number policy below.

## How to use it

- **Open reference first.** Read the section that matches the decision in front of you. Do not read all seven; a framework you did not need is a framework you will misapply.
- **Offer, never impose.** These sections produce candidate answers for a human to accept, sharpen or reject. Nothing here is a verdict.
- **Say which part is evidence and which part is your read.** Every claim you take out of here into a real document carries a tag: `FOUND` (read this cycle from a named source, with a locator), `CALCULATED` (computed, with the math shown), `INFERRED` (reasoned from evidence, reasoning stated), `CONSTRUCTED` (synthesised from several sources), `HYPOTHESIS` (speculation, never load-bearing), `NEEDS-CONFIRMATION` (waiting on a named person). A framework never upgrades a guess into a fact.

## The doctrine constants

Frameworks from different traditions contradict each other. These contradictions are resolved once, here, and every section below obeys the resolution rather than restating its own version.

### The headline doctrine

**Lead with the outcome the user came for, in the user's own words. The capability is the how, never the headline.** Test it by deleting the technology word from your pitch. If the sentence still says what you do and for whom, you are positioned on the problem. If it collapses, you are positioned on the technology, and every competitor renting the same capability sounds exactly like you.

### Time to first value: one definition

**Time to first value is the elapsed time from a person's first open of the product to the first outcome they actually came for, measured inside that same first session.** Not the install. Not the account. Not the tour. The outcome.

- **The target:** `[HYPOTHESIS: no durable market source found]`, no published dataset states an elapsed first-open-to-first-value time for any consumer product class. Every duration figure in circulation was traced to one vendor's own customer base or to a survey of practitioner opinion, and each was struck on that basis. Measure yours, write it here, and keep it the only one in the library.
- **The weekend test** is the unaided version of the same gate: can a stranger reach that outcome with no human help, using only what ships with the product? A product that needs a call, a demo or a founder in a chat window to reach first value has no unaided path, and every acquisition channel you open will leak.

This is the only place in the library where the target is stated. Other sections refer to it and never restate it, so there is exactly one canonical constant to keep current.

### Retention is always cohort-typed

A retention number without its cohort type is a rumour. Two kinds, never comparable:

- **Open cohort:** everyone who first used the product in a period, including the people who tried once and vanished. Measured against the whole intake. Always the lower number, and always the honest one for asking "is this working".
- **Closed cohort:** a qualified subset only, for example the people who reached first value, or paying members. Measured forward from the moment they qualified. Structurally higher, useful for asking "does the value hold once they get it".

Rule: every retention figure in this library, and every retention figure you publish, names its cohort type in the same sentence. Comparing a closed-cohort number to an open-cohort benchmark is the most common way teams convince themselves a leaking product is fine.

### Reply rate is not join rate

Recruiting people to talk to you has two separate conversion steps, and quoting one as the other is how interview programmes get planned at a fraction of the outreach they need:

- **Reply rate:** the share of personalised outreach that gets any reply at all.
- **Reply-to-completed rate:** the share of those repliers who actually sit through an interview.

Outreach volume needed is your target panel size divided by the product of those two rates. Both rates are separate slots in this library and are never collapsed into a single "conversion" figure.

### Retention before acquisition

Prove that people come back before you spend on bringing more of them in. Acquisition into a leaking first run does not buy growth, it buys a faster way to lose people, and it burns the channel while it does. This ordering governs the launch and pricing sections as much as the metrics one.

## The number policy

Every quantitative market claim in this library came into it through a labelled slot rather than as a typed-in figure. The slot form is:

```
{{MF:<topic>.<key>}}
```

- **Topics** map to the research areas this library is filled from: `t1` cohort-typed retention benchmarks, `t2` interview recruiting conversion, `t3` time-to-first-value norms, `t4` free-to-paid and membership conversion, `t5` consumer pricing and packaging norms, `t6` launch-channel effectiveness.
- **A filled slot carries its evidence inline:** the value, the population it was measured on, the year, the named source, the method note, and its tag. A number whose population you cannot state is not a benchmark for your product.
- **An unfilled slot renders as `[HYPOTHESIS: no durable market source found]`.** Visibly empty beats quietly invented. A reader who sees the gap can go and close it; a reader who sees a confident wrong number cannot.
- **Structural counts are written as words** (the seven-step interview method, the five differentiation questions, the four parts of a deal).
- **Your own numbers are not market numbers.** Your retention, your conversion and your prices come from your own instrumentation, tagged as read this cycle. This library never supplies them.
- The full slot inventory, with what each fill must carry, is in `references/mf-token-registry.md`.

## The seven sections

| Open this | When |
|---|---|
| `references/icp-sharpening.md` | Your audience description would not exclude anybody, or you cannot name who is clearly not a fit, or you are aiming the message at whoever holds the wallet instead of whoever chooses |
| `references/interview-method.md` | You have never interviewed a user who is not a friend, or your messaging is clever but unverified, or the roadmap is being argued internally instead of asked |
| `references/differentiation-questions.md` | Anyone could rent your capability tomorrow, buyers doubt it works, or you cannot say why you win when the underlying model, catalogue or fleet is a commodity |
| `references/launch-anatomy.md` | A launch is coming and you want goodwill instead of a flaming, or you are about to blast the same announcement into five rooms |
| `references/pricing-value-metric.md` | You are guessing at a price, stuck on where the free line goes, or people use it happily and nobody pays |
| `references/deal-test.md` | Everyone loves it and nobody signs, or deals keep dying on "let me think about it", or you are tempted to hire someone to do the selling you have not cracked |
| `references/stage-metrics.md` | Your dashboard is full of numbers that cannot answer "is this working", or you are pouring effort into acquisition over a leaky bucket |

## Reading a dev-tool-era framework in a consumer or marketplace context

Most published go-to-market craft was written for products sold to engineers by the people who build them. The mechanisms survive translation; the assumptions do not. No section carries a separate adaptation note; the adaptation is in the numbers, where every borrowed benchmark names the population it came from, so a developer-tool or B2B figure is never read as a consumer one. Four moves recur:

- **The chooser and the payer split differently.** In a developer tool the adopter has no budget and the executive does. In consumer the same person often does both, and when they do not, the second party is a household member, an employer or a benefit plan, not a procurement committee.
- **Two-sided products have two audiences and one constraint.** A marketplace has to win supply and demand. Whichever side is scarce is the side your positioning, pricing and launch are really about, and it changes as you grow.
- **The unaided path matters more, not less.** Nobody reads documentation to order groceries. In consumer, first value is measured in a first session, and there is no support call to fall back on.
- **Trust is a feature with a price.** Money movement, health, children, pets and identity all raise the trust bar above the convenience bar. Reliability and honesty about limits are positioning, not compliance overhead.

## Method provenance

These seven sections are original write-ups of classic, publicly documented product and go-to-market methods; where a section leans on a named classic framework, the file credits its originator inline (jobs-to-be-done per Christensen, Ulwick and Klement; van Westendorp price sensitivity; BANT-class qualification). Every figure in the library carries its source, population, year and evidence tag inline; the ones that fill a slot in the fact registry trace to it as well.

Where a section's structure matches the author's earlier private library, that is because this library grew out of it: same author, same copyright holder as this package's LICENSE, and no third-party licensed text is incorporated.

