# Differentiation Questions

When the underlying technology can be bought, copied, or rebuilt inside one release cycle, the capability list stops deciding anything and the system around it starts. This file is the question set for working out where a product actually wins in that situation: which alternatives the customer weighs (including doing nothing), what it costs to arrive and what it costs to leave, what accumulates in an account the longer it is used, and which claims a skeptical evaluator can check without your help. Run it before writing positioning, not after.

## Gate: is the technology actually a commodity here?

Ask one question. Could a competent team reach the same output inside one release cycle using components that are publicly available to buy or download? If yes, every capability claim is parity and belongs in a footnote. If no, write one sentence naming the specific thing that is not reproducible and the reason it stays that way for at least a year. Most teams answer "no" and then cannot write the sentence. That is the answer.

Everything below assumes the answer is yes.

## The method

### Question 1. The alternative set

Fill four slots. An analysis with an empty slot is not finished.

1. **The named product.** The competitor the customer would say out loud.
2. **The manual substitute.** The spreadsheet, the phone call, the group chat, the existing habit.
3. **The thing already paid for.** A feature bundled into a tool they already buy, or an internal build.
4. **Doing nothing.** No purchase, no change, no budget line.

This is the jobs-to-be-done move (Christensen, Ulwick, Klement): the alternative set is everything hired for the same job, not everything in the same product category. Slot 4 wins most often and gets analysed least. It has no switching cost, no procurement, no internal sponsor to recruit, and no risk of anyone looking wrong. BANT-class qualification will not surface it, because BANT asks whether the buyer can buy, not whether they would rather keep doing what they already do.

Two calibration points for how strong slot 4 is:

