#!/usr/bin/env bash
# hostcheck.sh — HOST-AWARE FLIGHT CHECK: what does enabling this plugin on THIS host duplicate?
#
# ⛔ HARD RULE (printed on every run): this script NEVER installs, removes, or enables anything. It
#    is a read-only inventory + diff that emits a PLAN — a skip list, install PROPOSALS, dedup
#    PROPOSALS — and every proposal needs your approval and your own hands. No flag, env var, or
#    code path performs a mutation. IT ITSELF writes no file, no stamp, no cache.
#
#    ONE HONEST QUALIFIER, because the promise above is about THIS script's own writes: when the
#    default harness CLI is present, step 1 calls it to list servers, and that tool may create its
#    own configuration in your home directory on a machine where it has never run. Nothing this
#    package owns is written either way, and PM_SKIP_MCP_LIST=1 skips the call entirely (the
#    inventory then falls back to config parsing).
#
# WHY IT EXISTS: installing a plugin bundle onto a host that already runs equivalents of the bundled
# tool servers silently doubles every one of them, and nothing in a normal install tells you. Run
# this on the TARGET host BEFORE any install/enable, and any time duplicate tools are suspected.
#
# WHAT IT DOES
#   1. INVENTORY the active harnesses:
#        · the default harness — its server listing when its CLI is available (calling that CLI is
#          the one outward call this script makes; names and status only; command lines, URLs with
#          parameters, and config bodies are never reprinted), else the user config fallback, which
#          reads that one config file for its user and project scopes.
#        · any ADDITIONAL harness you declare in ${local:harness_configs} (see
#          config/local.template.json): [{"id","format":"json"|"toml","path","servers_key"}].
#          Nothing is guessed: no declared harness = a named limit in the report, never a silent
#          "clean". Only server NAMES (and an `enabled` flag when present) are read — entry bodies
#          can carry secrets and are never opened past that.
#   2. DIFF the inventory against what this plugin brings: its own .mcp.json servers (if it ships
#      one) plus config/dependencies.json rows of kind=mcp. Non-server rows (cli/skill/config) are
#      preflight territory: named here, never verdicted. Matching is case/dash/underscore
#      insensitive and EQUIVALENTS-AWARE via per-server "equivalents": [...] arrays in .mcp.json
#      (data-driven — a new pair needs no code change).
#   3. VERDICT per item:
#        DUPLICATE       the host runs it (or an equivalent) AND this plugin declares it — enabling
#                        the plugin doubles that server
#        PRESENT-host    the host provides it; this plugin does not ship it — nothing to install
#        PRESENT-bundle  only this plugin provides it here — enabling the plugin is sufficient
#        MISSING         nowhere on this host and not launched by this plugin — an install PROPOSAL
#                        is emitted from the row's FIX (REQUIRES YOUR APPROVAL)
#   4. PLAN: skip list · install proposals · choose-one dedup proposals (host and plugin configs are
#      named, never printed — you compare them yourself and decide).
#
# Usage: hostcheck.sh [--help]      (no other flags exist, deliberately: mutation has no entry point)
#
# Env (all optional):
#   PM_SKIP_MCP_LIST=1     skip the harness server listing call (it spawns servers, so it is slow);
#                          inventory falls back to config parsing. Preflight's step-0 sets this.
#   PM_LOCAL_JSON          local config path (default config/local.json)
#   PM_LOCAL_HARNESS_CONFIGS  JSON array overriding the declared extra harnesses
#   HOSTCHECK_FAKE_*       hermetic test overrides; any set value triggers a loud FIXTURE MODE
#                          banner, because fixture output must never be cited as host evidence:
#     HOSTCHECK_FAKE_HARNESS_LIST=<file>    fake default-harness server listing text
#     HOSTCHECK_FAKE_NO_HARNESS_CLI=1       force the no-CLI config fallback path
#     HOSTCHECK_FAKE_USER_CONFIG=<file>     fake harness user config
#     HOSTCHECK_FAKE_MCP_JSON=<file>        fake this-plugin .mcp.json
#     HOSTCHECK_FAKE_DEPS_JSON=<file>       fake config/dependencies.json
#
# Exit: 0 = CLEAN (no duplicates, nothing missing) · 1 = duplicates and/or missing found
#       (REPORT-ONLY either way — exit 1 changes nothing, it flags that the plan needs you) ·
#       2 = self-config error (this plugin's own files unreadable)
# Portability: bash + python3 only; no locks, no platform-specific calls. Invoke it as
# `bash scripts/hostcheck.sh` so a lost exec bit on a shared volume never matters.

