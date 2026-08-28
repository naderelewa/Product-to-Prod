[Back to the README](../README.md) · every capability, every local key, and the order they resolve in.

# Connections and configuration

**Configuration.** [`config/local.template.json`](../config/local.template.json) documents every host-specific key, all shipped null.
Copy it to `config/local.json`, which is machine-local and gitignored, and fill only the keys your run actually needs. A key you leave unset is a named miss: the run says which key is unset and what filling it would unlock, then continues on what it can prove.

This package **ships no MCP server of its own and bakes no vendor into any id, row or default**. Capability rows describe what a capability *does*, never who provides it, because an id like `<vendor>_<company>` would ship one operator's tooling choice, and one operator's identity, to everybody else. Where a vendor is named at all it is as an example of what you might connect, never as a configured default. You point each row at whatever you already use.

Read this section as a data-custody contract: what turns on, when it turns on, what is recorded, and what is never recorded.

Three ways a capability turns on, and the difference matters:

- **Required** is probed on every run of that verb. A miss blocks with its exact one-time fix.
- **Stack-selected** is probed only when you pass its key in `--stack`, once the run is right-sized. A selected miss blocks exactly like a required one.
- **Elicited** does not exist until the wizard asks and you say yes. While the switch is off the row is not probed, no fix is printed, and nothing is named as missing. Declining is a complete answer, not a gap.

## The capability rows

| Capability | What it gives you | How it turns on | Local keys recorded | Never recorded |
|---|---|---|---|---|
| `python3` | the scripts that need an interpreter run on it: `preflight`, `hostcheck`, `tag-lint`, `inference-gate`, `telemetry` (`publish-lint` and `release` are pure shell) | required | none | n/a |
| `shasum` |  the sha256 receipts a reviewer re-computes to prove no artifact drifted after sealing (`sha256sum` satisfies this row equally on hosts without `shasum`) | required (requirements verb) | none | n/a |
| `eng-registry` | your engineering toolchain's surface and repository registry, read-only ground truth so a handoff never hardcodes surface names | stack: `eng-handoff` | `eng_plugin.name`, `eng_plugin.surfaces_registry` | anything written back; the engine reads it and never writes it |
| `eng-seam-check` | your own command that verifies the contract versions still match; a clean success run of it is a precondition for drafting any seam artifact | stack: `eng-handoff` | `eng_plugin.seam_check_cmd`, `eng_plugin.handoff_dir` | nothing is assumed on absence; "not checked" is recorded, never a silent pass |
| `analytics-web` | read-only web-analytics reads, so funnel claims are measured instead of pending | stack: `analytics-verification`, `gate-state-snapshot` | `analytics_web.property_id.prod`, `.staging`, `analytics_web.service_account_json` (a **path**) | the credential itself |
| `analytics-product` | read-only product-analytics reads, with both environments named so a staging read can never be reported as production | stack: `analytics-verification`, `gate-state-snapshot` | `analytics_product.project_id.prod`, `.staging`, `analytics_product.cli_config` | the credential itself |
| `session-replay` | session-replay and heatmap reads for behavioural evidence, with a daily query budget the run plans against | stack: `analytics-verification`, `gate-state-snapshot` | `session_replay.project`, `session_replay.token_path` (a **path**), `session_replay.daily_query_budget` | the token |
| `issue-tracker` | read-only reads of item types, stories and tickets, for backlog cross-checks | **elicited** at gate I1 | `issue_tracker.enabled`, `.base_url`, `.project_key`, `.auth_pointer` (a **path**) | the token value, always |
| `docs-workspace` | docs and wiki pages as citable evidence | stack: `workspace-docs` | `docs_workspace.name` | credentials; your harness holds the authorisation |
| `design-tool` | design-tool reads for design-parity evidence | stack: `design-extraction` | `design_tool.token_path` (a **path**) | the token |
| `repo-state` | read-only repository and change-request state, for grounding claims about what actually shipped | stack: `repo-state` | none beyond your own CLI being authenticated | credentials |

## The stack keys, per verb

| Verb | Keys you can pass to `--stack` |
|---|---|
| `pm-requirements-v1` | `eng-handoff` · `analytics-verification` · `design-extraction` · `backlog-sync` · `workspace-docs` · `repo-state` |
| `pm-verify-release-v1` | `eng-handoff` · `analytics-verification` · `repo-state` |
| `pm-portfolio-v1` | `analytics-verification` · `backlog-sync` · `workspace-docs` |
| `pm-gtm-v1` | `gate-state-snapshot` · `workspace-docs` · `backlog-sync` |

```bash
bash scripts/preflight.sh --help                    # what each verb requires, and its stack keys
bash scripts/preflight.sh <verb> --stack <keys>     # the job-scoped probe
bash scripts/hostcheck.sh                           # report-only: what this host already runs vs what this package brings
```

`hostcheck.sh` never installs, removes or enables anything, and writes no file of its own. It prints a plan you approve and execute yourself. One disclosure: when your harness ships a CLI and it is present, the script calls that CLI to list servers, and the CLI may create its own config on a machine where it has never run. Those files are the harness's, not this package's.

## The other local keys

Not capabilities, but the same rule applies: pointers and identifiers, never secret values.

| Key | What it is |
|---|---|
| `provenance_id` | the label written into receipts instead of a machine hostname and OS user. Unset means receipts say unattributed, which is honest and leaks nothing |
| `secrets_dir` | RESERVED and user-extensible: where your credential files live. No shipped script or capability row reads it today; it is declared so a row you add can build pointer paths from it instead of hardcoding a location. Contents are never read either way |
| `credential_index` | RESERVED and user-extensible: your own index of which credential lives where. No shipped script or capability row reads it today; it is declared so a row you add can point a miss at your index instead of naming one fixed location |
| `tools_dir` | RESERVED and user-extensible: where locally installed analytics and CLI binaries live. No shipped capability row probes it today; it is the documented place to point one you add |
| `corpus_base` | the root of your read-only evidence corpora; pack pointers resolve against it |
| `harness_configs` | additional agent harnesses to inventory on this host |
| `tag_container.id` | RESERVED and user-extensible: a tag-manager container id, for when web instrumentation planning is in scope. No shipped script or capability row reads it today |
| `packs_dir_extra` | an extra directory scanned for packs, so your own packs live outside the plugin and survive upgrades |

**Resolution order for every key**: an environment variable first (the key uppercased with dots and dashes as underscores, prefixed `PM_LOCAL_`), then `config/local.json`, then a named miss. Environment-first is what lets a harness with no writable config still run fully configured. The template ships every key null on purpose: a foreign default is worse than a named miss, and a completeness test enforces that every key the engine can reference is documented in the template.
