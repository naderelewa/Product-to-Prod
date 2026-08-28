#!/usr/bin/env bash
# telemetry.sh — the ONE writer of this plugin's optional local event log, and the ONE remover.
#
#   telemetry.sh emit <event> [key=value ...]        append ONE JSONL line (silent, always rc 0)
#   telemetry.sh consent local "<basis>"             record the typed yes and turn capture on
#   telemetry.sh consent off  ["<reason>"]           turn capture off, keep the log and the record
#   telemetry.sh status                              print what is on, where it is, how big it is
#   telemetry.sh purge [--apply]                     remove the log + this feature's own keys
#   telemetry.sh uninstall [--apply --confirm "<phrase>"]
#                                                    remove the log AND the config file
#   telemetry.sh help
#
# THE CONTRACT — six properties, each enforced by a mechanism in this file, not by prose.
#
#   OFF UNTIL ASKED        The default mode is `off`. With no config, a malformed config, or a
#                          config whose telemetry.mode is not exactly `local`, this file writes
#                          NOTHING and creates NO directory. The mode gate is checked BEFORE any
#                          directory would be made, so declining leaves no trace on disk at all.
#
#   CONSENT IS A RECORD    `telemetry.mode` is the SETTING. `acknowledged.telemetry_local` is the
#                          CONSENT: when it was given and on what basis, in the user's own words.
#                          `consent local` refuses to write without a basis, and nothing here ever
#                          writes anything on a NO — an empty record means declined-or-never-asked,
#                          and both are true statements that a fabricated timestamp would destroy.
#
#   CLASS ONLY, ENFORCED   A value is stored only if it is a bare `[A-Za-z0-9_.:-]` token of at
#                          most 64 characters. Anything else is stored as `?`, WHOLE and never
#                          partially. `/` is outside that set BY CONSTRUCTION, so a real path
#                          cannot be recorded even by a call site that passes one in error, and
#                          the length bound REJECTS rather than truncates — validate the whole
#                          value, then bound it, never the other way round. Truncating first would
#                          hand the character test a value the caller never passed: a long
#                          absolute path whose first 64 characters happen to be class-clean would
#                          land on disk as a real path prefix and never be seen as a failure.
#                          That is the partial storage this rule exists to refuse.
#
#   NOTHING LEAVES         There is no transmission path in this build. This file speaks to the
#                          local filesystem and to nothing else: no transport, no remote, no
#                          push, no upload, no third mode to turn on. A feature that sends
#                          anything anywhere has to be written, with its own consent gate — it
#                          cannot be reached by editing a config value.
#
#   BOUNDED ON DISK        Ring rotation, checked on every append: the live generation is rotated
#                          to the single previous generation at `telemetry.max_bytes` (512 KiB by
#                          default), and that previous generation is REPLACED, never accumulated.
#                          The log therefore occupies at most 2 generations — about 1 MB on the
#                          default — forever, with no cleanup job that can fail. The generation
#                          count is structural and is not a config key.
#
#   NEVER BREAKS A CALLER  `emit` is silent on stdout and stderr and always exits 0. Callers
#                          invoke it as `telemetry.sh emit ... || true` and discard its output:
#                          telemetry that can fail its caller is a worse defect than telemetry
#                          that is missing. In a harness where stdout is session context — or a
#                          permission-decision channel — one stray line is a corrupted contract.
#
# THE ENVIRONMENT CONTRACT — four names, one namespace (`PKG_`), and nothing else.
#   PKG_CONFIG             absolute path to the config file, overriding the ladder below
#   PKG_DATA_DIR           where a NEW log would live; ignored once telemetry.dir is recorded
#   PKG_TELEMETRY_SESSION  an opaque grouping id; what lands on disk is a 12-hex digest of it
#   PKG_PYTHON             the name of a python 3 interpreter to try ahead of the usual ones; the
#                          version probe still applies, so a name that is not 3.x is refused
#   (names private to this file are `_pkg_*` in the shell and `PKG_T_*` where python must see
#   them, so nothing here can be mistaken for a config key.)
#
# RESOLUTION LADDERS, composed at run time from the environment — this file contains no absolute
# path and no home-directory literal, which is also what keeps it portable across harnesses:
#   config: $PKG_CONFIG  ->  $XDG_CONFIG_HOME/<slug>/config.json  ->  $HOME/.config/<slug>/config.json
#   log dir: telemetry.dir (RECORDED, wins)  ->  $PKG_DATA_DIR  ->  $XDG_STATE_HOME/<slug>
#            ->  $HOME/.local/state/<slug>
# The recorded value wins on purpose: the writer and the remover must never disagree about which
# directory is in play, and removal acts on what was RECORDED, never on a path it inferred.
#
# THE DEFAULT TABLE below is the ONE the shipped code applies. config.schema.json declares the
# same defaults as its declarative twin; if the two ever disagree, this file is what runs.
#
# THE NAME. product2prod is this package's declared name. Every config path, log directory and
# stamp folder below composes from the slug set immediately after this header, so the name is
# stated once and read everywhere.