set -u
command -v python3 >/dev/null 2>&1 || {
  echo "hostcheck: python3 not available — cannot inventory (nothing was changed)" >&2
  exit 2
}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 - "$SCRIPT_DIR" "$@" <<'PY'
import json, os, re, shutil, subprocess, sys

script_dir = sys.argv[1]
argv = sys.argv[2:]
ROOT = os.path.dirname(script_dir)
HOME = os.path.expanduser("~")

# ⛔ HARD RULE — enforced by construction: this program contains no install/remove/enable code path
# and takes no mutating flag. It reads files and prints a plan.
HARD_RULE = ("HARD RULE: this tool NEVER installs, removes, or enables anything — report and "
             "proposals only; YOU approve and run every change yourself.")

if argv and argv[0] in ("-h", "--help"):
    print("usage: hostcheck.sh [--help]")
    print()
    print("Host-aware flight check: inventories the active harnesses, diffs them against what this")
    print("plugin brings (.mcp.json + config/dependencies.json rows of kind=mcp, equivalents-aware),")
    print("and prints a verdict per item (PRESENT-host / PRESENT-bundle / MISSING / DUPLICATE) plus")
    print("a PLAN: skip list, install proposals (each requires your approval), choose-one dedup")
    print("proposals. Run it on the target host BEFORE any install or enable. Exit 0 clean; exit 1")
    print("when duplicates or missing items were found.")
    print(HARD_RULE)
    sys.exit(0)
if argv:
    sys.stderr.write("hostcheck: unknown argument %r — only --help exists (no mutating flags, by "
                     "design)\n" % argv[0])
    sys.exit(2)


def fake(name):
    return (os.environ.get("HOSTCHECK_FAKE_" + name) or "").strip()


FIXTURE_MODE = any(k.startswith("HOSTCHECK_FAKE_") and (os.environ.get(k) or "").strip()
                   for k in os.environ)


def sh(cmd, timeout=120):
    try:
        p = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr)
    except Exception as e:  # noqa: BLE001 — any failure degrades to the config fallback
        return 125, "runner error: %s" % e


def norm(s):
    return re.sub(r"[\s_\-]+", "", (s or "").strip().lower())


def dig(obj, dotted):
    cur = obj
    for part in (dotted or "").split("."):
        if not part:
            continue
        if not isinstance(cur, dict):
            return None
        cur = cur.get(part)
    return cur


# ── local config (only the keys this tool needs) ─────────────────────────────────────────────
local_path = os.environ.get("PM_LOCAL_JSON") or os.path.join(ROOT, "config", "local.json")
local_values, local_note = {}, "no config/local.json (env only)"
try:
    with open(local_path) as f:
        local_values = (json.load(f).get("local") or {})
    local_note = local_path
except FileNotFoundError:
    pass
except Exception as e:  # noqa: BLE001
    local_note = "%s unreadable (%s) — extra harnesses not inventoried" % (local_path, e)

declared = os.environ.get("PM_LOCAL_HARNESS_CONFIGS") or local_values.get("harness_configs")
if isinstance(declared, str):
    try:
        declared = json.loads(declared)
    except Exception:  # noqa: BLE001
        declared = None
if not isinstance(declared, list):
    declared = []

# ── this plugin's side: .mcp.json servers + dependencies.json rows of kind=mcp ────────────────
mcp_path = fake("MCP_JSON") or os.path.join(ROOT, ".mcp.json")
deps_path = fake("DEPS_JSON") or os.path.join(ROOT, "config", "dependencies.json")
bundle_servers, mcp_json_present = {}, False
try:
    with open(mcp_path) as f:
        bundle_servers = json.load(f).get("mcpServers") or {}
    mcp_json_present = True
except FileNotFoundError:
    pass  # a plugin need not bundle any server — then nothing of ours can duplicate
