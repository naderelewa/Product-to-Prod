# Pricing and the Value Metric

A value metric is the unit your bill scales with, and it is the single pricing decision that outlives every other one: tiers, discounts and packaging can be rewritten in a quarter, but changing what you charge per is a migration. This file covers how to choose that unit, how to cut tiers at moments the customer has actually earned, where to put the free line and why, and how to climb an evidence ladder for willingness to pay instead of settling it in a room. Numbers below are illustrations of the method, each carrying its source class, population, vintage and evidence tag; substitute your own market's data before using any of them.

A note on sourcing: sources here are identified by publisher class, population and vintage rather than by brand, so the method stays industry-neutral. Any number you carry into a real decision should be re-fetched with its full citation attached.

## The method

### Gate 1: list the candidate units before you argue about price

Price level is the last question, not the first. Write the candidates first, in four families:

- **Customer-outcome volume**: orders completed, transactions cleared, claims settled, documents processed, animals or accounts under care, questions answered.
- **Access breadth**: seats, locations, brands, channels, environments.
- **Outcome share**: a percentage of the value created (share of transaction volume, share of the savings, share of recovered spend).
- **Flat access**: one price, unmetered.

Then screen every candidate against five tests. A unit that fails test 2 loses to a worse-correlated unit that passes it, because a bill the buyer cannot predict is renegotiated every cycle.

1. **Correlation**: does the unit rise when the customer's own outcome rises?
2. **Legibility**: can the buyer count it before the invoice arrives, without a dashboard lesson?
3. **Fairness under variance**: does a heavy month feel earned, or punitive?
4. **Non-gaming**: can the buyer suppress the count without giving up the value?
5. **Metering cost**: can you count it accurately at low engineering and low dispute cost?

### Gate 2: decide whether one unit carries the whole bill

Most durable structures use two units, not one. A marketplace can put the usage correlation on a transaction take rate and put the customer relationship on a flat membership, which trades correlation for legibility on purpose. Public disclosure from one MENA on-demand marketplace shows the shape: its membership-fee line moved from 0.6% of marketplace volume in Q2 2025 to 1.0% in Q2 2026 [FOUND: listed-company quarterly release, Q2/H1 2026, per the fact registry references/mf-token-registry.md §t4], which works out to roughly +86% membership-fee revenue against roughly 11% volume growth [CALCULATED: subscription-fee share multiplied by disclosed GMV, both quarters]. Under a flat fee the bill grows with penetration, not with any one customer's usage. That is a choice, not a mistake, as long as you know which of the two units you expect growth to come from. <!-- tag-lint:allow-multi -->

### Gate 3: place the free line at a mechanism, not at a feeling

The question is not "free or not". It is: which side of the first earned-value moment does the line sit on, and what does free buy you that a trial does not.

What the aggregate says, from a subscription-platform benchmark covering 115,000+ apps, 2025 data:

- Day-35 install-to-paid conversion is about 10.7% median where access is gated versus about 2.1% where a free tier exists, roughly 5x, with a gated-model 90th percentile of about 38.7% [FOUND: per the fact registry references/mf-token-registry.md §t4]. Ship the labelling conflict alongside it: the report page calls this pair download-to-paid while the same publisher's digest calls the identical pair trial-to-paid, and the download reading is the only coherent one, since free-tier apps largely run no trial.
- Revenue per install at day 60 is about $0.38 for free-tier models versus about $3.09 for gated ones, roughly 8x; at day 14, about $0.27 versus about $2.32 [FOUND: same population, per the fact registry references/mf-token-registry.md §t4].
- Twelve-month subscriber retention is about 28% for free-tier models versus about 27% for gated ones [FOUND: same population, per the fact registry references/mf-token-registry.md §t1]. The free line moves **who starts paying**, not **how long they stay**.

The counterweight is real. One audio-streaming platform's registration filing credits its ad-supported tier with more than 60% of gross added premium subscribers over the tracked period [FOUND: SEC F-1, covering 2014 to 2017]. Free earns its place when the free tier *is* the acquisition surface. So the rule is a mechanism test: name how free produces paid (network density, supply liquidity, referral, indexable public output, category habit). If the only answer is "so they can try it", a trial does that with a fixed expiry and better unit economics.

