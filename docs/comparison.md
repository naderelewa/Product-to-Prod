[Back to the README](../README.md) · the comparison table in full, and the limits stated in the same place as the strengths.

# The full comparison

Every cell about another tool comes from one grounding file compiled for this comparison, and from nothing beyond it. **That grounding file is not shipped with this package and is not published anywhere**, so the cells about other tools are the one set of claims here you cannot re-open from the tree: weigh them as this comparison's own reading, not as something you can audit. The first column is not a product: it is what you already have with nothing installed. Where a cell says *not established here*, the comparison did not verify it either way, which is different from a no. Our own cons are in the same table as our strengths, in bold, because that is the only version of this table worth publishing.

| | Plain chat, no plugin | A PRD-writing SaaS | A product-coaching SaaS | Standard product-skill packs | An open-source GTM playbook pack | This plugin |
|---|---|---|---|---|---|---|
| **Setup** | nothing to install | zero setup, chat in a web app | hosted, per seat | installed as skill packs, with the connectors they ship | not established here | four rungs, from pasting one file to a harness plugin; `init` only for the log or the tracker |
| **Enforcement** | none: nothing to lint, nothing to gate | not established here | none: no lint, no tests, no gates | not established here | prose-only gates that nothing enforces | tag linter, fail-closed inference gate, publish lint, 89 self-tests, three human gates per requirements cycle |
| **Evidence discipline** | none: whatever the model volunteers | no evidence-tagging discipline | no evidence-tag system | none, per the class definition | folklore numbers with internal contradictions | six tags on every factual claim, no false FOUND, no anchor no claim, linted mechanically |
| **Memory and traceability** | the conversation, until it is lost | not established here | cross-stage memory plus a decision traceability log | not established here | not established here | canonical phase files re-ground a run from disk; requirement to scenario to slice trace; sha256 seal over the package |
| **Outputs** | whatever you paste out of the chat | PRDs from templates | seven coaching stages; the handoff is a markdown build brief opened into a coding agent | template documents per verb | prose playbooks, strong coaching voice | packages on disk: spec, plan, data model, contracts, slice graph, batch verdicts, acceptance reports, plan packages |
| **Verification against reality** | none | none against analytics | not among its stages | not established here | not established here | a dedicated verb: pre-declared scenarios graded against the deployed build, pre-declared queries executed read-only |
| **Data custody** | wherever your chat already runs | cloud-held | cloud-held | not established here | not established here | local; usage log off by default and sends nothing; one read-only version check of this package's own published manifest, off with `PKG_NO_UPDATE_CHECK=1` |
| **Team features** | whatever your chat app already offers | team sharing | team features | not established here | not established here | **none: single-player, no seats, no sharing** |
| **Cost model** | nothing beyond the agent you already have | subscription | about 99 dollars per month, in beta | not established here | open source, per the class name | MIT-licensed source, running in a harness you already have |
| **Weakest point** | nothing pushes back: no tag, no lint, no gate that refuses to seal | no repository or codebase awareness | the handoff is a prompt, not a contract | no evidence discipline: that is the class's defining gap | single-vertical fit, and no wizard to route a stranger | **no SaaS UI, single-player, young at v0.1.3, no cloud dashboards, field-proven in one harness only** |

**Where the other classes are genuinely stronger.** The PRD-writing SaaS: zero setup, a polished web experience, team sharing. The product-coaching SaaS: a polished hosted product, team features, and a guided coaching voice. Plain chat with no plugin remains the fastest way to draft anything, with nothing installed and nothing enforced.

**What this package is not.**

- **Not a SaaS product.** There is no web UI and no hosted service. It needs an agent harness to run in.
- **Single-player.** No team seats, no sharing, no collaboration features.
- **Young.** Version 0.1.3. The interfaces described here can still move.
- **No cloud dashboards.** Everything it produces is a file on your machine.