set -uo pipefail

_pkg_slug="product2prod"
_pkg_log_name="telemetry.jsonl"          # the ring's second generation is this name plus `.1`
_pkg_def_mode="off"
_pkg_def_max_bytes="524288"              # 512 KiB per generation, 2 generations, ~1 MB forever
_pkg_confirm_phrase="apply uninstall"    # the ONE phrase; any caller must ask for these words

# ---------------------------------------------------------------------------------
# resolution helpers — one implementation each, used by every subcommand
# ---------------------------------------------------------------------------------

# The config path, or rc 1 when the environment names nowhere to look. rc 1 is a finding, not an
# error: with no HOME and no override there is no machine-local config, so this feature is inert.
_pkg_cfg_path() {
  if [ -n "${PKG_CONFIG:-}" ]; then printf '%s' "${PKG_CONFIG}"; return 0; fi
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then printf '%s/%s/config.json' "${XDG_CONFIG_HOME}" "$_pkg_slug"; return 0; fi
  if [ -n "${HOME:-}" ]; then printf '%s/.config/%s/config.json' "${HOME}" "$_pkg_slug"; return 0; fi
  return 1
}

# Where a NEW log would go. Only ever a FALLBACK: a recorded telemetry.dir wins over all of it.
_pkg_dir_fallback() {
  if [ -n "${PKG_DATA_DIR:-}" ]; then printf '%s' "${PKG_DATA_DIR}"; return 0; fi
  if [ -n "${XDG_STATE_HOME:-}" ]; then printf '%s/%s' "${XDG_STATE_HOME}" "$_pkg_slug"; return 0; fi
  if [ -n "${HOME:-}" ]; then printf '%s/.local/state/%s' "${HOME}" "$_pkg_slug"; return 0; fi
  return 1
}

# A python 3 interpreter, by name only — no interpreter path is baked into this tree. The version
# probe is the point: a bare `python` that is not 3.x is refused rather than handed this program.
_pkg_py() {
  _pkg_c=""
  for _pkg_c in "${PKG_PYTHON:-}" python3 python; do
    [ -n "$_pkg_c" ] || continue
    command -v "$_pkg_c" >/dev/null 2>&1 || continue
    "$_pkg_c" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1 || continue
    printf '%s' "$_pkg_c"
    return 0
  done
  return 1
}

_pkg_usage() {
  cat <<'USAGE'
telemetry.sh — this plugin's optional, local-only event log. Off until you turn it on.

  emit <event> [key=value ...]     append one line (silent; never fails its caller)
  consent local "<basis>"          record a typed yes and start capturing
  consent off ["<reason>"]         stop capturing; the log and the consent record stay
  status                           what is on, where the log is, how big it is
  purge [--apply]                  delete the log and clear this feature's own config keys
  uninstall [--apply --confirm "apply uninstall"]
                                   delete the log AND the whole config file for this plugin
  help                             this text

Both purge and uninstall are DRY RUN by default: they print exactly what they would remove and
change nothing. Nothing in this file sends anything anywhere.

Exit codes: 0 ok (a dry run is a success) · 1 a step FAILED · 2 usage · 4 REFUSED by a rule.
USAGE
}

_pkg_cmd="${1:-}"
[ "$#" -gt 0 ] && shift