except Exception as e:  # noqa: BLE001
    sys.stderr.write("hostcheck: this plugin's .mcp.json is unreadable at %s (%s) — self-config "
                     "error; nothing was changed\n" % (mcp_path, e))
    sys.exit(2)
try:
    with open(deps_path) as f:
        deps = json.load(f).get("deps") or {}
except Exception as e:  # noqa: BLE001
    sys.stderr.write("hostcheck: config/dependencies.json unreadable at %s (%s) — self-config "
                     "error; nothing was changed\n" % (deps_path, e))
    sys.exit(2)

mcp_deps = {n: d for n, d in deps.items() if isinstance(d, dict) and d.get("kind") == "mcp"}
non_mcp_deps = sorted(n for n, d in deps.items() if isinstance(d, dict) and d.get("kind") != "mcp")

EQUIV_PAIRS = []
for sname, entry in bundle_servers.items():
    for eq in (entry.get("equivalents") or []) if isinstance(entry, dict) else []:
        EQUIV_PAIRS.append((sname, eq))
eq_class, eq_display = {}, {}
for a, b in EQUIV_PAIRS:
    na, nb = norm(a), norm(b)
    eq_display.setdefault(na, a)
    eq_display.setdefault(nb, b)
    cls = eq_class.get(na) or eq_class.get(nb) or set()
    cls.update([na, nb])
    for m in cls:
        eq_class[m] = cls


def same(a, b):
    na, nb = norm(a), norm(b)
    return na == nb or nb in eq_class.get(na, ())


# ── host inventory ───────────────────────────────────────────────────────────────────────────
ANSI = re.compile(r"\x1b\[[0-9;]*m")
host_regs = []       # (harness, scope, display_name)
bundle_state = {}    # harness -> state of THIS plugin there
inventory_lines = []
limits = []


def default_harness_inventory():
    host, bundle_live, other_plugins = [], [], []
    listing, src = None, ""
    fk = fake("HARNESS_LIST")
    no_cli = os.environ.get("HOSTCHECK_FAKE_NO_HARNESS_CLI") == "1"
    if fk:
        try:
            with open(fk) as f:
                listing, src = f.read(), "fixture server listing"
        except Exception as e:  # noqa: BLE001
            inventory_lines.append("  default harness: fixture listing unreadable (%s)" % e)
    elif not no_cli and os.environ.get("PM_SKIP_MCP_LIST") != "1" and shutil.which("claude"):
        rc, out = sh("claude mcp list 2>/dev/null")
        if rc == 0 and out.strip():
            listing, src = out, "live server listing"
    if listing is not None:
        for line in listing.splitlines():
            line = ANSI.sub("", line).strip()
            if ": " not in line or " - " not in line:
                continue
            left = line.split(": ", 1)[0].strip()
            status = line.rsplit(" - ", 1)[1].strip()
            if left.startswith("plugin:"):
                parts = left.split(":", 2)
                if len(parts) == 3:
                    other_plugins.append((parts[1], parts[2], status))
            else:
                host.append(("registered server", left, status))
    else:
        src = "config fallback (harness CLI unavailable or listing skipped)"
        cj_path = fake("USER_CONFIG") or os.path.join(HOME, ".claude.json")
        try:
            with open(cj_path) as f:
                cj = json.load(f)
            seen = set()
            for name in (cj.get("mcpServers") or {}):
                if norm(name) not in seen:
                    seen.add(norm(name))
                    host.append(("user scope", name, ""))
            for proj in (cj.get("projects") or {}).values():
                for name in ((proj or {}).get("mcpServers") or {}):
                    if norm(name) not in seen:
                        seen.add(norm(name))
                        host.append(("project scope", name, ""))
        except Exception:  # noqa: BLE001
            limits.append("no readable harness user config — user/project server scope unknown, so "
                          "a duplicate there would not be visible to this run")
    for pname, sname, status in other_plugins:
        host.append(("plugin:%s" % pname, sname, status))
    hn = ", ".join("%s [%s%s]" % (n, sc, ", " + st if st else "") for sc, n, st in host) or "(none)"
    inventory_lines.append("  default harness (%s): host-side servers: %s" % (src or "not detectable", hn))
    bundle_state["default harness"] = "declares %d server(s)" % len(bundle_servers) \
        if bundle_servers else "brings no servers"
    return [("default harness", sc, n) for sc, n, _ in host]


