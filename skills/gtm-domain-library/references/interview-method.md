# Interview Method

Interviews are worth running only when they can move a decision you wrote down before recruiting, and only when the output survives being argued with by someone who wants a different answer. This file separates four things that usually get collapsed: recruiting (which produces two separate rates, never one), question design (past behaviour, not stated intent), synthesis into tagged findings, and the point at which a sample is large enough to act on. Every benchmark below carries its population, its size and its year, because a rate without its denominator is not a number anyone can use.

## The method

### 1. Write the decision first

Write the decision the interviews are supposed to change, and the two or three answers that would send it in different directions. If every plausible answer leads to the same next step, do not run the study. Write the flip condition in the same sentence: what would have to be true, in how many interviews, in which segment, for you to choose the other option. A study with no flip condition produces quotes, and quotes get selected to fit whatever the loudest person already wanted.

### 2. Model the funnel as four rates, each with its own denominator

Reached, replied, qualified, scheduled, completed. That is four rates, and collapsing them hides which leg is actually broken:

- reply rate = replied / reached
- screen pass rate = qualified / replied
- schedule rate = scheduled / qualified
- completed-interview rate = completed / scheduled

Reply rate and completed-interview rate are the two you report. They fail for unrelated reasons, they are fixed by unrelated actions, and a single blended "interview conversion" number tells you nothing about either. This is not a stylistic preference. Published no-show averages range from 6% to over 30% almost entirely because sources count different denominators, scheduled versus confirmed versus invited, moderated versus unmoderated, late cancellations counted or not [FOUND: definitional spread documented across the source set], so a completion figure quoted without its denominator is not portable.

Assume you will have to measure this yourself. A systematic review of 215 studies found the recruitment rate could not be calculated at all in 77% (166 of 215), and the proportion of eligible participants from those screened could not be calculated in 80%; of the 49 studies where a rate was calculable, 31% had recruited under half the eligible pool [FOUND: 215 studies reviewed, published 2016, per the fact registry references/mf-token-registry.md §t2]. No public source publishes all four legs with matching denominators, so any end-to-end funnel figure you present is a join you made and must be tagged CONSTRUCTED.

### 3. Recruit the reply leg on channel, not on copy

Channel choice moves reply rate by multiples; message polish moves it by fractions. In job-candidate outreach across more than 4,000,000 messages from 1,500+ organizations, an in-network platform message replied at 17.08%, a human-written email at 6.31%, and an automated email at 4.96% [FOUND: Jun 2025 to May 2026, per the fact registry references/mf-token-registry.md §t2]. In the same dataset, a two-step sequence combining email with an in-network message replied at 45.76% against 19.73% for email only, and including the recipient's first name lifted replies from 2.61% to 5.13% [FOUND: same dataset]. Follow up, but cap it: the first three touches captured 93.2% of all replies and a fourth reached 97.7% cumulative, so touches five and beyond buy annoyance rather than interviews [FOUND: same dataset].

Treat the copy-tuning question as unsettled rather than answered. A 2x2 factorial randomized trial on 1,943 delivered invitations reported 6.7% versus 6.0% for emphasising the incentive in the subject line (RR 1.12, 95% CI 0.80 to 1.58) and 6.3% versus 6.4% for send day (RR 0.98, 95% CI 0.70 to 1.38), neither significant [HYPOTHESIS: contested on review; physicians, 2017]. That is one population and two manipulations, so it is a reason to stop spending days on subject lines, not proof that copy never matters.

Two structural options usually beat outbound entirely:

- In-product prompts. Across 1,382 in-app surveys and 50,305,103 views, response averaged 27.52% and completion 24.84%, with mobile at 36.14% against web at 26.48% [FOUND: vendor platform data, 2025, per the fact registry references/mf-token-registry.md §t2]. Read this as an upper bound on attention, not on agreement: a survey start costs seconds and a moderated session costs 30 to 60 minutes, so using it as an interview opt-in rate is INFERRED at best.
- Intercept at the moment of the behaviour. A physical-retail intercept study completed 35% of eligible people it approached (616 completed of 1,765 eligible), found 55% of passers-by eligible, and produced 4.5 completed interviews per hour of fieldwork [FOUND: 128 stores, 204 visits, 2014, per the fact registry references/mf-token-registry.md §t2]. Time of day mattered (40% in the late-afternoon rush against 32% at weekends). The digital equivalent is a prompt fired inside the flow you want to ask about, while the memory is still intact.

