# Launch anatomy

A launch is not an announcement. It is a scheduled experiment that buys one dated cohort of strangers under conditions you control, and its only durable output is what that cohort does after the announcement stops. This file structures the launch so the cohort stays legible: channels picked by where the audience already is, a message that names the problem before the product, a day-of sequence built around the moment value lands rather than the moment the post goes up, and a measurement window declared in advance and read on cohort-typed retention instead of on the spike.

## The method

### 1. Write the launch question first

One sentence, falsifiable, with a date attached. "Does a cold cohort from [channel] reach first value in session one and return in the day 8 to 14 bracket at or above [rate]?" Not "did the launch go well." Write down, before launch day, the result that would make you stop and rebuild rather than scale. A launch that cannot fail teaches nothing.

### 2. Type the cohort before you pick a channel

Decide the shape of the measurement now. It determines what must be instrumented on day zero, and it cannot be reconstructed afterwards. Two independent axes (definitional anchor, FOUND, current documentation of a product-analytics vendor):

- **Membership.** A CLOSED cohort fixes its members at t0, everyone who installed or signed up inside the launch window, and follows them forward. An OPEN cohort re-forms its denominator every period, everyone active at the start of that period.
- **Retained test.** BOUNDED (N-day) counts a return on exactly day N. UNBOUNDED (rolling) counts a return on day N or any day after it. BRACKET counts a return anywhere inside a range, for example days 1 to 3, or "in month 2."

Four rules follow:

- A launch is measured on a CLOSED cohort. Creating a dated population is what a launch is for.
- Unbounded always reads higher than bounded on the same closed cohort. Choose one before launch and never restate in the other.
- Sporadic-use products (ordering, booking, buying) belong on bracket or unbounded counting. Only genuinely daily products belong on N-day.
- Adding a large launch cohort to an OPEN metric mechanically depresses it, because the new members have had no time to repeat. If an open company-level rate is your headline, a successful launch makes it fall. Put that in writing beforehand.

### 3. Choose channels by presence, intent, and traceability

Three gates per candidate. A channel that fails any gate is not a launch channel, though it may still be a brand channel.

**Gate 1, presence.** Is the audience already there, in countable numbers, counted as people rather than as modeled reach? Self-serve ad planners publish inventory estimates that double-count devices and accounts. Any figure exceeding the population it is drawn from is the tell: one late-2025 national ad-reach snapshot lists a video platform at 79.2% of population and a messaging platform at 72.9%, then a short-video platform at 154.3% of the adult population [HYPOTHESIS: platform self-serve estimates, single-country snapshot; the last figure is impossible as a headcount].

**Gate 2, intent.** Is the audience in a state where the problem is live? App stores are permanently in intent mode. About 52% of average weekly store visitors run a search [CALCULATED from a platform owner's 2025 regulatory transparency report: 892,670,823 average weekly visitors, 463,575,966 average weekly accounts that searched, all storefronts, calendar 2025]. Intent shows in conversion, not reach: ads at the top of store search results convert over 60% of taps to installs [FOUND: platform owner's ads documentation, all available markets, Nov 2024 to Oct 2025, per the fact registry references/mf-token-registry.md §t6], and a third-party advertiser panel of 6.3B impressions, 495.6M taps and 315.6M downloads yields a pooled tap-to-install of 63.7% on a pooled tap-through rate of 7.87% [CALCULATED: 2026-edition search-ads benchmark dataset, self-selected panel].  <!-- tag-lint:allow-multi -->

**Gate 3, traceability.** Thirty days from now, can you still tell which cohort came from here? Learn the store taxonomy before spending: on one major store, "Search" means found in search results, "Explore" means found while browsing, third-party referrers means arrived via an untagged deep link, and paid ads are a separate channel, with search and explore organic-only [FOUND: current platform console documentation].

Plan the paid and organic mix as a range, not a point. One attribution vendor's e-commerce panel puts the median paid-to-organic install ratio at 0.54 globally and 0.63 in MENA for 2025 [FOUND: per the fact registry references/mf-token-registry.md §t6], implying organic at roughly 65% and 61% of installs [CALCULATED]. A smaller independent panel implies close to the inverse balance for the same vertical and period, about 3.5x apart [CALCULATED]. Neither is wrong for its own population, so budget across the range. Expect breadth, not a single channel: tracked e-commerce apps averaged 6.3 ad-network partners in 2025, and the marketplace and classifieds subvertical averaged 10 [FOUND: same panel]. <!-- tag-lint:allow-multi -->

