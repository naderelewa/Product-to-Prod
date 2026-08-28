#!/usr/bin/env bash
# preflight.sh — JOB-SCOPED capability preflight for the verbs in this plugin.
#
# Each verb declares its capability MANIFEST in config/dependencies.json: a REQUIRED set plus
# CONDITIONAL sets keyed to the stack choices a run locks at right-sizing. This script probes ONLY
# the required set plus the --stack-selected conditional sets, prints a PASS/MISS table with the
# exact one-time fix per miss, and fails closed on any miss in the probed set. A missing capability
# NOTIFIES and blocks that verb — it never silently degrades into a quieter, wronger answer.
#
# Usage:
#   preflight.sh <verb> [--stack <key[,key…]>] [--setup] [--manifest <path>]
#   preflight.sh --help
#
#   <verb>       any verb declared in the manifest (--help lists them with their stack keys)
#   --stack      comma-separated conditional keys locked at right-sizing; an unknown key is a usage
#                error (exit 2), never a silent skip
#   --setup      run the idempotent INSTALLABLE fixes (rows carrying setup_cmd) for current misses.
#                AUTH and credential flows are NEVER executed — their instructions print for you to
#                run. Each successful setup_cmd is stamped so repeat runs skip finished work.
#   --manifest   manifest override (tests use this); default config/dependencies.json
#
# HOST-SPECIFIC VALUES: a probe or fix may reference ${local:<key>}, resolved per
# config/local.template.json — environment variable PM_LOCAL_<KEY> first, then config/local.json,
# else a NAMED MISS naming the key. An unresolved key is NEVER substituted with an empty string and
# the probe is not run: a probe against an empty path can only lie. No foreign default is ever
# offered — the miss names the key and what filling it unlocks.
#
# Probe method per kind (a row's probe is a bash expression run on THIS machine):
#   mcp     reachability first (`claude mcp list` when that CLI exists; a failed-to-connect or
#           needs-authentication server is a MISS), else registration presence in the harness user
#           config or this plugin's own .mcp.json when it has one; then the row's own probe.
#   cli     row probe only (command -v … + file tests)
#   skill   row probe only (skill directory / SKILL.md exists)
#   config  row probe only (file readable / key set)
#
# ELICITED ROWS (optional integrations): a row carrying `elicited_by: <local key>` is an integration
# this package ships with NO vendor, instance, or company preconfigured — the setup wizard asks
# whether you want it, and records your answer on your machine. While that key is unset or false the
# row is dropped from the probe set entirely: not probed, no FIX line, no effect on the exit code.
# It is listed once under "optional integrations not connected", because a setting that changes what
# a run can do must not be invisible — but absence here is a complete answer, never a miss.
#
# STAMP PATH (--setup only): PM_STAMP_JSON when set, else XDG_STATE_HOME, else the state rung under
# $HOME/.local/state — and under that rung the per-plugin folder this package uses everywhere else,
# the same one the usage log and the machine-local config are written under. One product name, one
# folder: a second name here would be a path the rename mechanism does not know about.
#
# Env: PM_DEPS_JSON (manifest path) · PM_LOCAL_JSON (local config path) · PM_STAMP_JSON (stamp path)
#      PM_LOCAL_<KEY> (one local key) · PM_SKIP_MCP_LIST=1 (skip the reachability layer — tests use
#      it for determinism) · PM_SKIP_HOSTCHECK=1 (skip the step-0 host check, which is report-only
#      and never blocks).
#
# Exit: 0 = every probed capability PASSes · 1 = ≥1 miss (each listed with its exact fix) ·
#       2 = usage / unknown verb or stack key / manifest error, OR an environment fault that stops
#           this gate running at all (no working python3) — fail-closed, never guessed. A 2 is a
#           failure, never a pass: a gate that could not run has not been passed. Nothing else
#           escapes either: a missing interpreter used to leave the shell's own not-found status
#           behind, and a status this header does not name cannot be acted on by whatever runs it.
# Dependencies: python3 only. Probes are read-only; --setup additionally runs setup_cmd installs and
# writes the stamp file. Secrets stay pointers — never read, never echoed.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# ── THE INTERPRETER IS A PRECONDITION, CHECKED FIRST ───────────────────────────────────────────
# Everything below the heredoc is python3, and `exec` into a missing interpreter leaves the shell's
# own not-found status behind as this script's answer — a number the header above does not name and
# nothing calling this can act on. So an environment fault is caught HERE and reported as what it
# is: a 2, a gate that could not run, which is never a pass. Checked before step-0 so a host with no
# python3 gets one true sentence instead of a host-check report it could not produce either.
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c '' >/dev/null 2>&1; then
  echo "preflight: no working python3 interpreter on this host — this gate could not run, so nothing" >&2
  echo "           was probed and nothing was passed. Install the command line tools (on macOS:" >&2
  echo "           xcode-select --install) or put a python3 on PATH, then run this again." >&2
  exit 2
