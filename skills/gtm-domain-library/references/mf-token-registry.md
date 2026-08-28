# Market-fact slot registry

This file is the whole inventory of the library's market-number slots, plus the contract each fill has to satisfy. Every figure that fills a slot was filled through one of them and points back to its slot. The library also carries figures that fill no slot, and those carry their source and tag inline instead: either way, no figure travels without its evidence. If you are filling this library from research, this is the only file you need to work from.

## Slot form

```
{{MF:<topic>.<key>}}
```

- `<topic>` names the research area the number comes from.
- `<key>` names the specific quantity.
- The braces make live slots mechanically findable. A slot written **without** braces (`MF:t1.marketplace_m2_open`) is a reference to the slot, used in the per-section contract tables, and is deliberately left alone by the fill pass so those tables survive as documentation.

## Topics

| Topic | Research area |
|---|---|
| `t1` | Retention benchmarks, cohort type stated on every number |
| `t2` | Interview recruiting conversion, reply rate and completion rate kept separate |
| `t3` | Time-to-first-value norms by product class |
| `t4` | Free-to-paid and membership conversion |
| `t5` | Consumer pricing and packaging norms |
| `t6` | Launch-channel effectiveness for consumer products |

## The inventory

The **Live occurrences** column records how many braced slots each entry had before the fill pass. All eleven are now resolved, see *Fill state* at the bottom of this file, so the column is the inventory's history, not a live count. The only braced form left anywhere in the library is the grammar example above, which uses `<topic>` and `<key>` placeholders and is deliberately never filled.

| Slot | Section | Live occurrences | What the fill must carry |
|---|---|---|---|
| `MF:t3.ttfv_target` | `SKILL.md`, doctrine constants | one | The target elapsed time from first open to first real outcome, for the product class, with the class named. **This is the library's single canonical time-to-first-value constant.** It is stated in exactly one place and referenced everywhere else, so the fill must not introduce a second value anywhere. |
| `MF:t1.marketplace_m2_open` | `stage-metrics.md` | one | Second-month return rate, **open cohort**, consumer marketplace. Population, natural usage frequency, year. |
| `MF:t1.subscription_m2_open` | `stage-metrics.md` | one | Second-month return rate, **open cohort**, subscription or membership app. Population, year. |
| `MF:t1.marketplace_m3_closed` | `stage-metrics.md` | one | Third-month return rate, **closed cohort**. The qualifying event that defined the cohort must be stated in the fill itself, not left implicit. |
| `MF:t2.outreach_reply_rate` | `interview-method.md` | one | Reply rate for personalised, problem-first outreach. Audience type and channel. Never a blended recruiting figure. |
| `MF:t2.reply_to_completed` | `interview-method.md` | one | Share of repliers who complete an interview, measured separately from the reply rate. |
| `MF:t4.free_to_paid_rate` | `pricing-value-metric.md` | one | Free-to-paid conversion for consumer products. Product class, the definition of a free user, the measurement window, year. |
| `MF:t4.membership_attach_rate` | `stage-metrics.md` | one | Share of active users holding a paid membership. Product class, the definition of active, year. |
| `MF:t5.annual_prepay_discount` | `pricing-value-metric.md` | one | Typical annual prepay discount, with the category measured. |
| `MF:t5.consumer_price_band` | `pricing-value-metric.md` | one | Typical consumer subscription or membership price band, with the category, the market or region, and the year. Region matters more here than anywhere else in the inventory. |
| `MF:t6.launch_channel_yield` | `launch-anatomy.md` | one | What a launch channel returns for consumer products. Channel named, product class, year, and whether the figure counts reach, installs or retained users. |

Eleven slots, and they live in five sections. Three sections hold no slot of their own: `icp-sharpening.md` and `differentiation-questions.md` and `deal-test.md` are definitional and qualifying frameworks, so no market figure is filled into them as a slot. Where one of them leans on a registry figure it cites that figure in place, with the `§t` pointer, rather than carrying a slot.

## The fill contract

For each slot:

