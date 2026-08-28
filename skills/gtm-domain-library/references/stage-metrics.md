# Stage metrics

Most funnel dashboards fail not because the numbers are wrong but because each stage is measured with a number that cannot go down. This file sets one rule per stage: name the user state change, pick one fraction whose denominator you can count, stamp it with its cohort type and window, and pair it with the slower number it claims to predict. The last section gives the test that decides whether acquisition spend is a growth lever or a way to pour traffic into a bucket that still leaks.

## What makes a metric honest

A stage metric is honest when all four hold. If any one fails, the number is decoration.

1. **The denominator is a population you can name and count.** "Users" is not a population. "Accounts created between the 1st and the 7th, from source X, in market Y" is.
2. **The numerator is something the user did**, not something you sent. Sends, impressions, emails delivered and pushes fired measure your effort, not their response.
3. **Numerator and denominator sit in the same window and the same population.** A ratio across two different populations is not a rate, it is a coincidence.
4. **The number can go down.** Any cumulative total (installs to date, registered accounts, GMV since launch) is a counter. Counters cannot fail, so they cannot inform a decision.

## The method

### Step 1. Cut the funnel where the user's state changes

Cut at user state changes (saw it, joined, got value once, came back, paid, still here), not at your team's handoffs (marketing to product to lifecycle). Handoff-shaped funnels produce metrics each team can win while the whole thing shrinks.

### Step 2. Write one metric per stage, denominator first

One. Not three. A stage with three metrics has none, because the stage review becomes a search for whichever of the three moved. Write the denominator before the numerator; it forces the population question first.

### Step 3. Stamp four labels before you read any retention-shaped number

Nothing downstream is comparable until these are on the page:

- **Cohort type.** A closed cohort fixes membership at t0 (installs, signups, or subscription starts in a window) and tracks that same set forward. An open cohort re-forms its denominator every period (actives at period start) and so blends new, retained and reactivated users. Reference definition [FOUND: product-analytics vendor documentation, retrieved 2026-08-14, per the fact registry references/mf-token-registry.md §t1].
- **The retained test.** Independent of cohort type: exact-day/bounded (returned on day N), rolling/unbounded (returned on day N or any time after), or bracket (returned inside a range, for example "in month N"). On the same closed cohort, unbounded always reads higher than bounded [FOUND: same documentation, per the fact registry references/mf-token-registry.md §t1]. Exact-day suits daily-use products; rolling suits sporadic-use products such as ordering apps.
- **The window.** A retention number with no window is not a measurement.
- **The population.** Product-analytics event panels, install panels and subscription-billing panels are different universes and their category labels do not cross-walk.

The size of the error this prevents: cross-industry month-1 retention on a closed first-visit cohort with monthly bracket counting has a median of 6.5% and a top-decile of just over 26%, and at month 3 a median of 3.8% against a 90th percentile of 18.5% [FOUND: 2,600+ companies, all industries, data Sept 2023 to Sept 2024, per the fact registry references/mf-token-registry.md §t1]. Closed install cohorts on a different panel read day 1 at 25.4% (iOS) and 20.2% (Android), falling to day 30 at 5.3% and 3.8% [FOUND: MMP network averages as republished 2026-07-14, underlying quarter not named, per the fact registry references/mf-token-registry.md §t1]. Neither set is wrong. Placing them on one chart is.

### Step 4. Pair every leading metric with the lagging metric it claims to buy

A leading metric earns its place only when you have shown, in your own data, that its movement precedes movement in the paired lagging metric. Two facts set the bar:

- Products in the top group on a day-7 return test were also in the top group at three months 69% of the time [FOUND: 2,600 companies / 10,600 products, same window, per the fact registry references/mf-token-registry.md §t3]. Note what this is: co-occurrence of top-quartile membership, not a measured causal effect size.
- The counter-case: apps behind a hard paywall convert installs to paid at roughly 5x the freemium rate by day 35 (10.7% against 2.1% medians), and yet 12-month subscriber retention lands at 27% and 28%, a difference the source itself calls negligible [FOUND: 115,000+ apps, 2026 edition, data mostly 2025, per the fact registry references/mf-token-registry.md §t4]. A 5x gap in the leading metric bought no difference in the lagging one.