fi
# ── step-0 · host check — REPORT-ONLY: it never installs, removes, or enables anything, and a ──
# ── finding never blocks preflight (notify, then continue)                                   ──
# The host check's OWN exit codes are read one by one. Collapsing every non-zero status into the
# single "found duplicates/missing" sentence prints a diagnosis that is untrue whenever the check
# could not run at all (its 2), and claims findings nobody measured — the opposite of what a
# report-only step is for.
if [ "$#" -gt 0 ] && [ "${PM_SKIP_HOSTCHECK:-0}" != "1" ]; then
  case " $* " in
    *" --help "*|*" -h "*) : ;;
    *) PM_SKIP_MCP_LIST=1 bash "$SCRIPT_DIR/hostcheck.sh"; hc_rc=$?
       case "$hc_rc" in
         0) : ;;
         1) echo "preflight step-0: hostcheck found duplicates/missing on this host (proposals above — report-only, nothing changed; preflight continues)" ;;
         2) echo "preflight step-0: hostcheck COULD NOT RUN on this host (its own reason is printed above). Nothing was inventoried, so this is not a finding and not a clean bill either; preflight continues." ;;
         *) echo "preflight step-0: hostcheck exited $hc_rc, a status it does not declare (its output is above). Treated as could-not-run, never as a finding; preflight continues." ;;
       esac ;;
  esac
fi
exec python3 - "$SCRIPT_DIR" "$@" <<'PY'
import json, os, re, shutil, subprocess, sys
from datetime import datetime, timezone

script_dir = sys.argv[1]
argv = sys.argv[2:]
ROOT = os.path.dirname(script_dir)
USAGE = ("usage: preflight.sh <verb> [--stack <key[,key...]>] [--setup] [--manifest <path>]\n"
         "       preflight.sh --help")
KINDS = {"mcp", "skill", "cli", "config"}
SCOPES = {"machine", "account", "session"}
LOCAL_REF = re.compile(r"\$\{local:([A-Za-z0-9_.-]+)\}")


def die(msg, rc=2):
    sys.stderr.write(msg.rstrip() + "\n")
    sys.exit(rc)


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sh(cmd, timeout=45):
    """Run a bash expression; return (rc, combined output)."""
    try:
        p = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124, "timed out after %ss" % timeout
    except Exception as e:  # noqa: BLE001 — surface, never mask
        return 125, "runner error: %s" % e


# ── local config (${local:<key>} resolution: env → local.json → NAMED MISS) ───────────────────
local_path = os.environ.get("PM_LOCAL_JSON") or os.path.join(ROOT, "config", "local.json")
local_values = {}
local_source = "none"
try:
    with open(local_path) as f:
        local_values = (json.load(f).get("local") or {})
    local_source = local_path
except FileNotFoundError:
    local_source = "no config/local.json yet (env vars only)"
except Exception as e:  # noqa: BLE001 — a corrupt local config must be loud, not ignored
    die("config/local.json unreadable/invalid JSON: %s (%s) — fix or remove it; preflight will not "
        "guess your machine layout" % (local_path, e))


def local_get(key):
    env_name = "PM_LOCAL_" + re.sub(r"[.-]", "_", key).upper()
    v = os.environ.get(env_name)
    if v is not None and str(v).strip() != "":
        return str(v), env_name
    v = local_values.get(key)
    if v is None or (isinstance(v, str) and not v.strip()):
        return None, None
    if isinstance(v, (dict, list)):
        return json.dumps(v), local_source
    return str(v), local_source


def expand_local(text):
    """Substitute every ${local:<key>}. Returns (expanded, [unresolved keys])."""
    missing = []

    def sub(m):
        key = m.group(1)
        val, _src = local_get(key)
        if val is None:
            missing.append(key)
            return ""
        return val

    return LOCAL_REF.sub(sub, text or ""), missing


