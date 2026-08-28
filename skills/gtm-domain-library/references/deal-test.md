# Deal Test

An enthusiastic conversation is the cheapest object in go-to-market: it costs the other side nothing to produce and it feels like progress to everyone in the room. This file is a test for deciding whether one specific conversation is a purchase path, by requiring that money, authority, need and timing each be backed by a record that cost the other side something. It also fixes, in advance, the conditions under which you stop, because a deal you should have left consumes the quarter twice, once while you work it and once while you explain it.

## Rule zero: evidence is what the other side spent

A record is something that existed before you asked for it, or that the other side produced at a cost to themselves. Statements are not records, however precisely you write them down. Score signals by what they cost the person who produced them.

| Free signal (worth zero in scoring) | Costly signal (record it) |
| --- | --- |
| "This is exactly what we need" | Their own number for the problem, exported from their system |
| "Budget should not be an issue" | The line item, the amount, and what was last bought from it |
| "I will take it to my manager" | The manager attends a scheduled call and asks about rollout |
| Heavy, delighted free-tier usage | A request for an invoice, a purchase order, or a security review |
| "Send me pricing" | A returned order form, a signed pilot scope, or a card on file |

The base rate under the enthusiasm is unkind. Median download-to-paid conversion by Day 35 is 2.1% for freemium apps against 10.7% for apps with no free tier, a gap of about 5x from the access model alone [FOUND: 2026-edition benchmark, 115,000+ consumer subscription apps, 2025 data, per the fact registry references/mf-token-registry.md §t4].

## The method

1. **Write the deal sentence.** One sentence, no hedges, in their words: who pays, how much, for which outcome, by when. If you cannot write it within an hour of the call, you had a conversation and not a deal, and the honest next step is another conversation rather than a forecast entry.
2. **Split it into four claims.** Money exists. A named person can commit it. The need outranks the other things competing for that money. A date is forced by something outside your control. This is BANT-class qualification, which is old and public. The part that fails in practice is not the four letters, it is that teams record opinions about them instead of artifacts.
3. **Name the artifact before you ask.** For each claim, write down in advance what would prove it and what would disprove it. An artifact you only recognise after it arrives is a rationalisation, because anything that arrives will fit.
4. **Collect and tag.** One ledger row per claim: claim, artifact requested, what arrived, what it cost them, tag, date. Tag against the six-tag vocabulary at the end of this file, and tag before you feel good about the call.
5. **Separate the user from the buyer.** Run the separation questions below. The enthusiastic person and the paying person are frequently different humans with different problems.
6. **Score by count, not by warmth.** Use the gate table. A claim supported only by enthusiasm scores zero regardless of how strong the enthusiasm was.
7. **Set the walk-away line in writing before the next contact.** A pre-commitment made while you are calm is the only defence against the sunk cost you will feel later.
8. **Re-date the ledger every cycle.** Evidence decays. Budget confirmed one buying cycle ago is NEEDS-CONFIRMATION, not FOUND, and a champion who has since changed roles takes their artifacts with them.

## The gate

| Claims carrying a costly artifact | Verdict | Next action |
| --- | --- | --- |
| 4 of 4 | Purchase path | Ask for the order. Stop discovering. |
| 3 of 4 | One named experiment | Design a single test, with a date, whose failure kills the deal. |
| 2 of 4 | Research, not a deal | Keep the relationship, remove it from the forecast, offer no discount and no custom build. |
| 0 to 1 | Walk away | Log the missing claim and set a re-check trigger. |

## The free-tier lover and the buyer

- Roughly nineteen of twenty enthusiastic free users are not buyers inside five weeks, on the 2.1% freemium median above [FOUND]. Any argument that starts "but they really love it" has to beat that arithmetic, not ignore it.
- Company-level targets differ by motion: for self-serve freemium, 3% to 5% conversion is described as good and 6% to 8% as great; for sales-assisted freemium, 5% to 7% and 10% to 15%; for free trials, 8% to 12% and 15% to 25% [FOUND: 2023 survey of 1,000+ B2B SaaS products, self-reported, six-month cohort window, per the fact registry references/mf-token-registry.md §t4].
- Paid penetration of monthly actives in public freemium businesses runs from about 8.7% to about 38.6% [CALCULATED from 2025 and 2026 public filings of three global consumer platforms]. There is no single correct number, so choose the comparison whose access model and denominator match yours before you argue about your own.
- The free user is a lead, not a buyer. A free tier drove more than 60% of one large platform's gross added paying subscribers across a 2014 to 2017 window [FOUND: 2018 securities filing, per the fact registry references/mf-token-registry.md §t4]. Count the free base in pipeline and in research, never in forecast.
- Where a payer came from stops mattering once they pay: twelve-month subscriber retention was 28% for freemium and 27% for no-free-tier apps [FOUND: same 2026-edition benchmark, per the fact registry references/mf-token-registry.md §t1]. The free tier buys you volume, not better customers.
- Separation questions, each answerable only with a record: Who is billed, by name and role? Does the free tier already produce the outcome they described? What breaks for them within 90 days if nothing changes? Which budget line does the money leave, and what left that line last?
- The clearest tell that the free tier is the product they actually want: every ask is for more free capacity (seats, limits, trial length), and the stated deadline moves the moment a signature is mentioned.

