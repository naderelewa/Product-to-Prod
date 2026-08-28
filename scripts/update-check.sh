#!/usr/bin/env bash
# update-check.sh — the advisory version check: it says a newer release exists, and stops there.
#
#   update-check.sh            print at most ONE advisory line, then exit 0
#   update-check.sh --help     this text
#
# WHAT IT TOUCHES, in one breath. It fetches ONE public file — this package's own manifest on the
# published branch — with a plain GET under a five-second ceiling. That request carries no query,
# no body and nothing about you or your machine: there is no identifier to opt out of, because none
# is assembled. It writes one date to one file on your own disk, and `PKG_NO_UPDATE_CHECK=1` turns
# the whole thing off before anything is read or written.
#
# ADVISORY MEANS ADVISORY, as a mechanism and not an intention: every path exits 0 except an unknown
# flag, which is a usage error. Offline, DNS down, a proxy in the way, an answer that will not parse
# — print nothing, stamp nothing, exit 0. This is called from a front door whose standard output is
# session context, so a check that can fail its caller, or narrate its own failure into that stream,
# is a worse defect than no check at all.
#
# THE STAMP, and why only a success writes one. At most one network attempt every 2 days, recorded
# as a UTC date under the name below, in the SAME config root the telemetry config resolves to:
# PKG_CONFIG's own directory, else $XDG_CONFIG_HOME/<slug>, else $HOME/.config/<slug>. A failed
# fetch or an unparseable answer leaves the stamp alone on purpose, so a machine that was offline
# looks again next run instead of going quiet for two days on the strength of a failure nobody saw.
#
# The environment it reads: PKG_NO_UPDATE_CHECK (the off switch), PKG_CONFIG (the config file whose
# directory is the stamp root), PKG_PYTHON (a python 3 name to try ahead of the usual ones). Names
# private to this file are `_pkg_*` in the shell and `PKG_U_*` where python must see them.

set -uo pipefail

_pkg_slug="product2prod"
_pkg_stamp_name="update-check-stamp"
_pkg_max_age_days="2"
_pkg_manifest_rel=".claude-plugin/plugin.json"
_pkg_url="https://raw.githubusercontent.com/naderelewa/Product-to-Prod/main/.claude-plugin/plugin.json"

_pkg_usage() {
  cat <<'USAGE'
update-check.sh — advisory only: whether a newer release of this plugin exists.

  update-check.sh          at most one line, then exit 0
  update-check.sh --help   this text

It reads one public version file with a plain GET, keeps a date stamp in this plugin's config
directory so it looks at most once every 2 days, and prints nothing at all when it cannot reach the
network, when the answer will not parse, or when you are already current. PKG_NO_UPDATE_CHECK=1
turns it off entirely.

Exit: 0 always, every failure included — this never fails its caller · 2 unknown flag.
USAGE
}

case "${1:-}" in
  "")             : ;;
  --help|-h|help) _pkg_usage; exit 0 ;;
  *)              _pkg_usage >&2; exit 2 ;;
esac

[ "${PKG_NO_UPDATE_CHECK:-}" = "1" ] && exit 0          # rung 1: the off switch, above everything

# rung 2: the config root, by the same ladder the telemetry config walks. Nowhere to look is a
# finding, not an error: with no override and no home there is no machine-local state, so this
# feature is inert.
if   [ -n "${PKG_CONFIG:-}" ];     then _pkg_cfg_root="$(dirname "${PKG_CONFIG}")"
elif [ -n "${XDG_CONFIG_HOME:-}" ]; then _pkg_cfg_root="${XDG_CONFIG_HOME}/$_pkg_slug"
elif [ -n "${HOME:-}" ];            then _pkg_cfg_root="${HOME}/.config/$_pkg_slug"
else exit 0
fi
_pkg_stamp="$_pkg_cfg_root/$_pkg_stamp_name"