# ── args ─────────────────────────────────────────────────────────────────────────────────────
verb, stack_raw, do_setup, manifest_path, help_mode = None, "", False, None, False
i = 0
while i < len(argv):
    a = argv[i]
    if a in ("-h", "--help"):
        help_mode = True
    elif a == "--setup":
        do_setup = True
    elif a == "--stack":
        i += 1
        if i >= len(argv):
            die("--stack needs a value\n" + USAGE)
        stack_raw = argv[i]
    elif a == "--manifest":
        i += 1
        if i >= len(argv):
            die("--manifest needs a path\n" + USAGE)
        manifest_path = argv[i]
    elif a.startswith("-"):
        die("unknown flag %r\n%s" % (a, USAGE))
    elif verb is None:
        verb = a
    else:
        die("unexpected argument %r\n%s" % (a, USAGE))
    i += 1

manifest_path = manifest_path or os.environ.get("PM_DEPS_JSON") \
    or os.path.join(ROOT, "config", "dependencies.json")

# ── manifest (fail-closed on shape errors — a malformed manifest must never half-probe) ───────
try:
    with open(manifest_path) as f:
        manifest = json.load(f)
except Exception as e:  # noqa: BLE001
    if help_mode or (verb is None and not argv):
        print("preflight.sh — job-scoped capability preflight")
        print(USAGE)
        print("(manifest unreadable at %s — verb/stack listing unavailable: %s)" % (manifest_path, e))
        sys.exit(0 if help_mode else 2)
    die("manifest unreadable/invalid JSON: %s (%s)" % (manifest_path, e))
deps = manifest.get("deps")
verbs = manifest.get("verbs")
if not isinstance(deps, dict) or not deps or not isinstance(verbs, dict) or not verbs:
    die("manifest %s missing deps{}/verbs{}" % manifest_path)
for name, d in deps.items():
    if not isinstance(d, dict) or d.get("kind") not in KINDS:
        die("manifest row %r: kind must be one of mcp|skill|cli|config" % name)
    if not isinstance(d.get("probe"), str) or (not d["probe"].strip() and d["kind"] != "mcp"):
        die("manifest row %r: probe must be a bash expression (empty legal only for kind=mcp)" % name)
    if not isinstance(d.get("fix"), str) or not d["fix"].strip():
        die("manifest row %r: fix (the exact one-time instruction) is required" % name)
    if d.get("auth_scope") not in SCOPES:
        die("manifest row %r: auth_scope must be machine|account|session" % name)

if help_mode or (verb is None and not argv):
    print("preflight.sh — job-scoped capability preflight")
    print(USAGE)
    print()
    print("verbs + conditional stack keys (from %s):" % manifest_path)
    for v in verbs:
        spec = verbs[v] or {}
        req = ", ".join(spec.get("required") or []) or "(none)"
        keys = ", ".join(sorted((spec.get("conditional") or {}).keys())) or "(none)"
        print("  %s\n    required: %s\n    --stack keys: %s" % (v, req, keys))
    print()
    print("local config: %s" % local_source)
    print("A MISS on any probed capability exits 1 and BLOCKS the verb run (notify, never silently")
    print("degrade). --setup runs only the installable fixes; auth flows always print as")
    print("instructions. An unset ${local:} key is a NAMED miss, never a guessed default.")
    print("An ELICITED row (an optional integration you were asked about and declined, or were")
    print("never asked about) is NOT probed and is NOT a miss: it is listed as not connected and")
    print("does not affect the exit code. No vendor and no company is preconfigured in any row.")
    sys.exit(0 if help_mode else 2)

if verb is None:
    die(USAGE)
if verb not in verbs:
    die("unknown verb %r — manifest verbs: %s" % (verb, ", ".join(sorted(verbs))))

vspec = verbs[verb] or {}
required = vspec.get("required") or []
conditional = vspec.get("conditional") or {}
selected = [k.strip() for k in stack_raw.split(",") if k.strip()]
unknown = [k for k in selected if k not in conditional]
if unknown:
    die("unknown stack key(s) for %s: %s — valid keys: %s"
        % (verb, ", ".join(unknown), ", ".join(sorted(conditional)) or "(none)"))

order, seen = [], set()
for dn in list(required) + [d for k in selected for d in (conditional.get(k) or [])]:
    if dn not in deps:
        die("manifest error: verb %s references unknown row %r" % (verb, dn))
    if dn not in seen:
        seen.add(dn)
        order.append(dn)
if not order:
    die("verb %s resolves to an empty capability set — manifest error" % verb)


# ── elicited rows: absent until the wizard asked and the user said yes ────────────────────────
# An ELICITED row (one carrying elicited_by) describes an OPTIONAL INTEGRATION that this package
# ships with nobody's vendor, instance, or company preconfigured. Until its switch key is true it
# is not a capability this run is missing — it is a capability this user never asked for, so it is
# dropped from the probe set entirely: no probe, no FIX line, no effect on the exit code. It is
# still PRINTED, once, under its own heading, because a setting that changes what the run can do
# must never be invisible; "not connected" is a fact the reader is entitled to, and it is not a miss.
TRUE_ISH = ("1", "true", "yes", "on")