Publish the denominator with every conversion number. One consumer learning app's own quarter reads 9.0% paid over monthly actives and 21.6% paid over daily actives, a 2.4x swing from denominator choice alone [CALCULATED from that company's disclosed subscriber, MAU and DAU figures, Q2 2026].

### Gate 4: cut tiers at moments where value has already landed, and size the window to reach them

A tier boundary should sit at a moment the buyer reaches on their own and can feel. Feature-count boundaries get gamed: the buyer lands on the cheapest tier containing the one feature they need, and nothing about their growth ever moves them up.

The window matters as much as the boundary:

- Trial-to-paid rises with trial length: about 25.5% median at 4 days or fewer, 37.4% at 5 to 9 days, 42.5% at 17 to 32 days, a 17-point spread [FOUND: same 115,000-app population, cohorted by trial length, per the fact registry references/mf-token-registry.md §t5].
- Yet 4-day-or-shorter trials are 46.5% of apps and rising (+4.4pp year over year) while 17-to-32-day trials sit at 5.0% and falling [FOUND: same population, per the fact registry references/mf-token-registry.md §t5]. The market is moving toward the worst-converting length [CALCULATED by joining the two series from that one population].
- About 7 in 10 apps offer a trial at all; global median trial-to-paid is about 27.8% [FOUND: second subscription platform, 16,000+ apps, 2025, per the fact registry references/mf-token-registry.md §t5].
- Timing is compressed. More than 60% of paid conversions land by day 7 under both access models [FOUND: per the fact registry references/mf-token-registry.md §t4]. Trial starts are near-entirely same-day, about 89.9% on day 0 in business categories and 82.1% in health and fitness [FOUND: per the fact registry references/mf-token-registry.md §t3]. In one region grouping that includes Saudi Arabia and the UAE, 63.5% of paid conversions land on day 0, the fastest of any region reported [FOUND: per the fact registry references/mf-token-registry.md §t4].

If your first earned-value moment takes ten days to reach and your trial is four, you priced a promise rather than a value moment.

Plan duration is packaging, not billing administration. Twelve-month retention by plan duration runs about 3% weekly, 11% monthly, 28% annual [FOUND: closed cohort of subscription starts, 10,000+ apps, roughly 2022 vintage, app-level medians, per the fact registry references/mf-token-registry.md §t1]. First-renewal medians in shopping categories run about 58% monthly, 51% weekly, 30% annual [FOUND: closed cohort at billing cycle 1, 2026 benchmark set, per the fact registry references/mf-token-registry.md §t1].

### Gate 5: climb the willingness-to-pay ladder, and record which rung you stopped on

Rung 0 is where most prices are set, and it carries no evidence weight.

| Rung | Method | What it proves | What it cannot prove |
|---|---|---|---|
| 0 | Conference-room number | Nothing | Anything |
| 1 | Competitor price scrape | The anchor buyers have already seen | What they would pay you |
| 2 | Stated-preference survey, van Westendorp-class four questions (too cheap, a bargain, expensive, too expensive) | A plausible range and its shape | Behaviour, since nothing was at stake |
| 3 | Deflected purchase intent: real price, real traffic, intent captured, sale then declined or the charge held | That the click cost the buyer something | That money would actually clear |
| 4 | Live price test with money moving, randomized cells, read on retained revenue and not conversion alone | Real demand at a real price | Whether it still felt earned later |
| 5 | Renewal behaviour at that price | Whether the bill still felt earned after the value showed up | Prices you never tested |

Rung 1 has a failure mode worth naming: for some product classes a published price does not exist at all. One KSA delivery membership's own terms state the fee "may vary from customer to customer and from time to time" and is set in-app [FOUND: first-party terms of use, retrieved 2026-08-14], which makes every third-party figure for it unciteable. Confirm a competitor price is a price before you anchor on it.

The operating rule: never let a rung-0 or rung-1 number set a price that a rung-4 test could settle inside a quarter, and write the rung next to the price in the document, because six weeks later nobody remembers where it came from.

### The affordability check nobody runs

