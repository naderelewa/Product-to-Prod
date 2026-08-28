# ICP Sharpening

An ideal customer profile is a rule for sorting the world into people this product is built for and people it is not. It earns the word "ideal" only when someone who did not write it can apply it to a list of real people or accounts and reach the same verdict you would, and when the group it selects behaves measurably differently from everyone else in your own data. This file gives a method for writing that rule, for stating the exclusions that make it believable, for separating who pays from who uses, and for testing whether the result was validated or guessed.

## The method

### Step 1. Write the profile as five observable slots

Adjectives are not a profile. Each slot has to be checkable by an outsider.

1. **Role.** What this person is accountable for, in the words they would use, not your category words.
2. **Trigger context.** The situation that makes the problem urgent this month rather than someday.
3. **Shape.** The organisation or household around them: size, structure, geography, how they pay.
4. **Current alternative.** What they use today, including a spreadsheet, a group chat, or nothing.
5. **Observable qualifier.** A threshold you can compute from data you already hold.

Slot 5 is what turns a description into a rule. A published example of the form: one listed consumer marketplace defines its highest-value buyer tier by two observable thresholds inside one window, a currency amount spent plus purchases on six or more separate days in the past twelve months. That tier was 5.9 million people, about 7% of 86.5 million trailing-twelve-month active buyers, and carried about 40% of merchandise volume (FY2025 annual filing) [FOUND: per the fact registry references/mf-token-registry.md §t1]. Two numbers, one window, no adjectives.

Slot 2 is the jobs-to-be-done idea wearing ICP clothing. Christensen's framing of a product being hired for a job, Ulwick's outcome statements, and Klement's attention to the circumstances that push a person to switch all make the same argument: the situation predicts behaviour better than the demographic does. If your profile would still read the same for someone in a calm month and someone in a crisis month, slot 2 is empty.

### Step 2. Test whether the group concentrates value

Rule: if the group you named does not carry more value per member than the rest of the base, you have named a demographic, not an ICP.

Public reference points for the shape to look for:

- A listed Gulf on-demand marketplace reported subscribers at 25% of its customer base and 47% of gross merchandise value for FY2025, with a 28% order-frequency uplift [FOUND: per the fact registry references/mf-token-registry.md §t4].
  That works out to roughly 1.88 times the average customer and roughly 2.7 times a non-subscriber [CALCULATED].
- A listed global ride and delivery platform reported 50 million members against 199 million monthly active platform consumers in Q1 2026, with members driving about half of gross bookings [FOUND: per the fact registry references/mf-token-registry.md §t4]: about 25.1% of consumers at roughly 2.0 times the average and 3.0 times a non-member [CALCULATED]. <!-- tag-lint:allow-multi -->
- A third-party survey of shoppers at one large online retailer put member annual spend near $1,100 against about $500 for non-members, a 2:1 ratio the survey describes as stable across five years (2022 vintage) [FOUND: per the fact registry references/mf-token-registry.md §t4].

Read these as a pattern, not a target. Heavy users select themselves into membership, so concentration tells you the group is worth naming and does not tell you the product caused the behaviour.

### Step 3. Write the exclusions before you write the pitch

Every line on the not-for list needs a reason, and there are only three honest ones.

- **Wrong context.** The trigger never fires for them, so the product is a preference rather than a need.
- **Wrong economics.** The value they can get is smaller than the price, or they have no budget line it can sit in.
- **Wrong shape.** They need something the product structurally will not do, and doing it would break it for the people in the profile.

Rule: a screen that rejects almost nobody is not a screen. A peer-reviewed clinic recruitment study in Qatar with counts at every step approached 1,503 people, of whom 784 (52%) were ineligible before anyone declined, and 319 declined (21% of those approached, 44% of the 719 eligible), leaving 400 enrolled [FOUND: per the fact registry references/mf-token-registry.md §t2]. The population is healthcare, in person, with 2012 fieldwork, so the level does not transfer; the ratio discipline does. The same study is a warning about slots you forgot to write: under one protocol in one city, enrolment ran 32% among Arabic speakers and 18% among Hindi speakers, a 1.8x spread on a dimension the profile did not contain [FOUND: per the fact registry references/mf-token-registry.md §t2].

Price objections are not an exclusion by themselves. Willingness-to-pay instruments in the van Westendorp tradition belong to pricing work; the only price fact that belongs in an ICP is the structural one, that the value on offer is smaller than any price you can charge.

### Step 4. Split the buyer from the user

Write two sentences, not one.

- **The user has to believe:** this gets me through the thing I am doing right now, without new work to remember.
- **The buyer has to believe:** this is worth the money and worth being wrong about in front of other people.

Classic qualification checklists of the BANT type (budget, authority, need, timing) are useful here as a reminder that authority and budget sit with the buyer while need sits with the user. Use them to structure questions, not to score people.