def elicited_off(d):
    """(is_elicited, is_off). A row with no elicited_by is an ordinary always-probed row."""
    key = d.get("elicited_by")
    if not key:
        return False, False
    val, _src = local_get(key)
    return True, (val is None or str(val).strip().lower() not in TRUE_ISH)


not_elicited = [n for n in order if elicited_off(deps[n])[1]]
order = [n for n in order if n not in not_elicited]
for _n in not_elicited:
    _row = deps[_n]
    if not isinstance(_row.get("elicit"), dict):
        die("manifest row %r carries elicited_by but no elicit{} block — the wizard would have no "
            "question to ask, and an integration nobody can be offered is dead config" % _n)
if not order:
    die("verb %s resolves to an empty capability set once optional integrations are excluded — "
        "manifest error (a verb's required set may never be empty)" % verb)

# ── mcp reachability layer ───────────────────────────────────────────────────────────────────
_mcp_list_cache = None


def harness_mcp_list():
    """Harness server listing, once; '' when unavailable or skipped."""
    global _mcp_list_cache
    if _mcp_list_cache is None:
        if os.environ.get("PM_SKIP_MCP_LIST") == "1" or not shutil.which("claude"):
            _mcp_list_cache = ""
        else:
            rc, out = sh("claude mcp list 2>/dev/null", timeout=60)
            _mcp_list_cache = out if rc == 0 else ""
    return _mcp_list_cache


def plugin_config_presence(name):
    try:
        with open(os.path.join(ROOT, ".mcp.json")) as f:
            return name in (json.load(f).get("mcpServers") or {})
    except Exception:  # noqa: BLE001 — this plugin need not ship an .mcp.json at all
        return False


def user_config_presence(name):
    try:
        with open(os.path.join(os.path.expanduser("~"), ".claude.json")) as f:
            cj = json.load(f)
        if name in (cj.get("mcpServers") or {}):
            return True, "registered in the harness user config (user scope)"
        for proj in (cj.get("projects") or {}).values():
            if name in ((proj or {}).get("mcpServers") or {}):
                return True, "registered in the harness user config (project scope)"
    except Exception:  # noqa: BLE001
        pass
    return False, ""


def probe_dep(name, d):
    """Return (ok, detail). Unresolved ${local:} keys miss BEFORE any probe runs."""
    details = []
    probe_raw = (d.get("probe") or "").strip()
    probe, missing_keys = expand_local(probe_raw)
    if missing_keys:
        return False, ("local config key(s) unset: %s — set them in config/local.json (or the "
                       "matching PM_LOCAL_* env var); the probe was NOT run against an empty value"
                       % ", ".join(sorted(set(missing_keys))))
    if d["kind"] == "mcp":
        listing = harness_mcp_list()
        line = None
        if listing:
            line = next((l.strip() for l in listing.splitlines()
                         if l.strip().startswith(name + ":")
                         or (":" + name + ":") in l.strip()), None)
        if line is not None:
            low = line.lower()
            if "✗" in line or "✘" in line or "failed to connect" in low:
                return False, "server listing: registered but FAILED to connect"
            if "needs auth" in low:
                return False, ("server listing: registered but NOT authenticated — complete the "
                               "once-per-account authorisation (see FIX)")
            details.append("server listing: reachable")
        else:
            ok_user, det_user = user_config_presence(name)
            if ok_user:
                details.append(det_user)
            elif not plugin_config_presence(name):
                return False, "NOT registered (harness user config / this plugin's own .mcp.json)"
            elif d.get("auth_scope") == "account":
                # A plugin always declares its own servers, so that presence proves nothing about
                # the once-per-account authorisation — the only thing that can actually be missing.
                return False, ("declared by this plugin, but the once-per-account authorisation is "
                               "UNVERIFIED (self-declaration is not proof) — complete the FIX, then "
                               "confirm in your harness's server listing")
            else:
                details.append("declared by this plugin")
    if probe:
        rc, _ = sh(probe)
        if rc != 0:
            miss = "probe failed: %s" % probe_raw
            if details:
                miss += "  [%s]" % "; ".join(details)
            return False, miss
        details.append("probe passed")
    if not details:
        details.append("registration is the artifact (no row probe)")
    return True, "; ".join(details)