case "$_pkg_cmd" in

  # =================================================================================
  # emit — one line, consent-gated, class-only, ring-bounded, silent, always rc 0.
  #
  # Every rung below ends the call having written nothing. The ladder is re-run HERE, in the
  # writer, rather than trusted from a caller: most call sites are skills and scripts, not
  # hooks, and a gate that lives only in the caller is a gate that one new caller forgets.
  # =================================================================================
  emit)
    [ -n "${1:-}" ] || exit 0                                   # rung 1: an event name
    PKG_T_CFG="$(_pkg_cfg_path)" || exit 0                      # rung 2: somewhere to read
    PKG_T_DIR_FALLBACK="$(_pkg_dir_fallback || printf '')"
    PKG_T_PY="$(_pkg_py)" || exit 0                             # rung 3: a usable interpreter
    PKG_T_DEF_MODE="$_pkg_def_mode"
    PKG_T_DEF_MAX="$_pkg_def_max_bytes"
    PKG_T_LOG_NAME="$_pkg_log_name"
    export PKG_T_CFG PKG_T_DIR_FALLBACK PKG_T_DEF_MODE PKG_T_DEF_MAX PKG_T_LOG_NAME
    "$PKG_T_PY" - "$@" >/dev/null 2>&1 <<'PY' || true
import hashlib, json, os, string, sys, time

MAX_TOKEN = 64
# Built from the standard library rather than typed as one long literal: a 60-character run of
# letters and digits inside a shipped file is indistinguishable, to any secret-shaped scanner,
# from a key. The set is the point, not its spelling.
OK = set(string.ascii_letters + string.digits + "_.:-")


def klass(value):
    """A CLASS token, or `?`. Refuses whole values instead of sanitising them: a half-scrubbed
    path is still a path, and `/` is outside OK by construction.

    VALIDATE THE WHOLE VALUE, THEN BOUND IT — never the other way round. The length bound
    REJECTS; it does not truncate. Truncating first would hand the character test a value the
    caller never passed: anything longer than the bound whose FIRST 64 characters happen to be
    class-clean would be written verbatim-but-cut, so a long absolute path would land on disk as
    a real path prefix and never be seen as a failure."""
    text = str(value)
    if not text:
        return ""
    if len(text) > MAX_TOKEN or not all(ch in OK for ch in text):
        return "?"
    return text


def cfg_read(path):
    """The config, or None when it cannot be read as an object. A malformed config is treated
    exactly like an absent one HERE — inert, silent — because the emit path is not the place to
    tell anyone about it: `status` reports it, and the setup skill repairs it."""
    try:
        with open(path) as fh:
            data = json.load(fh)
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def ns(cfg, name):
    node = cfg.get(name)
    return node if isinstance(node, dict) else {}


cfg = cfg_read(os.environ["PKG_T_CFG"])
if cfg is None:
    raise SystemExit(0)                       # rung 4: no readable config -> no events

tel = ns(cfg, "telemetry")

# rung 5: THE MODE GATE, and it sits above every line that could create a directory. Anything
# that is not exactly `local` is off — an unknown or misspelled value is never read as the more
# permissive setting.
if tel.get("mode", os.environ["PKG_T_DEF_MODE"]) != "local":
    raise SystemExit(0)

target = tel.get("dir") or os.environ.get("PKG_T_DIR_FALLBACK") or ""
if not target:
    raise SystemExit(0)                       # rung 6: nowhere to write

try:
    max_bytes = int(tel.get("max_bytes", os.environ["PKG_T_DEF_MAX"]))
except (TypeError, ValueError):
    max_bytes = int(os.environ["PKG_T_DEF_MAX"])
if max_bytes < 4096:
    max_bytes = int(os.environ["PKG_T_DEF_MAX"])

log = os.path.join(target, os.environ["PKG_T_LOG_NAME"])

rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
       "event": klass(sys.argv[1])}

# The grouping id, when a caller passed one. The RAW value is never stored: what lands on disk is
# a 12-hex digest, which groups one run's events exactly as the raw value would without
# reproducing anything the caller might have put in it.
raw = os.environ.get("PKG_TELEMETRY_SESSION", "")
if raw:
    rec["session"] = hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest()[:12]

for arg in sys.argv[2:]:
    if "=" not in arg:
        continue
    key, _, val = arg.partition("=")
    key = klass(key)
    if not key or key == "?" or key in rec:
        continue
    rec[key] = klass(val)

try:
    os.makedirs(target, exist_ok=True)        # created only AFTER the mode gate passed