Budget the labour honestly. Finding enough qualified participants was the top reported challenge for researchers, with time to recruit named by 54% and cost by 23% [FOUND: 485 researcher responses, 2025, per the fact registry references/mf-token-registry.md §t2], and in-house recruiting has been measured at 1.15 hours of staff time per participant [FOUND: 201 usability professionals, published 2003 with a 2013 addendum noting costs about 20% higher].

### 4. Plan the completion leg as a range, and over-schedule

Across 14,210 moderated studies run through one paid panel, no-shows averaged 8.6%: consumer in-person 8.3% (564 studies), consumer remote 8.3% (8,850), business in-person 7.2% (27), business remote 10.4% (4,769) [FOUND: 2022 data, per the fact registry references/mf-token-registry.md §t2]. One independent operator measured 5.0% across 24 studies and 958 participants [FOUND: 2024], and the same operator hit 14% (18 of 128 sessions) across three snowbound days [FOUND: Nov 2024]. So: schedule 11 to land 10 completed at an 8.3% to 8.6% rate, and 12 at 10.4% [CALCULATED from the panel cut].

Three things follow that people get backwards:

- Going async does not remove drop-off, it multiplies it. Unmoderated studies ran near 30% no-show at the most common low incentive, falling to 8.2% at the highest [FOUND: roughly 20,000 projects, year to Jan 2025, per the fact registry references/mf-token-registry.md §t2]. At 30% you schedule 15 to land 10 [CALCULATED].  <!-- tag-lint:allow-multi -->
- Incentive is the lever with measured signal. One operator recorded a correlation of r = -0.50 between incentive and no-show across its 24 studies [FOUND: 2024, per the fact registry references/mf-token-registry.md §t2].
- Reminders are worth sending and not worth modelling. The best causal evidence is outpatient appointments: pooled RR 1.11 for attendance (95% CI 1.05 to 1.19), telephone RR 1.11 significant, SMS RR 1.14 (0.99 to 1.31) not significant [FOUND: 10 RCTs, 8,236 participants, published 2026, per the fact registry references/mf-token-registry.md §t2]. It does not port: applying RR 1.11 to a 91.7% attendance baseline yields 101.8%, which is impossible [CALCULATED]. Send them, forecast nothing from them.  <!-- tag-lint:allow-multi -->

Whether remote beats in-person is unresolved and should be carried as a range, never a direction: a clinical meta-analysis found remote less likely to be missed (pooled OR 0.61, 45 cohort studies), one operator's own numbers agreed (4.5% remote against 5.8% in-person), and the 14,210-study panel cut showed no consumer difference (8.3% against 8.3%) and reversed for business (remote 10.4% against in-person 7.2%) [CALCULATED: documented contradiction across four datasets].

### 5. Ask about the last time, never the next time

The question that produces evidence is dated, specific and checkable. The question that produces noise is hypothetical, general and flattering.

- Anchor to an event, not a habit: "walk me through the last time you needed this," not "how often do you need this."
- Ask for the record, not the memory: the receipt, the order, the message thread, the screenshot. An artifact you saw is a different tag from a story you heard, and that difference survives into synthesis.
- Ask what they did instead, what it cost them, what triggered the switch and what they gave up. The jobs-to-be-done tradition (Christensen, Ulwick, Klement) is right about where the signal sits: in the sequence around a real switching moment, not in an attribute rating.
- Forbid futures. "Would you use," "how much would you pay," "how often would you" all return a preference statement, and preference statements have no measured relationship to the behaviour they describe. If pricing is the question, capture what was actually paid; price-sensitivity instruments in the van Westendorp tradition are survey instruments with real denominators, run separately.
- Keep qualification out of the room. A BANT-class checklist is a fine screener for deciding who is worth an hour, but asked live it tells the interviewee which answers you are hoping for, and people are cooperative.
- One interviewer does not both sell and ask. If the person running the session has a stake in the answer, the session produces agreement.