# ── stamp (--setup only; labelled by ${local:provenance_id}, never by a machine identity) ─────
PKG_SLUG = "product2prod"          # the declared plugin name: one product name, one host folder
stamp_path = os.environ.get("PM_STAMP_JSON") or os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state"),
    PKG_SLUG, "preflight-stamp.json")
prov, _src = local_get("provenance_id")
provenance = prov or "unattributed"


def load_stamp():
    try:
        with open(stamp_path) as f:
            s = json.load(f)
        if s.get("provenance") != provenance:
            return {"provenance": provenance, "deps": {}, "at": None}  # foreign stamp ignored
        if not isinstance(s.get("deps"), dict):
            s["deps"] = {}
        return s
    except Exception:  # noqa: BLE001
        return {"provenance": provenance, "deps": {}, "at": None}


def save_stamp(s):
    s["at"] = now_iso()
    os.makedirs(os.path.dirname(stamp_path) or ".", exist_ok=True)
    tmp = stamp_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, stamp_path)


# ── probe pass ───────────────────────────────────────────────────────────────────────────────
results = {}
for name in order:
    results[name] = probe_dep(name, deps[name])

setup_lines = []
if do_setup:
    missing = [n for n in order if not results[n][0]]
    if not missing:
        setup_lines.append("  (nothing to set up — every probed capability already PASSes)")
    else:
        stamp = load_stamp()
        stamp_dirty = False
        for name in missing:
            d = deps[name]
            cmd_raw = (d.get("setup_cmd") or "").strip()
            cmd, cmd_missing = expand_local(cmd_raw)
            if not cmd_raw:
                fix, _ = expand_local(d["fix"])
                setup_lines.append("  MANUAL %s — one-time step, never auto-run; do it yourself: %s"
                                   % (name, fix or d["fix"]))
                continue
            if cmd_missing:
                setup_lines.append("  SKIP %s — setup_cmd needs unset local key(s): %s"
                                   % (name, ", ".join(sorted(set(cmd_missing)))))
                continue
            if name in stamp["deps"]:
                setup_lines.append(
                    "  SKIP %s — setup_cmd already ran here (%s); the probe still misses, so the "
                    "remaining fix is the manual part: %s"
                    % (name, (stamp["deps"][name] or {}).get("at", "?"), d["fix"]))
                continue
            rc, out = sh(cmd, timeout=900)
            if rc != 0:
                tail = " · ".join(out.splitlines()[-3:]) if out else "(no output)"
                setup_lines.append("  FAIL %s — setup_cmd exited %d: %s" % (name, rc, tail))
                continue
            stamp["deps"][name] = {"at": now_iso()}
            stamp_dirty = True
            results[name] = probe_dep(name, d)  # re-probe after the install
            if results[name][0]:
                setup_lines.append("  RAN  %s — setup_cmd ok; probe now PASSES (stamped)" % name)
            else:
                setup_lines.append("  RAN  %s — setup_cmd ok (stamped) but the probe STILL fails; "
                                   "remaining fix is the manual part: %s" % (name, d["fix"]))
        if stamp_dirty:
            save_stamp(stamp)

# ── report (every line, then the verdict; exit 1 on any miss) ─────────────────────────────────
print("== preflight (verb=%s · stack=%s) ==" % (verb, ",".join(selected) or "∅ required-only"))
for name in order:
    ok, detail = results[name]
    print("  %s %s [%s] — %s" % ("OK  " if ok else "MISS", name, deps[name]["kind"], detail))
if not_elicited:
    print("-- optional integrations not connected (not misses; nothing to fix) --")
    for name in not_elicited:
        print("  n/a  %s — %s" % (name, (deps[name].get("elicit") or {}).get("on_no", "not connected")))
    print("  (to connect one, run this plugin's setup skill; it asks, and records your answer "
          "locally. Declining is a complete answer and stays declined.)")
if setup_lines:
    print("-- setup --")
    for line in setup_lines:
        print(line)
misses = [n for n in order if not results[n][0]]
if misses:
    print("---")
    for name in misses:
        fix, fix_missing = expand_local(deps[name]["fix"])
        if fix_missing:
            fix = deps[name]["fix"]  # show the raw text rather than a hole
        print("  FIX  %s (auth_scope: %s) → %s" % (name, deps[name]["auth_scope"], fix))
    print("== PREFLIGHT FAILED: %d miss(es) — a miss on the required+selected set BLOCKS the %s "
          "run; apply the FIX lines above (installables: rerun with --setup) ==" % (len(misses), verb))
    sys.exit(1)
print("== PREFLIGHT OK: %d capability row(s) satisfied for %s ==" % (len(order), verb))
sys.exit(0)
PY