def declared_harness_inventory(spec):
    hid = str((spec or {}).get("id") or "declared harness")
    path = str((spec or {}).get("path") or "")
    fmt = str((spec or {}).get("format") or "").lower()
    skey = str((spec or {}).get("servers_key") or "")
    if not path or fmt not in ("json", "toml") or not skey:
        limits.append("harness %r declaration incomplete (needs path, format json|toml, "
                      "servers_key) — not inventoried" % hid)
        return []
    path = os.path.expanduser(path)
    if not os.path.isfile(path):
        inventory_lines.append("  %s: not present on this host (declared config file absent)" % hid)
        bundle_state[hid] = "absent"
        return []
    names = []
    if fmt == "json":
        try:
            with open(path) as f:
                cfg = json.load(f)
        except Exception as e:  # noqa: BLE001
            inventory_lines.append("  %s: config unparseable (%s) — inventory unknown" % (hid, e))
            bundle_state[hid] = "unknown"
            return []
        table = dig(cfg, skey) or {}
        if isinstance(table, dict):
            for n, entry in table.items():
                # names (+ an enabled flag when present) ONLY — entry bodies can carry secrets
                disabled = isinstance(entry, dict) and entry.get("enabled") is False
                names.append(n + (" (disabled)" if disabled else ""))
        elif isinstance(table, list):
            names = [str(x) for x in table]
    else:
        try:
            import tomllib
            with open(path, "rb") as f:
                table = dig(tomllib.load(f), skey) or {}
            names = sorted(table.keys()) if isinstance(table, dict) else []
        except Exception:  # noqa: BLE001 — python older than 3.11, or malformed: header regex
            try:
                pat = re.compile(r'^\s*\[' + re.escape(skey) + r'\.(?:"([^"]+)"|([^\]"]+))\]\s*$')
                with open(path) as f:
                    for line in f:
                        m = pat.match(line)
                        if m:
                            raw = m.group(1) or m.group(2)
                            name = raw if m.group(1) else raw.split(".")[0]
                            if name not in names:
                                names.append(name)
            except Exception as e:  # noqa: BLE001
                inventory_lines.append("  %s: config unreadable (%s) — inventory unknown" % (hid, e))
                bundle_state[hid] = "unknown"
                return []
    inventory_lines.append("  %s (declared): servers at %s: %s"
                           % (hid, skey, ", ".join(names) or "(none)"))
    bundle_state[hid] = "this plugin's servers are not auto-consumed here — check its own install path"
    return [(hid, skey, n) for n in names]


host_regs += default_harness_inventory()
for spec in declared:
    host_regs += declared_harness_inventory(spec)
if not declared:
    limits.append("no extra harnesses declared in ${local:harness_configs} — only the default "
                  "harness was inventoried (set the key if you run others)")

# ── diff: verdict per item ───────────────────────────────────────────────────────────────────
items = []
for sname in bundle_servers:
    items.append((sname, True, mcp_deps.get(sname)))
for dname, drow in mcp_deps.items():
    if not any(same(dname, i[0]) for i in items):
        items.append((dname, False, drow))

verdicts = []
for name, bundled, drow in items:
    hits = [(h, sc, dn) for (h, sc, dn) in host_regs if same(name, dn.split(" (")[0])]
    if hits and bundled:
        v = "DUPLICATE"
        detail = ("the host already runs it: "
                  + "; ".join("%s %s '%s'" % (h, sc, dn) for h, sc, dn in hits)
                  + " — and this plugin declares '%s'" % name)
    elif hits:
        v = "PRESENT-host"
        detail = ("the host provides it (%s) and this plugin does not ship it — nothing to install"
                  % "; ".join("%s %s '%s'" % (h, sc, dn) for h, sc, dn in hits))
    elif bundled:
        v = "PRESENT-bundle"
        detail = "only this plugin provides it here — enabling the plugin is sufficient"
    else:
        v = "MISSING"
        detail = "nowhere on this host and not launched by this plugin"
    verdicts.append((v, name, detail, hits))

matched = set()
for v, name, _, hits in verdicts:
    matched.add(norm(name))
    for _, _, dn in hits:
        matched.add(norm(dn.split(" (")[0]))