### 6. Synthesise into tagged findings, one segment at a time

A finding is a single sentence with five parts: the claim, the segment, the count within that segment, the count of people who had the chance to say it and did not, and the tag. Anything missing a part is a note, not a finding.

Tag every finding with the same six-tag vocabulary the rest of the library uses. FOUND means you saw the artifact. INFERRED means they described it and you did not see it. CONSTRUCTED means you assembled the statement from several partial accounts. CALCULATED means arithmetic over your own counts. HYPOTHESIS means plausible with no evidence yet. NEEDS-CONFIRMATION means load-bearing, unverified, and blocking.

Count inside a segment and never across one. Three mentions from three different segments are three hypotheses, not one finding. Keep the disconfirming column visible: a claim made by 6 of 10 people is a different object from a claim made by 6 of 10 where the other 4 were never asked.

### 7. Decide when the sample is big enough

Run the gates in order. Each one can stop you.

- **Gate A, segment floor.** A segment with fewer than 5 completed interviews produces hypotheses only [CONSTRUCTED: a working rule, not a benchmark].
- **Gate B, independent repetition.** A claim becomes a finding at 3 independent occurrences inside one segment, where independent means not recruited through the same referral chain and not from a single channel [CONSTRUCTED]. Same-channel repetition measures the channel.
- **Gate C, new-information stop.** Stop a segment when 3 consecutive interviews add no new tagged finding to it [CONSTRUCTED]. If they are still adding, keep going and write down that you did. Segments close independently; one closing does not close the study.
- **Gate D, reversal test.** State how many contradicting interviews would flip the decision. If the answer is one, the sample is too small no matter how many you ran.
- **Gate E, cost of being wrong.** Cheap and reversible: act at Gates A and B. Expensive or hard to reverse (a pricing change, a rebuild, a market entry): require a second method that can be wrong in a different way, such as usage logs, a paid test, or a survey with a real denominator.

## Errors that pass review

- **Reporting one interview conversion rate.** It blends a channel problem with a scheduling problem, and the published spread from 6% to over 30% is mostly denominator differences, not performance differences [FOUND: definitional spread documented across the source set, per the fact registry references/mf-token-registry.md §t2].
- **Using a survey response rate as an interview opt-in rate.** Answering one in-app question and committing to a 30 to 60 minute live session are not the same ask, and the gap between them is not a constant you can calibrate once.
- **Recruiting whoever replies fastest.** Your most engaged users reply first and are the least informative about the problem you are trying to size. Speed of reply is correlated with the thing you are measuring.
- **Spending the week on subject lines.** The only randomized evidence available found no effect from the two tweaks it tested, while in the largest outreach dataset channel choice moved replies by 3.4x, an effect that held across every quarter measured [FOUND: 4M+ messages, Jun 2025 to May 2026, per the fact registry references/mf-token-registry.md §t2].
- **Counting a finding across segments.** It converts three weak signals into one confident wrong answer.
- **Recording stated intent as data.** "I would definitely pay for that" is a politeness artifact. It belongs in the transcript, not in the findings table.
- **Stopping because interviews got boring.** Boredom and saturation feel identical and are not. Write down which stop rule fired.
- **Treating unmoderated as the fix for no-shows.** It roughly triples drop-off at low incentives.
- **Quoting a channel-share number as a rate.** Share of recruits by channel has no contacted denominator and cannot be converted into one.
- **Building the full funnel from borrowed benchmarks.** No public source publishes all four legs on matching denominators, so the join is yours and inherits every population mismatch in it.

## Worked example

[Put Your Company Name] runs a marketplace with a paid membership and has to choose what the membership includes next. All counts in this example are CONSTRUCTED for illustration; only the planning benchmarks carry sources.

**Decision written first.** Ship benefit A or benefit B in the next release. Flip condition: if 3 or more members in the same segment show evidence of having paid for A out of pocket in the last 60 days, A goes first.

**Segments.** (1) members who have renewed at least once, (2) members who cancelled within 90 days. Two segments, counted separately.