## Timing is a distribution, not a promise

- More than 60% of paid conversions land by Day 7, and 50.6% of download-to-paid conversions happen on Day 0 [FOUND: 2026-edition benchmark]. Same-day share varies 2.5x across categories, from 71.9% at the top to 28.5% at the bottom, and by region, with the Middle East and Africa at 63.5% against North America at 44.2% [FOUND: per the fact registry references/mf-token-registry.md §t3].
- INFERRED from those distributions: in a self-serve motion, "next quarter" usually means no. Check the stated date against your own conversion distribution before you accept it, and treat any date outside your observed tail as a decline you have not been told about.
- The counter-case matters. Longer evaluation windows convert better as a packaging choice: trial-to-paid is 25.5% for trials of four days or fewer against 42.5% for trials of 17 to 32 days [FOUND: per the fact registry references/mf-token-registry.md §t5]. A request for more evaluation time is therefore not automatically a stall. What separates the two is whether the extra time is scoped, dated, and ends in a named decision by a named person.
- A benchmark summary claims 55% of trial cancellations occur on Day 0. That claim did not survive independent checking, so carry it as a hypothesis [HYPOTHESIS: 2026-edition benchmark summary]. If it holds in your own data, your follow-up sequence is arriving after the decision was already made.
- Commitments attached to a scheduled slot hold better than commitments attached to an inbox: moderated sessions with a live slot showed 8.6% no-shows across 14,210 studies, while asynchronous sessions at the common incentive level lost about 30% [FOUND: 2022 and 2024 research-panel data, per the fact registry references/mf-token-registry.md §t2]. INFERRED for selling, NEEDS-CONFIRMATION in your context: prefer a booked, attended meeting over a promised email.

## Budget: compute it first, then confirm it

- Do not ask whether budget exists. Compute what your price is a share of, then ask what they currently pay for the nearest substitute and what happened at the last renewal.
- Anchor the share against the right wallet. A $10.00 monthly subscription is about 0.34% of the average household's total monthly consumption expenditure in one Gulf market, but about 3.4% of the restaurants-and-accommodation category wallet it actually competes with [CALCULATED from a 2023 household expenditure survey of 122,325 households and a widely reported 2025 global price point, whose median-versus-mode reading is contested across sources; the pricing file's evidence bar carries the disclosure]. The second number is the one that decides.
- Use the median, not the average. In that same market, average household disposable income is about 1.6x the median [FOUND: 2023 household survey, per the fact registry references/mf-token-registry.md §t5]. Sizing budget from an average describes a buyer who is not typical.
- List price is not always the paid price. One market's leading membership states in its own terms that the fee "may vary from customer to customer and from time to time" [FOUND: first-party terms of use, retrieved 2026]. Ask what was paid, not what is published.
- Willingness to pay is a measurement, not an opinion. The van Westendorp price sensitivity questions and the jobs-to-be-done interview tradition (Christensen, Ulwick, Klement) exist for this reason. Both work by asking about a purchase that already happened rather than about a hypothetical one, which is exactly the discipline this test applies to a single deal.

## Walk-away signals worth respecting

- The person who signs will not take a scheduled meeting after two attempts, and the champion supplies a reason each time.
- The stated need cannot be traced to any number inside their own system.
- The date moves at every next step while nothing outside the deal has moved.
- They ask for a custom build, an integration, or a migration before any money is committed.
- Procurement, security or legal will not start "until we see results", and seeing results requires the purchase.
- The free tier already produces the outcome they described, and the only stated reason to pay is fairness, goodwill, or supporting you.
- Nothing has ever been written down by them, including after you ask for it in writing.
- The economics work only at a discount you would refuse the next buyer.

Walking away is an outcome you record, not a failure you hide. Log the claim that failed, the date, and a re-check trigger tied to something real: contract end, funding, headcount, a price change, or a season.

## Errors that pass review