Evidence that the split changes outcomes: in a 2023 survey of more than 1,000 B2B software products, self-serve free-to-paid conversion was characterised as good at 3% to 5% and strong at 6% to 8%, while sales-assisted conversion of the same model was good at 5% to 7% and strong at 10% to 15%, on a six-month cohort window [FOUND: per the fact registry references/mf-token-registry.md §t4]. That population is B2B software and self-reported, so it is not a consumer benchmark; the transferable point is that inserting a human into the buyer's moment moves the number by more than most product changes do.

In consumer products, buyer and user are usually the same person at two different moments, and the buying moment is short. Across a subscription platform covering more than 115,000 apps (2026 edition, 2025 data), more than 60% of paid conversions land by day 7, and in the Middle East and Africa region 63.5% land on day 0 [FOUND: per the fact registry references/mf-token-registry.md §t4].

One more result belongs here. In a survey of 2,000 consumers aged 18 to 50 in Saudi Arabia and the UAE, among people who cancelled a paid service, 21% named lack of use and 20% named cost [FOUND: per the fact registry references/mf-token-registry.md §t4]. Lack of use ranking ahead of price is an ICP result, not a pricing result.

### Step 5. Attach boundary conditions

A profile with no geography, platform or period attached will be applied where it never held.

- Median download-to-paid conversion by day 35 was 2.0% globally, 2.8% in North America, and 0.7% in India and Southeast Asia, a 4.0x gap on the same platform and the same definition [FOUND: per the fact registry references/mf-token-registry.md §t4].
- One listed audio streaming service's paid penetration computes to roughly 60% in North America against roughly 16% in its rest-of-world region, about one quarter the rate, from Q2 2026 chart shares with rounded inputs [CALCULATED].

Same product, same profile words, different economics. Write the boundary into the profile line.

### Step 6. Make the profile findable

A profile you cannot reach is a hypothesis with formatting. Name the channel and the list before you trust it.

Structural evidence from more than 4 million recruiting outreach messages across more than 1,500 organisations, June 2025 to May 2026: direct professional-network messages drew a 17.08% reply rate against 6.31% for human-written email and 4.96% for automated email [FOUND: per the fact registry references/mf-token-registry.md §t2]; messages containing the recipient's first name replied at 5.13% against 2.61% without, observational and confounded with overall sender effort [FOUND: per the fact registry references/mf-token-registry.md §t2]; and the first three touches captured 93.2% of all replies, with more than half arriving after the first message [FOUND: per the fact registry references/mf-token-registry.md §t2]. That population is hiring outreach, so treat the levels as foreign and the structure as portable: who sends and how specific the ask is moves reply rate, and a single-touch invitation forfeits about half of the replies available.

### Step 7. Run four evidence tests

1. **Restatement.** Hand the profile and a list of twenty real names to someone who did not write it. If their yes/no disagrees with yours often, the wording is doing the work rather than the definition.
2. **Screen-out.** Record how many people you approach fail the screen. A near-zero rejection rate means the profile excludes nothing.
3. **Denominator.** Write the funnel with counts at every step: approached, eligible, agreed, scheduled, completed. This is the step most often skipped. A systematic review of 215 studies found the recruitment rate could not be calculated in 77% of them (166), and the proportion eligible out of those screened could not be calculated in 80% [FOUND: per the fact registry references/mf-token-registry.md §t2].
   Plan for the attrition you did not cause: across 14,210 moderated studies run through a paid panel with automated reminders, no-shows ran 8.6% overall, 8.3% for consumer remote sessions and 10.4% for business remote sessions [FOUND: per the fact registry references/mf-token-registry.md §t2].
   Treat that as a floor rather than an expectation for a team emailing its own users, and schedule 11 to complete 10 [CALCULATED].
4. **Behavioural.** The group has to separate in your own product data, not only in conversation. Whole-population averages hide exactly the split you are hunting: install-to-purchase within 30 days ran 9.84% for one-time buyers against 4.64% for repeat buyers across a 2026 monetisation dataset of non-gaming apps [FOUND: per the fact registry references/mf-token-registry.md §t4].

## Errors that pass review

- **Firmographics with no trigger.** Two identical companies, same size, same sector, same stack: one has the problem this quarter and one does not. The profile that cannot tell them apart is a mailing list.
- **A not-for list made of customers you want later.** Writing off a segment you intend to chase in a year is sequencing, not exclusion, and readers can tell. The exclusion that makes a profile believable is one that costs you revenue you could take today.
- **The union of your best customers instead of the intersection.** Collecting every trait your favourite accounts share produces a profile so wide it selects everyone. Sharpening happens on the intersection, then you check that the intersection is large enough to matter.
- **Interviewing whoever answers.** Convenience samples describe reachability, not the market. Among 485 researchers surveyed in 2025, finding enough qualified participants was the top reported challenge at about 61%, with time to recruit at 54% [FOUND: vendor-run census with an interest in the answer, per the fact registry references/mf-token-registry.md §t2]. Easy recruiting is usually a sign you relaxed the screen.
- **Letting the loudest user stand in for the buyer.** The person who files feature requests is rarely the person who signs. Ship what the user asks for and lose the renewal that the buyer never got a reason for.
- **Reasoning from goalposts.** Practitioner consensus published in 2020 from about twenty growth practitioners put good six-month retention for consumer transactional products near 30% and strong near 50% [FOUND: consensus rather than measurement, six years old, per the fact registry references/mf-token-registry.md §t1]. Goalposts frame a conversation. They are not evidence about your group.
- **Quoting a global benchmark to describe a local profile.** See the 4.0x regional conversion gap in step 5. The number is real and it is not yours.
- **Writing the profile once.** It is a rule about a market, and markets move. In the marketplace filing cited in step 1, the top buyer tier fell 9% year over year while the active buyer base fell 3%, and most of those people moved down a tier rather than leaving [FOUND: per the fact registry references/mf-token-registry.md §t1]. A profile with no review date will be quoted long after it stopped being true.