# rung 3: a python 3, by name only — no interpreter path is baked into this tree, and a bare
# `python` that is not 3.x is refused rather than handed these programs.
_pkg_py=""
for _pkg_c in "${PKG_PYTHON:-}" python3 python; do
  [ -n "$_pkg_c" ] || continue
  command -v "$_pkg_c" >/dev/null 2>&1 || continue
  "$_pkg_c" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1 || continue
  _pkg_py="$_pkg_c"; break
done
[ -n "$_pkg_py" ] || exit 0
command -v curl >/dev/null 2>&1 || exit 0

# rung 4: the 2-day gate, and its rc is inverted on purpose — rc 1 means FRESH, so the `||` below
# is the silent stop. A stamp that cannot be read counts as absent and therefore stale: the cost of
# an unreadable stamp is one extra GET, never a check that goes silent for good.
PKG_U_STAMP="$_pkg_stamp" PKG_U_MAX_AGE="$_pkg_max_age_days" "$_pkg_py" - 2>/dev/null <<'PY' || exit 0
import datetime, os
try:
    with open(os.environ["PKG_U_STAMP"]) as fh:
        stamped = datetime.date(*[int(x) for x in fh.read().strip().split("-")[:3]])
except Exception:
    raise SystemExit(0)                       # absent, empty or unreadable -> stale -> go and look
age = (datetime.datetime.now(datetime.timezone.utc).date() - stamped).days
raise SystemExit(1 if 0 <= age < int(os.environ["PKG_U_MAX_AGE"]) else 0)
PY

# rung 5: the read. One GET, five seconds, no redirect chasing, nothing sent but the request line.
_pkg_body="$(curl -fsS --max-time 5 "$_pkg_url" 2>/dev/null)" || exit 0
[ -n "$_pkg_body" ] || exit 0

# rung 6: the comparison. rc 0 means it COMPLETED — whether or not it had anything to say — and
# that is the only thing the stamp records. Anything unparseable on either side exits 1 in silence.
_pkg_self="$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")"
PKG_U_MANIFEST="$(dirname "$(dirname "$_pkg_self")")/$_pkg_manifest_rel" \
PKG_U_REMOTE="$_pkg_body" PKG_U_SLUG="$_pkg_slug" "$_pkg_py" - 2>/dev/null <<'PY' || exit 0
import json, os, re


def parts(v):
    """A comparable key of FIXED WIDTH, and the width is the point. A non-numeric segment scores
    -1, so `0.2.0-rc1` sits below `0.2.0` — but only once both keys are four wide. Compared at
    their natural lengths, the longer list wins on a shared prefix, so the prerelease came out
    ABOVE the release it precedes and this check would have advertised an rc to someone already
    running the finished version."""
    seg = [int(x) if x.isdigit() else -1 for x in re.split(r"[.+-]", v)[:4]]
    return (seg + [0, 0, 0, 0])[:4]


try:
    with open(os.environ["PKG_U_MANIFEST"]) as fh:
        local = json.load(fh)["version"]
    remote = json.loads(os.environ["PKG_U_REMOTE"])["version"]
    if not (isinstance(local, str) and isinstance(remote, str)):
        raise ValueError("a version that is not a string")
except Exception:
    raise SystemExit(1)                       # nothing printed, and nothing gets stamped

if parts(remote) > parts(local):
    print("%s %s is available and this is %s — update a clone with `git pull`, or a marketplace "
          "install with `/plugin install %s`."
          % (os.environ["PKG_U_SLUG"], remote, local, os.environ["PKG_U_SLUG"]))
PY

# rung 7: stamp the completed comparison, atomically, and never let that failure reach the caller.
mkdir -p "$_pkg_cfg_root" 2>/dev/null || exit 0
if printf '%s\n' "$(date -u +%Y-%m-%d)" > "$_pkg_stamp.tmp" 2>/dev/null; then
  mv -f "$_pkg_stamp.tmp" "$_pkg_stamp" 2>/dev/null || rm -f "$_pkg_stamp.tmp" 2>/dev/null
fi
exit 0