- Cross-industry month-3 retention has a median of 3.8% of new users, with the source's own gloss that 96% of the median group's new users had churned by the end of the third month [FOUND: a product-analytics vendor's 2025 cross-industry benchmark report, closed first-visit cohort, monthly bracket]. This measures product-analytics activity, not app installs, so do not cross-compare it with install numbers.
- Among consumers in KSA and the UAE who cancelled a video subscription, 21% cited lack of use and 20% cited cost [FOUND: a global consultancy's 2025 Middle East digital-consumer survey, n=2,000 aged 18 to 50, per the fact registry references/mf-token-registry.md §t4]. Non-use is stated slightly ahead of price. Different category from marketplace membership, so read it as directional.

The practical reading: the most common loss is to non-consumption, and non-consumption never appears in a competitor comparison table.

### Question 2. Switching cost, priced in both directions

Produce two numbers, each with the line items that generate it.

**Cost to arrive.** Data movement, re-entry of credentials and settings, retraining hours, the period of running both systems in parallel, the internal person who has to sponsor the change, and the risk that the first attempt goes badly in front of someone who matters. Klement's switch interviews are the cheapest way to get these: ask about the last time they changed something, and record the anxiety and habit that held them, not just the pull that moved them.

**Cost to leave.** What the account forfeits on exit, split into two kinds that behave differently:

- **Earned.** History, calibration, saved configurations, relationships, accumulated standing. The customer built it, so leaving feels like discarding their own work.
- **Imposed.** Export restrictions, penalties, contract terms, formats only you can read. This defers churn instead of preventing it, and it reappears at renewal and in public reviews.

A near-zero cost to leave is a legitimate choice, not an error, but it has a price. One first-party membership page sells at "as low as AED 19/month", monthly billing only with no annual option, two weeks free, cancel anytime [FOUND: a Gulf food-delivery platform's first-party membership campaign page, retrieved 2026-08]. Commitment length tracks with survival: 12 months after purchase, median retention across apps was 3% for weekly plans, 11% for monthly, and 28% for annual [FOUND: a subscription-analytics vendor's one-year retention analysis, 10,000+ apps, closed subscription-start cohort, subscription-level and resurrect-inclusive, so it reads higher than never-lapsed survival]. If you deliberately keep exit friction low, you have chosen to win on Question 3 instead.

### Question 3. The compounding asset

Finish this sentence with something specific:

> In month 12, this customer's account does X that a new account cannot do.

If X is empty there is no compounding, and the product re-earns the subscription every month with nothing carried forward.

Four places compounding usually lives:

- **History.** Past activity that shortens the next action: reorder, restore, prefill, resume.
- **Calibration.** The product fits this account better than a fresh one because it has observed this account.
- **Graph.** Other people, records, or counterparties attached to the account.
- **Earned economics.** Status, rate, credit, or a realised-savings position the customer forfeits by leaving.

Test each candidate with one question: could a competitor reconstruct it in the first session? A saved address can be. Fourteen months of preference-shaped history cannot be.

The prize is concentrated, not average. In one marketplace annual filing, the habitual buyer tier (defined there as spending $200 or more across six or more purchase days in twelve months) was approximately 7% of active buyers and about 40% of merchandise sales [FOUND: one listed marketplace's FY2025 annual filing (Form 10-K), open trailing-twelve-month cohort, in a year when that tier fell 9%, per the fact registry references/mf-token-registry.md §t1]. So the design question is what moves an account into the top tier, not what the average account does.

Paid membership is the common commodity-market answer, and reported penetration is real but loosely defined. One operator reported more than one in four active customers subscribed and a 51% share of platform GMV [FOUND: a listed Gulf food-delivery operator's Q2 and H1 2026 results release, and the release does not state whether subscribers include free trials or bundled seats, per the fact registry references/mf-token-registry.md §t4].
Treat "members of paid loyalty programmes are about 60% more likely to spend more, versus about 30% for free programmes" as an unverified restatement, not a fact [HYPOTHESIS: a global consultancy's 2020 paid-loyalty survey, available only through secondary restatements].

### Question 4. The verifiable claim set

For every claim you plan to make, record where a skeptic looks and how long the check takes. Grade each one.

| Grade | Definition | The check |
|---|---|---|
| 1 | Checkable inside the product, by them, alone | Run the task in the trial and time it |
| 2 | Checkable in a public document | Pricing page, terms of service, filing, changelog, status history |
| 3 | Checkable only with your cooperation | Reference call, guided demo, benchmark under NDA |
| 4 | Not checkable | "Customers love it", ratios with undefined denominators |

Rules:

- Each of your top three claims must carry at least one grade 1 or grade 2 check.
- Grade 4 claims get deleted, not defended.
- A grade 3 claim written to look like grade 2 is worse than an honest grade 3.

Published contracts show the split most clearly. One membership product prints a verbatim monthly price on its own page, which anyone can confirm in under a minute. Another states in its terms that "The membership fee may vary from customer to customer and from time to time", and that free delivery requires a minimum order value "communicated in the app" [FOUND: a second Gulf food-delivery platform's published terms of use, retrieved 2026-08]. The second price cannot be verified by anyone outside the company. That is a packaging decision with a differentiation consequence.

Disclosed metrics hit the same trap. A quarterly release reporting 50 million members "now driving half of our Gross Bookings" gives no definition of a member and no reconciling table [FOUND: a global ride-hailing and delivery operator's Q1 2026 results release]. A number without a definition is grade 3 wearing grade 2 clothes.

Budget the check in minutes, not weeks. Just over half of download-to-paid conversions happen on day 0 (50.6%), and MEA is the fastest region at 63.5% [FOUND: a subscription-analytics vendor's 2026 state-of-subscription-apps report, 115,000+ apps, per the fact registry references/mf-token-registry.md §t3]. Whatever a skeptic cannot verify in the first session is usually never verified.

Note on pricing research: van Westendorp's price-sensitivity questions tell you what a respondent says a price feels like. They do not tell you whether a claim is checkable. Keep the two apart.

### Question 5. One sentence, and the sentence that breaks it

Write the claim in a fixed form:

> Against **[alternative]**, for **[customer in a stated situation]**, [Put Your Company Name] wins because **[mechanism]**, and you can check it by **[grade 1 or 2 check]**.

Then write the falsifier: the observation that would show the mechanism is not working, with a threshold and a date. A differentiation claim with no falsifier is a slogan.

## Routing: what the answers mean together

| Compounding (Q3) | Cost to leave (Q2) | Best check (Q4) | What to do next |
|---|---|---|---|
| Present | Earned | Grade 1 or 2 | The differentiation is real. Spend on getting accounts to first use, because compounding starts only after it. |
| Present | Earned | Grade 3 or 4 only | A product problem dressed as a messaging problem. Instrument the mechanism so the customer can see it themselves. |
| Absent | Low | Any | You compete on price and distribution. The next decisions are packaging and channel, not features. |
| Absent | Imposed | Any | Churn is deferred, not avoided. Expect it at renewal and in public reviews. |

## Errors that pass review

1. **Naming three competitors and stopping.** The alternative set is not finished until doing nothing has been priced against the others.
2. **Treating the feature comparison table as the analysis.** That table measures the commodity, which is the part that does not decide.
3. **Pricing switching cost only inbound.** Sales forecasts the arrival cost; renewal is decided by the exit cost; most teams have never written the second number down.
4. **Confusing a barrier with an asset.** A contract that makes leaving painful and a history that makes staying useful both raise churn resistance. Only one of them survives a competitor offering to cover the exit cost.
5. **Reading penetration as conversion.** A members-to-monthly-actives ratio is a ceiling under the most generous definition of a member. One published pair works out at roughly 62.5%, computed from two "over X" floors, with members including trials and partner-bundled seats [CALCULATED from a US delivery platform's Q4 2025 results release]. Comparing that against a paid-conversion benchmark compares two different quantities.
6. **Shortening the trial to force a decision.** Trials of 4 days or fewer are now 46.5% of apps and convert worst at 25.5% median trial-to-paid, against 42.5% for trials of 17 to 32 days [FOUND: the same 2026 state-of-subscription-apps benchmark set, per the fact registry references/mf-token-registry.md §t5]. This is a between-apps comparison, not a controlled test, so treat it as a decision to take deliberately rather than a rule to apply.
7. **Answering "why do we win" with something only you can measure.** If the proof needs your dashboard, the evaluator's real decision is whether to trust you, which is a different and harder sale.
8. **Assuming the losses were about price.** Pull the last ten losses and separate "chose someone else" from "chose nothing". The two have different fixes and only one of them is competitive.
9. **Mixing cohort types when borrowing a benchmark.** A closed cohort fixes membership at t0 and tracks it forward; an open cohort re-forms its denominator every period [FOUND: a product-analytics vendor's retention methodology documentation, per the fact registry references/mf-token-registry.md §t1]. Numbers from the two are not comparable, and most published figures do not state which they are.
10. **Turning a survey share into an attribution mix.** The widely quoted "51% find apps through friends and family" comes from a multi-select question about ways respondents had ever discovered an app, US sample of 999, fielded in 2016, with options summing far past 100 [HYPOTHESIS: a search company's 2016 discovery survey run with a polling firm]. It supports the existence of word of mouth, not a channel budget.
11. **Declaring a compounding asset before measuring one.** "Our data gets better over time" is a hypothesis until a month-12 account and a month-1 account are compared on the same task.

## Worked example: [Put Your Company Name]

[Put Your Company Name] runs a consumer marketplace app with a paid membership. Search, checkout, payments, and dispatch are all available from vendors, so the gate answer is yes: the technology is a commodity.

**Q1 alternative set.** (1) The competing marketplace app. (2) Ordering direct from the merchant by phone or website. (3) A membership the household already pays for through a bank card or telco bundle. (4) Doing nothing: ordering less often, or cooking. Slot 4 is the largest and is currently unmeasured.

**Q2 switching costs.** Cost to arrive: about 6 minutes to install, enter an address and a card, plus the risk that the first order arrives wrong. Cost to leave: one tap, monthly billing, no annual plan, so the exit cost is close to zero by design and cannot be the moat. That is consistent with the observed regional packaging pattern of fee-elimination benefits, monthly-only billing, and no annual plan (source: pattern read across three GCC membership products; HYPOTHESIS).

**Q3 compounding.** Saved address is weak (a competitor reconstructs it in one session). Order history that makes a repeat basket a two-tap action is medium. A visible realised-savings ledger for the member is strong, because it is earned economics the customer can see. Month-12 sentence: "In month 12 this account rebuilds a 9-item basket in two taps and shows the fees avoided since signup; a new install can do neither."

**Q4 claim grades.** "No delivery fee above the stated basket threshold": grade 2, checkable on the pricing page in under a minute, provided the threshold is actually published. "Members save more than X per month": grade 3 today, and it becomes grade 1 the moment the app shows each member their own realised savings. "One in four of our customers are members": grade 4 until a member definition is published, and it should be cut from external use until then.

**Q5 sentence.** "Against ordering direct and against ordering less often, for a household that places 6 or more orders a month, [Put Your Company Name] wins because the repeat basket takes two taps and the membership fee is repaid by the fourth order, and you can check both inside the free trial." Falsifier: if median member orders per month stays below the break-even order count 60 days after signup, the mechanism is not working. Observation to watch: break-even order count against actual orders, by signup cohort month.

**Routing.** Compounding is present but thin, exit cost is earned and small, and at least one grade 1 check is reachable. That is row 1 of the routing table, so the spend goes to reaching first use fast. The urgency is supported by the day-0 conversion concentration cited in Question 4.

## Evidence bar

Nothing above is trustworthy until each part carries a tag. Use the six-tag vocabulary and apply it per line, not per document.

- **The alternative set** must be FOUND: drawn from interview transcripts, support tickets, or win-loss notes where a customer named the alternative themselves. A set produced in a room without customers is CONSTRUCTED, and must be labelled that way and tested before any plan depends on it.
- **Switching costs** must be CALCULATED from named line items with the arithmetic visible, or marked NEEDS-CONFIRMATION. A single round number with no components is not an estimate.
- **The compounding asset** is HYPOTHESIS until you can show a month-N account and a month-1 account performing the same task with different results in your own data. Sentence-level plausibility is INFERRED at best.
- **Claim grades** are FOUND only when someone outside the company ran the check and it passed. Your belief that a claim is checkable is INFERRED.
- **Every borrowed benchmark** keeps its cohort definition, its population, and its date attached. A number stripped of those is NEEDS-CONFIRMATION regardless of how often it is repeated.
- **A HYPOTHESIS may appear in the analysis, never in an external document as a fact.** If a number carries the HYPOTHESIS tag here, it goes into a board deck or a sales page as an open question with the check named, or it does not go in.

The output of this file is trusted when three things hold: slot 4 of the alternative set has a number against it, the month-12 sentence is filled in and measured rather than asserted, and the top claim carries a grade 1 or grade 2 check that someone outside the company has actually run.