## Worked example: [Put Your Company Name]

[Put Your Company Name] runs a consumer marketplace in one metropolitan market and sells a paid membership on top of it. Swap the nouns for another industry; the slots do not change. Bracketed values are the ones the company fills from its own data.

| Slot | Value | Tag | Basis |
| --- | --- | --- | --- |
| Role | The household member who places and pays for the order, not everyone who consumes it | INFERRED | from single-payer accounts |
| Trigger context | Orders in a category where the delivery fee appears as its own line at checkout | FOUND | in checkout data |
| Shape | Single-metro household, stored card or wallet, no shared corporate billing | FOUND | basis not stated |
| Current alternative | Rotates between [two or three] competing apps, following whichever shows a discount | HYPOTHESIS | until [n] interviews |
| Observable qualifier | Ordered on [six or more] days and spent [threshold] in the last 12 months | CONSTRUCTED | thresholds chosen by the team |

**Not for, with the reason on the line:**

- Households below the frequency threshold. Wrong economics: the fees they would avoid at their current rate total less than the membership price [CALCULATED once fee and price are entered].
- Cash-on-delivery-only households. Wrong shape: no stored payment means no renewal, whatever the value [INFERRED from renewal mechanics, NEEDS-CONFIRMATION against [n] cash-only accounts].
- Office and corporate ordering accounts. Wrong buyer: the payer is a procurement process rather than a person at checkout, and the membership makes a personal-savings promise [HYPOTHESIS].
- Addresses outside the delivery radius. Wrong context, structural and permanent [FOUND from coverage data].

**Buyer and user:**

- Buyer moment: the checkout screen where the fee appears. Has to believe the monthly price is smaller than the fees already being paid at the current order rate. The evidence to put in front of them is their own last-90-days fee total, not a category average.
- User moment: the second and third orders after joining. Has to believe the benefit applies without conditions to remember. If it does not apply automatically, the buyer's arithmetic was fiction.
- These are the same person separated by time rather than identity, and the window is narrow: more than 60% of paid conversions land by day 7 in the platform data cited above, and 63.5% on day 0 in the Middle East and Africa region [FOUND: per the fact registry references/mf-token-registry.md §t4].

**Status of this example:** the profile is CONSTRUCTED from the slot structure. The frequency threshold stays HYPOTHESIS until the value-concentration cut in step 2 is run on the company's own base, and the corporate-account exclusion stays HYPOTHESIS until [n] such accounts are screened.

## The evidence bar

Before this profile is used to point engineering, pricing or spend, every line carries a tag and the whole document clears these gates.

1. **Every slot is tagged.** FOUND means read from your own records or a named external document whose population and period travel with the number. INFERRED means a reasoned step from something FOUND, with the step written down. CONSTRUCTED means you chose it, which is what thresholds and tier names always are, and saying so prevents a choice from being quoted back as a discovery. CALCULATED means arithmetic over stated inputs, with the arithmetic shown. HYPOTHESIS means plausible and untested, and it stays HYPOTHESIS until a test with a date is named. NEEDS-CONFIRMATION means a specific person or dataset can settle it and has not yet.
2. **The observable qualifier is FOUND or CALCULATED, never HYPOTHESIS.** If you cannot compute it against today's data, the profile is not operational yet, whatever else is true about it.
3. **The value-concentration cut is CALCULATED on your own base, denominator printed.** External multiples, roughly 1.9x to 3.0x member versus non-member value in the cases above, are context for the shape of the answer and are not evidence about you.
4. **At least one exclusion is FOUND.** You need people who match the older, looser definition and demonstrably do not get value. An exclusion list made entirely of HYPOTHESIS lines means the profile has never been tested against the market's edges.
5. **The recruiting funnel is written with counts at every step.** Any missing denominator drops the whole profile to HYPOTHESIS regardless of how many conversations were held, which is the failure the 77% reporting review documents.
6. **Conversations came from at least two channels and cleared the screen.** State the number reached, the number that passed, and the number completed, with no-show accounted for rather than assumed away.
7. **Every borrowed number keeps its population and year.** A percentage with no population attached is not evidence, and any figure tagged HYPOTHESIS stays framed as a hypothesis in every downstream document that repeats it.
8. **The profile has a review date.** Anything untested for [two quarters] reverts to NEEDS-CONFIRMATION and stops being usable as a decision input until it is re-run.