except OSError:
    raise SystemExit(0)

# The ring, checked on every append. The previous generation is REPLACED, so two generations is
# structural: there is no third file to grow and no job that has to run to keep it that way.
try:
    if os.path.getsize(log) >= max_bytes:
        os.replace(log, log + ".1")
except OSError:
    pass
try:
    with open(log, "a") as fh:
        fh.write(json.dumps(rec, sort_keys=True, separators=(",", ":")) + "\n")
except OSError:
    pass
PY
    exit 0
    ;;

  # =================================================================================
  # consent — the only writer of the consent record, and the only writer of the setting.
  #
  #   consent local "<basis>"   requires a basis, records the ISO stamp with it, and RECORDS the
  #                             log directory, which is what makes the log removable by rule.
  #   consent off ["<reason>"]  flips the setting only. The log stays readable and purgeable, and
  #                             the record of when permission was given stays true — turning a
  #                             thing off does not unsay that it was once agreed to. `purge` is
  #                             the action that removes the data and the record together.
  # =================================================================================
  consent)
    _pkg_mode="${1:-}"
    _pkg_basis="${2:-}"
    case "$_pkg_mode" in
      local)
        if [ -z "$_pkg_basis" ]; then
          printf 'REFUSED: `consent local` needs the basis — the words the user actually typed.\n' >&2
          printf '         A consent record with no basis cannot tell a later reader what was agreed to.\n' >&2
          exit 4
        fi
        ;;
      off) : ;;
      *)
        printf 'usage: telemetry.sh consent <local|off> ["<basis>"]\n' >&2
        exit 2
        ;;
    esac
    PKG_T_CFG="$(_pkg_cfg_path)" || {
      printf 'FAILED: no config location — set PKG_CONFIG, XDG_CONFIG_HOME or HOME.\n' >&2
      exit 1; }
    PKG_T_DIR_FALLBACK="$(_pkg_dir_fallback || printf '')"
    PKG_T_PY="$(_pkg_py)" || {
      printf 'FAILED: no python 3 interpreter on PATH; nothing was written.\n' >&2
      exit 1; }
    PKG_T_MODE="$_pkg_mode"
    PKG_T_BASIS="$_pkg_basis"
    PKG_T_DEF_MAX="$_pkg_def_max_bytes"
    export PKG_T_CFG PKG_T_DIR_FALLBACK PKG_T_MODE PKG_T_BASIS PKG_T_DEF_MAX
    "$PKG_T_PY" - <<'PY'
import json, os, sys, time

path = os.environ["PKG_T_CFG"]
mode = os.environ["PKG_T_MODE"]
basis = os.environ["PKG_T_BASIS"]

# READ FIRST, AND REFUSE WHAT CANNOT BE PARSED. This config file is shared with the rest of the
# plugin, so rewriting one it could not read would silently delete settings this feature does not
# own. A refusal costs the user one repair; an overwrite costs them their other answers.
cfg = {}
if os.path.exists(path):
    try:
        with open(path) as fh:
            cfg = json.load(fh)
    except Exception as exc:
        sys.stderr.write(
            "REFUSED: %s exists but is not readable JSON (%s).\n"
            "         Nothing was written. Repair or move that file, then run this again —\n"
            "         it holds settings for the rest of this plugin, so it is not overwritten.\n"
            % (path, exc))
        raise SystemExit(4)
    if not isinstance(cfg, dict):
        sys.stderr.write("REFUSED: %s is valid JSON but not an object. Nothing was written.\n" % path)
        raise SystemExit(4)

tel = cfg.get("telemetry")
if not isinstance(tel, dict):
    tel = {}
ack = cfg.get("acknowledged")
if not isinstance(ack, dict):
    ack = {}

tel["mode"] = mode
if mode == "local":
    # Record the directory as well as the setting. This is the ledger the removal paths read:
    # they act on what was recorded and refuse to guess a location, so a later change to the
    # environment can never point a delete at a directory nobody consented to.
    if not tel.get("dir"):
        target = os.environ.get("PKG_T_DIR_FALLBACK", "")
        if not target:
            sys.stderr.write("FAILED: no log directory could be resolved; nothing was written.\n")
            raise SystemExit(1)
        tel["dir"] = target
    tel.setdefault("max_bytes", int(os.environ["PKG_T_DEF_MAX"]))
    ack["telemetry_local"] = "%s | basis: %s" % (
        time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), basis)