- **Fill from a sourced research record**, one that carries value, population, year, source name, source locator and a method note. A number without a checkable source cannot be tagged `FOUND`.
- **Write the evidence inline, next to the value**, in the form the consuming project's tag lint expects. Confirm that form against the lint's own grammar before writing values; do not invent a citation shape. The tag vocabulary is `FOUND`, `CALCULATED`, `INFERRED`, `CONSTRUCTED`, `HYPOTHESIS`, `NEEDS-CONFIRMATION`.
- **Population beats precision.** A figure measured on a population unlike yours is at best `INFERRED`, and it must say so in the same sentence.
- **Cohort type is mandatory on every `t1` slot** and on any other fill that describes people coming back. The prose around those slots already names open or closed cohort; the fill must agree with the prose rather than contradict it.
- **Do not merge two rates into one.** The `t2` pair exists precisely because collapsing them is the standard planning error.
- **An unresolvable slot renders exactly as:**

```
[HYPOTHESIS: no durable market source found]
```

  Never a bare number, never a plausible-sounding range, never a figure carried over from a framework's original source. Visibly empty beats quietly invented, and a reader who sees the gap can close it.

- **After a fill pass, no live slot should remain** unless it was deliberately left as the hypothesis marker above. Both states are checkable: search for the brace form to find unfilled slots, and read the gap table below to count known gaps; that table is the count of record, because a gap is recorded there rather than pre-rendered into a framework file, so searching the tree for the marker string finds its definition above and not the gaps.

## Why no number is ever borrowed

**No figure in these files was carried over from any other framework write-up or skill pack.** Retention targets, growth-rate norms, conversion rates, price anchors, value multiples, panel sizes, recruiting rates, presence windows and platform field limits exist here only as registry slots filled from sourced research, restated as unnumbered judgment, or left visibly open. Two classes are deliberately unnumbered:

- **Funding-stage growth-rate norms.** No research topic backs them here, and an unsourced growth target is worse than none.
- **Platform field limits** (name, tagline and description caps, image dimensions). They go stale between writing and reading, so `launch-anatomy.md` tells you to check the platform on the day instead.

## Fill state

One fill pass has run against the eleven slots. Every candidate number went through two independent attempts to refute it, wrong population, survivorship, vendor marketing, dead link, and a number either survived both or was struck. Six slots carry a value; five are recorded as gaps in the table below, and render the hypothesis marker when a run reaches them, because the honest answer was that nobody has measured the thing the slot asks for.

**Resolved with a value**

| Slot | What it now carries | Status |
|---|---|---|
| `MF:t1.marketplace_m3_closed` | Month-3 closed-cohort retention for products labelled ecommerce, with the qualifying event and the missing marketplace breakout both named | read this cycle from a named source |
| `MF:t2.outreach_reply_rate` | Two adjacent measured populations, in-product prompt and cold one-to-one outreach, each with its audience, channel and sample | read this cycle from named sources |
| `MF:t2.reply_to_completed` | The attendance leg only, with its denominator stated as scheduled sessions rather than repliers | read this cycle from a named source |
| `MF:t4.free_to_paid_rate` | Freemium and hard-paywall download-to-paid at day 35, with the definition of a free user and the window | read this cycle from a named source |
| `MF:t4.membership_attach_rate` | A spread across two disclosed consumer models, with the arithmetic shown and the member definitions flagged as unpublished | computed from disclosed inputs |
| `MF:t5.consumer_price_band` | Modal and median app-subscription price points worldwide, with the regional disagreement named | read this cycle from a named source |

**Rendered as the hypothesis marker**

| Slot | Why nothing durable exists |
|---|---|
| `MF:t3.ttfv_target` | No published elapsed time-to-first-value figure for any consumer product class. The duration tables in circulation trace to one vendor's own customers or to practitioner opinion, and both were struck on refutation. |
| `MF:t1.marketplace_m2_open` | No open-cohort month-2 return rate is published for a consumer marketplace. What exists is annual repeat purchase on a rolling active base, a different question on a different clock. |
| `MF:t1.subscription_m2_open` | Every published subscription retention benchmark is a closed cohort of subscription starts. |
| `MF:t5.annual_prepay_discount` | The circulating discounts are ratios between medians of two different populations, not offers; the one same-plan study behind them is stale web-billing data. |
| `MF:t6.launch_channel_yield` | No disclosed-sample dataset publishes what a launch post, a community thread, a referral loop or an editorial feature returns, and none splits retention by acquisition channel. The store-surface figures the slot now carries alongside the gap are reach and installs, and are labelled as such. |

Five markers is not a failure of the pass. It is the mechanism working: each one marks a place where a confident number would have been invented, and a reader who needs one of them now knows it has to be measured rather than looked up.