- **Reading confidence as authority.** A champion's certainty is evidence about their intent, not about their signing power. The only thing that settles authority is the signer's own time or the signer's name on a procurement artifact.
- **Reading member-versus-non-member ratios as proof of causation.** Members index at about 2.0x the average customer and about 3.0x a non-member on spend [CALCULATED from 2026 platform disclosures], and a large paid retail membership shows a roughly 2:1 spend ratio described as stable over five years [FOUND: 2022 shopper survey estimate, per the fact registry references/mf-token-registry.md §t4]. Heavy users select themselves into paid tiers, so the ratio mixes selection with effect, and public data does not split them. A separate survey claim that paid programme members are about 60% more likely to increase spend against about 30% for free programmes is unverified on sample and geography [HYPOTHESIS: 2020 consumer survey]. Use these to size an offer, never to argue that a given free user will pay.  <!-- tag-lint:allow-multi -->
- **Porting a lift from one population to yours.** Applying an 11% relative attendance lift measured on clinic appointments to a research panel's 8.3% no-show baseline yields 101.8% attendance, which is impossible [CALCULATED]. When a transfer can exceed 100%, it was invalid before anyone argued about it. Check the denominator and the base rate before importing any benchmark into a deal.
- **Recording the answer to a budget question as budget.** "We have budget" is a statement about optimism. The record is a line, an amount, a period, and the last purchase made from it.
- **Counting the free base as pipeline value.** It is a lead source with a small base rate, and a small base rate has to be multiplied rather than described with adjectives.
- **Believing a date with no forcing function.** A date the buyer can move at no cost is a preference. Renewals, notice periods, audits, seasons, funding events and announced price changes are forcing functions, and price changes do occur after long flat periods: one Gulf membership raised its monthly price by about 53% after nearly five years unchanged [FOUND: 2026 press reporting, per the fact registry references/mf-token-registry.md §t5].
- **Discounting to test interest.** A discount measures price sensitivity across a population, not commitment in one deal, and it destroys the walk-away line you set. Ask for a smaller scope at full price instead.
- **Treating price as the only way a deal dies.** Among consumers who dropped a paid subscription in two Gulf markets, 21% cited lack of use and 20% cited cost [FOUND: 2025 survey of 2,000 consumers aged 18 to 50, per the fact registry references/mf-token-registry.md §t4]. Non-use kills at about the rate price does, so need evidence must name who will use the thing, on which day, for which task.

## Worked example: [Put Your Company Name]

[Put Your Company Name] sells a paid tier of a scheduling and payments product. A team lead at a mid-size regional operator has been on the free tier for seven months, sits in the top decile of usage, and says on a call: "We love this, we want the whole operations team on it next quarter, probably 40 seats."

Deal sentence: the operations director pays a per-seat monthly fee for 40 seats to cut missed appointments before peak season starts.

| Claim | Artifact requested | What arrived | Cost to them | Tag |
| --- | --- | --- | --- | --- |
| Money exists | The line item and amount | "There is budget for tooling" | None | HYPOTHESIS |
| A person can commit it | The operations director on a scheduled call | Director attended 30 minutes, asked about rollout | Their time | FOUND |
| Need outranks alternatives | Their own missed-appointment count for last quarter | Exported report showing 812 missed appointments | Pulled from their system | FOUND |
| A date is forced | Peak season start date and who owns it | "Next quarter, probably" | None | NEEDS-CONFIRMATION |

Verdict: 2 of 4 claims carry a costly artifact, so this is research, not a deal, and it stays out of the forecast.

Free-tier check: the free tier already covers five seats and already produces the outcome described. What changes at 40 seats is administration and reporting, not the outcome, so the buying reason is scale. Scale is owned by whoever owns headcount, not by the enthusiastic team lead [INFERRED].

The single named experiment: ask the operations director, in writing and by a fixed date, for the peak season start date and the budget line for the tool this replaces. If both arrive, the ledger reaches 4 of 4 and [Put Your Company Name] sends the order form. If either does not, [Put Your Company Name] leaves the free account alone, sets a re-check one month before peak season, and moves the selling time to a deal that already has four artifacts.

Walk-away line, written before the next contact: if the director has not put the date and the budget line in writing by the fixed date, [Put Your Company Name] stops selling into this account and re-checks at the season trigger.

## Evidence bar

This output is trusted only after all of the following hold.

- Every ledger row carries exactly one tag and a date. **FOUND**: an artifact you have seen and can produce on request. **INFERRED**: a conclusion you drew from artifacts you hold, with the artifacts named. **CONSTRUCTED**: a figure assembled from parts, with the parts listed. **CALCULATED**: arithmetic on stated inputs, with the inputs shown. **HYPOTHESIS**: a claim someone asserted with nothing behind it, including your own reasonable guess. **NEEDS-CONFIRMATION**: was FOUND once and has aged past one buying cycle, or came from one side only.
- No claim is tagged FOUND on the strength of a verbal statement, including one you transcribed accurately.
- The gate is scored on FOUND rows only. INFERRED and CONSTRUCTED rows may shape the next action; they never move a deal into the forecast.
- Every external benchmark used as a target has been matched to your own population on four dimensions before use: access model (free tier or none), region, category, and denominator (installs, monthly actives, or accounts). Access model alone moves the figures about 5x and category alone moves same-day conversion share about 2.5x [FOUND: per the fact registry references/mf-token-registry.md §t4 and §t3], so a mismatch is not a rounding error.
- Claims tagged HYPOTHESIS in this file, specifically the Day 0 trial-cancellation share and the paid-programme spend uplift, are not load-bearing anywhere in your gate. If either has become load-bearing, replace it with your own measurement or remove the rule that depends on it.
- Any figure older than one buying cycle in your market is downgraded to NEEDS-CONFIRMATION regardless of how well sourced it was when collected.
- Source descriptors here name population, size and year rather than publisher. If you cannot produce the underlying citation on request, downgrade the number to NEEDS-CONFIRMATION before you put it in front of a customer.