cfg["telemetry"] = tel
cfg["acknowledged"] = ack

parent = os.path.dirname(path)
try:
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(cfg, fh, indent=2, sort_keys=True)
        fh.write("\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)                     # atomic: a reader never sees half a config
except OSError as exc:
    sys.stderr.write("FAILED: could not write %s (%s). Nothing changed.\n" % (path, exc))
    raise SystemExit(1)

# THE RECEIPT, read back off disk — never echoed from the values above. A record you did not
# verify is the same defect as a gate you did not verify.
try:
    with open(path) as fh:
        back = json.load(fh)
except Exception as exc:
    sys.stderr.write("FAILED: wrote %s but could not read it back (%s).\n" % (path, exc))
    raise SystemExit(1)
bt = back.get("telemetry", {}) if isinstance(back.get("telemetry"), dict) else {}
ba = back.get("acknowledged", {}) if isinstance(back.get("acknowledged"), dict) else {}
print("config                       : %s" % path)
print("telemetry.mode               : %s" % bt.get("mode", ""))
print("telemetry.dir                : %s" % (bt.get("dir") or "(none recorded)"))
print("acknowledged.telemetry_local : %s" % (ba.get("telemetry_local") or "(none — not given)"))
PY
    exit $?
    ;;

  # =================================================================================
  # status — print the facts, compute nothing upstream of them.
  #
  # A value that cannot be read prints as `unknown (<reason>)`, never as 0 and never as blank:
  # a zero that means "could not read" is the one number nobody can act on.
  # =================================================================================
  status)
    PKG_T_CFG="$(_pkg_cfg_path || printf '')"
    PKG_T_DIR_FALLBACK="$(_pkg_dir_fallback || printf '')"
    PKG_T_PY="$(_pkg_py)" || {
      printf 'telemetry: unknown (no python 3 interpreter on PATH)\n'
      exit 1; }
    PKG_T_DEF_MODE="$_pkg_def_mode"
    PKG_T_DEF_MAX="$_pkg_def_max_bytes"
    PKG_T_LOG_NAME="$_pkg_log_name"
    export PKG_T_CFG PKG_T_DIR_FALLBACK PKG_T_DEF_MODE PKG_T_DEF_MAX PKG_T_LOG_NAME
    "$PKG_T_PY" - <<'PY'
import json, os

path = os.environ.get("PKG_T_CFG", "")
log_name = os.environ["PKG_T_LOG_NAME"]
state, cfg = "absent", {}
if not path:
    state = "unknown (no config location: set PKG_CONFIG, XDG_CONFIG_HOME or HOME)"
elif os.path.exists(path):
    try:
        with open(path) as fh:
            cfg = json.load(fh)
        state = "present" if isinstance(cfg, dict) else "malformed (valid JSON, not an object)"
        if not isinstance(cfg, dict):
            cfg = {}
    except Exception as exc:
        state, cfg = "malformed (%s)" % exc, {}

tel = cfg.get("telemetry") if isinstance(cfg.get("telemetry"), dict) else {}
ack = cfg.get("acknowledged") if isinstance(cfg.get("acknowledged"), dict) else {}
mode = tel.get("mode", os.environ["PKG_T_DEF_MODE"])
recorded = tel.get("dir") or ""
target = recorded or os.environ.get("PKG_T_DIR_FALLBACK", "")

try:
    max_bytes = int(tel.get("max_bytes", os.environ["PKG_T_DEF_MAX"]))
except (TypeError, ValueError):
    max_bytes = int(os.environ["PKG_T_DEF_MAX"])


def measure(p):
    """(size, lines) for one generation, or a reason string."""
    if not p:
        return "unknown (no directory resolved)"
    if not os.path.exists(p):
        return "absent"
    try:
        size, lines = os.path.getsize(p), 0
        with open(p, "rb") as fh:
            while True:
                chunk = fh.read(1024 * 1024)
                if not chunk:
                    break
                lines += chunk.count(b"\n")
        return "%d bytes, %d lines" % (size, lines)
    except OSError as exc:
        return "unknown (%s)" % exc


live = os.path.join(target, log_name) if target else ""
prev = live + ".1" if live else ""