**Recruit plan.** Target 10 completed per segment, so schedule 11 per segment [CALCULATED from 8.3% consumer no-show, 8,850 remote studies, 2022 panel cut]. Channel order set by the measured spread: in-network message first at 17.08%, human-written email second at 6.31%, automated template never at 4.96% [FOUND: 4M+ messages, Jun 2025 to May 2026, per the fact registry references/mf-token-registry.md §t2]. Cap at three touches, which carry 93.2% of replies [FOUND: same dataset]. Volume floor: roughly 64 in-network messages or 173 written emails per 10 completed [CALCULATED: same dataset with an 8.3% no-show].  <!-- tag-lint:allow-multi -->

**Questions asked.** Not "would you pay for A." Instead: "Tell me about the last time you needed A. What did you actually do? What did it cost? Can you show me the order or the thread?"

**Findings after 20 completed interviews.**

- F-1 [FOUND: receipt artifact seen, §5 record rule] 6 of 10 renewers showed a receipt for A purchased outside the product within 60 days. The other 4 were asked and had none.
- F-2 [INFERRED] 4 of 10 cancellers described buying A elsewhere but showed no artifact.
- F-3 [HYPOTHESIS] price is the main cancel reason. No canceller raised price unprompted, so this stays a hypothesis until a survey with a real denominator runs.
- F-4 [NEEDS-CONFIRMATION → study owner: blocks any single-channel claim until a second channel is run] both segments were recruited through the in-network channel only, so Gate B independence is not satisfied for any single-channel claim.

**Gates.** F-1 clears Gates A and B and the flip condition, and 2 contradicting cases would not overturn it, so it clears Gate D. F-3 fails Gate D outright, since one contradicting interview would flip it. Gate C fired for renewers (interviews 8, 9 and 10 added nothing new) and did not fire for cancellers, which stayed open. Because the release is reversible, Gate E allows acting on F-1 now. F-4 blocks any claim that rests on channel-independent repetition until a second channel is run.

**Result.** Ship A. Keep the canceller segment open. Do not put price in the decision doc as a reason.

## Evidence bar

Before this method's output is trusted, the following must hold.

- **Two rates, never one.** Reply rate and completed-interview rate are reported separately, each with its numerator definition and its denominator attached. A blended rate is CONSTRUCTED and must say so.
- **No public benchmark exists for the thing you actually want.** Nothing public measures the reply rate to an interview invitation sent to a consumer product's own users. Everything available measures a survey start, a sales reply or a job-candidate reply. Your own first measurement is FOUND for you and NEEDS-CONFIRMATION for anyone else.
- **Borrowed numbers change tag when the population changes.** Every recruiting benchmark quoted here comes from a different population than a consumer marketplace. Reused, they are INFERRED, and the mismatch has to be named in writing.
- **No regional benchmark exists.** There is no measured interview-recruitment or reply rate for consumer apps in the GCC. The nearest evidence is a multi-language clinic cohort that enrolled 27% of those approached (400 of 1,503), with a per-language spread from 33% down to 18% under one protocol [FOUND: 2012, per the fact registry references/mf-token-registry.md §t2]. Any regional rate you state is HYPOTHESIS until measured first-party.
- **Messaging-app recruitment has no rate at all.** The available regional evidence is a share of recruits (messaging-app-mediated strategies accounted for roughly 55% of 3,176 participants across 19 countries) with no contacted denominator [FOUND: 2021, per the fact registry references/mf-token-registry.md §t2]. Any messaging-app reply rate is HYPOTHESIS pending a first-party test.
- **Every acted-on finding names four numbers.** Segment, count within segment, count who could have said it and did not, and the number of contradicting cases that would flip it.
- **Sufficiency thresholds are declared, not assumed.** The 5, 3 and 3 in Gates A, B and C are CONSTRUCTED working rules, not measured benchmarks. State them in the output so a reader can disagree with the specific number rather than with the conclusion.
- **Unresolved contradictions stay contradictions.** Remote versus in-person completion is the live example: four datasets disagree, so it is carried as a range and never quoted as a direction.
- **Anything still HYPOTHESIS or NEEDS-CONFIRMATION at decision time goes into the decision document** as the named condition that would make the decision wrong, with the check that would resolve it.