host_only = ["%s (%s %s)" % (dn, h, sc) for h, sc, dn in host_regs
             if norm(dn.split(" (")[0]) not in matched
             and not any(same(dn.split(" (")[0], m) for m in matched)]

dups = [x for x in verdicts if x[0] == "DUPLICATE"]
missing = [x for x in verdicts if x[0] == "MISSING"]
skips = [x for x in verdicts if x[0] in ("PRESENT-host", "PRESENT-bundle")]

# ── report ───────────────────────────────────────────────────────────────────────────────────
print("== hostcheck — host-aware flight check ==")
print(HARD_RULE)
if FIXTURE_MODE:
    print("FIXTURE MODE: HOSTCHECK_FAKE_* overrides are active — everything below is FIXTURE data;"
          " never cite it as host evidence.")
print("-- host inventory --")
for line in inventory_lines:
    print(line)
if host_only:
    print("  host-only servers (no overlap with this plugin — untouched, listed for completeness): %s"
          % ", ".join(sorted(host_only)))
print("-- what enabling this plugin brings --")
print("  own servers (.mcp.json): %s"
      % (", ".join(sorted(bundle_servers)) or ("(none declared)" if mcp_json_present
                                               else "(this plugin ships no .mcp.json)")))
nb = sorted(n for n, b, _ in items if not b)
print("  server rows NOT bundled (registered separately when their stack is selected): %s"
      % (", ".join(nb) or "(none)"))
print("  non-server rows (cli/skill/config) are preflight territory — probed per verb with FIX "
      "lines, never host-inventory items: %s" % (", ".join(non_mcp_deps) or "(none)"))
eq_classes = sorted({tuple(sorted(eq_display.get(m, m) for m in c)) for c in eq_class.values()})
print("-- verdicts (equivalents honoured: %s) --"
      % ("; ".join(" ≡ ".join(c) for c in eq_classes) or "none declared"))
if verdicts:
    for v, name, detail, _ in verdicts:
        print("  %-14s %s — %s" % (v, name, detail))
else:
    print("  (none — this plugin declares no tool servers, so nothing of its own can duplicate)")
if limits:
    print("-- named limits of this inventory (what it could NOT see) --")
    for lim in limits:
        print("  · %s" % lim)

print("-- PLAN (proposals only — nothing was or will be executed by this tool) --")
if skips:
    print("  SKIP (no action needed):")
    for v, name, detail, _ in skips:
        print("    %s [%s] — %s" % (name, v, detail))
if missing:
    print("  INSTALL PROPOSALS — each REQUIRES YOUR APPROVAL (never auto-run; authorisation flows "
          "stay yours):")
    for _, name, _, _ in missing:
        drow = mcp_deps.get(name) or {}
        fix = (drow.get("fix") or "no row found — add one to config/dependencies.json first").strip()
        print("    PROPOSAL %s (auth_scope: %s) → %s" % (name, drow.get("auth_scope", "?"), fix))
if dups:
    print("  DEDUP PROPOSALS — choose ONE per duplicate (you decide; the host's and this plugin's "
          "configs may differ under the same capability — compare them by NAME in their own files; "
          "this tool never prints config contents or secrets):")
    for _, name, _, hits in dups:
        for h, sc, dn in hits:
            print("    PROPOSAL %s — %s: keep the HOST server (%s '%s') and disable this plugin's "
                  "entry where the plugin is enabled, OR keep this plugin's '%s' and disable the "
                  "host one. Never rename one to shadow the other. [state here: %s]"
                  % (name, h, sc, dn, name, bundle_state.get(h, "?")))

CALL_NOTE = ("nothing this package owns was changed; where the harness CLI was called it may have "
             "written its own config")
if dups or missing:
    print("VERDICT: action needed — %d duplicate(s) · %d missing. (exit 1 — REPORT-ONLY: %s; every "
          "proposal above awaits your explicit approval)" % (len(dups), len(missing), CALL_NOTE))
    print(HARD_RULE)
    sys.exit(1)
print("VERDICT: CLEAN — no duplicates, nothing missing. (exit 0; %s)" % CALL_NOTE)
print(HARD_RULE)
sys.exit(0)
PY