A price is a share of somebody's month, and the same number lands differently on different households. Applying a $10.00/month global median to one national household expenditure survey: about 0.34% of Kingdom-wide average household monthly consumption, about 0.23% for national households, about 0.67% for expatriate households, so the expatriate household feels the same price about 2.9x as heavily [CALCULATED: global median price at the standing fixed 3.75 local-currency-per-USD peg, over 2023 survey averages, n=122,325 households; the **ratio** is the durable input, the absolute percentage mixes a 2025 price with a 2023 base]. Against the category wallet it actually competes for, restaurants and accommodation at about 11.7% of household monetary consumption or roughly 1,103 in local currency per month, the same price is about 3.4% of that category wallet [CALCULATED: with the caveat that a Kingdom-wide division share is applied to nationality-specific totals, which the survey does not establish].

Observed regional anchor: two citable GCC marketplace memberships price at AED 19 to AED 29 per month, about US$5.17 to US$7.90, which is 52% to 79% of the $10.00 global median monthly app subscription [CALCULATED at the standing 3.6725 AED/USD peg; n=2 products, a pattern indication and not a market median].

Price-level anchors from the 115,000-app population: modal prices are round numbers rather than charm points, with modal monthly at exactly $10.00, modal weekly $5.00, modal annual $30.00 [FOUND: per the fact registry references/mf-token-registry.md §t5]; annual median $34.80, mode $30.00, 90th percentile $90.00 [FOUND: per the fact registry references/mf-token-registry.md §t5].
The monthly **median** is contested in verification between $8.00 and $10.00, with $10.00 confirmed only as the mode [HYPOTHESIS].

## Errors that pass review

1. **Choosing the unit that is easiest to meter.** Metering cost is a constraint, not a criterion. This is how you end up billing for API calls when the customer buys resolved cases.
2. **Choosing a unit that grows when the customer is failing.** Support tickets, retries, duplicate storage, minutes spent inside the tool. The bill rises exactly when they are unhappy, and the renewal conversation writes itself.
3. **Cutting tiers by feature count.** Feature lists invite the buyer to find the cheapest box containing their one requirement. Nothing about their success then moves them upward, so expansion revenue has to be sold rather than earned.
4. **Copying a competitor's free line.** Both outcomes in the data are real: gating converts about 5x better on day 35, and a free tier supplied more than 60% of one platform's gross premium adds [both FOUND]. Copying either without naming your own mechanism copies a result you cannot reproduce.
5. **Reading a cross-median ratio as a discount.** Dividing a population's annual median by its monthly median gives about 3.48x [CALCULATED], and the "annual saves 71% to 75%" claim built on that is an artefact of two different product mixes, not an offer anyone makes.
6. **Shortening the trial because conversion feels slow.** The data runs the other way: about 25.5% at 4 days or fewer versus about 42.5% at 17 to 32 days [FOUND: per the fact registry references/mf-token-registry.md §t5]. Short trials look efficient because they compress the reporting window, not because they earn more.
7. **Quoting a conversion rate without denominator, window and cohort type.** A 2.4x swing appears inside one company's own quarter from the denominator alone [CALCULATED].
   Separately, the widely-repeated "3% to 5% is a good freemium conversion" band comes from a 1,000+ product B2B software survey measured on a 6-month cohort window [FOUND] and is not comparable to a 35-day consumer install-to-paid median.