print("mode                         : %s%s" % (mode, "  (default; nothing is captured)" if mode != "local" else "  (capturing, on this machine only)"))
print("consent record               : %s" % (ack.get("telemetry_local") or "(none — declined, or never asked)"))
print("config                       : %s [%s]" % (path or "(unresolved)", state))
print("log directory                : %s%s" % (target or "(unresolved)",
      "  (recorded)" if recorded else "  (not recorded — nothing is removable by rule)"))
print("log, live generation         : %s" % measure(live))
print("log, previous generation     : %s" % measure(prev))
print("ceiling                      : %d bytes per generation, 2 generations, structural" % max_bytes)
print("leaves this machine          : no — this build ships no transmission path of any kind")
PY
    exit $?
    ;;

  # =================================================================================
  # purge / uninstall — the ONE destructive path, dry-run by default.
  #
  # Both act on the RECORDED directory and on two exact basenames inside it. Never a glob, never
  # a path matched by shape: if the config does not record a directory, nothing is removed and
  # the honest sentence is printed instead. An uninstaller that guesses is worse than none,
  # because the thing it guesses wrong about is somebody's data.
  #
  #   purge      the log + this feature's own keys (mode -> off, dir cleared, record cleared).
  #              Every other key in the config belongs to another part of this plugin and is
  #              left byte-for-byte alone.
  #   uninstall  the log, and then the config FILE itself — which also removes any other
  #              settings this plugin keeps in it. That consequence is printed in the plan,
  #              before the confirmation, never discovered afterwards.
  # =================================================================================
  purge|uninstall)
    _pkg_apply="no"
    _pkg_confirm=""
    while [ "$#" -gt 0 ]; do
      case "${1:-}" in
        --apply)   _pkg_apply="yes" ;;
        --confirm) shift; _pkg_confirm="${1:-}" ;;
        *) printf 'usage: telemetry.sh %s [--apply] [--confirm "<phrase>"]\n' "$_pkg_cmd" >&2; exit 2 ;;
      esac
      shift
    done
    if [ "$_pkg_cmd" = "uninstall" ] && [ "$_pkg_apply" = "yes" ] \
       && [ "$_pkg_confirm" != "$_pkg_confirm_phrase" ]; then
      printf 'REFUSED: `uninstall --apply` needs --confirm "%s" — the exact words, typed by the\n' "$_pkg_confirm_phrase" >&2
      printf '         user in the conversation and passed through unchanged. Nothing was touched.\n' >&2
      exit 4
    fi
    PKG_T_CFG="$(_pkg_cfg_path || printf '')"
    PKG_T_PY="$(_pkg_py)" || {
      printf 'FAILED: no python 3 interpreter on PATH; nothing was touched.\n' >&2
      exit 1; }
    PKG_T_MODE_CMD="$_pkg_cmd"
    PKG_T_APPLY="$_pkg_apply"
    PKG_T_LOG_NAME="$_pkg_log_name"
    export PKG_T_CFG PKG_T_PY PKG_T_MODE_CMD PKG_T_APPLY PKG_T_LOG_NAME
    "$PKG_T_PY" - <<'PY'
import json, os, sys

path = os.environ.get("PKG_T_CFG", "")
cmd = os.environ["PKG_T_MODE_CMD"]
apply_it = os.environ["PKG_T_APPLY"] == "yes"
log_name = os.environ["PKG_T_LOG_NAME"]
head = "APPLY" if apply_it else "DRY RUN"
failed = []

print("== %s · telemetry %s ==" % (head, cmd))

if not path:
    print("no config location could be resolved, so nothing is recorded and nothing is removed.")
    print("(set PKG_CONFIG, XDG_CONFIG_HOME or HOME if you expected one.)")
    raise SystemExit(0)

if not os.path.exists(path):
    print("config      : %s [absent]" % path)
    print("nothing was ever recorded on this machine, so there is nothing to remove.")
    raise SystemExit(0)

try:
    with open(path) as fh:
        cfg = json.load(fh)
    if not isinstance(cfg, dict):
        raise ValueError("valid JSON, not an object")