So write, next to each pair, the **break condition**: the observation that would tell you the pair has decoupled. Then check it quarterly.

### Step 5. Run the leak test before the spend test

See the dedicated section below.

### Step 6. Set the re-baseline trigger

Levels move when mix moves; structure survives longer than level. One vendor restated its own global category cost-per-install for 2024 by roughly 3.4x between two consecutive report editions ($3.44 then $1.00) [FOUND: two PDF editions of the same trends report, per the fact registry references/mf-token-registry.md §t6].
Two vendors that both publish their method disagree by 3.5x on the paid-versus-organic split of the same vertical and year [CALCULATED: 0.54 ratio against an implied 1.91 from a second network's organic share]. Rule: use borrowed numbers for structure and ordering within one source, never for absolute level across sources, and re-baseline your own series whenever market mix, channel mix or plan mix changes.

## The stage ledger

| Stage | User state change | The one metric (denominator first) | Cohort | Paired lagging metric |
|---|---|---|---|---|
| Reach | Saw the offer | Store-page or landing views in one market and window that start a signup | Open by nature | Cost per activated user, not per install |
| Acquisition | Created an identity | First-time visitors from one named source who create an account, same window | Closed by source and week | Share of that source's cohort still active at month 3 |
| Activation | Got value once | Share of a closed signup cohort completing the first value event inside a fixed window | Closed | Repeat rate of the same cohort |
| Repeat | Came back unpaid | Share of the same cohort with a second value event in window 2, excluding paid re-engagement | Closed | Month-6 survival of the cohort |
| Monetization | Paid | Share of the closed cohort that pays by day N, N fixed in advance | Closed | Revenue per acquired user at a fixed day marker |
| Durability | Still here | Cohort share active in month N, or renewal stated as "cycle N renewal" | Closed | Contribution of the durable tier to total volume |

Two notes on the Durability row. First, renewal at the first billing cycle is not month-12 retention: category medians for a shopping-class app run 58% (monthly plans) and 30% (annual plans) at cycle 1, rise 25 to 30 points between the first and second renewal, and converge into a 74% to 91% band by the third [FOUND: 115,000+ apps, 2026 edition]. Second, plan duration dominates the headline: 12-month retention on a closed cohort of subscription starts runs about 3% weekly, 11% monthly, 28% annual [FOUND: 10,000+ apps, published 2022, updated 2024]. A mix shift toward annual plans raises "retention" with no behaviour change at all.

## The leak test

Three gates. Acquisition spend is premature if any answer is no.

**Gate 1. Does the newest complete closed cohort's curve flatten?**
A curve that is still falling at the horizon you care about means added users decay at the same rate as the ones you have. Flattening is the evidence that a retained core exists. Practitioner goalposts for six-month retention on a consumer transactional product sit near 30% (adequate) and 50% (strong) [FOUND: consensus of roughly 20 growth practitioners plus public filings, published 2020, so six years stale and stated as target thresholds rather than an observed distribution, per the fact registry references/mf-token-registry.md §t1]. Treat them as a shape check, not a pass mark.

**Gate 2. Does value per acquired user clear the price of an acquired user, in the same market and the same window?**
Both sides must use the same day marker. Median revenue per install at day 60 is 8x apart between two monetization models on one panel ($0.38 freemium against $3.09 hard paywall) [FOUND: same 2026 edition, per the fact registry references/mf-token-registry.md §t4], which is the size of the error you make by pricing traffic against a blended average.

**Gate 3. Will the next unit of traffic reach the same population you measured?**
Paid traffic reaches a different population than the organic base it is benchmarked against. Even in the most paid-leaning region measured, organic supplied roughly 61% of e-commerce app installs, against 65% globally [CALCULATED from a published paid-to-organic ratio, 2026 edition, 2025 data]. If your cohort evidence comes from an organic base, it does not license paid volume.

**If a gate fails, the cheaper moves usually sit behind you in the funnel.** Two market facts support looking there first: category-level download volume was roughly flat year on year (up 0.8% to nearly 150 billion) while in-app purchase revenue rose 10.6% [FOUND: vendor market estimates for 2025, per the fact registry references/mf-token-registry.md §t6], and re-engagement budget share moved from 25% to 29% in one year while paid re-engagement conversions grew 22% against 2% growth for acquisition [FOUND: MMP trend reports, 2024 and 2025 editions, per the fact registry references/mf-token-registry.md §t6]. The market is buying depth, not width.

## Errors that pass review

- **Comparing your closed cohort to someone's open cohort.** An open-cohort repeat rate can hold near 48% of active buyers for years while purchase frequency per buyer barely moves (5.0 down to 4.9 over four years) [FOUND: audited annual filings of a listed consumer marketplace, FY2024, per the fact registry references/mf-token-registry.md §t1]. That is a healthy-looking number that describes the survivors, not the intake.
- **Letting the denominator do the work.** One listed freemium app in one quarter reads 9.0% paid over monthly actives and 21.6% paid over daily actives [CALCULATED from disclosed subscribers, MAU and DAU, Q2 2026]. Same company, same day, 2.4x apart from the denominator choice alone. Any conversion benchmark quoted without its denominator is unusable.
- **Reading an install-denominated rate against a trial-denominated one.** Trial-to-paid medians run 25.5%, 37.4% and 42.5% across short, medium and long trial lengths [FOUND: 2026 edition, per the fact registry references/mf-token-registry.md §t4]. Those live in a different universe from the 2.1% install-to-paid median above. Stacking them produces a funnel that leaks 90% at an imaginary step.
- **Treating uninstall as one minus retention.** A 46.1% 30-day Android uninstall rate [FOUND: 2.2K apps, 1.3B installs, data Jan 2023 to Nov 2024, per the fact registry references/mf-token-registry.md §t1] does not imply 53.9% retention. Apps sit installed and dormant, so uninstall understates abandonment.
- **Treating speed as health.** One region records 63.5% of its paid conversions on day 0, the fastest of any region, and is also the only geography with negative median subscription revenue growth, at -9.7% [FOUND: both from the same 2026 edition, per the fact registry references/mf-token-registry.md §t4]. Fast deciding is not growing.
- **Counting reinstalls as acquisition.** On one major store, weekly redownloads run about 2.21 per new download [CALCULATED from a platform transparency report, 2025]. A launch plan that reads its install counter as net-new demand is sizing the wrong market.
- **Averaging a right-skewed duration.** Average time to first purchase for a set of e-commerce apps is 3.6 days after install, explicitly an average and explicitly excluding marketplaces and grocery [FOUND: 1.6K apps, data Oct 2022 to Apr 2024, per the fact registry references/mf-token-registry.md §t3]. Averages of skewed durations overstate the typical user. Use the share-inside-a-window form instead: for example, more than 60% of paid conversions land by day 7 and 50.6% on day 0 [FOUND: 2026 edition, per the fact registry references/mf-token-registry.md §t3 and §t4].
- **Adopting a magic number from a talk.** Widely repeated activation thresholds and one famously cited "N connections in M days" rule survive only as secondhand transcriptions with no published dataset [HYPOTHESIS: no methodology, no sample, single company, attributed to a 2012 conference talk]. Derive your own activation window from your own cohorts.
- **Optimising a membership ratio you cannot compare.** A membership base can reach 62.5% of monthly actives under the most generous definition, where both inputs are "over X" floors and members include trials and bundled partnership seats [CALCULATED: from a Q4 2025 results release]. That is a ceiling, not a conversion rate.
- **Reading a member-value index as causation.** Subscribers running about 2.0x the average customer and 3.1x a non-member on volume [CALCULATED: from a regional marketplace's Q2 2026 release, where subscribers are more than 25% of customers and 51% of volume] is a selection result before it is a program result. Heavy users join memberships.

## Worked example: [Put Your Company Name]

A consumer marketplace app, one market, planning a paid push. The same ledger applies unchanged to a food ordering, pet services, fintech or AI product; only the value event changes.

The value event is defined as the first completed order. The cohort is all accounts created in one calendar week from one named source, closed at t0, bracket counting.

<!-- tag-lint:allow-multi start -->

| Stage | Metric as written | [Put Your Company Name] reading | Outside band, for shape only |
|---|---|---|---|
| Activation | Share of the week's signup cohort with a first completed order by day 14 | 11% [CONSTRUCTED: illustrative placeholder, not measured] | Top-quartile activation proxy sits near 7% day-7 return [FOUND: per the fact registry references/mf-token-registry.md §t3] |
| Repeat | Share of the same cohort with a second order by day 30, paid re-engagement excluded | 24% of activated [CONSTRUCTED] | Repeat-buyer share of an open active base runs near 48% [FOUND: per the fact registry references/mf-token-registry.md §t1], not comparable, different cohort type |
| Durability | Share of the same cohort ordering in month 3 | 4% [CONSTRUCTED] | E-commerce month-3 closed-cohort median 2.8%, top decile 18.9% [FOUND: per the fact registry references/mf-token-registry.md §t1] |

<!-- tag-lint:allow-multi end -->

Reading. The month-3 figure sits above the median band and far below the top decile, so the product retains, weakly. Gate 1 is a maybe: the curve must be shown to flatten between month 2 and month 3 before it counts. Gate 2 cannot be answered yet, because revenue per acquired user at day 60 has not been computed on the same cohort. Gate 3 fails outright: the cohort came from an organic source, and the planned push is paid.

Decision. Hold the spend. Two prior stages are cheaper: activation (89% of the cohort never reached first value) and repeat (76% of those who did never came back). One qualifier to write down: the durable tier may already carry the volume. In one listed marketplace, roughly 7% of active buyers accounted for about 40% of volume [FOUND: FY2025 annual filing, per the fact registry references/mf-token-registry.md §t1]. If that shape holds here, the honest target is the size of the durable tier, not the average.

## Evidence bar

Before any stage ledger is used to move money, each cell must carry one of six tags, and the reader must be able to see which.

- **FOUND.** Taken from a named source with a stated population, window and definition. Every borrowed number in this file that carries this tag also carries its population and data window, because a benchmark without both is not FOUND, it is folklore.
- **INFERRED.** Your reading of a source that did not state the thing directly. Legitimate, but the inference step must be written next to it.
- **CONSTRUCTED.** Built for illustration or modelling, not measured. Every [Put Your Company Name] figure above is CONSTRUCTED. Constructed numbers must never migrate into a slide as if measured.
- **CALCULATED.** Arithmetic on stated inputs, valid only when all inputs share one source, one cohort basis and one window. Cross-source arithmetic is not CALCULATED, it is invention.
- **HYPOTHESIS.** Plausible, unverified, or from a source that will not disclose its sample. Renders as a question to test, never as a fact. Example of correct rendering: a widely circulated regional claim that 56% of Android apps in one Gulf market are uninstalled within a month is HYPOTHESIS, because the underlying report is not named and the figure sits well above that vendor's own published global rate.
- **NEEDS-CONFIRMATION.** Load-bearing and currently unverifiable. Blocks the decision it supports until resolved.

The ledger is trusted only when all of the following are true.

1. Every retention-shaped cell states cohort type, retained test, window and population.
2. No two numbers on one chart come from different cohort types or different panels.
3. Every leading metric has a named lagging pair and a written break condition.
4. All three leak gates are answered with your own cohort data, not with borrowed bands.
5. Borrowed numbers are used for ordering and shape within one source, never as an absolute target across sources.
6. Known blanks are written down as blanks. Three that recur: no published cohort-typed retention curve exists for Gulf consumer marketplace apps at any grain finer than a combined Middle East and Africa bucket; no source separates demand-side from supply-side marketplace retention; and no published elapsed time-to-first-value benchmark exists for two-sided consumer marketplaces in duration form. Those are NEEDS-CONFIRMATION against your own data, not gaps to fill with the nearest adjacent number.