### 4. Build the message stack: problem, change, proof

Three sentences, written in that order, before any asset is designed.

1. **Problem.** The situation the audience is already in, in their words, with no product in it. This is the jobs-to-be-done discipline in the tradition of Christensen, Ulwick and Klement: state the progress someone is trying to make and the circumstance blocking it. If the sentence only parses for someone who already knows your product, it is not a problem sentence.
2. **Change.** What is now different in the world. One clause. The product appears here for the first time.
3. **Proof.** The most checkable claim available: a number, a named constraint, a guarantee, a timed before-and-after.

Render the same stack per channel without rewriting it:

- Store listing: problem sentence in the first line, because search traffic arrives with the problem already formed.
- Paid creative: change sentence carries, problem sentence is the hook.
- Owned channels (email, in-product, existing customers): proof first. They already accept the problem.
- Earned and community: problem only. Let them ask what you built.

The common failure is writing three product sentences and calling the first one the problem.

### 5. Sequence the day around the value clock

The gap between message and install is not where launches fail: 95% of downloads following an ad tap happen within one minute [FOUND: platform owner's ads documentation, all markets, August 2024, per the fact registry references/mf-token-registry.md §t6]. The gap between install and first value is where they fail. So sequence backwards from first value.

- **T minus 1 week.** Instrumentation frozen. Cohort definition, retained test and window are written down and tested against fake data. If this slips, nothing below matters.
- **T minus 1 day.** Owned channels scheduled, support staffed for the full window, and the one thing that breaks under load identified and load-tested.
- **Hour 0.** Highest-intent channel first, because it converts on its own schedule and needs no coordination. Store presence and search coverage live before any announcement.
- **Hours 0 to 4.** Paid on at a fraction of planned budget. You are buying measurement, not volume.
- **Hours 4 to 24.** Owned, then earned. For subscription-shaped products most of the monetization decision is made here: 50.6% of download-to-paid conversions occur on day 0, and trial starts run from 78.0% to 89.9% on day 0 in the fastest categories [FOUND: both figures, 115,000+ subscription apps, 2025 data, per the fact registry references/mf-token-registry.md §t4]. Same-day share is regional: 63.5% in MEA against 44.2% in North America [FOUND: same panel, per the fact registry references/mf-token-registry.md §t4].
- **Days 1 to 3.** No new channels. Fix the first-value blocker the cohort just exposed.
- **Days 3 to 7.** Re-engagement leg, budgeted in advance. Re-engagement is about 29% of app marketing budget, up from 25% a year earlier [FOUND: 45,000-app spend panel, 2025, per the fact registry references/mf-token-registry.md §t6], and paid re-engagement conversions grew 22% year over year against 2% for acquisition [FOUND: 35,000-app panel, 2024]. Re-engagement response is reported to concentrate at 40% on day 1 and over 75% inside week one [HYPOTHESIS: the same claim carries conflicting tags across two slices of the source set, see evidence bar].  <!-- tag-lint:allow-multi -->

### 6. Hold the window

Two clocks answering different questions.

**The spike clock (hours 0 to 72)** answers "did the channel work." It cannot answer anything about the product. Never present it as a result.

**The verdict clock** answers "did the product work," and its length is set by product shape:

| Product shape | Earliest honest read | Verdict read | Retained test |
|---|---|---|---|
| Subscription-shaped | Day 7 | Month 1, then month 12 | Bracket, closed cohort |
| Transaction-shaped (commerce, marketplace) | Day 7 | Day 30, then month 3 | Bracket or unbounded, closed cohort |
| Frequency-shaped (daily or near-daily use) | Day 7 | Day 30 | N-day, closed cohort |

Day 7 is the earliest defensible read because it predicts the later one: 7% day-7 retention places a product in the top quartile on activation, and 69% of top day-7 performers were also top three-month performers [FOUND: both figures, 2,600 companies and 10,600 digital products, Sept 2023 to Sept 2024, per the fact registry references/mf-token-registry.md §t1].

Anchors for the verdict, each usable only inside its own population and never printed beside another:

- **Install cohorts, cross-category averages.** Day-1 25.4% falling to day-30 5.3% on iOS; day-1 20.2% to day-30 3.8% on Android [FOUND: large attribution network, published 2026, per the fact registry references/mf-token-registry.md §t1]. About 21% of the day-1 win survives to day 30 on iOS, about 19% on Android [CALCULATED].  <!-- tag-lint:allow-multi -->
- **Product-analytics closed cohorts, monthly bracket.** Month-1 median 6.5% with a top decile just over 26%; month-3 median 3.8%; the e-commerce slice at month-3 median 2.8% against a top decile of 18.9% [FOUND: 2,600+ companies, Sept 2023 to Sept 2024, per the fact registry references/mf-token-registry.md §t1]. This population is product-analytics users, not installs.
- **Subscription starts, closed cohort at first billing cycle.** Shopping-category median first renewal 58% monthly and 30% annual, rising 25 to 30 points by the second renewal and converging to 74% to 91% by the third [FOUND: 115,000+ subscription apps, 2025 data, per the fact registry references/mf-token-registry.md §t1].
- **Churn floor.** 46.1% of Android installs were uninstalled within 30 days in 2024 [FOUND: 2.2K apps, 1.3B installs, 402M uninstalls, per the fact registry references/mf-token-registry.md §t1].

Long-horizon payoff is a cohort-economics question, not a retention question. One regional food-delivery platform's 2019 first-order cohort reached about 3.4x its acquisition-year GMV by 2024, rising every year [FOUND: company capital-markets presentation, per the fact registry references/mf-token-registry.md §t1]. The limit: GMV multiples blend retained users with order frequency, basket size and price changes, so they support a business case without substituting for a user-count curve.

## Errors that pass review

- **Announcing on the channel you are best at rather than the one the audience is on.** Owned channels are easy to measure and reach people who already chose you. A launch confined to them proves retention of the converted, not acquisition.
- **Treating modeled reach as a headcount.** See gate 1. The impossible percentage is the visible case; the merely inflated ones are not.
- **Reading the spike as the result.** Part of it is people who already had the product. Redownloads run about 2.2x new downloads each week on one major store [CALCULATED from a 2025 platform transparency report]. Meanwhile the pool itself is nearly flat: total downloads across the two major stores rose 0.8% in 2025 while in-app purchase revenue rose 10.6% [FOUND: vendor estimate panel, worldwide, per the fact registry references/mf-token-registry.md §t6].
- **Comparing two retention numbers from two vendors.** Bounded, unbounded and bracket counting can move a "day-30 retention" figure by multiples, and most published benchmarks never state which they used. Within-source comparison only.
- **Budgeting on a single published cost-per-install.** One vendor restated its own global e-commerce CPI for the same year by about 3.4x between two editions, from $3.44 to $1.00 [FOUND: per the fact registry references/mf-token-registry.md §t6]. Cost also spreads about 14x across markets and about 30x across niches on one large ads panel [FOUND: per the fact registry references/mf-token-registry.md §t6]. Plan a range, then re-derive from your own first week.
- **Assuming paid spend lifts organic by a fixed multiple.** The widely repeated multiplier comes from an undated, pre-privacy-change dataset whose own source named shopping a weak-lift category [HYPOTHESIS]. Measure your lift with a held-out market or period.
- **Launching into a rising season and crediting the launch.** Seasonal demand moves whole categories: shopping-app non-organic installs rose 76% year over year across three GCC markets in one religious season, at 111% in its first half against 47% in its second [FOUND: 800+ apps, 220M installs, per the fact registry references/mf-token-registry.md §t6]. Inside such a window you need a same-season baseline or a holdout, not a year-ago comparison.
- **Setting the verdict on an open-cohort headline.** The launch cohort dilutes it, so the number falls while the launch succeeds.
- **Borrowing a retention curve from aggregator posts.** The most-quoted marketplace-versus-shopping retention split has no reachable primary; it appears only on content-farm pages that all credit the same vendor without a link. No reachable population definition means no benchmark.
- **Closing the launch at day 3.** For transaction-shaped products first purchase averages 3.6 days after install [FOUND: 1.6K e-commerce apps excluding marketplace and groceries, Oct 2022 to Apr 2024, per the fact registry references/mf-token-registry.md §t3]. A three-day read ends before the product has been used.

## Worked example: [Put Your Company Name]

[Put Your Company Name] is launching a consumer app in one market. Starting state: a 4,000-person waitlist, no paid spend, no store presence.

**Launch question.** "Do cold installs from store search and one paid social platform reach first value in session one, and does the closed launch-week cohort return in the day 8 to 14 bracket at 12% or better?"

**Cohort typing, frozen one week ahead.** CLOSED cohort; membership is every install between 00:00 on launch day and 23:59 on launch day plus 6, market fixed. Retained test is a BRACKET, any qualifying action in days 8 to 14. The company-level active rate stays OPEN and is expected to fall during the window; that fall is written into the plan so nobody reads it as failure.

**Channels after the three gates.**

- Store search. Presence: about half of weekly store visitors search. Intent: highest available. Traceability: platform-native channel split. In.
- Paid search ads. Traceability full; cost unknown for this niche, so week one is priced as measurement. In, at 20% of planned budget.
- One paid social platform where the audience is verifiable as accounts rather than as reach estimates. In, at 20% of planned budget.
- Waitlist email and in-product. In, but excluded from the acquisition cohort and counted separately, because they are not cold.
- Creator seeding. Held. No disclosed-dataset benchmark for creator-driven installs exists, so it runs as a labeled experiment with its own holdout rather than as a planned channel.

**Message stack.** Problem: "You redo the same thing every week and it takes twenty minutes each time." Change: "[Put Your Company Name] does it in one." Proof: "The same task, timed, published as a before-and-after."

**Day-of.** Store listing live at hour 0. Paid on at hour 1 at one-fifth budget. Waitlist email at hour 4. Earned outreach hours 4 to 24. No new channel days 1 to 3. Re-engagement push at day 4.

**Reads.**

- Hour 72: channel verdict only. Cost per install by channel, tap-to-install, first-session completion. No product claims.
- Day 7: earliest honest product read. At or above the top-quartile activation marker on the closed cohort, scale paid. Below it, the blocker is first value, and more spend buys more of the same loss.
- Day 30 and month 3: the verdict. Bracket retention on the launch cohort, compared against that cohort's own day-7 figure, and against no external benchmark whose population is unknown.

## Evidence bar

Nothing built from this file should be trusted until the following are checked.

- **Citation convention.** Sources here are described by publisher class, document, year and disclosed population rather than by brand name, so the library stays vendor-neutral. Each description is specific enough to retrieve. Restore the names in any internal copy where a reader must audit the source directly.
- **FOUND.** The store-visitor and search counts, the top-of-search conversion rate, the one-minute post-tap download share, the store channel taxonomy, the paid-to-organic ratios, ad-network partner counts, day-0 conversion and trial-start shares, re-engagement budget share and growth, the day-7 activation marker and its three-month persistence, the install-cohort day-1 and day-30 averages, the monthly-bracket medians, first-renewal medians, the 30-day uninstall rate, the seasonal install swing, the 3.6-day first purchase, the CPI restatement, cost spreads, download and revenue growth, and the cohort GMV multiple. All are vendor or platform disclosures with a stated population, not audited figures. Re-check the year on each before quoting it externally.
- **CALCULATED.** The 52% search share, the 63.7% pooled tap-to-install and 7.87% pooled tap-through, the organic install shares, the 3.5x panel disagreement, the day-1 survival ratios, and the 2.2x redownload ratio. Arithmetic on the FOUND figures above; re-derive if any input is restated.
- **HYPOTHESIS.** The national ad-reach snapshot, the fixed paid-to-organic lift multiplier, and the day-1 concentration of re-engagement response. Render these as hypotheses in any output. The last one is a live tag conflict: the same claim from the same publisher carries FOUND in one slice of the source set and a refuted demotion to HYPOTHESIS in another, so it is treated as a hypothesis here.
- **CONSTRUCTED.** The three-gate channel test, the problem-change-proof stack, the day-of sequence, the two-clock split, and the product-shape window table. These are reasoning structures, not measured practice, and no dataset validates them as written.
- **INFERRED.** The claim that day 7 is the earliest defensible read is inferred from one dataset's finding that top day-7 performers persist at three months. It is a correlation inside one product-analytics population, not a proven rule for install cohorts.
- **NEEDS-CONFIRMATION.** No disclosed-dataset benchmark exists for word-of-mouth or referral share of installs, for creator or influencer driven installs, for store-feature lift dated after two store redesigns, or for retention split by acquisition channel. No cohort-typed retention curve for GCC consumer apps was found in any reachable source. The widely quoted marketplace retention split has no traceable primary. Treat all of these as open, and never fill them from an aggregator page.
- **Before trusting an output.** Confirm the cohort type and retained test are stated on every retention number, that no two numbers from different populations sit in the same comparison, that the measurement window was declared before launch rather than chosen after, and that the seasonal baseline is a same-season holdout wherever the category itself was moving.