except Exception as exc:
    # A malformed config means there is no ledger, which means there is no authority. Do not
    # "recover" one by scanning the disk for likely files — that is inference from path shape
    # wearing a helpful hat.
    sys.stderr.write(
        "REFUSED: %s cannot be read as JSON (%s), so nothing records what this feature wrote.\n"
        "         Nothing was removed. Repair that file, or remove the log yourself: it is\n"
        "         named %s (plus %s.1) inside whichever directory you pointed this at.\n"
        % (path, exc, log_name, log_name))
    raise SystemExit(4)

tel = cfg.get("telemetry") if isinstance(cfg.get("telemetry"), dict) else {}
ack = cfg.get("acknowledged") if isinstance(cfg.get("acknowledged"), dict) else {}
recorded = tel.get("dir") or ""

print("config      : %s [present]" % path)
print("recorded log directory : %s" % (recorded or "(none)"))

targets = []
if recorded:
    live = os.path.join(recorded, log_name)
    targets = [live, live + ".1"]             # exact basenames only; never a glob
else:
    print("nothing is recorded as this feature's log location, so no file is removed by rule.")

for t in targets:
    if os.path.exists(t):
        try:
            print("  log file  : %s (%d bytes)" % (t, os.path.getsize(t)))
        except OSError as exc:
            print("  log file  : %s (size unknown: %s)" % (t, exc))
    else:
        print("  log file  : %s (absent)" % t)

print("config keys : telemetry.mode -> off · telemetry.dir -> cleared · "
      "acknowledged.telemetry_local -> cleared")
if cmd == "uninstall":
    others = sorted(k for k in cfg if k not in ("telemetry", "acknowledged"))
    print("config file : %s WILL BE REMOVED" % path)
    print("              it also holds these other top-level settings for this plugin, and they")
    print("              go with it: %s" % (", ".join(others) or "(none)"))
    print("              use `purge` instead if you only want the log gone.")

if not apply_it:
    print("")
    print("nothing has been changed. re-run with --apply%s to do it."
          % (' --confirm "apply uninstall"' if cmd == "uninstall" else ""))
    raise SystemExit(0)

# ---- APPLY. Log first, then the config: the config is the ledger every step above reads, so
# ---- removing it first would destroy this path's own authority mid-run.
for t in targets:
    if not os.path.exists(t):
        print("  skipped   : %s (already absent)" % t)
        continue
    try:
        os.remove(t)
    except OSError as exc:
        failed.append("could not remove %s (%s)" % (t, exc))
        print("  FAILED    : %s (%s)" % (t, exc))
        continue
    print("  removed   : %s (verified gone: %s)" % (t, not os.path.exists(t)))

if recorded and os.path.isdir(recorded):
    try:
        os.rmdir(recorded)                    # only if empty; never a recursive delete
        print("  removed   : %s (the directory was empty)" % recorded)
    except OSError:
        print("  left      : %s (not empty — it holds something this feature did not write)"
              % recorded)

if cmd == "purge":
    tel["mode"] = "off"
    tel["dir"] = ""
    ack["telemetry_local"] = ""
    cfg["telemetry"] = tel
    cfg["acknowledged"] = ack
    try:
        tmp = path + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(cfg, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
        with open(path) as fh:
            back = json.load(fh)
        bt = back.get("telemetry", {})
        ba = back.get("acknowledged", {})
        print("  cleared   : telemetry.mode=%r dir=%r consent=%r (read back from disk)"
              % (bt.get("mode"), bt.get("dir"), ba.get("telemetry_local")))
    except Exception as exc:
        failed.append("could not clear the config keys (%s)" % exc)
        print("  FAILED    : clearing the config keys (%s)" % exc)
else:
    try:
        os.remove(path)
        print("  removed   : %s (verified gone: %s)" % (path, not os.path.exists(path)))
    except OSError as exc:
        failed.append("could not remove %s (%s)" % (path, exc))
        print("  FAILED    : %s (%s)" % (path, exc))

print("")
if failed:
    print("NOT COMPLETE — %d step(s) FAILED:" % len(failed))
    for f in failed:
        print("  - %s" % f)
    raise SystemExit(1)
print("done. what remains: this plugin's own files, which your harness removes when you")
print("uninstall the plugin. nothing was sent anywhere, and nothing else on this machine was")
print("touched.")
PY
    exit $?
    ;;

  help|--help|-h)
    _pkg_usage
    exit 0
    ;;

  *)
    _pkg_usage >&2
    exit 2
    ;;
esac