8. **Holding price for years, then correcting in one step.** One GCC membership moved from AED 19 to AED 29, about +53%, in a single change, its first in nearly five years [FOUND: national newspaper, 2026, per the fact registry references/mf-token-registry.md §t5]. The size of the step is the interest on the years of not testing.
9. **Treating penetration multiples as causal uplift.** Members indexing roughly 1.9x to 2.0x the average customer and 2.7x to 3.1x a non-member [CALCULATED from two platforms' disclosures] is a correlation. Heavy users subscribe. What you can bank is the change in the same users' behaviour before and after subscribing, not the gap between the two groups.
10. **Testing price on conversion alone.** A mispriced value metric passes the conversion test and fails at renewal, which is rung 5 and the only rung that catches it.

## Worked example: [Put Your Company Name]

[Put Your Company Name] runs a two-sided marketplace where buyers place recurring orders, and it is deciding whether to launch a paid membership.

**Candidates screened.** Orders completed correlates well and is legible, but it charges the heaviest buyer the most, and the heaviest buyer is the one worth keeping. Share of transaction value correlates best of all, but it fails legibility (the buyer cannot predict it) and invites basket-splitting. Seats do not apply. Flat access correlates only with penetration but passes legibility, fairness and metering outright.

**Decision: two units.** The supply-side take rate carries the usage correlation. A flat monthly membership carries the buyer relationship. This is the same split visible in the disclosed marketplace above, where the membership line grew about 86% against about 11% volume growth [FOUND + CALCULATED].

**Free line.** Browsing and the first order stay free, because that is the acquisition surface and the mechanism is nameable: the first order creates the address, payment method and category habit that make a second order cheap. The membership gate sits at the second order, which is the first point at which fee elimination pays for itself.

**Tiers.** One tier at launch. A second tier only if it is defined by a value moment the buyer reaches unaided, such as adding a second product category. That boundary has some support: one marketplace reports a retention uplift of 20 percentage points on subscribing plus a further 16 percentage points when a subscriber adds groceries or pharmacy [FOUND: executive statements on a Q4 2025 earnings call; note the sources disagree between a "26%" relative figure and "20 percentage points", so never quote the uplift without its basis].

**Price.** Start at rung 2 with a van Westendorp-class survey to get a range, then settle it at rung 4 within one quarter. Regional anchor: AED 19 to AED 29 per month, about US$5.17 to US$7.90 [CALCULATED]. Wallet check: about 3.4% of the category wallet it competes for [CALCULATED].

**Trial.** 14 days, not 4, because the value moment is the second order and the median new buyer does not reach it in four days. This costs revenue recognition and runs against where the market is moving [FOUND: per the fact registry references/mf-token-registry.md §t5], and it is supported by the trial-length conversion series [FOUND: per the fact registry references/mf-token-registry.md §t5].

**What must be true, and is not yet known.** That the median new buyer places a second order inside 14 days. Nothing in the public data answers this for [Put Your Company Name]. NEEDS-CONFIRMATION, and it blocks the trial length, the gate placement and the price.

## Evidence bar

Tags used above, and what each one obliges you to ship alongside the number:

- **FOUND**: read from a named primary or platform source. Ships with population, vintage and measurement window.
- **INFERRED**: reasoned from a found fact plus a stated assumption. The assumption ships with it.
- **CONSTRUCTED**: built by joining sources never designed to be joined. The construction rule ships with it.
- **CALCULATED**: arithmetic on found numbers. The formula ships with it.
- **HYPOTHESIS**: plausible, unverified, or refuted in review. Never carried as fact, never load-bearing.
- **NEEDS-CONFIRMATION**: a load-bearing input you do not have. Blocks the decision until answered.

Before this output is trusted:

1. Every conversion or price number carries its **denominator, window and cohort type** (closed at start versus open and re-forming each period). No public source in this material states cohort openness for conversion, so any "conversion cohort" claim you make is CONSTRUCTED at best.
2. Your value metric's correlation to customer outcome is shown **on your own data**, pre and post. Asserted correlation is HYPOTHESIS.
3. Every external benchmark is **off-population until proven on-population**. A 115,000-app subscription-platform median describes app stores, not marketplaces; a B2B software survey band measured on a 6-month window is not comparable to a 35-day install-to-paid median. Both are FOUND and both are off-population for most readers of this file.
4. **Regional read-across is the weakest link.** No published free-to-paid conversion rate exists for GCC or KSA in this material; only region-aggregate timing (63.5% of paid conversions on day 0) [FOUND: per the fact registry references/mf-token-registry.md §t4]. Any regional conversion figure in your plan is HYPOTHESIS until you measure it.
5. **Membership penetration multiples are correlations.** Bankable only as a within-user change. The 1.9x to 3.1x figures are CALCULATED, not causal, and every disclosing company leaves "member" undefined as to paid, trial or bundled.
6. **Any price set below rung 3 is NEEDS-CONFIRMATION, not a decision.** Record the rung next to the price.
7. The 10% to 30% same-plan annual discount band with a 16.7% mode (two months free) is **HYPOTHESIS**: merchant-mixed population, 2018 vintage, refuted in review. Do not let it set your annual price.
8. The monthly-price **median** is contested between $8.00 and $10.00 in a single verification pass; only the $10.00 **mode** is confirmed [FOUND for the mode, HYPOTHESIS for the median]. Ship the mode.
9. Wallet-share figures mix a 2025 price with a 2023 expenditure base. The **ratio** between household types (about 2.9x) is the durable input; the absolute percentages are CALCULATED on a stale base.
10. If you cannot name the mechanism by which free produces paid, the free tier is a cost centre, not a channel. NEEDS-CONFIRMATION before launch.
