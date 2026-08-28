#!/usr/bin/env bash
# run-tests.sh — this package's own test entry.
#
# Every check here runs offline, touches no network, needs no credentials, and writes nothing outside
# a temporary directory. Run it before any release, and after any edit to a script or a reference.
#
#   tests/run-tests.sh            run everything
#   tests/run-tests.sh --list     print the check names and exit
#   tests/run-tests.sh --help     print the usage block and exit
#
# Exit: 0 = all checks passed · 1 = at least one failed (each failure names itself) · 2 = usage error.
#
# One rule for anybody adding a check: a check that cannot run must FAIL. It must never pass quietly,
# and it must never skip quietly either — a skipped block ends the run non-zero, because a green
# suite that silently skipped its most important check is worse than a red one.
#
# TWO FILES, ONE SUITE. The expectations this file asserts against — how many checks there are, what
# each one is called, which section it prints under, the document and link floors — live in
# tests/expected-checks.txt, on purpose. A suite that counts its own checks reports whatever it
# happens to hold: delete a check and the count follows it down, and the summary still reads green.
# The pinned file is the second opinion, and check_suite_ran_every_check is what compares them.

set -uo pipefail

# TOOL RESOLUTION, in one place. A shell function or alias named `grep` on the running machine can
# swallow matches silently, and a silent zero from a scanner is the worst failure mode it has. This
# is the ONE resolver in this file; check_no_hardcoded_tool_paths asserts nothing else hardcodes a
# tool path outside it.
GREP=grep                                              # tool-resolver (exempt)
if [ -x /usr/bin/grep ]; then GREP=/usr/bin/grep; fi   # tool-resolver (exempt)
AWK=awk                                                        # tool-resolver (exempt)
if [ -x "/usr/bin/awk" ]; then AWK="/usr/bin/awk"; fi          # tool-resolver (exempt)

HERE="$(cd "$(dirname "$0")" && pwd -P)"
PKG_ROOT="$(dirname "$HERE")"
FIX="$HERE/fixtures"
EXPECT="$HERE/expected-checks.txt"

PASS=0; FAIL=0; SKIP=0
SECTION="(none)"
LEDGER=""

# The pinned-expectations reader. A missing pin is never a default: every caller treats an empty
# answer as a failure, because a floor nobody wrote is not a floor.
expect_val() {
  [ -r "$EXPECT" ] || return 1
  $GREP -E "^[[:space:]]*$1[[:space:]]*=" "$EXPECT" | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//'
}

_record() {
  # The detail is flattened: a multi-line reason written raw would become several ledger rows and
  # check_suite_ran_every_check would then read a fragment of a failure message as a check name.
  [ -n "$LEDGER" ] || return 0
  printf '%s|%s|%s|%s\n' "${1%% *}" "$SECTION" "$2" "$(printf '%s' "$3" | tr '\n|' '  ')" >> "$LEDGER"
}

ok()   { PASS=$((PASS+1)); _record "$1" pass ""; printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); _record "$1" fail "${2:-}"; printf '  FAIL  %s\n' "$1"; if [ $# -gt 1 ]; then printf '        %s\n' "$2"; fi; }
skip() { SKIP=$((SKIP+1)); _record "$1" skip "${2:-}"; printf '  SKIP  %s — %s\n' "$1" "${2:-}"; }
banner() { SECTION="$1"; printf '\n-- %s --\n' "$1"; }

if { [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; } && [ $# -eq 1 ]; then
  # A FRESH READER'S FIRST MOVE ON ANY ENTRY POINT IS TO ASK IT FOR HELP, and the documents send
  # that reader straight here. Every other entry point in this package answers on stdout and exits
  # zero; this one used to refuse with a usage error on stderr, which reads as a broken package to
  # the person least able to tell the difference. The block is written out rather than harvested
  # from the comments above, so it says what a caller needs and stops there.
  printf '%s\n' \
    'usage: run-tests.sh [--list | --help]' \
    '' \
    '  run-tests.sh          run every check and print a verdict line for each one' \
    '  run-tests.sh --list   print the check names and exit' \
    '  run-tests.sh --help   print this block and exit' \
    '' \
    'Exit: 0 = every check passed - 1 = at least one failed or skipped - 2 = usage error.' \
    'A check that cannot run FAILS; a skipped block ends the run non-zero.' \
    '' \
    'Environment:' \
    '  PKG_PACKAGE_ROOT        the package the consent-telemetry checks measure. Defaults to the' \
    '                          package this suite lives in and honours a value the caller sets.' \
    '  PKG_ALLOW_FOREIGN_ROOT  set to yes to allow PKG_PACKAGE_ROOT to name another tree. Without' \
    '                          it, a re-aimed run FAILS rather than reporting on a tree it did' \
    '                          not name.' \
    '  TMPDIR                  every scratch directory this suite creates is made under it.'
  exit 0
elif [ "${1:-}" = "--list" ] && [ $# -eq 1 ]; then
  # The ids a run REPORTS, harvested from the reporting calls themselves. Three function names are
  # shorter than the id they report, because the deny-list bans any token of 40 characters or more
  # and three of these ids cross that line once the check_ prefix is on the front.
  $GREP -ohE '\b(ok|bad) "[a-z0-9_]+' "$0" | sed -E 's/^.*"/  /' | sort -u
  exit 0
elif [ $# -gt 0 ]; then
  printf 'usage: run-tests.sh [--list | --help]\n' >&2; exit 2
fi

if ! TMP="$(mktemp -d "${TMPDIR:-/tmp}/pkg-suite.XXXXXX" 2>/dev/null)"; then
  # capture the tool's own diagnosis: "could not" with no cause teaches the operator nothing
  cause="$(mktemp -d "${TMPDIR:-/tmp}/pkg-suite.XXXXXX" 2>&1 >/dev/null)"
  printf 'cannot create a temporary directory under %s: %s\n' "${TMPDIR:-/tmp}" "$cause" >&2
  exit 2
fi
# The consent block below re-points $TMP at its own mktemp directory (that fragment's own idiom),
# and the trap body expands at exit time, so the trap must also carry the path created HERE by name
# — otherwise this directory is never removed and the suite leaks one per run.
TMP_ROOT="$TMP"
LEDGER="$TMP_ROOT/ledger.psv"; : > "$LEDGER"
# The unreadable-directory fixture leaves a mode-000 directory behind if the run dies mid-check, and
# rm cannot descend into one. u+rwX restores the traverse bit as well as the write bit.
trap 'chmod -R u+rwX "$TMP" "$TMP_ROOT" 2>/dev/null; rm -rf "$TMP" "$TMP_ROOT"' EXIT

# A permission-clean copy. A fixture copied out of a read-only checkout inherits the source's mode,
# the append then dies, and the diagnosis accuses the code under test instead of the checkout. Every
# fixture in this file is materialised through these two helpers, and check_fixture_writes_are_guarded
# is what keeps that true.
fixture_copy() {  # $1 = source file, $2 = destination file
  mkdir -p "$(dirname "$2")" 2>/dev/null
  cp "$1" "$2" || { printf 'fixture copy failed (permission?): %s -> %s\n' "$1" "$2"; return 1; }
  chmod u+w "$2" || { printf 'fixture is not writable after copy (permission?): %s\n' "$2"; return 1; }
  return 0
}

fixture_write() {  # $1 = destination file, rest = the lines to write
  local dest="$1"; shift
  mkdir -p "$(dirname "$dest")" 2>/dev/null || { printf 'cannot create the fixture directory for %s (permission?)\n' "$dest"; return 1; }
  printf '%s\n' "$@" > "$dest" || { printf 'cannot write the fixture %s (permission? unwritable scratch?)\n' "$dest"; return 1; }
  return 0
}

printf '== %s: package self-tests ==\n' "$(basename "$PKG_ROOT")"

# --- publish-lint: the confidentiality gate ---
banner "publish-lint"

check_publish_lint_self_test() {
  if out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --self-test 2>&1) && printf '%s' "$out" | $GREP -q 'self-test: PASS'; then
    ok "publish_lint_self_test (the scanner provably fires on planted samples)"
  else
    bad "publish_lint_self_test" "$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"
  fi
}

check_publish_lint_tree_clean() {
  # Exit 0 is necessary and NOT sufficient: a linter that walked one file of forty and printed
  # "clean" would pass on the exit code alone. It prints its own file count, so hold it to the tree
  # it was pointed at. The expected count is every file minus the deliberate exclusions:
  #   1. config/denylist.txt, which holds the patterns;
  #   2. config/local.json when it exists — the machine-local file the documented first run creates.
  #      The scanner prunes it by name and this arithmetic subtracts it in the same breath, so the
  #      pair is reconciled by the sum rather than by two lists somebody has to keep identical.
  # If a third exclusion is ever added this check fails loudly and whoever adds it updates the
  # arithmetic — the right amount of friction for changing what a leak scanner skips.
  #
  # THE FILE-LISTER BELOW IS NOT PINNED TO AN ABSOLUTE PATH, and that is deliberate rather than an
  # oversight. The scanner's own walk is pinned, because a shimmed lister there yields "scanned 0
  # files … clean" and nobody sees it. Here the same shim yields a count that DISAGREES with the
  # scanner's, and this check fails loudly naming both numbers. A loud site does not need the pin;
  # recording why is cheaper than pinning it and cheaper than re-deciding later.
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    bad "publish_lint_tree_clean" "$(printf '%s' "$out" | $GREP -v '^--$' | head -5 | tr '\n' ' ')"
    return
  fi
  scanned=$(printf '%s' "$out" | $GREP -oE 'scanned [0-9]+ files' | $GREP -oE '[0-9]+' | head -1)
  files=$(find "$PKG_ROOT" -type f -not -path '*/.git/*' -not -path '*/__pycache__/*' \
            -not -name '*.pyc' | wc -l | tr -d ' ')
  expect=$((files - 1))
  [ -f "$PKG_ROOT/config/local.json" ] && expect=$((expect - 1))
  if [ -z "$scanned" ]; then
    bad "publish_lint_tree_clean" "exit 0 with no scanned-file count — nothing proves the scan covered anything"
  elif [ "$scanned" -ne "$expect" ]; then
    bad "publish_lint_tree_clean" "coverage mismatch: scanned $scanned of $files file(s), expected $expect after the deny-list (and machine-local config) exclusions — a clean verdict over a partial walk is not a pass"
  else
    ok "publish_lint_tree_clean (no banned token anywhere in the package; full coverage $scanned/$expect files)"
  fi
}

check_publish_lint_fails_closed() {
  # Four ways a pattern set can be unusable, and every one of them must be exit 2. The first two are
  # the shipped pair; the rest are the class the malformed-pattern defect belongs to — a set that
  # loads but cannot be USED is exactly as blind as a set that never loaded, and the search tool's
  # own error exit is the only thing that tells them apart.
  : > "$TMP/empty-denylist.txt"
  bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$TMP/empty-denylist.txt" >/dev/null 2>&1
  [ $? -eq 2 ] || { bad "publish_lint_fails_closed" "an empty pattern set did not exit 2"; return; }
  bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$TMP/does-not-exist.txt" >/dev/null 2>&1
  [ $? -eq 2 ] || { bad "publish_lint_fails_closed" "a missing deny-list did not exit 2"; return; }
  local shape out rc
  mkdir -p "$TMP/fc-target"; printf 'nothing findable here\n' > "$TMP/fc-target/plain.txt"
  for shape in '(unbalanced' '*badrepeat' '[unterminated'; do
    fixture_write "$TMP/bad-pattern.txt" 'harmless-structural-shape' "$shape" || {
      bad "publish_lint_fails_closed" "could not write the malformed-pattern fixture"; return; }
    out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$TMP/bad-pattern.txt" "$TMP/fc-target" 2>&1); rc=$?
    [ $rc -eq 2 ] || { bad "publish_lint_fails_closed" "a malformed pattern ($shape) did not exit 2 — an unusable pattern set scanned as clean"; return; }
    printf '%s' "$out" | $GREP -q 'bad-pattern.txt' || {
      bad "publish_lint_fails_closed" "the malformed-pattern error never named the file it came from"; return; }
  done
  ok "publish_lint_fails_closed (empty, missing or unusable rules = exit 2 naming the file, never a silent pass)"
}

check_pattern_set_is_usable() {
  # The same class from the outside, with the two halves a fail-closed test needs: a VALID set must
  # still scan, and a malformed one must die naming the file AND the line, or whoever has to fix it
  # is hunting through a pattern file by eye.
  local out rc
  fixture_write "$TMP/usable-ok.txt" 'harmless-structural-shape-[0-9]+' || {
    bad "pattern_set_is_usable" "could not write the pattern fixture"; return; }
  fixture_write "$TMP/usable-bad.txt" 'harmless-structural-shape-[0-9]+' '(unbalanced' || {
    bad "pattern_set_is_usable" "could not write the malformed pattern fixture"; return; }
  mkdir -p "$TMP/usable-target"; printf 'plain text\n' > "$TMP/usable-target/plain.txt"
  bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$TMP/usable-ok.txt" "$TMP/usable-target" >/dev/null 2>&1
  [ $? -eq 0 ] || { bad "pattern_set_is_usable" "a valid pattern set did not scan clean — the control failed"; return; }
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$TMP/usable-bad.txt" "$TMP/usable-target" 2>&1); rc=$?
  if [ $rc -ne 2 ]; then
    bad "pattern_set_is_usable" "a malformed pattern did not stop the scan (rc=$rc): the search tool errored and the run continued as clean"
    return
  fi
  if printf '%s' "$out" | $GREP -qE 'usable-bad\.txt(:| line )2\b'; then
    ok "pattern_set_is_usable (every pattern is validated at load; a malformed one dies naming its file and line)"
  else
    bad "pattern_set_is_usable" "the error did not name the offending file AND line: $(printf '%s' "$out" | tail -1)"
  fi
}

check_publish_lint_catches_a_plant() {
  mkdir -p "$TMP/plant"
  # assembled, never written literally, so this file stays clean under its own linter
  printf 'note: /%s/somebody/private.txt\n' "$(printf 'U%ss' 'ser')" > "$TMP/plant/leak.md"
  fixture_copy "$PKG_ROOT/config/denylist.txt" "$TMP/dl.txt" || {
    bad "publish_lint_catches_a_plant" "could not copy the pattern file into the scratch tree"; return; }
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$TMP/dl.txt" "$TMP/plant" 2>&1); rc=$?
  if [ $rc -eq 1 ] && printf '%s' "$out" | $GREP -q 'leak.md'; then
    ok "publish_lint_catches_a_plant (a real violation exits 1 and names the file)"
  else
    bad "publish_lint_catches_a_plant" "expected exit 1 naming leak.md, got rc=$rc"
  fi
}

check_publish_lint_allow_scope() {
  mkdir -p "$TMP/scope/config"
  local sha out
  # The allowed token is assembled from parts, so THIS file stays clean under the same scanner while
  # the fixtures it writes carry the whole token.
  # Self-contained fixture: the check supplies its OWN deny pattern + scoped allow directive,
  # so it tests the MECHANISM without depending on any directive the shipped list happens to carry.
  sha="$(printf '%s%s' 'scopeprobe' 'token7')"
  printf 'fixture token: %s\n' "$sha" > "$TMP/scope/CREDITS-NOTES.md"
  printf 'fixture token: %s\n' "$sha" > "$TMP/scope/config/elsewhere.md"
  fixture_copy "$PKG_ROOT/config/denylist.txt" "$TMP/dl2.txt" || {
    bad "publish_lint_allow_scope" "could not copy the pattern file into the scratch tree"; return; }
  printf '%s\n' "$sha" >> "$TMP/dl2.txt"
  printf '#!allow %s :: CREDITS-NOTES.md\n' "$sha" >> "$TMP/dl2.txt"
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$TMP/dl2.txt" "$TMP/scope" 2>&1)
  if printf '%s' "$out" | $GREP -q 'config/elsewhere.md' && ! printf '%s' "$out" | $GREP -q '^CREDITS-NOTES.md'; then  # (annotated: a scratch fixture this check writes)
    ok "publish_lint_allow_scope (an allowed token is excused only inside its declared scope)"
  else
    bad "publish_lint_allow_scope" "scope enforcement did not behave as declared"
  fi
}

check_allow_budget() {
  # An allow directive is the one construct in the pattern set that can turn a hit into silence, so
  # the NUMBER of them is pinned and every excused span is accounted for. Three assertions:
  #   (a) no allow token may contain a path separator — no legitimate directive needs one, and the
  #       one that shipped excused a real machine path;
  #   (b) the public directive count equals the pinned number;
  #   (c) the public excused-span count equals the pinned number. The maintainer-mode twin, which
  #       counts spans excused with the private overlay attached, is pinned in the private harness
  #       and re-measured whenever that overlay changes.
  local pin_d pin_x out directives excused sep
  pin_d="$(expect_val allow_directives)"; pin_x="$(expect_val allow_excused_spans)"
  if [ -z "$pin_d" ] || [ -z "$pin_x" ]; then
    bad "allow_budget" "tests/expected-checks.txt pins no allow_directives / allow_excused_spans value — an unpinned budget is not a budget"
    return
  fi
  sep=$($GREP -E '^#!allow ' "$PKG_ROOT/config/denylist.txt" | sed 's/^#!allow //; s/::.*//' | $GREP -c '/' | tr -d ' ')
  if [ "$sep" != "0" ]; then
    bad "allow_budget" "$sep allow token(s) carry a path separator — a directive that excuses a path excuses the class the scan exists to catch"
    return
  fi
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --list 2>&1)
  directives=$(printf '%s' "$out" | $GREP -oE 'allow directives \([0-9]+\)' | $GREP -oE '[0-9]+' | head -1)
  excused=$(bash "$PKG_ROOT/scripts/publish-lint.sh" 2>&1 | $GREP -oE '[0-9]+ span\(s\) excused' | $GREP -oE '[0-9]+' | head -1)
  [ -n "$directives" ] || { bad "allow_budget" "the pattern listing printed no directive count"; return; }
  [ -n "$excused" ] || { bad "allow_budget" "the scan printed no excused-span count"; return; }
  if [ "$directives" = "$pin_d" ] && [ "$excused" = "$pin_x" ]; then
    ok "allow_budget ($directives allow directive(s), $excused span(s) excused, both equal to the pinned numbers; no allow token carries a path separator)"
  else
    bad "allow_budget" "the allow budget drifted: $directives directive(s) against a pin of $pin_d, $excused excused span(s) against a pin of $pin_x"
  fi
}

check_denylist_integrity() {
  # Pattern-file content, pinned. Deleting a whole class, deleting one pattern inside a class, or
  # substituting a junk line for a real one all leave the scanner "working" and the suite green,
  # because the self-test only requires four hits and a pristine run yields more. So: the pattern
  # count and the class list are pinned here, and every declared class must be non-empty.
  local pin_n pin_c count classes empty ncls
  pin_n="$(expect_val deny_patterns)"; pin_c="$(expect_val deny_classes)"
  if [ -z "$pin_n" ] || [ -z "$pin_c" ]; then
    bad "denylist_integrity" "tests/expected-checks.txt pins no deny_patterns / deny_classes value"
    return
  fi
  count=$($GREP -cvE '^[[:space:]]*(#|$)' "$PKG_ROOT/config/denylist.txt" | tr -d ' ')
  classes=$($GREP -E '^#@class ' "$PKG_ROOT/config/denylist.txt" | sed 's/^#@class //' | tr -d ' ' | sort | tr '\n' ',' | sed 's/,$//')
  ncls=$($GREP -cE '^#@class ' "$PKG_ROOT/config/denylist.txt" | tr -d ' ')
  empty=$($AWK '
    /^#@class /      { if (cls != "" && n == 0) print cls; cls=$2; n=0; next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
                     { n++ }
    END              { if (cls != "" && n == 0) print cls }' "$PKG_ROOT/config/denylist.txt" | tr '\n' ' ')
  if [ -n "$empty" ]; then
    bad "denylist_integrity" "declared class(es) with no pattern under them: $empty"
  elif [ "$count" != "$pin_n" ]; then
    bad "denylist_integrity" "the pattern count drifted: $count loaded against a pin of $pin_n — a deleted class, a deleted pattern or a substituted junk line all read exactly like this"
  elif [ "$classes" != "$pin_c" ]; then
    bad "denylist_integrity" "the class list drifted: [$classes] against a pin of [$pin_c] — an undeclared class is as much a hole as a missing one"
  else
    ok "denylist_integrity ($count patterns across $ncls declared classes, count and class list both pinned, none empty)"
  fi
}

check_denylist_header_is_current() {
  # The pattern file's header describes the file. Once the clear-text literals moved to the private
  # overlay, every sentence that still promised them became false rather than merely stale. So: no
  # open ruling anywhere in config/, no aside about a decision still to come, no count claim that
  # disagrees with the measured count, and no instruction pointing a maintainer at a class this file
  # does not carry or at what lives outside the package.
  local hits count claimed known instr
  hits=$($GREP -rniE 'open ruling|before the (public )?flip|still (has )?to be ruled|patterns that are themselves confidential|one directory up|lives? outside the package' \
           "$PKG_ROOT/config" 2>/dev/null | head -3 | tr '\n' ' ')
  if [ -n "$hits" ]; then
    bad "denylist_header_is_current" "a pre-flip ruling or an out-of-package aside survives in config/: $hits"
    return
  fi
  count=$($GREP -cvE '^[[:space:]]*(#|$)' "$PKG_ROOT/config/denylist.txt" | tr -d ' ')
  claimed=$($GREP -oiE '(holds|carries|contains) [0-9]+ patterns' "$PKG_ROOT/config/denylist.txt" | $GREP -oE '[0-9]+' | head -1)
  if [ -n "$claimed" ] && [ "$claimed" != "$count" ]; then
    bad "denylist_header_is_current" "the header claims $claimed patterns and the file holds $count"
    return
  fi
  known="$($GREP -E '^#@class ' "$PKG_ROOT/config/denylist.txt" | sed 's/^#@class //' | tr -d ' ' | tr '\n' '|' | sed 's/|$//')"
  # TWO INSTRUCTION GRAMMARS, because a maintainer instruction is written both ways and only the
  # imperative one was recognised. "Add channel patterns to the section above" and "Financial
  # patterns belong under the plan-private heading" name a class this file does not carry in
  # exactly the same way and disclose exactly the same thing; the second form shipped invisible.
  # The class filter is unchanged: a line naming one of the DECLARED classes is an instruction
  # about this file's own contents and is none of this check's business.
  instr=$($GREP -inE '^#[^@].*((add|put|file|keep|place) [a-z-]+ patterns (to|under|in|beside|with) |[a-z-]+ patterns (belong|belongs|go|goes|live|lives|are filed|are kept) (under|in|beside|with|to|next to) )' \
            "$PKG_ROOT/config/denylist.txt" \
          | $GREP -viE "($known)" | head -2 | tr '\n' ' ')
  if [ -n "$instr" ]; then
    bad "denylist_header_is_current" "an instruction names a pattern class this file does not carry (declared: $known): $instr"
  else
    ok "denylist_header_is_current (no open-ruling block, no pre-flip or out-of-package aside in config/, any stated count equals the measured $count)"
  fi
}

check_denylist_has_no_empty_sections() {
  # A section heading with no pattern under it is pure disclosure: it names a class of thing this
  # operator has and carries nothing that would catch it. Every heading must be followed by at least
  # one pattern before the next heading.
  local orphan
  orphan=$($AWK '
    /^# ={4,}/       { if (h != "" && n == 0) print h; h=$0; n=0; next }
    /^#@class /      { next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
                     { n++ }
    END              { if (h != "" && n == 0) print h }' "$PKG_ROOT/config/denylist.txt" | tr '\n' ' ')
  if [ -n "$orphan" ]; then
    bad "denylist_has_no_empty_sections" "heading(s) with no pattern beneath them: $orphan"
  else
    ok "denylist_has_no_empty_sections (every section heading carries at least one pattern)"
  fi
}

check_repro() {
  # The header offers a hand form that a reviewer is told reproduces the scan. If it cannot, the
  # offer is worse than no offer: it produces a confident clean over a fixture the real tool fails.
  # So run BOTH over one fixture carrying a hit per case class, and require the same verdict.
  local hand tool_rc hand_rc probe
  hand=$($GREP -E '^#[[:space:]]+/usr/bin/grep .*denylist' "$PKG_ROOT/config/denylist.txt" | head -1 | sed 's/^#[[:space:]]*//')  # (annotated: the SUBJECT of a search, not a tool this file calls)
  if [ -z "$hand" ]; then
    bad "repro" "the pattern file offers no hand form to reproduce — the cross-check sentence names a command that is not there"
    return
  fi
  probe="$TMP/repro"; mkdir -p "$probe"
  {
    printf 'path: /%s/somebody/notes.txt\n' "$(printf 'U%ss' 'ser')"
    printf 'container: %s-%s%s\n' 'GTM' 'AB' 'C1234'
  } > "$probe/sample.txt"
  bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$PKG_ROOT/config/denylist.txt" "$probe" >/dev/null 2>&1
  tool_rc=$?
  hand="${hand/<file>/$probe/sample.txt}"
  ( cd "$PKG_ROOT" && eval "$hand" ) >/dev/null 2>&1
  hand_rc=$?
  if [ "$tool_rc" -eq 1 ] && [ "$hand_rc" -eq 0 ]; then
    ok "repro (the documented hand form and the shipped tool agree on a fixture carrying one hit per case class)"
  else
    bad "repro" "the documented hand form does not reproduce the tool: tool rc=$tool_rc (1 = hits found), hand rc=$hand_rc (0 = hits found). A hand form that cannot match what the tool matches is a false reassurance"
  fi
}

check_local_config_is_not_a_leak() {
  # Following the package's own documented first run must not turn the gates red. Fill the
  # machine-local config from the template into a scratch copy of the tree and require BOTH: the
  # scan passes, and the coverage arithmetic still balances (so the file is pruned, not merely
  # lucky). The negative control is in the same check: the same content in a TRACKED file must
  # still fail, or the prune has become a hole.
  local work out rc scanned files expect
  work="$TMP/localcfg/pkg"
  mkdir -p "$work" || { bad "documented_local_config_is_not_a_leak" "could not create the scratch tree"; return; }
  cp -R "$PKG_ROOT/." "$work" 2>/dev/null || { bad "documented_local_config_is_not_a_leak" "could not copy the package into the scratch tree"; return; }
  chmod -R u+w "$work" 2>/dev/null
  rm -rf "$work/.git"
  printf '{"local": {"tools_dir": "/%s/somebody/tools"}}\n' "$(printf 'U%ss' 'ser')" > "$work/config/local.json" \
    || { bad "documented_local_config_is_not_a_leak" "could not write the documented machine-local config"; return; }
  out=$(bash "$work/scripts/publish-lint.sh" "$work" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    bad "documented_local_config_is_not_a_leak" "the documented first run turns the leak scan RED: $(printf '%s' "$out" | $GREP -v '^--$' | head -2 | tr '\n' ' ')"
    return
  fi
  scanned=$(printf '%s' "$out" | $GREP -oE 'scanned [0-9]+ files' | $GREP -oE '[0-9]+' | head -1)
  files=$(find "$work" -type f -not -path '*/.git/*' -not -path '*/__pycache__/*' -not -name '*.pyc' | wc -l | tr -d ' ')
  expect=$((files - 2))
  if [ "$scanned" != "$expect" ]; then
    bad "documented_local_config_is_not_a_leak" "the arithmetic no longer balances: scanned $scanned of $files, expected $expect (pattern file + machine-local config). A second exempt file was added without updating the sum"
    return
  fi
  printf '{"tracked": "/%s/somebody/tools"}\n' "$(printf 'U%ss' 'ser')" > "$work/config/tracked-probe.json"
  bash "$work/scripts/publish-lint.sh" "$work" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    bad "documented_local_config_is_not_a_leak" "CONTROL FAILED: the same content in a tracked file scanned clean — the prune is a hole, not an exemption"
  else
    ok "documented_local_config_is_not_a_leak (the documented first run stays clean and the coverage sum balances; the same content in a tracked file still fails)"
  fi
}

check_paths_with_metachars() {
  # Prefix-strips are how this tree turns an absolute path into a relative one before printing it.
  # Unquoted, the operand is a glob: a bracket, star or question mark anywhere in the checkout path
  # makes the strip a silent no-op, the scanner prints absolute host paths — breaking its own
  # privacy promise — and every scoped allow directive stops matching. Two halves: the static census
  # (every strip quotes its operand) and the behavioural one (a scan from a bracketed path still
  # prints relative).
  local unquoted work out
  unquoted=$($GREP -nE '\$\{[A-Za-z_][A-Za-z0-9_]*#{1,2}\$[A-Za-z_{]' "$PKG_ROOT"/scripts/*.sh "$PKG_ROOT"/tests/*.sh 2>/dev/null \
             | head -5 | tr '\n' ' ')
  if [ -n "$unquoted" ]; then
    bad "paths_with_metachars" "unquoted prefix-strip operand(s) — a glob in the checkout path makes these silent no-ops: $unquoted"
    return
  fi
  work="$TMP/meta[1]"
  mkdir -p "$work/target" 2>/dev/null || { bad "paths_with_metachars" "could not create the bracketed scratch directory"; return; }
  printf 'note: /%s/somebody/private.txt\n' "$(printf 'U%ss' 'ser')" > "$work/target/leak.md"
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$PKG_ROOT/config/denylist.txt" "$work/target" 2>&1)
  if printf '%s' "$out" | $GREP -q '^leak.md:'; then
    ok "paths_with_metachars (every prefix-strip quotes its operand; a scan from a bracketed path still prints relative)"
  else
    bad "paths_with_metachars" "run from a path carrying a glob metacharacter the scanner printed absolute host paths instead of relative ones"
  fi
}

# A SYNTHETIC overlay, built here, carrying no real private literal by construction. Three checks
# below need a second pattern list to say anything at all about overlay behaviour, and a proof that
# needs a secret to run is a proof that cannot ship with the package. These tokens are invented for
# the fixture and match nothing in the tree, which is exactly why the assertions can be public.
# It is written OUTSIDE the scanned root on purpose: the scanner refuses an --extra list stored
# inside the tree, and a fixture that tripped that refusal would prove the wrong thing.
# The vocabulary is shared with the private proof harness on purpose: one invented word family
# means one thing to look for, whether the fixture was built here or handed in from outside.
synthetic_overlay() {  # $1 = destination path; prints nothing, returns non-zero on failure
  fixture_write "$1" \
    '# synthetic overlay fixture, written by the suite. No real private literal appears here.' \
    'synthetic-secret-token' \
    'zzsynthetic-overlay-pattern-[0-9]+'
}

check_reports_unscannable_files() {
  # An unreadable, UTF-16 or NUL-bearing file matches nothing, and counting it as scanned is how a
  # coverage number certifies bytes nobody read. Four undecodable shapes must land in the printed
  # census and stop the run; a latin-1 file is the negative control that must still be SCANNED and
  # must still fail on the hit it carries. The shipped tree's own census is asserted at zero, so
  # this check also fails the day a real binary enters the published tree.
  local work out rc census shape misses="" scanned
  work="$TMP/unscannable"
  for shape in unreadable utf16le utf16be nul; do
    mkdir -p "$work/$shape"
    fixture_write "$work/$shape/ok.md" 'an ordinary line the scanner can read' || {
      bad "reports_unscannable_files" "could not write the readable control for the $shape fixture"; return; }
  done
  fixture_write "$work/unreadable/UNREADABLE.md" 'x' || {
    bad "reports_unscannable_files" "could not write the unreadable fixture"; return; }
  chmod 000 "$work/unreadable/UNREADABLE.md" 2>/dev/null
  python3 - "$work" <<'PY' >/dev/null 2>&1
import sys, os
w = sys.argv[1]
open(os.path.join(w, "utf16le", "U16LE.md"), "wb").write("hello there\n".encode("utf-16-le"))
open(os.path.join(w, "utf16be", "U16BE.md"), "wb").write("hello there\n".encode("utf-16-be"))
open(os.path.join(w, "nul", "NULFILE.md"), "wb").write(b"ab\x00cd\n")
PY
  for shape in unreadable utf16le utf16be nul; do
    out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$PKG_ROOT/config/denylist.txt" "$work/$shape" 2>&1); rc=$?
    census=$(printf '%s' "$out" | $GREP -oE '^unscannable: [0-9]+' | $GREP -oE '[0-9]+' | head -1)
    [ "$rc" = 2 ] || misses="$misses [$shape exited $rc, not the hard error a census entry must be]"
    [ "$census" = 1 ] || misses="$misses [$shape printed 'unscannable: ${census:-none}', not 1]"
  done
  chmod 644 "$work/unreadable/UNREADABLE.md" 2>/dev/null
  # the latin-1 control: decodable by the scanning tool, so it must be COUNTED and its hit reported
  mkdir -p "$work/latin1"
  python3 - "$work" <<'PY' >/dev/null 2>&1
import sys, os
w = sys.argv[1]
body = "café note: /" + "Us" + "ers/someone/build\n"
open(os.path.join(w, "latin1", "LATIN1.md"), "wb").write(body.encode("latin-1"))
PY
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$PKG_ROOT/config/denylist.txt" "$work/latin1" 2>&1); rc=$?
  scanned=$(printf '%s' "$out" | $GREP -oE 'scanned [0-9]+ files' | $GREP -oE '[0-9]+' | head -1)
  [ "$rc" = 1 ] || misses="$misses [the latin-1 control exited $rc; it is decodable, so it must be scanned and must fail on its hit, not be excused as unscannable]"
  [ "$scanned" = 1 ] || misses="$misses [the latin-1 control was counted as ${scanned:-no} scanned file(s), so a decodable file was skipped]"
  # and the shipped tree itself: nothing undecodable, and nothing decodable-but-dirty either. The
  # latin-1 case above is why both halves are here — a file the scan CAN read is a file whose hits
  # this check is entitled to see.
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" 2>&1); rc=$?
  census=$(printf '%s' "$out" | $GREP -oE '^unscannable: [0-9]+' | $GREP -oE '[0-9]+' | head -1)
  [ "$census" = 0 ] || misses="$misses [the shipped tree reports 'unscannable: ${census:-none}' — a published file nobody can read is not a file that scanned clean]"
  [ "$rc" = 0 ] || misses="$misses [the shipped tree does not scan clean (exit $rc), so a file that IS decodable is carrying a hit this census would otherwise wave through]"
  if [ -z "$misses" ]; then
    ok "reports_unscannable_files (four undecodable shapes each land in the printed census and stop the run; a latin-1 file is still scanned and still fails on its hit; the shipped tree's census is zero)"
  else
    bad "reports_unscannable_files" "the unscannable census does not hold:$misses"
  fi
}

check_file_floor() {
  # Zero files scanned is not a clean verdict, it is a scan that did not happen. Three ways a walk
  # legitimately finds nothing — an empty directory, only version-control data, only cache files —
  # must all be errors, and a one-file control must scan exactly one so the floor is not simply
  # "always fail".
  local work out rc scanned misses="" shape
  work="$TMP/floor"
  mkdir -p "$work/empty" "$work/vcs/.git" "$work/cache/__pycache__" "$work/onefile"
  fixture_write "$work/vcs/.git/HEAD" 'ref: refs/heads/main' || {
    bad "file_floor" "could not write the version-control-only fixture"; return; }
  fixture_write "$work/cache/__pycache__/module.pyc" 'cache bytes' || {
    bad "file_floor" "could not write the cache-only fixture"; return; }
  fixture_write "$work/onefile/one.md" 'one ordinary readable line' || {
    bad "file_floor" "could not write the one-file control"; return; }
  for shape in empty vcs cache; do
    out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$PKG_ROOT/config/denylist.txt" "$work/$shape" 2>&1); rc=$?
    if [ "$rc" = 0 ]; then
      misses="$misses [$shape scanned nothing and exited 0 — a walk that covered nothing reported a clean verdict]"
    elif ! printf '%s' "$out" | $GREP -q 'covered nothing'; then
      misses="$misses [$shape exited $rc but the diagnosis never says the walk covered nothing]"
    fi
  done
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$PKG_ROOT/config/denylist.txt" "$work/onefile" 2>&1); rc=$?
  scanned=$(printf '%s' "$out" | $GREP -oE 'scanned [0-9]+ files' | $GREP -oE '[0-9]+' | head -1)
  [ "$rc" = 0 ] && [ "$scanned" = 1 ] || \
    misses="$misses [the one-file control exited $rc having scanned ${scanned:-no} file(s); the floor must let a real one-file tree through, or it is just a second way to fail]"
  if [ -z "$misses" ]; then
    ok "file_floor (an empty tree, a version-control-only tree and a cache-only tree are each errors naming the empty walk; a one-file control still scans exactly 1 and exits clean)"
  else
    bad "file_floor" "the zero-file floor does not hold:$misses"
  fi
}

check_resolves_its_tools() {
  # The search tool was pinned to an absolute path with a written rationale about silent zeros, and
  # the tools that decide WHICH FILES EXIST were not: a shimmed file-lister yields "scanned 0 files
  # ... clean". Two halves. STATIC: the lister and the sorter are resolved the same way the search
  # tool is, and the walk uses the resolved names. BEHAVIOURAL: with a shim earliest on the path,
  # the scan's answer is UNCHANGED — same file count, and a planted hit still found. An inert shim
  # is the proof the pinning holds; a shim that changes the answer is the defect.
  local lint="$PKG_ROOT/scripts/publish-lint.sh" work shim out base rc misses="" tool pinned scanned
  # STATIC: three resolver pairs, one per tool the walk depends on — the name, then the pin.
  pinned=$($GREP -cE '^(GREP|FIND|SORT)=[a-z]+$' "$lint" | tr -d ' ')
  [ "${pinned:-0}" -eq 3 ] || misses="$misses [$pinned of the three tools the walk depends on are resolved to a name; the search tool, the file lister and the sorter each need one]"
  pinned=$($GREP -cE '^if \[ -x .?/usr/bin/(grep|find|sort).? \]; then (GREP|FIND|SORT)=' "$lint" | tr -d ' ')
  [ "${pinned:-0}" -eq 3 ] || misses="$misses [$pinned of the three names are pinned to a system binary; an unpinned lister is the shape that yields a silent zero]"
  $GREP -qE '\$FIND "\$root"' "$lint" || misses="$misses [the walk does not call the resolved file lister]"
  $GREP -qE '\| \$SORT' "$lint" || misses="$misses [the walk does not call the resolved sorter]"
  if [ -n "$misses" ]; then
    bad "resolves_its_tools" "the tools that decide which files exist are not pinned the way the search tool is:$misses"
    return
  fi
  work="$TMP/tools"; shim="$work/shims"
  mkdir -p "$work/target" "$shim"
  fixture_write "$work/target/plain.md" 'an ordinary line' || {
    bad "resolves_its_tools" "could not write the tool-shim target fixture"; return; }
  printf 'note: /%s/somebody/private.txt\n' "$(printf 'U%ss' 'ser')" > "$work/target/leak.md"
  base=$(bash "$lint" --denylist "$PKG_ROOT/config/denylist.txt" "$work/target" 2>&1)
  for tool in find sort grep; do
    fixture_write "$shim/$tool" "$(printf '#!/%s/sh' bin)" 'exit 0' || {
      bad "resolves_its_tools" "could not write the $tool shim"; return; }
    chmod +x "$shim/$tool"
    out=$(PATH="$shim:$PATH" bash "$lint" --denylist "$PKG_ROOT/config/denylist.txt" "$work/target" 2>&1); rc=$?
    scanned=$(printf '%s' "$out" | $GREP -oE 'scanned [0-9]+ files' | $GREP -oE '[0-9]+' | head -1)
    if [ "$rc" = 0 ] || printf '%s' "$out" | $GREP -q 'RESULT: clean'; then
      misses="$misses [with a silent $tool shim earliest on the path the scan reported clean over a planted hit]"
    fi
    [ "$scanned" = 2 ] || misses="$misses [with a silent $tool shim the walk counted ${scanned:-no} file(s) instead of 2]"
    rm -f "$shim/$tool"
  done
  # the exported-function shape: inert once the tool is invoked by absolute path
  out=$(find() { :; }; export -f find 2>/dev/null; bash "$lint" --denylist "$PKG_ROOT/config/denylist.txt" "$work/target" 2>&1)
  printf '%s' "$out" | $GREP -q 'RESULT: FAIL' || \
    misses="$misses [an exported shell function named for the file lister changed the verdict, so the walk is resolving the caller's name and not the pinned tool]"
  if [ -z "$misses" ]; then
    ok "resolves_its_tools (the lister and the sorter are pinned beside the search tool and the walk calls the pinned names; a silent shim for any of the three, and an exported function of the same name, leave the file count and the verdict unchanged)"
  else
    bad "resolves_its_tools" "a shimmed tool changed what the scan reported:$misses"
  fi
}

check_allow_scope_is_cwd_independent() {
  # A scoped allow directive is matched against the file's root-relative path. Unquoted, the scope
  # value expands against the CALLER's working directory, so the same tree, the same list and the
  # same directive give clean from one directory and fail from another. The fixture is built once
  # and scanned twice from two different directories, one of them a decoy laid out to satisfy a
  # leaked glob; the two verdicts must be byte-identical.
  local work tok a b arc brc misses=""
  work="$TMP/cwdscope"
  mkdir -p "$work/tree/config" "$work/decoy/config"
  tok="$(printf '%s%s' 'zzscopeprobe' '11')"
  fixture_write "$work/tree/config/inside.md" "fixture token: $tok" || {
    bad "allow_scope_is_cwd_independent" "could not write the in-scope fixture"; return; }
  fixture_write "$work/tree/outside.md" "fixture token: $tok" || {
    bad "allow_scope_is_cwd_independent" "could not write the out-of-scope fixture"; return; }
  fixture_write "$work/decoy/config/lure.md" 'a file laid out to satisfy a scope value that escaped' || {
    bad "allow_scope_is_cwd_independent" "could not write the decoy directory"; return; }
  fixture_copy "$PKG_ROOT/config/denylist.txt" "$work/dl.txt" || {
    bad "allow_scope_is_cwd_independent" "could not copy the pattern file into the scratch tree"; return; }
  printf '%s\n' "$tok" >> "$work/dl.txt"
  printf '#!allow %s :: config/*\n' "$tok" >> "$work/dl.txt"
  a=$(cd "$work" && bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$work/dl.txt" "$work/tree" 2>&1); arc=$?
  b=$(cd "$work/decoy" && bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$work/dl.txt" "$work/tree" 2>&1); brc=$?
  [ "$arc" = "$brc" ] || misses="$misses [exit $arc from one directory, $brc from the other]"
  [ "$a" = "$b" ] || misses="$misses [the two runs printed different output, so the scope value was expanded against the caller's directory]"
  printf '%s' "$a" | $GREP -q 'config/inside.md.*allowed by' || misses="$misses [the in-scope file was not excused at all, so the fixture proves nothing about scope]"  # (annotated: a path inside the scratch fixture this check writes, not a tree path)
  printf '%s' "$a" | $GREP -q '^outside.md:' || misses="$misses [the out-of-scope file was excused, so the directive is not being scoped]"
  if [ -z "$misses" ]; then
    ok "allow_scope_is_cwd_independent (the same tree, list and scoped directive give the identical verdict from two different working directories, one of them a decoy laid out for an escaped glob)"
  else
    bad "allow_scope_is_cwd_independent" "the scoped allow is not independent of the caller's working directory:$misses"
  fi
}

check_list_redacts_overlay_patterns() {
  # Listing the loaded pattern set with a private overlay attached would print every private entry
  # verbatim to standard output, and into whatever build log is open — the one invocation that
  # defeats the tool's own minimisation promise. Public entries stay visible; overlay entries print
  # as an index. The fixture overlay is SYNTHETIC, which is why this proof can ship publicly.
  local work ov out misses="" pub leaked
  work="$TMP/redactlist"; mkdir -p "$work/target"
  ov="$work/synthetic-overlay.txt"
  fixture_write "$work/target/plain.md" 'an ordinary line' || {
    bad "list_redacts_overlay_patterns" "could not write the listing target fixture"; return; }
  synthetic_overlay "$ov" || { bad "list_redacts_overlay_patterns" "could not write the synthetic overlay fixture"; return; }
  printf '#!allow zzsynthetic-allow-token :: *\n' >> "$ov"
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --list --extra "$ov" "$work/target" 2>&1)
  printf '%s' "$out" | $GREP -qF 'synthetic-secret-token' && misses="$misses [an overlay pattern printed verbatim]"
  printf '%s' "$out" | $GREP -qF 'zzsynthetic-overlay-pattern' && misses="$misses [a second overlay pattern printed verbatim]"
  printf '%s' "$out" | $GREP -qF 'zzsynthetic-allow-token' && misses="$misses [an overlay allow token printed verbatim]"
  printf '%s' "$out" | $GREP -q '\[overlay #1\] (redacted)' || misses="$misses [no overlay entry printed as an index, so nothing proves the listing loaded the overlay at all]"
  printf '%s' "$out" | $GREP -q 'from overlays, listed redacted' || misses="$misses [the counts line does not say the overlay entries were listed redacted]"
  pub=$(printf '%s' "$out" | $GREP -cE '^  \[[is]\] ' | tr -d ' ')
  [ "${pub:-0}" -gt 1 ] || misses="$misses [only ${pub:-0} pattern line(s) printed, so the listing was not exercised]"
  printf '%s' "$out" | $GREP -qE '^  \[i\] \\bTR-' || misses="$misses [no PUBLIC pattern printed verbatim — redacting the public half too would be a different defect]"
  # the two leak-by-accident paths: usage text and an error message must not echo an entry either
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --help 2>&1; bash "$PKG_ROOT/scripts/publish-lint.sh" --extra "$ov" --extra "$work/target/nope.txt" "$work/target" 2>&1)
  printf '%s' "$out" | $GREP -qE 'synthetic-secret-token|zzsynthetic' && misses="$misses [an overlay entry reached the usage text or an error message]"
  # and the quietest path of all: an entry COPIED INTO the shipped bytes, where no invocation has to
  # print it for a reader to find it. The fixture vocabulary is invented and has no business in any
  # shipped script, so a hit here means something moved an overlay entry into the tree.
  leaked=$($GREP -rlE 'synthetic-secret-token|SYNTHCO-[0-9]|synthetic\.example\.invalid' "$PKG_ROOT/scripts" 2>/dev/null | head -3 | tr '\n' ' ')
  [ -z "$leaked" ] || misses="$misses [shipped script(s) carry an overlay entry in their own bytes: $leaked]"
  if [ -z "$misses" ]; then
    ok "list_redacts_overlay_patterns (public patterns print verbatim, every overlay pattern and allow token prints as an index, the counts line says so, and neither the usage text nor an error message echoes an entry)"
  else
    bad "list_redacts_overlay_patterns" "a private entry is reachable through the tool's own output:$misses"
  fi
}

check_allow_cannot_cross_to_overlay() {
  # Allows apply to the MERGED pattern set, so without a provenance rule the PUBLIC list can disarm
  # the stricter private one and the run still prints clean, naming no file, pattern or token. Four
  # assertions, two of them negative controls: a public directive may never excuse a hit raised by
  # an overlay pattern (tree-wide or scoped), a private directive may still excuse a hit raised by a
  # public pattern, and every excused span is reported with its file, its pattern and its token.
  local work ov dl out rc misses=""
  work="$TMP/crossallow"; mkdir -p "$work/tree" "$work/tree/config"
  ov="$work/synthetic-overlay.txt"
  synthetic_overlay "$ov" || { bad "allow_cannot_cross_to_overlay" "could not write the synthetic overlay fixture"; return; }
  fixture_write "$work/tree/CROSS-PLANT.md" 'note: zzsynthetic-overlay-pattern-7 here' || {
    bad "allow_cannot_cross_to_overlay" "could not write the cross-provenance fixture"; return; }
  fixture_copy "$PKG_ROOT/config/denylist.txt" "$work/dl.txt" || {
    bad "allow_cannot_cross_to_overlay" "could not copy the pattern file into the scratch tree"; return; }
  dl="$work/dl.txt"
  # (a) a TREE-WIDE public allow against a private pattern must not excuse
  printf '#!allow zzsynthetic-overlay-pattern-7 :: *\n' >> "$dl"
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$dl" --extra "$ov" "$work/tree" 2>&1); rc=$?
  [ "$rc" = 1 ] || misses="$misses [a tree-wide PUBLIC allow excused a hit raised by an OVERLAY pattern (exit $rc) — the public file disarmed the private one]"
  # (b) the same directive, scoped: same answer
  fixture_copy "$PKG_ROOT/config/denylist.txt" "$work/dl-scoped.txt" || {
    bad "allow_cannot_cross_to_overlay" "could not copy the pattern file for the scoped case"; return; }
  printf '#!allow zzsynthetic-overlay-pattern-7 :: CROSS-PLANT.md\n' >> "$work/dl-scoped.txt"
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$work/dl-scoped.txt" --extra "$ov" "$work/tree" 2>&1); rc=$?
  [ "$rc" = 1 ] || misses="$misses [a SCOPED public allow excused a hit raised by an overlay pattern (exit $rc)]"
  # (c) the converse must still work: a PRIVATE allow may excuse a PUBLIC pattern's hit
  fixture_copy "$PKG_ROOT/config/denylist.txt" "$work/dl-pub.txt" || {
    bad "allow_cannot_cross_to_overlay" "could not copy the pattern file for the converse case"; return; }
  printf 'zzpublicprobe[0-9]+\n' >> "$work/dl-pub.txt"
  fixture_write "$work/tree/config/PUB.md" 'token zzpublicprobe7 here' || {
    bad "allow_cannot_cross_to_overlay" "could not write the public-pattern fixture"; return; }
  rm -f "$work/tree/CROSS-PLANT.md"
  fixture_write "$work/ov-allow.txt" '# synthetic overlay fixture. No real private literal appears here.' \
    '#!allow zzpublicprobe7 :: *' || {
    bad "allow_cannot_cross_to_overlay" "could not write the private-allow overlay fixture"; return; }
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$work/dl-pub.txt" --extra "$work/ov-allow.txt" "$work/tree" 2>&1); rc=$?
  [ "$rc" = 0 ] || misses="$misses [a PRIVATE allow no longer excuses a hit raised by a PUBLIC pattern (exit $rc) — the provenance rule became a blanket refusal]"
  # (d) the excused span is reported with file, pattern and token, not merely counted
  printf '%s' "$out" | $GREP -qE '^excused config/PUB\.md:[0-9]+: \[.*\].*allowed by' || misses="$misses [the excused span was not reported with its file, its pattern and the directive that excused it]"  # (annotated: a path inside the scratch fixture this check writes, not a tree path)
  printf '%s' "$out" | $GREP -q '1 span(s) excused' || misses="$misses [the excused-span count line is missing, so the report cannot be reconciled against a budget]"
  if [ -z "$misses" ]; then
    ok "allow_cannot_cross_to_overlay (a public directive cannot excuse an overlay pattern's hit tree-wide or scoped, a private directive still excuses a public pattern's hit, and the excused span is reported with file, pattern and token)"
  else
    bad "allow_cannot_cross_to_overlay" "the allow provenance rule does not hold:$misses"
  fi
}

check_publish_lint_self_test
check_publish_lint_tree_clean
check_publish_lint_fails_closed
check_pattern_set_is_usable
check_publish_lint_catches_a_plant
check_publish_lint_allow_scope
check_allow_budget
check_denylist_integrity
check_denylist_header_is_current
check_denylist_has_no_empty_sections
check_repro
check_local_config_is_not_a_leak
check_paths_with_metachars
check_reports_unscannable_files
check_file_floor
check_resolves_its_tools
check_allow_scope_is_cwd_independent
check_list_redacts_overlay_patterns
check_allow_cannot_cross_to_overlay

# --- tag-lint: the evidence-grammar gate ---
banner "tag-lint"

check_tag_lint_clean_fixture() {
  if bash "$PKG_ROOT/scripts/tag-lint.sh" "$FIX/tag-lint/clean.md" >/dev/null 2>&1; then
    ok "tag_lint_clean_fixture (a well-tagged artifact passes)"
  else
    bad "tag_lint_clean_fixture" "$(bash "$PKG_ROOT/scripts/tag-lint.sh" "$FIX/tag-lint/clean.md" 2>&1 | $GREP '\[T' | head -3 | tr '\n' ' ')"
  fi
}

check_tag_lint_negative_fixtures() {
  # One fixture per SHAPE the grammar admits, not one per rule. The three original fixtures cover
  # the bracket forms; the four added with the widened recogniser cover the shapes the linter used
  # to be blind to — a parenthesised tag, a comma payload, two tags on one line, and a tag split
  # across a line break. A shape with no fixture is a shape nobody proved the linter can see.
  local f rc missing="" n=0
  for f in bad-found-no-anchor bad-hypothesis-final bad-multi-and-unknown \
           bad-paren-form bad-comma-payload bad-multi-tag bad-split-line; do
    [ -f "$FIX/tag-lint/$f.md" ] || { missing="$missing $f(no-fixture)"; continue; }
    n=$((n + 1))
    bash "$PKG_ROOT/scripts/tag-lint.sh" "$FIX/tag-lint/$f.md" >/dev/null 2>&1; rc=$?
    [ $rc -eq 1 ] || missing="$missing $f(rc=$rc)"
  done
  if [ -z "$missing" ] && [ "$n" -ge 7 ]; then
    ok "tag_lint_negative_fixtures ($n planted shapes, each exits 1)"
  else
    bad "tag_lint_negative_fixtures" "did not fail as expected:$missing (fixtures found: $n of 7)"
  fi
}

check_tag_lint_rules_are_documented() {
  # The grammar reference is the source of truth; every rule id the script enforces must appear in
  # it. The harvest is floored: a renamed flag makes the sub-command error, the loop body never
  # runs, and a check that iterates over nothing passes vacuously.
  local ref="$PKG_ROOT/skills/pm-requirements-v1/references/evidence-tags.md" id missing="" ids n=0
  [ -f "$ref" ] || { bad "tag_lint_rules_are_documented" "the grammar reference is missing: $ref"; return; }
  ids=$(bash "$PKG_ROOT/scripts/tag-lint.sh" --rules 2>/dev/null); rc=$?
  if [ $rc -ne 0 ]; then
    bad "tag_lint_rules_are_documented" "the rule listing exited $rc — a harvest from a failing sub-command is an empty loop, not a pass"
    return
  fi
  for id in $(printf '%s' "$ids" | $AWK '{print $1}'); do
    n=$((n + 1))
    $GREP -q "| $id |" "$ref" || missing="$missing $id"
  done
  if [ "$n" -eq 0 ]; then
    bad "tag_lint_rules_are_documented" "the rule listing printed nothing — zero rules harvested is a vacuous pass, not a documented grammar"
  elif [ -z "$missing" ]; then
    ok "tag_lint_rules_are_documented ($n rule ids enforced, every one documented in the reference)"
  else
    bad "tag_lint_rules_are_documented" "undocumented rule id(s):$missing"
  fi
}

check_tag_grammar_walk() {
  # "This package obeys its own grammar" — over the WHOLE document surface, not over the three
  # globs that happened to be written first. The walk is every .md in the tree minus an explicit,
  # named exclusion list, and it carries a floor: fewer documents than the pinned number is a FAIL,
  # because an empty walk prints the same green verdict as a clean one.
  #
  # EXCLUDED BY NAME, never by shape: tests/fixtures/tag-lint/ holds deliberate violations that the
  # negative-fixture check above requires to fail. Excluding them by directory keeps that
  # deliberate red visible in one place instead of turning the whole walk amber.
  #
  # AND THE FLOOR IS PINNED IN BOTH DIRECTIONS, which is the half this check first shipped without.
  # A floor only ever compared as "fewer than" cannot tell a shrinking walk from a pin that went
  # stale while the tree grew: documents land, nobody moves the number, and the guard silently
  # stops covering everything added since. So a walk that enumerates MORE than the pin is a failure
  # too, and its message asks for the number to move in the diff that added the documents — which
  # is the pinned file's own change-law, enforced instead of merely written down.
  #
  # AND THE WALK ALSO BUDGETS THE LINTER'S ESCAPE HATCH, over the same document set, because this is
  # the one place that set is enumerated. `tag-lint:allow-multi` silences three rules on the lines
  # it covers; the shipped uses are legitimate, and nothing counted them. Two numbers, both pinned
  # beside the document floor: how many lines carry the marker, and how many claim lines the marker
  # actually silences. The second one is MEASURED rather than trusted — each carrying document is
  # re-linted with the marker text neutralised, and what the linter then reports is the count. That
  # probe is also the non-vacuity proof: a subjects count of zero would mean the neutralisation
  # changed nothing, so the budget would be a number nobody could falsify, and this check refuses it.
  local f rel n=0 bad_files="" floor
  local am_n=0 am_files=0 am_subjects=0 am_pin_d am_pin_s am_copy am_flat am_out am_hits
  floor="$(expect_val documents)"
  am_pin_d="$(expect_val tag_allow_multi_directives)"; am_pin_s="$(expect_val tag_allow_multi_subjects)"
  if [ -z "$floor" ]; then
    bad "tag_grammar_walk" "tests/expected-checks.txt pins no document floor — a walk with no floor cannot tell clean from empty"
    return
  fi
  mkdir -p "$TMP/allow-multi" 2>/dev/null
  while IFS= read -r f; do
    rel="${f#"$PKG_ROOT"/}"
    case "$rel" in tests/fixtures/*) continue ;; esac
    n=$((n + 1))
    bash "$PKG_ROOT/scripts/tag-lint.sh" "$f" >/dev/null 2>&1 || bad_files="$bad_files $rel"
    am_hits=$($GREP -c 'tag-lint:allow-multi' "$f" 2>/dev/null | tr -d ' ')
    [ -n "$am_hits" ] || am_hits=0
    [ "$am_hits" -gt 0 ] || continue
    am_n=$((am_n + am_hits)); am_files=$((am_files + 1))
    am_flat=$(printf '%s' "$rel" | tr '/' '_')
    am_copy="$TMP/allow-multi/$am_flat"
    sed 's/tag-lint:allow-multi/tag-lint:budget-probe/g' "$f" > "$am_copy" 2>/dev/null || {
      bad_files="$bad_files $rel(allow-multi-probe-unwritable)"; continue; }
    am_out=$(bash "$PKG_ROOT/scripts/tag-lint.sh" "$am_copy" 2>&1)
    am_hits=$(printf '%s' "$am_out" | $GREP -oE 'TAG-LINT FAILED: [0-9]+ violation' | $GREP -oE '[0-9]+' | head -1)
    [ -n "$am_hits" ] || am_hits=0
    am_subjects=$((am_subjects + am_hits))
  done < <(find "$PKG_ROOT" -type f -name '*.md' -not -path '*/.git/*' | sort)
  if [ "$n" -lt "$floor" ]; then
    bad "tag_grammar_walk" "the walk enumerated $n document(s) against a floor of $floor — a shrinking walk is how a document leaves the grammar gate unnoticed"
  elif [ "$n" -gt "$floor" ]; then
    bad "tag_grammar_walk" "the walk enumerated $n document(s) against a pin of $floor, so the pin is stale and the floor has stopped guarding $((n - floor)) of them — move documents in tests/expected-checks.txt in the same diff as the change that added them"
  elif [ -n "$bad_files" ]; then
    bad "tag_grammar_walk" "grammar violations in:$bad_files"
  elif [ -z "$am_pin_d" ] || [ -z "$am_pin_s" ]; then
    bad "tag_grammar_walk" "tests/expected-checks.txt pins no tag_allow_multi_directives / tag_allow_multi_subjects — the grammar linter's allow-multi marker silences three of its rules, and an unpinned budget is not a budget"
  elif [ "$am_n" != "$am_pin_d" ] || [ "$am_subjects" != "$am_pin_s" ]; then
    bad "tag_grammar_walk" "the allow-multi budget drifted: $am_n marker line(s) against a pin of $am_pin_d, silencing $am_subjects claim line(s) against a pin of $am_pin_s — move both numbers in tests/expected-checks.txt in the same diff as the change that moved them"
  elif [ "$am_subjects" -eq 0 ]; then
    bad "tag_grammar_walk" "neutralising the allow-multi markers changed nothing: 0 claim line(s) silenced, so the budget is pinned to a probe that cannot fire and no future widening could be measured against it"
  else
    ok "tag_grammar_walk ($n documents walked against a pin of $floor, current in both directions, this package obeys its own grammar, and the allow-multi escape hatch is budgeted: $am_n marker line(s) in $am_files document(s), silencing $am_subjects claim line(s) measured by re-linting them neutralised, both equal to their pinned numbers)"
  fi
}

check_grammar_parity() {
  # The documented predicate and the implemented one must be the same predicate. The unknown-tag
  # rule carries a length floor in code; a floor nobody documents is a rule readers cannot obey,
  # and dropping it would fire the rule on ordinary bracketed prose. Two halves: the number is in
  # the reference, and a fixture PAIR proves the boundary is where both say it is.
  local ref="$PKG_ROOT/skills/pm-requirements-v1/references/evidence-tags.md" impl short_rc long_rc
  impl=$($GREP -oE 'len\(t\) >= [0-9]+' "$PKG_ROOT/scripts/tag-lint.sh" | $GREP -oE '[0-9]+' | head -1)
  if [ -z "$impl" ]; then
    bad "grammar_parity" "no length floor found in the linter — the predicate this check compares against has moved or gone"
    return
  fi
  if ! $GREP -qE "(at least|fewer than|shorter than|floor of|minimum of)[^0-9]{0,20}$impl" "$ref"; then
    bad "grammar_parity" "the linter refuses a bracketed token below $impl characters and the grammar reference documents no such floor — the documented predicate is not the implemented one"
    return
  fi
  fixture_write "$TMP/parity-short.md" '# parity' '' "A claim in brackets [ABCD] with a short token." || {
    bad "grammar_parity" "could not write the parity fixture"; return; }
  fixture_write "$TMP/parity-long.md" '# parity' '' "A claim in brackets [ABCDEFG] with a long token." || {
    bad "grammar_parity" "could not write the parity fixture"; return; }
  bash "$PKG_ROOT/scripts/tag-lint.sh" "$TMP/parity-short.md" >/dev/null 2>&1; short_rc=$?
  bash "$PKG_ROOT/scripts/tag-lint.sh" "$TMP/parity-long.md" >/dev/null 2>&1; long_rc=$?
  if [ "$short_rc" -eq 0 ] && [ "$long_rc" -eq 1 ]; then
    ok "grammar_parity (the documented $impl-character floor is the implemented one, proven by a fixture pair either side of it)"
  else
    bad "grammar_parity" "the fixture pair straddling the documented floor did not behave: below rc=$short_rc (expected 0), above rc=$long_rc (expected 1)"
  fi
}

check_tag_lint_clean_fixture
check_tag_lint_negative_fixtures
check_tag_lint_rules_are_documented
check_tag_grammar_walk
check_grammar_parity

# --- inference gate: the pre-emit guard ---
banner "inference-gate"

check_gate_refuses_unruled() {
  mkdir -p "$TMP/pkg-none"
  bash "$PKG_ROOT/scripts/inference-gate.sh" "$TMP/pkg-none" >/dev/null 2>&1
  [ $? -eq 1 ] || { bad "gate_refuses_unruled" "a missing ruling file did not refuse"; return; }
  mkdir -p "$TMP/pkg-false"
  printf '{"confirmed": false}\n' > "$TMP/pkg-false/inference-confirmed.json"
  bash "$PKG_ROOT/scripts/inference-gate.sh" "$TMP/pkg-false" >/dev/null 2>&1
  [ $? -eq 1 ] || { bad "gate_refuses_unruled" "confirmed:false did not refuse"; return; }
  mkdir -p "$TMP/pkg-bad"
  printf 'not json at all\n' > "$TMP/pkg-bad/inference-confirmed.json"
  bash "$PKG_ROOT/scripts/inference-gate.sh" "$TMP/pkg-bad" >/dev/null 2>&1
  [ $? -eq 1 ] || { bad "gate_refuses_unruled" "invalid JSON did not refuse"; return; }
  ok "gate_refuses_unruled (missing, false, and unreadable all refuse)"
}

check_gate_passes_ruled() {
  mkdir -p "$TMP/pkg-ok"
  printf '{"confirmed": true, "confirmer": "product owner", "at": "2026-01-01T00:00:00Z", "items": []}\n' \
    > "$TMP/pkg-ok/inference-confirmed.json"
  if bash "$PKG_ROOT/scripts/inference-gate.sh" "$TMP/pkg-ok" >/dev/null 2>&1; then
    ok "gate_passes_ruled"
  else
    bad "gate_passes_ruled" "a recorded ruling was refused"
  fi
}

check_gate_branches_are_distinguishable() {
  # Two different problems must not print one message. A package DIRECTORY that is not there is a
  # different thing from a package whose ruling was never recorded, and a reader who cannot tell
  # them apart goes looking in the wrong place. The verdict and the exit code stay identical on
  # purpose — only the sentence differs.
  local missing_out present_out missing_rc present_rc
  missing_out=$(bash "$PKG_ROOT/scripts/inference-gate.sh" "$TMP/no-such-package-dir" 2>&1); missing_rc=$?
  mkdir -p "$TMP/pkg-unruled"
  present_out=$(bash "$PKG_ROOT/scripts/inference-gate.sh" "$TMP/pkg-unruled" 2>&1); present_rc=$?
  if [ "$missing_rc" -ne "$present_rc" ]; then
    bad "gate_branches_are_distinguishable" "the two branches take different exit codes ($missing_rc vs $present_rc) — the exit-code contract says they are the same refusal"
  elif [ "$(printf '%s' "$missing_out" | head -1)" = "$(printf '%s' "$present_out" | head -1)" ]; then
    bad "gate_branches_are_distinguishable" "a missing package directory and an unruled package print the same first line — two problems, one message"
  else
    ok "gate_branches_are_distinguishable (missing directory and unruled package print different lines and take the same exit code $missing_rc)"
  fi
}

check_entry_points_answer_help() {
  # A fresh reader's first move on any script is to ask it for help. Every inventoried entry point
  # must answer successfully and name itself in the answer; one that refuses reads as a broken
  # package, and one whose usage line names a different script sends the reader somewhere else.
  #
  # THE INVENTORY IS EVERY ENTRY POINT, not every script in one directory. Scoped to scripts/, this
  # census left out the one entry point the documents send a first-time reader to before any other
  # — the suite itself — and that entry point was the only one in the package that refused. An
  # exclusion the reader can walk into is not an exclusion; it is a gap with a directory name.
  local f base out rc broken="" n=0
  for f in "$PKG_ROOT"/scripts/*.sh "$PKG_ROOT"/tests/run-tests.sh; do
    [ -f "$f" ] || continue
    n=$((n + 1))
    base="$(basename "$f")"
    out=$(bash "$f" --help 2>&1); rc=$?
    if [ $rc -ne 0 ]; then broken="$broken $base(rc=$rc)"; continue; fi
    printf '%s' "$out" | $GREP -qF "$base" || broken="$broken $base(no-usage-line-naming-itself)"
  done
  if [ "$n" -eq 0 ]; then
    bad "entry_points_answer_help" "no entry point was enumerated — an empty inventory is not a pass"
  elif [ -z "$broken" ]; then
    ok "entry_points_answer_help ($n entry points, the suite's own included, each answers --help on standard output with a usage line naming itself)"
  else
    bad "entry_points_answer_help" "entry point(s) that do not answer help:$broken"
  fi
}

check_gate_refuses_unruled
check_gate_passes_ruled
check_gate_branches_are_distinguishable
check_entry_points_answer_help

# --- config: the machine-local indirection ---
banner "config"

check_template_keys_documented() {
  # Every ${local:<key>} used anywhere in the package must be documented in the template. Two
  # things this check learned the hard way: the key is matched as a FIXED STRING (interpolated into
  # a pattern, every dot is a wildcard, and a dotted key then "verifies" against an underscore one),
  # and harvested tokens that are not key-shaped are DROPPED with the count reported — the
  # documentation placeholder is one of those, and a wildcard match made it look like a real key.
  local tmpl="$PKG_ROOT/config/local.template.json" missing="" dropped=0 kept=0 k
  [ -f "$tmpl" ] || { bad "template_keys_documented" "template missing"; return; }
  local keys
  keys=$($GREP -rhoE '\$\{local:[^}]+\}' "$PKG_ROOT" \
           --exclude-dir=.git --exclude-dir=tests 2>/dev/null \
         | sed 's/^\${local://; s/}$//' | sort -u)
  for k in $keys; do
    case "$k" in
      *[!A-Za-z0-9_.-]*|''|.*|*.|*..*) dropped=$((dropped + 1)); continue ;;
      *[A-Za-z]*) : ;;
      *) dropped=$((dropped + 1)); continue ;;
    esac
    kept=$((kept + 1))
    $GREP -qF "\"$k\"" "$tmpl" || missing="$missing $k"
  done
  if [ "$kept" -eq 0 ]; then
    bad "template_keys_documented" "zero key-shaped references harvested — a completeness test with nothing to complete is not a pass"
  elif [ -z "$missing" ]; then
    ok "template_keys_documented ($kept referenced key(s) documented, $dropped non-key token(s) dropped and counted)"
  else
    bad "template_keys_documented" "undocumented key(s):$missing"
  fi
}

check_local_template_ships_no_values() {
  if python3 - "$PKG_ROOT/config/local.template.json" <<'PY' >/dev/null 2>&1
import json, sys
t = json.load(open(sys.argv[1]))
vals = [k for k, v in (t.get("local") or {}).items() if v not in (None, "", [], {})]
sys.exit(1 if vals else 0)
PY
  then ok "local_template_ships_no_values (no foreign default can render in your output)"
  else bad "local_template_ships_no_values" "a key ships with a value — a stranger's default would render"; fi
}

check_template_promise() {
  # A documentation string that promises engine behaviour must name a key some shipped surface
  # actually reads. The keys are NOT deleted when they go quiet — the schema's keys are protected
  # and the completeness check cross-references them — so the honest form is to say the key is
  # reserved and user-extensible, and this check is what keeps that wording in step with reality.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, re, subprocess, sys
root = sys.argv[1]
tmpl = json.load(open(os.path.join(root, "config", "local.template.json")))
local, doc = tmpl.get("local") or {}, tmpl.get("_doc") or {}
problems = []
for k in doc:
    if k not in local:
        problems.append("%s: documented but no such key — the promise outlived the key" % k)
for k in local:
    if k not in doc:
        problems.append("%s: no documentation string" % k)
PROMISE = re.compile(r"(the engine|this plugin|a shipped script|scanned|probed|inventoried|"
                     r"resolves? against|read by|enumerates)", re.I)
haystack = []
for sub in ("scripts", "skills", "config", "references", "packs"):
    d = os.path.join(root, sub)
    for dirpath, dirnames, filenames in os.walk(d):
        dirnames[:] = [x for x in dirnames if x != ".git"]
        for f in filenames:
            p = os.path.join(dirpath, f)
            if os.path.basename(p) == "local.template.json":
                continue
            try:
                haystack.append(open(p, encoding="utf-8", errors="replace").read())
            except OSError:
                pass
blob = "\n".join(haystack)
for k, text in doc.items():
    if k not in local:
        continue
    live = ("${local:%s}" % k) in blob or ('"%s"' % k) in blob or k in blob
    if live:
        continue
    if "RESERVED" in (text or ""):
        continue
    if PROMISE.search(text or ""):
        problems.append("%s: promises engine behaviour and nothing in the tree reads it" % k)
if problems:
    print("; ".join(problems[:4]))
    raise SystemExit(1)
print("%d documented key(s), every promise names a key the tree reads" % len(doc))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "template_promise ($out)"
  else bad "template_promise" "$(printf '%s' "$out" | tail -1)"; fi
}

check_gitignore_covers_local_config() {
  local gi="$PKG_ROOT/.gitignore"
  if [ -f "$gi" ] && $GREP -qE '(^|/)config/local\.json$' "$gi"; then
    ok "gitignore_covers_local_config"
  else
    bad "gitignore_covers_local_config" "config/local.json is not ignored — a machine layout could be committed"
  fi
}

check_dep_rows() {
  # A dependency row that names scripts is making a measurable claim: those scripts use the tool,
  # and the ones it leaves out do not. Both directions are checked, because the row that shipped
  # was wrong in both — it named a script with no reference to the dependency and omitted the one
  # with the most.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, re, sys
root = sys.argv[1]
deps = json.load(open(os.path.join(root, "config", "dependencies.json")))["deps"]
scripts = sorted(f for f in os.listdir(os.path.join(root, "scripts")) if f.endswith(".sh"))
problems, checked = [], 0
for dep_id, row in deps.items():
    if row.get("kind") != "cli":
        continue
    tools = re.findall(r"[A-Za-z0-9_.-]+", row.get("probe") or "")
    tools = [t for t in tools if t not in ("command", "-v", "v", "dev", "null", "test", "n", "r")]
    text = " ".join(str(row.get(k) or "") for k in ("what", "fix"))
    # A parenthetical that EXCLUDES scripts ("(publish-lint and release are pure shell)") names them
    # in order to say they are not users of this dependency. Read as a claim it would invert the row.
    text = re.sub(r"\([^)]*\b(pure shell|not|never|no longer|none)\b[^)]*\)", " ", text, flags=re.I)
    named = set()
    for s in scripts:
        stem = s[:-3]
        if re.search(r"\b%s(\.sh)?\b" % re.escape(stem), text):
            named.add(s)
    if not named:
        continue
    checked += 1
    uses = set()
    for s in scripts:
        body = open(os.path.join(root, "scripts", s), encoding="utf-8", errors="replace").read()
        if any(re.search(r"\b%s\b" % re.escape(t), body) for t in tools if len(t) > 2):
            uses.add(s)
    for s in sorted(named - uses):
        problems.append("%s: the row names %s, which never references it" % (dep_id, s))
    for s in sorted(uses - named):
        problems.append("%s: %s references it and the row does not name it" % (dep_id, s))
if not checked:
    print("no dependency row names any script — nothing was cross-checked, which is not a pass")
    raise SystemExit(1)
# AND THE SAME CLAIM AS PROSE. The row that shipped was false in both directions, and several
# documents restated it in a stronger, equally false "every script" form. A row corrected in
# config while a document still says "every script" is the same defect with a different reader, and
# the row-level cross-check above cannot see a document at all. So: where a row names a strict
# SUBSET of the scripts, no shipped surface may say the dependency is used by all of them.
docs = 0
for dep_id, row in deps.items():
    if row.get("kind") != "cli":
        continue
    text = " ".join(str(row.get(k) or "") for k in ("what", "fix"))
    text = re.sub(r"\([^)]*\b(pure shell|not|never|no longer|none)\b[^)]*\)", " ", text, flags=re.I)
    named = set(s for s in scripts if re.search(r"\b%s(\.sh)?\b" % re.escape(s[:-3]), text))
    if not named or named == set(scripts):
        continue
    words = [dep_id] + [t for t in re.findall(r"[A-Za-z0-9_.-]+", row.get("probe") or "")
                        if len(t) > 2 and t not in ("command", "dev", "null")]
    if dep_id.startswith("python"):
        words.append("interpreter")
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "drafts", "tests")]
        for f in sorted(filenames):
            if not f.endswith(".md"):
                continue
            p = os.path.join(dirpath, f)
            for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
                if not re.search(r"\b(every|all)\s+scripts?\b", line, re.I):
                    continue
                # THE CLAIM IS ONE PREDICATION, so the two halves have to sit in one sentence.
                # Matched line-wide, this fires on any line that says "every script" about one
                # thing and happens to name a dependency about another — an exit-code contract
                # sentence that ends by naming an interpreter, for instance. That is not a claim
                # that the dependency is used by every script, and reading it as one turns a
                # truthful document red while teaching nobody anything.
                for clause in re.split(r"(?<=[.:;])\s+", line):
                    if not re.search(r"\b(every|all)\s+scripts?\b", clause, re.I):
                        continue
                    if not any(re.search(r"\b%s\b" % re.escape(w), clause, re.I) for w in words):
                        continue
                    docs += 1
                    problems.append("%s:%d says %s is used by every script and the row names %d of "
                                    "%d: %.50s" % (os.path.relpath(p, root), n, dep_id, len(named),
                                                   len(scripts), clause.strip()))
                    break
if problems:
    print("; ".join(problems[:4]))
    raise SystemExit(1)
print("%d dependency row(s) naming scripts, every named script uses it and every user is named; "
      "no surface restates a subset row as every script" % checked)
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "dep_rows ($out)"
  else bad "dep_rows" "$(printf '%s' "$out" | tail -1)"; fi
}

check_stack_arity() {
  # A stated arity is a count, and counts are measurable. The capability manifest maps every stack
  # key to its rows; a surface that says how many capabilities a key adds must say the same number
  # the map does, in whichever grammar it uses.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, re, sys
root = sys.argv[1]
deps = json.load(open(os.path.join(root, "config", "dependencies.json")))
arity = {}
for verb, row in (deps.get("verbs") or {}).items():
    for key, ids in (row.get("conditional") or {}).items():
        arity.setdefault(key, set()).add(len(ids))
multi = sorted(k for k, v in arity.items() if max(v) > 1)
claims = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
    for f in filenames:
        if not f.endswith(".md"):
            continue
        p = os.path.join(dirpath, f)
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            if re.search(r"adds exactly one capability", line, re.I):
                claims.append("%s:%d" % (os.path.relpath(p, root), n))
if not arity:
    print("no stack key maps to any capability row — the arity map is empty, which is not a pass")
    raise SystemExit(1)
if multi and claims:
    print("the map gives %s more than one row each, and %s still says each key adds exactly one"
          % (", ".join(multi), ", ".join(claims)))
    raise SystemExit(1)
print("%d stack key(s) mapped, %d of them multi-row; no surface claims a one-row arity they contradict"
      % (len(arity), len(multi)))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "stack_arity ($out)"
  else bad "stack_arity" "$(printf '%s' "$out" | tail -1)"; fi
}

check_packs_registry_resolves() {
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import copy, json, os, sys
root = sys.argv[1]
reg = json.load(open(os.path.join(root, "config", "packs.json")))
packs = reg.get("packs") or {}
default = reg.get("default")
assert default == "none" or default in packs, "default names no registered pack"
# THE SHAPE TRIPLE, asserted on EVERY row including the template's. vertical/market/model live on
# the registry row rather than in a manifest because the question they answer — which registered
# pack does this company resemble — is asked over the INDEX, before any manifest is opened
# (packs/README.md §1, §8). So a row missing one of them is a pack the seeding question cannot see,
# and a row carrying an empty string is the same hole with a key in front of it.
SHAPE = ("vertical", "market", "model")


def audit_shape(rows):
    for pid, row in sorted(rows.items()):
        for key in SHAPE:
            assert key in row, \
                "%s: no %s — the shape triple is required on every registry row" % (pid, key)
            val = row[key]
            assert isinstance(val, str) and val.strip(), \
                "%s: %s is %r — a blank shape field is a row the seeding question cannot read" \
                % (pid, key, val)


audit_shape(packs)
# AND THE ASSERTION IS PROVED TO FIRE, over a copy of the registry it has just certified. A shape
# check that has only ever been shown complete rows is a check nobody has watched fail, and this
# one is new enough that nobody has.
plant = copy.deepcopy(packs)
victim = sorted(plant)[0]
del plant[victim]["vertical"]
try:
    audit_shape(plant)
except AssertionError:
    pass
else:
    raise AssertionError("CONTROL FAILED: a row with its vertical deleted passed the shape "
                         "assertion, so that half certifies whatever it is handed")
for pid, row in packs.items():
    m = os.path.join(root, row["manifest"])
    assert os.path.isfile(m), "manifest missing for %s: %s" % (pid, row["manifest"])
    man = json.load(open(m))
    assert man.get("name") == pid, "pack.json name != registry key for %s" % pid
    for key in ("company", "status", "context_files", "found_sources", "seam", "analytics", "deck_kit"):
        assert key in man, "%s lacks required key %s" % (pid, key)
    # A pack that pre-answers the org-shape question must pre-answer it with a LEGAL value: the
    # set is solo|domains|squads (skills/pm-requirements-v1/SKILL.md, skills/pm-gtm-v1/SKILL.md),
    # and the verb takes this key as a confirm-only default. Anything else hands the run an answer
    # it cannot confirm. A null is the way to decline pre-answering, as workbook_form already does.
    shape = man.get("org_shape_default")
    assert shape is None or shape in ("solo", "domains", "squads"), \
        "%s: org_shape_default must be solo, domains or squads, or null to decline " \
        "pre-answering it — got %r" % (pid, shape)
print("%d pack row(s): every manifest resolves, the ids agree, any pre-answered org shape is legal, "
      "and every row carries a filled vertical/market/model — proved by deleting one and watching "
      "the assertion fire" % len(packs))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "packs_registry_resolves ($out)"
  else bad "packs_registry_resolves" "$(printf '%s' "$out" | tail -1)"; fi
}

check_fictional_pack_guard() {
  # The template pack must declare itself fictional: a shipped pack full of a real company's facts
  # is the leak this package was extracted to prevent. The trigger for that assertion is read from
  # the REGISTRY — the reviewed index — and the two sides must agree, or flipping one field in the
  # artifact under guard switches its own guard off.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, sys
root = sys.argv[1]
reg = json.load(open(os.path.join(root, "config", "packs.json")))
rows = reg.get("packs") or {}
assert rows, "the registry lists no pack at all — an empty guard is not a guard"
# THE STATUSES ARE ROUTED BY NAME, in both directions, rather than by one set and a silent default.
# Written as "template or exemplar, else nothing", this guard skipped every status nobody had
# thought about yet — including a typo — and reported the same confident count while doing it.
GUARDED = ("template", "exemplar")
# SKIPPED DELIBERATELY, AND HERE IS THE REASON, because a skip with no reason beside it is
# indistinguishable from an oversight the next reader will "fix" or widen.
#   benchmark  a benchmark pack's subject is a real company, openly named, and its content is
#              public (packs/README.md §7). Demanding a fictional flag would be demanding a FALSE
#              declaration on a true pack. What stands in its place is check_benchmark_pack_facts,
#              which holds every figure in such a pack to a source class and a year.
#   active     a live pack points at the operator's own material. This guard was never about their
#              data; it exists so a SHIPPED pack cannot carry somebody's real facts behind an
#              invented label, and an active pack ships with nobody but its own owner.
SKIPPED = ("benchmark", "active")
KNOWN = GUARDED + SKIPPED
checked, waived = 0, 0
for pid, row in rows.items():
    man = json.load(open(os.path.join(root, row["manifest"])))
    reg_status, man_status = row.get("status"), man.get("status")
    assert reg_status == man_status, \
        "%s: the registry says status %r and the manifest says %r — the guard reads the registry, " \
        "so a manifest that disagrees is a guard switched off from inside" % (pid, reg_status, man_status)
    assert reg_status in KNOWN, \
        "%s: status %r is not one of %s — an unrecognised status falls through this guard by " \
        "default, which is a guard a typo can switch off" % (pid, reg_status, "/".join(KNOWN))
    if reg_status in GUARDED:
        checked += 1
        assert man.get("fictional") is True, "%s is shipped as %s but not marked fictional" % (pid, reg_status)
    else:
        waived += 1
assert checked, "no template or exemplar pack in the registry — the guard had nothing to guard"
print("%d shipped template/exemplar pack(s), registry and manifest agree, every one marked "
      "fictional; %d row(s) of a status this guard skips by name and for a written reason; no row "
      "carries a status outside the four this package declares" % (checked, waived))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "fictional_pack_guard ($out)"
  else bad "fictional_pack_guard" "$(printf '%s' "$out" | tail -1)"; fi
}

check_fictional_pack_content() {
  # The company in a template pack is fictional; the STRUCTURE can still fingerprint a real
  # internal exercise. So the corpus filenames a pack names must be built from a committed neutral
  # vocabulary (tests/pack-corpus-vocabulary.txt), and no pack surface may describe a graded
  # exercise. Both halves are content, not identity — the fictional flag above cannot see either.
  local out rc
  out=$(python3 - "$PKG_ROOT" "$HERE/pack-corpus-vocabulary.txt" 2>&1 <<'PY'
import json, os, re, sys
root, vocab_path = sys.argv[1], sys.argv[2]
if not os.path.isfile(vocab_path):
    print("no committed vocabulary at %s — an unpinned vocabulary permits anything"
          % os.path.basename(vocab_path))
    raise SystemExit(1)
vocab = set()
for line in open(vocab_path, encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#"):
        vocab.add(line.lower())
assert vocab, "the committed vocabulary is empty"
GRADED = re.compile(r"\b(graded|grading|marked exercise|the exercise)\b", re.I)
problems, names = [], 0
packs = json.load(open(os.path.join(root, "config", "packs.json"))).get("packs") or {}
# SCOPED TO THE FICTIONAL STATUSES, by name and on purpose — the same routing the flag guard above
# uses. This half polices STRUCTURE: it holds a pack's corpus filenames to a reviewed neutral
# vocabulary so an invented company cannot ship a real internal exercise's filing scheme behind its
# invented label. A benchmark pack has no such scheme to hide: its subject is public and openly
# named (packs/README.md §7), and its write-up is facts.md, a filename that describes the artifact
# and fingerprints nothing. Held to the fixture vocabulary it would fail for its own honest name,
# which is a gate manufacturing a finding rather than catching one.
SCOPE = ("template", "exemplar")
skipped_status = 0
for pid, row in packs.items():
    if row.get("status") not in SCOPE:
        skipped_status += 1
        continue
    mpath = os.path.join(root, row["manifest"])
    man = json.load(open(mpath))
    pack_dir = os.path.dirname(mpath)
    listed = list((man.get("quarantine") or {}).get("named_comparison_files") or [])
    on_disk = [f for f in sorted(os.listdir(pack_dir)) if f.endswith(".md") and f != "README.md"]
    for f in listed + on_disk:
        names += 1
        for tok in re.split(r"[^A-Za-z0-9]+", os.path.splitext(f)[0]):
            if tok and tok.lower() not in vocab:
                problems.append("%s: %s uses %r, which is not in the committed vocabulary" % (pid, f, tok))
    for surface in (mpath, os.path.join(pack_dir, "README.md")):
        if not os.path.isfile(surface):
            continue
        for n, line in enumerate(open(surface, encoding="utf-8", errors="replace"), 1):
            if GRADED.search(line):
                problems.append("%s:%d describes a graded exercise" % (os.path.relpath(surface, root), n))
if not names:
    print("no pack of a fictional status names any corpus file — nothing was checked against the "
          "vocabulary, and a scoped check whose scope is empty is not a pass")
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d corpus filename(s) across the template/exemplar packs, every token from the committed "
      "vocabulary, no graded-exercise wording; %d pack(s) of another status out of scope by name"
      % (names, skipped_status))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "fictional_pack_content ($out)"
  else bad "fictional_pack_content" "$(printf '%s' "$out" | tail -1)"; fi
}

check_benchmark_pack_facts() {
  # THE BENCHMARK PACKS' OWN GUARD, and the one standing where the fictional flag cannot. A pack
  # whose subject is a real, openly named company (packs/README.md §7) cannot be guarded by a
  # declaration that its content is invented, because its content is not invented — it is public.
  # What IS guardable is how the figures are written down: every line of a benchmark write-up that
  # states a number carries an evidence tag, one of three source-class DESCRIPTORS, and the year
  # that figure describes. A bare number is precisely the failure this exists to catch — unclassed
  # it reads as this package's own measurement, and undated it can never be seen to have gone stale.
  #
  # DESCRIPTORS ARE CLASSES, NOT ADDRESSES. That is the point of them: a class says how much weight
  # a figure carries and survives the disappearance of whatever page it was read on, where a link
  # rots quietly and takes the reader's ability to judge the number with it.
  #
  # AND THE ACCEPTED SET IS HELD AGAINST THE DOCUMENT THAT DECLARES IT, so the gate and the prose
  # cannot drift into two different rules — the failure mode where a check is green because it
  # stopped enforcing what the page still promises.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, re, sys
root = sys.argv[1]
DESCRIPTORS = ("public company reporting", "public filings",
               "founder interviews as publicly reported")
doc = os.path.join(root, "packs", "README.md")
if not os.path.isfile(doc):
    print("packs/README.md is missing, so the descriptor set this check enforces has no declaration "
          "to agree with and the rule exists in one place only")
    raise SystemExit(1)
declared = open(doc, encoding="utf-8", errors="replace").read().lower()
undeclared = [d for d in DESCRIPTORS if d not in declared]
if undeclared:
    print("this check accepts %s and packs/README.md names no such source class — a gate and its "
          "documentation that disagree are two different rules" % ", ".join(repr(d) for d in undeclared))
    raise SystemExit(1)

TAG = re.compile(r"\b(FOUND|INFERRED|CONSTRUCTED|CALCULATED|HYPOTHESIS|NEEDS-CONFIRMATION)\b")
YEAR = re.compile(r"\b(?:19|20)\d{2}\b")
# A FIGURE is a digit run that is not one of the things any document is full of anyway: the year
# itself, a section reference, an ordered-list marker, or the level digit of a citation (excluded by
# the lookbehind, since it is preceded by its own letter). What is left is a number the write-up is
# asserting, and an asserted number carries its class and its date.
SECTION = re.compile(r"[§#]\s*\d+(?:\.\d+)*")
LISTMARK = re.compile(r"^\s*\d+[.)]\s")
# the code-fence character is BUILT, never written: a literal one inside this heredoc, inside a
# command substitution, is a parse error on some shells before this program ever runs
TICK = chr(96)
FENCE = re.compile(r"^\s*(" + TICK * 3 + "|~~~)")
DIGIT = re.compile(r"(?<![A-Za-z0-9_.])\d")


def states_a_figure(line):
    body = SECTION.sub(" ", YEAR.sub(" ", LISTMARK.sub("", line)))
    return bool(DIGIT.search(body))


def classified(text):
    low = text.lower()
    return bool(TAG.search(text)) and bool(YEAR.search(text)) \
        and any(d in low for d in DESCRIPTORS)


def unclassified(line):
    return states_a_figure(line) and not classified(line)


# A WRAPPED BULLET IS ONE CLAIM, so the tag is looked for over the whole claim rather than over the
# physical line the figure landed on. Prose wraps; a rule that did not know it would fire on
# correctly written content whose tag sits two lines below its number, which is a gate manufacturing
# findings. The blocks are cut narrowly, though — a new bullet, a table row, a heading or a blank
# line ENDS one — because a block that ran on would let one bullet's tag classify the next bullet's
# figure, and that is the hole this check exists to close.
NEWBLOCK = re.compile(r"^\s*(?:[-*+]\s|\d+[.)]\s|\||#)")


def blocks(lines):
    """Yield (start_lineno, [lines]) for each claim block, in file order."""
    buf, start = [], 0
    for n, line in enumerate(lines, 1):
        if not line.strip() or NEWBLOCK.match(line):
            if buf:
                yield start, buf
            buf, start = ([line], n) if line.strip() else ([], 0)
            continue
        if buf:
            buf.append(line)
        else:
            buf, start = [line], n
    if buf:
        yield start, buf


# THE PLANT AND ITS CONTROL, run through the same predicate the tree is judged by, before the tree
# is judged. The control is asserted to STATE A FIGURE as well as to pass: a control that passes
# because the matcher could not see its number proves the matcher is broken, not that the rule works.
PLANT = "| paying customers | 1,200 | | |"
CONTROL = "| paying customers | 1,200 | FOUND | [L1: public company reporting, 2024] |"
if not unclassified(PLANT):
    print("CONTROL FAILED: a bare number with no source class and no year passed, so this check "
          "certifies whatever a benchmark write-up happens to contain")
    raise SystemExit(1)
if not states_a_figure(CONTROL):
    print("CONTROL FAILED: the tagged control is not even read as stating a figure, so its pass "
          "measures a blind matcher rather than a clean line")
    raise SystemExit(1)
if unclassified(CONTROL):
    print("CONTROL FAILED: a figure carrying a tag, a source class and a year was flagged, so this "
          "check would fail every correctly written benchmark line")
    raise SystemExit(1)
# AND THE BLOCK RULE IS PROVED IN BOTH DIRECTIONS TOO, because a wrapped bullet is where it earns
# its keep and where it could quietly become a hole. A tag on a continuation line must classify the
# figure above it; a tag on the NEXT BULLET must not.
WRAPPED = ["- paying customers reached 1,200 over the period, up from a much smaller base",
           "  [FOUND: public company reporting, 2024]"]
NEIGHBOUR = ["- paying customers reached 1,200 over the period",
             "- revenue held steady [FOUND: public company reporting, 2024]"]
if any(problem for _, blk in blocks(WRAPPED) for problem in [not classified(" ".join(blk))]
       if any(states_a_figure(l) for l in blk) and problem):
    print("CONTROL FAILED: a wrapped bullet whose tag sits on its continuation line was flagged, so "
          "this check fires on correctly written prose that merely wrapped")
    raise SystemExit(1)
if not any(True for _, blk in blocks(NEIGHBOUR)
           if any(states_a_figure(l) for l in blk) and not classified(" ".join(blk))):
    print("CONTROL FAILED: a bare figure was classified by the NEXT bullet's tag, so the block rule "
          "has run on and one claim's evidence is covering another's")
    raise SystemExit(1)

rows = json.load(open(os.path.join(root, "config", "packs.json"))).get("packs") or {}
bench = sorted(pid for pid, row in rows.items() if row.get("status") == "benchmark")
if not bench:
    print("the registry lists no benchmark pack, so this gate would certify an empty set while the "
          "status it guards is still documented and selectable")
    raise SystemExit(1)
problems, figures, walked = [], 0, 0
for pid in bench:
    pack_dir = os.path.dirname(os.path.join(root, rows[pid]["manifest"]))
    path = os.path.join(pack_dir, "facts.md")
    rel = os.path.relpath(path, root)
    if not os.path.isfile(path):
        problems.append("%s is registered as a benchmark pack and carries no %s — a benchmark that "
                        "states nothing is a registry row, not a benchmark" % (pid, rel))
        continue
    walked += 1
    here = 0
    body, inside = [], False
    for line in open(path, encoding="utf-8", errors="replace").read().splitlines():
        if FENCE.match(line):
            inside = not inside
            body.append("")
            continue
        body.append("" if inside else line)
    for start, block in blocks(body):
        whole = " ".join(block)
        for offset, line in enumerate(block):
            if not states_a_figure(line):
                continue
            figures += 1
            here += 1
            if not classified(whole):
                problems.append("%s:%d states a figure with no source class and year: %.58s"
                                % (rel, start + offset, line.strip()))
    if not here:
        problems.append("%s carries no figure at all, so its own numbers are guarded by nothing"
                        % rel)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d benchmark write-up(s), %d tagged figure(s), every one carrying one of the %d source "
      "classes packs/README.md declares and the year it describes; proved live on four controls "
      "before the walk: a bare number fails, a tagged figure passes, a wrapped bullet is read as "
      "one claim, and the next bullet's tag never reaches back to cover it"
      % (walked, figures, len(DESCRIPTORS)))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "benchmark_pack_facts ($out)"
  else bad "benchmark_pack_facts" "$(printf '%s' "$out" | tail -1)"; fi
}

check_capability_row_is_real() {
  # Every user-invocable verb skill (except the front door, which needs none) must have a ROW in
  # the capability manifest, or its preflight call is a lie. Membership is parsed, never grepped: a
  # bare substring search is satisfied by the name appearing anywhere at all, including in the free
  # text left behind after the row itself was deleted.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, sys
root = sys.argv[1]
deps = json.load(open(os.path.join(root, "config", "dependencies.json")))
verbs = deps.get("verbs") or {}
skills = sorted(d for d in os.listdir(os.path.join(root, "skills"))
                if os.path.isdir(os.path.join(root, "skills", d)))
skipped = {"pm-start", "init", "gtm-domain-library"}
missing = [s for s in skills if s not in skipped and s not in verbs]
checked = [s for s in skills if s not in skipped]
assert checked, "no verb skill was enumerated — an empty membership test is not a pass"
assert not missing, "no capability-manifest row for: %s" % " ".join(missing)
for v in checked:
    row = verbs[v]
    assert isinstance(row.get("required"), list), "%s: required is not a list of ids" % v
    for dep_id in row["required"]:
        assert dep_id in (deps.get("deps") or {}), "%s requires %r, which is not a declared row" % (v, dep_id)
print("%d verb skill(s), each a real row in the manifest with every required id declared" % len(checked))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "capability_row_is_real ($out)"
  else bad "capability_row_is_real" "$(printf '%s' "$out" | tail -1)"; fi
}

check_scripts_are_syntactically_valid() {
  local f bad_files="" n=0
  for f in "$PKG_ROOT"/scripts/*.sh "$PKG_ROOT"/tests/*.sh; do
    [ -f "$f" ] || continue
    n=$((n + 1))
    bash -n "$f" 2>/dev/null || bad_files="$bad_files ${f#"$PKG_ROOT"/}"
  done
  if [ "$n" -eq 0 ]; then
    bad "scripts_are_syntactically_valid" "no script was enumerated — an empty walk is not a pass"
  elif [ -z "$bad_files" ]; then
    ok "scripts_are_syntactically_valid ($n scripts parse)"
  else
    bad "scripts_are_syntactically_valid" "syntax errors in:$bad_files"
  fi
}

check_template_keys_documented
check_local_template_ships_no_values
check_template_promise
check_gitignore_covers_local_config
check_dep_rows
check_stack_arity
check_packs_registry_resolves
check_fictional_pack_guard
check_fictional_pack_content
check_benchmark_pack_facts
check_capability_row_is_real
check_scripts_are_syntactically_valid

# --- optional integrations: elicited, never preconfigured ---
banner "integrations"

check_no_vendor_named_integration_id() {
  # An integration id shaped <vendor>_<company> ships one operator's tooling choice AND that
  # operator's customer to every user of this package. The id must name the CAPABILITY instead.
  # Two halves, because a literal scan and a structural scan miss different things.
  # DO NOT add a vendor here that config/denylist.txt already bans by bare name. Four of the
  # obvious candidates are in that stronger class: publish-lint fails on the bare word, so a
  # <that-vendor>_<anything> id cannot reach a published byte in the first place — and naming one
  # here would plant the banned literal in this file and turn the leak scanner red. This list is
  # for vendors that are legitimate to MENTION but must never be BAKED IN as an integration id.
  local vendors='jira|confluence|asana|linear|clickup|monday|trello|shortcut|youtrack|redmine|github|gitlab|bitbucket|slack|amplitude|segment|zendesk'
  local hits
  hits=$($GREP -rniE "\\b(${vendors})_[a-z0-9]+\\b" "$PKG_ROOT" \
           --exclude-dir=.git --exclude-dir=__pycache__ \
           --exclude=denylist.txt --exclude=run-tests.sh 2>/dev/null)
  if [ -n "$hits" ]; then
    bad "no_vendor_named_integration_id" \
        "a <vendor>_<suffix> integration id is present: $(printf '%s' "$hits" | head -3 | tr '\n' ' ')"
    return
  fi
  # Structural: no capability row may be NAMED after a vendor at all, suffixed or not.
  if python3 - "$PKG_ROOT" "$vendors" <<'PY' >/dev/null 2>&1
import json, os, re, sys
root, vendors = sys.argv[1], sys.argv[2]
deps = json.load(open(os.path.join(root, "config", "dependencies.json")))["deps"]
named = [k for k in deps if re.match(r"^(%s)([_-]|$)" % vendors, k, re.I)]
assert not named, "vendor-named capability row(s): %s" % named
sys.exit(0)
PY
  then ok "no_vendor_named_integration_id (no vendor- or company-named integration id anywhere)"
  else bad "no_vendor_named_integration_id" "a capability row in dependencies.json is named after a vendor"; fi
}

check_issue_tracker_is_elicited() {
  # The row must be ELICITED (inert until asked for), must carry both questions the wizard asks,
  # and must record a credential POINTER — never a token value.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, sys
root = sys.argv[1]
row = json.load(open(os.path.join(root, "config", "dependencies.json")))["deps"]["issue-tracker"]
assert row.get("elicited_by"), "issue-tracker is not elicited — it would be probed unasked"
el = row.get("elicit") or {}
for q in ("connect", "api_access"):
    assert isinstance(el.get(q), str) and el[q].strip().endswith("?"), \
        "elicit.%s must be the actual question the wizard asks" % q
rec = el.get("on_yes_records") or []
assert set(rec) == {"issue_tracker.base_url", "issue_tracker.project_key",
                    "issue_tracker.auth_pointer"}, "recorded keys must be exactly base URL, project key, auth pointer: %r" % rec
assert not [k for k in rec if "token" in k or "secret" in k or "password" in k], \
    "a credential VALUE key is recorded — only a pointer may be"
assert el.get("on_no"), "elicit.on_no must state plainly that declining leaves the integration absent"
tmpl = json.load(open(os.path.join(root, "config", "local.template.json")))["local"]
for k in rec + [row["elicited_by"]]:
    assert k in tmpl, "%s is not documented in local.template.json" % k
    assert tmpl[k] is None, "%s ships a value — a foreign default would render" % k
print("asked for, never preconfigured; records a pointer, not a token")
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "issue_tracker_is_elicited ($out)"
  else bad "issue_tracker_is_elicited" "$(printf '%s' "$out" | tail -1)"; fi
}

check_wizard_asks_for_the_integration() {
  # The manifest documents the questions; the setup surface must actually ASK them. A manifest
  # nobody reads is documentation, not a wizard.
  local init="$PKG_ROOT/skills/init/SKILL.md" missing=""
  [ -f "$init" ] || { bad "wizard_asks_for_the_integration" "no init skill"; return; }
  $GREP -qiE 'issue tracker' "$init"        || missing="$missing the-offer"
  $GREP -qiE 'stories and tickets' "$init"  || missing="$missing item-types(stories-and-tickets)"
  $GREP -qiE 'API access' "$init"           || missing="$missing api-access-question"
  $GREP -qiE 'read-only|read only' "$init"  || missing="$missing read-only-promise"
  $GREP -qE  'issue_tracker\.auth_pointer' "$init" || missing="$missing auth-pointer"
  $GREP -qiE 'never the token|never a token|POINTER, never' "$init" || missing="$missing never-the-token"
  if [ -z "$missing" ]; then ok "wizard_asks_for_the_integration (both questions + the pointer rule are in the setup surface)"
  else bad "wizard_asks_for_the_integration" "the setup surface never asks:$missing"; fi
}

check_decline_is_not_a_miss() {
  # The behavioural half, and the one that matters: with the integration un-elicited, a run that
  # selects its stack key must still exit 0 and must NOT name it as a miss.
  local out rc
  out=$(cd "$PKG_ROOT" && PM_SKIP_MCP_LIST=1 PM_SKIP_HOSTCHECK=1 PM_LOCAL_JSON=/nonexistent \
        bash scripts/preflight.sh pm-portfolio-v1 --stack backlog-sync 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "decline_is_not_a_miss" "preflight exited $rc for a declined integration: $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"
    return
  fi
  case "$out" in
    *"MISS issue-tracker"*|*"FIX  issue-tracker"*)
      bad "decline_is_not_a_miss" "a declined integration is reported as a MISS/FIX"; return ;;
  esac
  case "$out" in
    *"not connected"*) : ;;
    *) bad "decline_is_not_a_miss" "absence was silent — it must be stated, just not as a miss"; return ;;
  esac
  # ...and the opposite must still hold: switched ON with nothing behind it IS a real miss.
  out=$(cd "$PKG_ROOT" && PM_SKIP_MCP_LIST=1 PM_SKIP_HOSTCHECK=1 PM_LOCAL_JSON=/nonexistent \
        PM_LOCAL_ISSUE_TRACKER_ENABLED=true \
        bash scripts/preflight.sh pm-portfolio-v1 --stack backlog-sync 2>&1); rc=$?
  if [ "$rc" -eq 1 ] && [ -z "${out##*MISS issue-tracker*}" ]; then
    ok "decline_is_not_a_miss (absent = not a miss; switched on and unfilled = a real miss)"
  else
    bad "decline_is_not_a_miss" "an integration switched ON with no values did not miss (rc=$rc) — the gate would pass an empty integration"
  fi
}

check_no_vendor_named_integration_id
check_issue_tracker_is_elicited
check_wizard_asks_for_the_integration
check_decline_is_not_a_miss

# >>> ADDITIONAL CHECK BLOCKS APPEND BELOW THIS MARKER <<<
# Keep new blocks in the same shape: one `check_<name>()` function that calls exactly one of ok/bad,
# then its invocation on its own line, and its name and section pinned in tests/expected-checks.txt.
# Never let a check pass because it could not run.

# ── consent telemetry: the local-only usage log, off until it is turned on ────────────────────
banner "consent-telemetry"

# SHAPE NOTE: the bodies below sit at column 0 inside their functions on purpose. Each one embeds a
# python heredoc whose payload is indentation-sensitive, so re-indenting a body would edit the
# programs and not just the layout.
TEL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/pkg-tel.XXXXXX")"
TMP="$TEL_TMP"
r_out=""; r_rc=0
run() { r_out="$("$@" 2>&1)"; r_rc=$?; }
has() { case "$r_out" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
export PKG_PACKAGE_ROOT="${PKG_PACKAGE_ROOT:-$PKG_ROOT}"

PKG="${PKG_PACKAGE_ROOT:-}"
TEL_RAN=0
# WHICH TREE THE CONSENT CHECKS MEASURED, said out loud on every run. The variable above honours a
# caller-set value on purpose — the documented skip branch cannot fire otherwise — and that same
# courtesy is a seam: a caller who points it at another checkout gets five consent verdicts about
# THAT tree, printed in a summary indistinguishable, byte for byte, from a run over this one. A
# report is only about the tree it names, so the measured root is printed here and the parity is
# asserted in check_env_var_honors_caller. Re-aiming is still possible and still supported; it just
# has to be deliberate, and PKG_ALLOW_FOREIGN_ROOT=yes is how a caller says so.
PKG_AIM=own
[ "$PKG" = "$PKG_ROOT" ] || PKG_AIM=foreign

# ── consent default OFF — declared in the schema AND enforced by the writer ───────────────────
# Two halves, and the second is the one that matters: a default declared in a schema nobody reads
# at run time is a promise, and this check exists because the writer is what actually decides.
check_consent_default_off() {
run python3 - "$PKG" <<'PY'
import json, os, sys
pkg = sys.argv[1]
sch = json.load(open(os.path.join(pkg, "config.schema.json")))
tel = sch["properties"]["telemetry"]["properties"]
mode = tel["mode"]
assert mode["default"] == "off", "schema default must be off, got %r" % mode["default"]
assert sorted(mode["enum"]) == ["local", "off"], \
    "the enum must be exactly off|local — a transmitting mode may not be reachable by editing a " \
    "config value: %r" % mode["enum"]
ack = sch["properties"]["acknowledged"]["properties"]["telemetry_local"]
assert ack["default"] == "", "the consent record must default to empty, got %r" % ack["default"]
assert tel["dir"]["default"] == "", "telemetry.dir must default to empty (nothing recorded)"
# The runtime default table is the authority; the schema is its declarative twin. Assert they agree.
src = open(os.path.join(pkg, "scripts", "telemetry.sh")).read()
assert '_pkg_def_mode="off"' in src, "the writer's own default table must say off"
want = '_pkg_def_max_bytes="%d"' % tel["max_bytes"]["default"]
assert want in src, "writer default table disagrees with the schema on max_bytes (%s)" % want
print("schema off|local, consent empty, dir empty; writer table agrees")
PY
if [ "$r_rc" -eq 0 ]; then
  # ...and now the mechanism, on a scratch HOME: no config at all, then a bogus mode.
  CONS="$TMP/consent"; mkdir -p "$CONS/home"
  run env -i PATH="$PATH" HOME="$CONS/home" TMPDIR="$TMP" \
      bash "$PKG/scripts/telemetry.sh" emit probe result=ok
  cons_rc="$r_rc"; cons_out="$r_out"
  # WHAT "CREATED NOTHING" MEANS, AND WHY IT IS SCOPED TO THE PATHS THIS FEATURE OWNS.
  # The claim under test is the one the documents make: declining leaves no trace — no config, no
  # log directory, no log file. It is NOT "no byte appears anywhere under HOME", because the
  # INTERPRETER writes under a fresh HOME on its own account: the system python3 caches the stdlib
  # bytecode it imports into a cache under HOME, and the count varies by interpreter version
  # (annotated: the interpreter's own cache directory, named in the sweep below). Counting those
  # fails a writer that did exactly what it promised, which is
  # the same false-FAIL-against-a-working-component class the grade bar warns about. So: assert the
  # two owned paths are absent, THEN sweep the rest of the scratch HOME with the interpreter's own
  # cache dir excluded by name. Do not "simplify" this back into a bare find — the bare form is the
  # false FAIL.
  cons_cfg="$CONS/home/.config/product2prod/config.json"
  cons_state="$CONS/home/.local/state/product2prod"
  cons_owned="ok"
  [ -e "$cons_cfg" ] && cons_owned="config-created"
  [ -e "$cons_state" ] && cons_owned="${cons_owned}+log-dir-created"
  cons_files="$(find "$CONS/home" -type f \
                 -not -path "$CONS/home/Library/Caches/com.apple.python/*" 2>/dev/null \
               | wc -l | tr -d ' ')"
  # a value that is not exactly `local` must be read as off, never as the permissive setting
  mkdir -p "$CONS/home/.config/product2prod"
  printf '{"telemetry":{"mode":"share","dir":"%s/state"}}\n' "$CONS" \
    > "$CONS/home/.config/product2prod/config.json"
  env -i PATH="$PATH" HOME="$CONS/home" TMPDIR="$TMP" \
      bash "$PKG/scripts/telemetry.sh" emit probe2 >/dev/null 2>&1
  cons_bogus="$([ -e "$CONS/state" ] && echo wrote || echo silent)"
  if [ "$cons_rc" -eq 0 ] && [ -z "$cons_out" ] && [ "$cons_owned" = "ok" ] \
     && [ "$cons_files" -eq 0 ] && [ "$cons_bogus" = "silent" ]; then
    ok "consent_default_off (schema+writer agree; no config → rc 0, 0 bytes out, no config and no log dir created, 0 non-interpreter files under a scratch HOME; an unknown mode writes nothing)"
  else
    bad "consent_default_off" \
        "mechanism: rc=$cons_rc out='$cons_out' owned_paths=$cons_owned other_files=$cons_files unknown_mode=$cons_bogus"
  fi
else bad "consent_default_off" "declaration: $r_out"; fi
TEL_RAN=$((TEL_RAN + 1))
}

# ── no transmission path anywhere in the telemetry surface ────────────────────────────────────
# FOUR assertions, weakest to strongest, because a token list is the weakest form of this claim:
#   (1) transmission-capable CALL FORMS — the tokens below cannot appear innocently in a file whose
#       whole job is to append a line to a local file. `push` is scoped to a call form (`git … push`,
#       `push -`) on purpose: the writer's own comments say "no push, no upload", and a bare token
#       would fail a file for stating the negative. `subprocess` is on the list because that is how
#       a capability reaches the network, and the capability is the thing, not the spelling.
#   (2) URL LITERALS, with the ONE allowlisted declaration stripped by exact string first: a JSON
#       Schema meta-schema `$schema` value is an identity string, not a call. Allowlisted by the
#       exact string, never by "it looked like documentation".
#   (3) THE PYTHON IMPORT SURFACE, against an allowlist — the assertion that does not depend on
#       anyone having thought of the right spelling. A token grep passes a file that reaches the
#       network through a module nobody listed; an import allowlist cannot.
#   (4) THE PROSE SURFACE of the wizard and the schema: an English instruction telling an agent to
#       send the usage log somewhere is a transmission path with no call in it. Fails when a
#       transmission verb and the log object co-occur inside one paragraph, or when any destination
#       shape appears. Stating the NEGATIVE stays green, which is what makes this usable in a file
#       whose whole subject is that nothing is transmitted.
check_no_transmission_path() {
run bash -c '
set -u
pkg="$1"; g="$2"
# QUOTE SAFETY, and it is load-bearing: the file list is an ARRAY, expanded quoted at every use
# below. Accumulated as a space-joined string and iterated as `for p in $paths`, it word-splits on
# every space in the package path, so a tree mounted under a directory whose name contains a space
# becomes N phantom fragments instead of 3 real files. The search tool is then handed paths that do
# not exist, reads ZERO bytes, finds nothing, and this check prints a green line naming a count of
# files it never opened. A planted transmission call sails straight through it. Array in, quoted
# out, and the count is the array length rather than a word count.
paths=("$pkg/config.schema.json")
for p in "$pkg"/scripts/telemetry*; do [ -e "$p" ] && paths+=("$p"); done
if [ -d "$pkg/skills/init" ]; then
  while IFS= read -r -d "" p; do paths+=("$p"); done < <(find "$pkg/skills/init" -type f -print0)
fi
n=${#paths[@]}
[ "$n" -ge 3 ] || { echo "expected at least 3 telemetry paths, found $n: ${paths[*]}"; exit 1; }
# (0) READABILITY FIRST, and it used to be third. The readability guard sat inside the URL loop
# below, so an unreadable telemetry surface was met first by the search tool in phase 1: the run
# still failed, correctly, but it failed by leaking the tool stderr into the detail instead of
# naming the file nobody can read. The rule is that a tool failure must be NAMED. Asked first, the
# question is answered by name.
for p in "${paths[@]}"; do
  [ -r "$p" ] || { echo "unreadable telemetry surface: $p - an unreadable file is not a clean one"; exit 1; }
done
# (1) transmission-capable call forms. The search tool is the RESOLVED one, passed in, and its exit
# status is discriminated: 0 = hits, 1 = clean, anything else = the tool could not run, which is a
# FAILURE and never a clean verdict.
TOK="c""url|w""get|net""cat|\bnc[ \t]|te""lnet|f""tp|s""cp|rs""ync|ss""h |u""rllib|urlo""pen|re""quests\.|http""lib|http\.cl""ient|so""cket\.|web""socket|xml""http|f""etch\(|git .*pu""sh|pu""sh (-|origin)|sub""process"
hits="$("$g" -inE "$TOK" "${paths[@]}")"; rc=$?
[ "$rc" -le 1 ] || { echo "the search tool exited $rc over the telemetry surface — a tool failure is not a clean verdict"; exit 1; }
[ -z "$hits" ] || { echo "TRANSMISSION CALL FORM(S) FOUND:"; echo "$hits"; exit 1; }
# (2) URL literals, with the one allowlisted declaration stripped first
for p in "${paths[@]}"; do
  [ -r "$p" ] || { echo "unreadable telemetry surface: $p — an unreadable file is not a clean one"; exit 1; }
  u="$(sed "s|ht""tp://json-schema.org/draft-07/schema#||g" "$p" | "$g" -inE "ht""tps?://")"; rc=$?
  [ "$rc" -le 1 ] || { echo "the search tool exited $rc over $p"; exit 1; }
  [ -z "$u" ] || { echo "URL LITERAL in $p:"; echo "$u"; exit 1; }
done
# (3) the import surface of every python program embedded in the writer
for p in "$pkg"/scripts/telemetry*; do
  [ -e "$p" ] || continue
  python3 - "$p" <<"PY" || exit 1
import re, sys
ALLOWED = {"hashlib", "json", "os", "string", "sys", "time"}
mods = set()
for line in open(sys.argv[1]):
    if line.lstrip().startswith("#"):
        continue
    m = re.match(r"\s*(?:import|from)\s+([A-Za-z0-9_., ]+)", line)
    if m:
        mods |= {x.strip().split(".")[0] for x in m.group(1).split(",") if x.strip()}
extra = mods - ALLOWED
if extra:
    print("UNEXPECTED IMPORT(S) in %s: %s — every module here must be local-only"
          % (sys.argv[1], sorted(extra)))
    raise SystemExit(1)
PY
done
# (4) the prose surface: an instruction is a transmission path with no call in it
python3 - "${paths[@]}" <<"PY" || exit 1
import re, sys
VERB = re.compile(r"\b(send|sends|sending|mail|mails|mailing|upload|uploads|uploading|transmit|"
                  r"transmits|transmitting|post|posts|posting|share|shares|sharing|forward|"
                  r"forwards|forwarding|report|reports|reporting|submit|submits|submitting)\b", re.I)
OBJ  = re.compile(r"\b(usage[ _-]?log|telemetry(\s+\w+){0,2}\s+(log|file|line|record)s?|"
                  r"event\s+log|telemetry\.jsonl)\b", re.I)
DEST = re.compile(r"(https?://|\b[\w.+-]+@[\w-]+\.[A-Za-z]{2,}\b)", re.I)
ALLOWED_URL = "ht" "tp://json-schema.org/draft-07/schema#"
NEG  = re.compile(r"\b(no|not|never|nothing|nowhere|cannot|without|off|refus\w*)\b", re.I)
# THE NEGATION IS SCOPED TO THE SENTENCE, not to the paragraph, and that is the whole point.
# Scoped to the paragraph, ONE "never" anywhere in a block disarmed every other sentence in it,
# and the prose of this very file ends in a long bulleted block of "Never ..." rules, so an
# instruction appended after it was skipped without being read. Four planted instructions (a literal
# mail verb, the same in upper case, the underscored object, and the instruction split across two
# lines) all shipped green through that hole. A sentence that carries the verb AND the object now
# has to carry its own negation, which is exactly what the true negative reads like:
# "Nothing here transmits the usage log anywhere."
SENT = re.compile(r"(?<=[.!?])\s+")
problems = []
for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        problems.append("%s: unreadable" % path); continue
    # the ONE allowlisted declaration, stripped by exact string: a meta-schema id is not a call
    text = text.replace(ALLOWED_URL, "")
    for para in re.split(r"\n\s*\n", text):
        flat = " ".join(para.split())
        if not flat:
            continue
        if DEST.search(flat):
            problems.append("%s: a destination shape appears in prose: %.90s" % (path, flat))
            continue
        for sent in SENT.split(flat):
            if VERB.search(sent) and OBJ.search(sent) and not NEG.search(sent):
                problems.append("%s: a transmission verb and the usage log share a sentence with "
                                "no negation: %.90s" % (path, sent))
                break
if problems:
    print("PROSE TRANSMISSION PATH(S):")
    for p in problems[:3]:
        print("  " + p)
    raise SystemExit(1)
PY
echo "$n telemetry paths: 0 transmission call forms, 0 URL literals (meta-schema declaration allowlisted), import surface within the local-only allowlist, 0 prose transmission instructions"
' _ "$PKG" "$GREP"
if [ "$r_rc" -eq 0 ]; then ok "no_transmission_path ($r_out)"
else bad "no_transmission_path" "$r_out"; fi
TEL_RAN=$((TEL_RAN + 1))
}

# ── the removal path removes the log — and refuses when it should ─────────────────────────────
# End to end on a scratch HOME, in the order a user meets it: consent → a real line on disk →
# dry run changes nothing → the two refusals → the apply → both artifacts verified gone. The
# foreign key is planted on purpose: `purge` must leave another component's settings byte-intact,
# and `uninstall` must say out loud that it is taking them.
check_removal_path() {
run bash -c '
set -u
pkg="$1"; work="$2"
mkdir -p "$work/home"
export HOME="$work/home"
env_run() { env -i PATH="$PATH" HOME="$HOME" TMPDIR="$TMPDIR" bash "$pkg/scripts/telemetry.sh" "$@"; }
CFG="$HOME/.config/product2prod/config.json"
LOG="$HOME/.local/state/product2prod/telemetry.jsonl"

env_run consent local "yes — suite check" >/dev/null 2>&1 || { echo "consent failed"; exit 1; }
python3 - "$CFG" <<PY
import json,sys
p=sys.argv[1]; c=json.load(open(p)); c["other_component"]={"keep":"me"}
json.dump(c,open(p,"w"),indent=2,sort_keys=True)
PY
env_run emit suite_probe result=ok >/dev/null 2>&1
[ -s "$LOG" ] || { echo "no log line was written, so there is nothing to prove removal of"; exit 1; }

env_run uninstall >/dev/null 2>&1 || { echo "dry run should exit 0"; exit 1; }
[ -s "$LOG" ] && [ -f "$CFG" ] || { echo "the DRY RUN removed something"; exit 1; }

env_run uninstall --apply >/dev/null 2>&1 && { echo "--apply with no phrase must REFUSE"; exit 1; }
env_run uninstall --apply --confirm "not the phrase" >/dev/null 2>&1 \
  && { echo "--apply with the wrong phrase must REFUSE"; exit 1; }
[ -s "$LOG" ] && [ -f "$CFG" ] || { echo "a REFUSED run touched something"; exit 1; }

# purge first, to prove the narrow path: the log goes, a foreign key does NOT.
env_run purge --apply >/dev/null 2>&1 || { echo "purge --apply should exit 0"; exit 1; }
[ -e "$LOG" ] && { echo "purge left the log behind"; exit 1; }
python3 - "$CFG" <<PY
import json,sys
c=json.load(open(sys.argv[1]))
assert c["other_component"]["keep"]=="me", "purge ate another component key"
assert c["telemetry"]["mode"]=="off", "purge left the mode on"
assert c["telemetry"]["dir"]=="", "purge left the recorded dir behind"
assert c["acknowledged"]["telemetry_local"]=="", "purge left the consent record behind"
PY
[ -f "$CFG" ] || { echo "purge removed the config file — that is uninstall Job, not purge"; exit 1; }

# then the full removal
env_run consent local "yes again" >/dev/null 2>&1
env_run emit suite_probe2 result=ok >/dev/null 2>&1
[ -s "$LOG" ] || { echo "re-consent did not resume logging"; exit 1; }
out="$(env_run uninstall --apply --confirm "apply uninstall" 2>&1)" \
  || { echo "uninstall --apply failed: $out"; exit 1; }
[ -e "$LOG" ] && { echo "uninstall left the log behind"; exit 1; }
[ -e "$CFG" ] && { echo "uninstall left the config behind"; exit 1; }
case "$out" in *"verified gone: True"*) : ;; *) echo "no verified-gone receipt printed"; exit 1 ;; esac
echo "consent→line→dry-run→2 refusals→purge (log gone, foreign key kept)→uninstall (log+config gone, receipts quoted)"
' _ "$PKG" "$TMP/removal"
if [ "$r_rc" -eq 0 ]; then ok "removal_path ($r_out)"
else bad "removal_path" "$r_out"; fi
TEL_RAN=$((TEL_RAN + 1))
}

# ── publish-lint COVERS the three telemetry files, and they are CLEAN ─────────────────────────
# Three halves, and the middle one is the discriminating one:
#   (i)   the scanner fires at all — its own `--self-test` plants samples and requires hits. A
#         "clean" from a scanner that cannot fire is the silent-zero failure this whole gate exists
#         to rule out, and it is worth one call.
#   (ii)  the three telemetry files are CLEAN, scanned in ISOLATION: only those three, at their real
#         relative paths, in a scratch root. Isolation is deliberate — see the scope note below.
#   (iii) COVERAGE, which a clean run can never prove on its own, because a lint that never looks
#         at these paths passes it too: plant a banned literal in each of the three copies and
#         require the lint to fail AND to name all three. The canary is a path form assembled from
#         parts at run time (never a confidential literal living in a fixture).
#
# SCOPE NOTE — why (ii) scans three files and not the whole package. "publish-lint green over the
# whole package with zero hits" is the tree-wide scan's business, over a tree many hands write
# into. A telemetry check that asserted it would fail this block for somebody else's file, which
# tells the reader nothing true about consent telemetry. So the whole-package verdict is RUN and
# REPORTED on the result line — never hidden, never silently tolerated — and only the telemetry
# files are asserted. If the package verdict reads FAIL here, check_publish_lint_tree_clean above
# owns it, and it names its own files.
#
# The deny-list resolves from the SCRIPT's own package root, not from the scanned path
# (publish-lint.sh: `DENYLIST="$PKG_ROOT/config/denylist.txt"`), so scanning a scratch root still
# loads the package's real rules — which is what makes (ii) and (iii) meaningful.
check_publish_lint_covers_telemetry() {
if [ ! -r "$PKG/scripts/publish-lint.sh" ]; then
  bad "publish_lint_covers_telemetry" \
      "no readable $PKG/scripts/publish-lint.sh — it is the package's own gate and the telemetry files cannot be certified without it"
else
  run bash -c '
  set -u
  pkg="$1"; work="$2"; g="$3"
  L="$pkg/scripts/publish-lint.sh"
  TEL_FILES="config.schema.json scripts/telemetry.sh skills/init/SKILL.md"

  # (i) the scanner fires
  st="$(bash "$L" --self-test 2>&1)" \
    || { echo "publish-lint --self-test FAILED — the scanner cannot prove it fires: $st"; exit 1; }

  # (ii) the three telemetry files, in isolation, must be clean
  mkdir -p "$work/only"
  for f in $TEL_FILES; do
    [ -e "$pkg/$f" ] || { echo "expected $f in the package"; exit 1; }
    mkdir -p "$work/only/$(dirname "$f")"
    cp "$pkg/$f" "$work/only/$f" || { echo "could not copy $f into the scratch tree (permission?)"; exit 1; }
    chmod u+w "$work/only/$f" || { echo "the copy of $f is not writable (permission?)"; exit 1; }
  done
  out="$(bash "$L" "$work/only" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "publish-lint FAILS on the telemetry files themselves: $out"; exit 1; }

  # (iii) coverage: the same three, each carrying a planted banned literal
  mkdir -p "$work/canary"
  cp -R "$work/only/." "$work/canary" || { echo "could not copy the fixture set (permission?)"; exit 1; }
  chmod -R u+w "$work/canary" || { echo "the canary copy is not writable (permission?)"; exit 1; }
  for f in $TEL_FILES; do
    printf "\ncanary /User""s/EXAMPLE/canary\n" >> "$work/canary/$f" \
      || { echo "could not append the canary to $f (permission?)"; exit 1; }
  done
  out="$(bash "$L" "$work/canary" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || { echo "publish-lint stayed green with a banned literal in all three telemetry files — it does not scan them"; exit 1; }
  for f in config.schema.json telemetry.sh SKILL.md; do
    case "$out" in *"$f"*) : ;; *) echo "publish-lint failed but never named $f: $out"; exit 1 ;; esac
  done

  # the whole-package verdict: reported, not asserted (check_publish_lint_tree_clean owns it)
  pkgout="$(bash "$L" "$pkg" 2>&1)"; pkgrc=$?
  if [ "$pkgrc" -eq 0 ]; then pkgv="whole package: clean"
  else
    nhits="$(printf %s "$pkgout" | "$g" -c ": \[")"; hrc=$?
    [ "$hrc" -le 1 ] || { echo "the search tool exited $hrc counting the package verdict"; exit 1; }
    pkgv="whole package: FAIL ($nhits hit(s), none in the telemetry files — the tree-clean check owns it)"
  fi
  echo "scanner self-test fires; telemetry files clean in isolation; fails and names all three when a banned literal is planted; $pkgv"
  ' _ "$PKG" "$TMP/coverage" "$GREP"
  if [ "$r_rc" -eq 0 ]; then ok "publish_lint_covers_telemetry ($r_out)"
  else bad "publish_lint_covers_telemetry" "$r_out"; fi
fi
TEL_RAN=$((TEL_RAN + 1))
}

# ── class-only redaction: only class words reach the log ──────────────────────────────────────
# This is the check that makes the privacy claim TRUE rather than stated. README.md ("What it can
# never contain") and skills/init/SKILL.md both promise that content, titles and real paths cannot
# be recorded — enforced by the writer, not by the call sites. Six assertions, in the order a
# reader doubts them: a real path lands as `?` · an over-long value lands as `?` WHOLE (the bound
# rejects, it never truncates, so no shortened-but-real prefix can land) · a non-class event name
# lands as `?` · a grouping id lands as a 12-hex digest · the raw id is absent from the file · no
# `/` reached disk at all.
#
# HARNESS NOTE, and it is the whole reason this block sat commented out until it was fixed: `er()`
# runs the writer under `env -i`, which is deliberate (it is what proves the writer needs nothing
# from the ambient environment) but which also strips PKG_TELEMETRY_SESSION — the one variable the
# writer reads to build the digest. Setting it as a prefix on the `er` CALL cannot survive that, so
# the fourth assertion failed with `KeyError: 'session'` against a writer that was behaving
# correctly. It is forwarded through `env -i` by name instead. Empty is the same as absent to the
# writer (`raw = os.environ.get(...); if raw:`), so the first three emits are unaffected. Do not
# "simplify" the forward away — the failure it fixes looks like a real defect.
check_class_only_redaction() {
run bash -c '
set -u
pkg="$1"; work="$2"; mkdir -p "$work/home"; export HOME="$work/home"
er() { env -i PATH="$PATH" HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" \
       PKG_TELEMETRY_SESSION="${PKG_TELEMETRY_SESSION:-}" bash "$pkg/scripts/telemetry.sh" "$@"; }
er consent local "class-only check" >/dev/null 2>&1
LOG="$HOME/.local/state/product2prod/telemetry.jsonl"
er emit probe p="/User""s/somebody/secret.md" >/dev/null 2>&1
er emit probe v="$(python3 -c "print(\"a\"*70)")" >/dev/null 2>&1
er emit "event with spaces" >/dev/null 2>&1
PKG_TELEMETRY_SESSION="raw-id-do-not-store" er emit grouped >/dev/null 2>&1
python3 - "$LOG" <<PY
import json,sys
rows=[json.loads(l) for l in open(sys.argv[1])]
assert rows[0]["p"]=="?", "a real path must be stored as ?"
assert rows[1]["v"]=="?", "an over-long value must be REJECTED whole, never truncated"
assert rows[2]["event"]=="?", "a non-class event name must be stored as ?"
assert len(rows[3]["session"])==12, "the grouping id must be a 12-char digest"
assert "raw-id-do-not-store" not in open(sys.argv[1]).read(), "the raw id reached disk"
assert "/" not in open(sys.argv[1]).read(), "a slash reached disk"
print("path→? · over-long→? whole · bad event name→? · id→12-char digest · no slash on disk")
PY
' _ "$PKG" "$TMP/redaction"
if [ "$r_rc" -eq 0 ]; then ok "class_only_redaction ($r_out)"
else bad "class_only_redaction" "$r_out"; fi
TEL_RAN=$((TEL_RAN + 1))
}

# ── the unreadable-log-directory case, documented and measured ────────────────────────────────
# What `status` and `purge` do when the recorded log directory cannot be read is a real state a
# user reaches, and the documents have to describe it as it is rather than as it ought to be. The
# fixture builds the state, measures what the tool prints, and requires the documented sentence to
# match the measurement — a document edited away from the tool fails here, and so does a tool that
# starts printing something the document never mentioned.
#
# WHICH DOCUMENT IS BEING HELD TO THE MEASUREMENT is named in every sentence this check prints. The
# subject is chosen at run time — docs/the-usage-log.md if it is there, README.md otherwise —
# and the failure message used to name the fallback whichever subject was actually read, so a
# reader was sent to a file the check had not opened. A retarget that nobody announces is the same
# defect one step earlier, so the fallback says so out loud when it fires.
check_unreadable() {
  local work home cfg logdir st_out pu_out pu_rc doc="$PKG_ROOT/docs/the-usage-log.md" doc_note=""
  if [ ! -f "$doc" ]; then
    doc="$PKG_ROOT/README.md"
    doc_note=" (docs/the-usage-log.md is absent, so this check fell back to README.md)"
    printf '  ..    unreadable: docs/the-usage-log.md is absent; the documented-behaviour subject is README.md\n'
  fi
  work="$TMP/unreadable"; home="$work/home"; mkdir -p "$home"
  env -i PATH="$PATH" HOME="$home" TMPDIR="$TMP" \
      bash "$PKG_ROOT/scripts/telemetry.sh" consent local "unreadable-case check" >/dev/null 2>&1
  env -i PATH="$PATH" HOME="$home" TMPDIR="$TMP" \
      bash "$PKG_ROOT/scripts/telemetry.sh" emit probe result=ok >/dev/null 2>&1
  cfg="$home/.config/product2prod/config.json"
  logdir="$home/.local/state/product2prod"
  if [ ! -s "$logdir/telemetry.jsonl" ]; then
    bad "unreadable" "the fixture could not produce a log line, so the unreadable case was never reached"
    return
  fi
  chmod 000 "$logdir" 2>/dev/null || { bad "unreadable" "could not make the log directory unreadable on this host"; return; }
  st_out=$(env -i PATH="$PATH" HOME="$home" TMPDIR="$TMP" bash "$PKG_ROOT/scripts/telemetry.sh" status 2>&1)
  pu_out=$(env -i PATH="$PATH" HOME="$home" TMPDIR="$TMP" bash "$PKG_ROOT/scripts/telemetry.sh" purge --apply 2>&1); pu_rc=$?
  chmod 700 "$logdir" 2>/dev/null
  if ! $GREP -qi 'unreadable' "$doc"; then
    bad "unreadable" "the tool has an unreadable-log-directory behaviour (status printed $(printf '%s' "$st_out" | wc -l | tr -d ' ') line(s), purge exited $pu_rc) and ${doc#"$PKG_ROOT"/} documents no such case$doc_note"
    return
  fi
  local mismatch=""
  case "$st_out" in *absent*) $GREP -qi 'absent' "$doc" || mismatch="$mismatch status-absent-undocumented" ;; esac
  case "$pu_out" in *"not empty"*) $GREP -qiF 'not empty' "$doc" || mismatch="$mismatch purge-not-empty-undocumented" ;; esac
  if [ "$pu_rc" -eq 0 ]; then
    $GREP -qiE 'purge (still )?(exits|reports|says|prints)' "$doc" || mismatch="$mismatch purge-exit-0-undocumented"
  fi
  if [ -z "$mismatch" ]; then
    ok "unreadable (the unreadable-log-directory case is documented in ${doc#"$PKG_ROOT"/}, and what status and purge actually print matches the documented sentence)"
  else
    bad "unreadable" "the behaviour ${doc#"$PKG_ROOT"/} documents for an unreadable directory does not match the measured one:$mismatch"
  fi
}

if [ -z "$PKG" ] || [ ! -d "$PKG" ]; then
  skip "consent_default_off" "PKG_PACKAGE_ROOT names no directory, so the five consent checks did not run. A skip ends this run non-zero"
else
  check_consent_default_off
  check_no_transmission_path
  check_removal_path
  check_publish_lint_covers_telemetry
  check_class_only_redaction
  check_unreadable
  printf '  ..    consent-telemetry checks run: %s of 5, plus the unreadable-directory case; measured over the %s tree at %s\n' \
    "$TEL_RAN" "$PKG_AIM" "$PKG"
fi

rm -rf "$TEL_TMP"
TMP="$TMP_ROOT"   # the telemetry block re-pointed $TMP at its own scratch; hand the suite its own back

# --- references: every string that names a file must find one ---
banner "references"

# The mechanised form of a defect class this package shipped three times before a reader caught it:
# in each case a document named a file the tree did not contain, and nothing in the suite checked
# that the file existed. The engine below walks the document surface once and answers three
# separate questions, each with its own check and its own floor:
#
#   (a) every RELATIVE markdown link target resolves — the file exists, and a `#anchor` resolves
#       against the GitHub-style heading slugs of the file it points into. Absolute URLs are not
#       this check's business: it proves internal consistency, and it does it offline.
#   (b) every BACKTICKED in-package path exists on disk, resolved relative to the citing file
#       first and then to the package root — the prefixes are DERIVED from the tree's own top-level
#       entries rather than listed, because a hardcoded prefix list is how a renamed reference file
#       stayed green under a fully passing suite.
#   (c) a backticked bare filename that names nothing anywhere is a dangling reference too, and the
#       manifest may not be cited as a root-level name once it lives in a directory. A prefix list
#       cannot express either rule, which is why the safety net the manifest move relies on did not
#       previously exist.
#
# Each half prints its own size, because a reference check over a tree with no references is not a
# passing check, it is an empty one, and each half carries the floor that makes an empty scan a
# FAIL instead of a silent green.
REFSCAN="$TMP_ROOT/refscan.py"
cat > "$REFSCAN" <<'REFSCAN_PY'
import os, re, sys

# refscan — one walk, three verdicts. The three reference assertions are one engine on purpose:
# they read the same documents, and three copies of a markdown walker is three places for the
# prefix list to drift.
#
#   paths   every backticked in-package path resolves, relative to its own file first and then to
#           the package root — exactly what the link half already does
#   links   every relative markdown link and in-document anchor resolves, against a pinned floor
#   root    the two rules a prefix list cannot express: a backticked bare filename that names no
#           file anywhere must not be presented as one, and the manifest may not be cited as a
#           root-level name once it lives in a directory
#
# PREFIXES ARE DERIVED, never listed: the package's own top-level directories are the prefix set,
# so a new directory is covered the day it appears and a deleted one stops being claimed. The
# hardcoded five-prefix list this replaces omitted two real directories and named one that did not
# exist, which is how a renamed reference file stayed green under a fully passing suite.
#
# EXCLUDED BY NAME, never by shape. Excluding a token because it "looks like a pattern" silently
# re-opens the class, so every entry below names one token and says what it is.

root, mode = sys.argv[1], sys.argv[2]
floor = int(sys.argv[3]) if len(sys.argv) > 3 else 0

# path-shaped tokens that are not paths into this tree
EXCLUDE_PATHISH = {
    "/",                        # a bare separator, quoted as a character
    "/pm-requirements-v1",      # a verb invocation, not a directory
    "/pm-gtm-v1",               # a verb invocation
    "/pm-portfolio-v1",         # a verb invocation
    "/pm-verify-release-v1",    # a verb invocation
    "/pm-start",                # a verb invocation
    "contracts/",               # a directory the RUN emits, inside its own output package
    "deck-brief/",              # another directory the RUN emits into its output package
    "and/or",                   # ordinary prose
    "solo/domains/squads",      # the org-shape enum, written as alternatives
    "off/local",                # the telemetry mode enum
    "yes/no",                   # a question's answer set
    "read/write",               # a permission pair
    "n/a",                      # ordinary prose
    "input/output",             # ordinary prose
    "pass/fail",                # a verdict pair
    "go/no-go",                 # a decision pair
}
# bare filenames the RUN emits into its own output package; they are named on purpose and are not
# artifacts of this tree
EXCLUDE_EMITTED = {
    "spec.md", "plan.md", "data-model.md", "slices.json", "case-contract.md",
    "design-gate.json", "gate-state-snapshot.md", "inference-confirmed.json",
    "p1_research_base.md", "p2_strategy_rationale.md", "p3_product_spec.md",
    "local.json", "config.json", "telemetry.jsonl",
    "handoff.md", "feedback-pack.md", "retro.md",
}
ALLOWED_ABSENT = {
    "config/local.json",  # created at init, gitignored by rule; gitignore_covers_local_config proves it
}

FENCE = re.compile(r"^\s*(```|~~~)")
LINK = re.compile(r"!?\[[^\]\n]*\]\(([^)\s]+)\)")
TICK = re.compile(r"`([^`\n]+)`")
HEAD = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
NAMED = re.compile(r"^[A-Za-z0-9_.-]+\.(md|json|txt|sh|yml|yaml)$")
GLOBBY = set("*?{}<>$|")


def slug(text):
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text.replace("`", ""))
    t = re.sub(r"[^\w\s-]", "", t.strip().lower(), flags=re.UNICODE)
    return re.sub(r"\s+", "-", t)


def prose(path):
    out, inside = [], False
    for line in open(path, encoding="utf-8", errors="replace").read().splitlines():
        if FENCE.match(line):
            inside = not inside
            out.append("")
        else:
            out.append("" if inside else line)
    return out


everything, basenames = [], {}
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
    for f in filenames:
        p = os.path.relpath(os.path.join(dirpath, f), root)
        everything.append(p)
        basenames.setdefault(f, []).append(p)
mds = sorted(os.path.join(root, p) for p in everything if p.endswith(".md"))
ROOTFILES = set(p for p in everything if "/" not in p)
MANIFEST = basenames.get("plugin.json", [])

anchors = {}
for m in mds:
    seen, slugs = {}, set()
    for line in prose(m):
        h = HEAD.match(line)
        if h:
            s = slug(h.group(2))
            n = seen.get(s, 0)
            seen[s] = n + 1
            slugs.add(s if n == 0 else "%s-%d" % (s, n))
    anchors[os.path.realpath(m)] = slugs


def resolves(token, from_file):
    """Relative to the citing file first, then the package root — what the link half already does."""
    here = os.path.normpath(os.path.join(os.path.dirname(from_file), token))
    return os.path.exists(here) or os.path.exists(os.path.join(root, token))


dangling, rootbad, linkbad = [], [], []
links, paths, rootrefs, skipped = 0, 0, 0, 0
for m in mds:
    rel = os.path.relpath(m, root)
    for lineno, line in enumerate(prose(m), 1):
        for target in LINK.findall(line):
            if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target) or target.startswith("//"):
                continue
            if set(target) & GLOBBY:
                linkbad.append("%s:%d  a link target carrying a glob names a pattern, not a page: %s"
                               % (rel, lineno, target))
                continue
            links += 1
            filepart, _, anchor = target.partition("#")
            if filepart:
                tgt = os.path.normpath(os.path.join(os.path.dirname(m), filepart))
                if not os.path.exists(tgt):
                    linkbad.append("%s:%d  link target does not exist: %s" % (rel, lineno, target))
                    continue
            else:
                tgt = m
            if anchor:
                key = os.path.realpath(tgt)
                if key not in anchors:
                    continue
                if anchor.lower() not in anchors[key]:
                    linkbad.append("%s:%d  no heading in %s makes the anchor #%s"
                                   % (rel, lineno, filepart or os.path.basename(m), anchor))
        for span in TICK.findall(line):
            words = span.strip().split()
            if not words:
                continue
            token = words[0].rstrip(".,;:!)]\"'")
            if not token or set(token) & GLOBBY:
                continue
            if "/" in token:
                if token in EXCLUDE_PATHISH or token.lower() in EXCLUDE_PATHISH:
                    skipped += 1
                    continue
                paths += 1
                if token in ALLOWED_ABSENT or resolves(token, m):
                    continue
                dangling.append("%s:%d  reference does not resolve: %s" % (rel, lineno, token))
                continue
            if not NAMED.match(token):
                continue
            if token.lower() in EXCLUDE_EMITTED:
                skipped += 1
                continue
            if token in ROOTFILES:
                rootrefs += 1
                continue
            if MANIFEST and token == "plugin.json" and "plugin.json" not in ROOTFILES:
                rootrefs += 1
                rootbad.append("%s:%d  the manifest is cited as a root-level name and it lives at %s"
                               % (rel, lineno, MANIFEST[0]))
                continue
            if token in basenames:
                continue          # a bare basename in prose, not a path reference
            rootrefs += 1
            rootbad.append("%s:%d  names a file that exists nowhere in the tree: %s" % (rel, lineno, token))

if mode == "report":
    for d in dangling + rootbad + linkbad:
        print(d)
    print("mds=%d links=%d paths=%d rootrefs=%d excluded=%d" % (len(mds), links, paths, rootrefs, skipped))
    raise SystemExit(0)

if mode == "paths":
    if dangling:
        print("DANGLING REFERENCE(S), %d:" % len(dangling))
        for d in dangling[:6]:
            print("  " + d)
        raise SystemExit(1)
    if paths < 1:
        print("scanned %d .md file(s) and found NO in-package path reference at all — a reference "
              "check with nothing to check is not a pass" % len(mds))
        raise SystemExit(1)
    print("%d .md files · %d backticked in-package path(s) resolve, relative-first then root · "
          "%d non-path token(s) excluded by name" % (len(mds), paths, skipped))
    raise SystemExit(0)

if mode == "links":
    if linkbad:
        print("DANGLING LINK(S), %d:" % len(linkbad))
        for d in linkbad[:6]:
            print("  " + d)
        raise SystemExit(1)
    if links < floor:
        print("the link half found %d relative link(s) against a pinned floor of %d — an engine "
              "with no inputs is not a passing engine, it is a rotting one" % (links, floor))
        raise SystemExit(1)
    # The other direction, and the one a floor alone can never see. A pin that only ever answers
    # "fewer than" goes stale the moment documents land: the count climbs, nobody moves the number,
    # and the guard stops covering every link added since — while a pin of zero cannot fire at all,
    # because no count is fewer than none. So more than the pin is a failure too, and it names the
    # drift rather than absorbing it.
    if links > floor:
        print("the link half found %d relative link(s) against a pin of %d, so the pin is stale "
              "and %d of them are unguarded — move links in tests/expected-checks.txt in the same "
              "diff as the change that added them" % (links, floor, links - floor))
        raise SystemExit(1)
    print("%d relative link(s) and in-document anchor(s), pinned at %d in both directions, every "
          "one resolves" % (links, floor))
    raise SystemExit(0)

if mode == "root":
    if rootbad:
        print("UNRESOLVED ROOT-LEVEL OR MANIFEST REFERENCE(S), %d:" % len(rootbad))
        for d in rootbad[:6]:
            print("  " + d)
        raise SystemExit(1)
    if rootrefs < 1:
        print("no backticked root-level filename is cited anywhere — the rule that covers the "
              "manifest move has nothing to prove itself on")
        raise SystemExit(1)
    print("%d root-level reference(s), every one resolves; the manifest is cited at the path it "
          "actually occupies" % rootrefs)
    raise SystemExit(0)

print("unknown mode: %s" % mode)
raise SystemExit(2)
REFSCAN_PY

check_references_resolve() {
  # AN EXCLUSION IS DECLARED, NEVER ACCUMULATED. The scanner's own law is that every excluded token
  # is named in a list with the reason it is there ("EXCLUDED BY NAME, never by shape"), and a list
  # is reviewable. A token added to an exclusion collection at RUN TIME is not: it never appears in
  # a diff of the list, it carries no reason, and it silently shrinks the census this check
  # reports. So an append to any exclusion collection is a failure of this check, comment or no
  # comment - the declaration form is the only form.
  local out rc accum
  accum=$($GREP -nE '(^|[^A-Za-z_])EXCLUDE[A-Za-z_]*[[:space:]]*(\+=|\.add\(|\.append\(|\.update\()' \
            "$HERE/run-tests.sh" | head -3 | tr '\n' ' ')
  if [ -n "$accum" ]; then
    bad "references_resolve" "an exclusion is added at run time instead of being declared in a named list with its reason: $accum"
    return
  fi
  out=$(python3 "$REFSCAN" "$PKG_ROOT" paths 2>&1); rc=$?
  if [ $rc -eq 0 ]; then ok "references_resolve ($out; every exclusion declared in a named list)"
  else bad "references_resolve" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
}

check_references_link_floor() {
  local out rc floor
  floor="$(expect_val links)"
  if [ -z "$floor" ]; then
    bad "references_link_floor" "tests/expected-checks.txt pins no link expectation — the link and anchor engine would have zero inputs and no tripwire, which is how a whole engine rots silently"
    return
  fi
  out=$(python3 "$REFSCAN" "$PKG_ROOT" links "$floor" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then ok "references_link_floor ($out)"
  else bad "references_link_floor" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
}

check_root_and_manifest_refs() {
  local out rc
  out=$(python3 "$REFSCAN" "$PKG_ROOT" root 2>&1); rc=$?
  if [ $rc -eq 0 ]; then ok "dangling_check_covers_root_and_manifest ($out)"
  else bad "dangling_check_covers_root_and_manifest" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
}

SCRIPTPROSE="$TMP_ROOT/scriptprose.py"
cat > "$SCRIPTPROSE" <<'SCRIPTPROSE_PY'
import os, re, sys

# scriptprose — the census the document-only reference check cannot do.
#
# Prose inside a SCRIPT names files too: a comment citing a receipts file, a printed line naming a
# document, an embedded string carrying a path. The reference check walks .md files and stops there,
# so two live dangling citations sat inside the very comment block that defines the dangling-
# reference defect class. Three assertions:
#
#   (a) every path-shaped token in a comment or a printed string resolves in this tree, unless the
#       line carries the annotation that says it deliberately points outside it;
#   (b) a comment that cites `<file> <TOKEN>` must find that TOKEN in the file it names — a dead
#       section anchor resolves its file and nothing else;
#   (c) every test hook a COMMENT documents is read, and every hook-shaped name a script reads is
#       documented in a comment in that script.
#
# ANNOTATED EXCEPTIONS, by line and with a stated reason, never by shape: a line carrying
# `(annotated: <why>)` declares that its path is deliberately not a file in this tree. One
# unannotated exception is allowed by name — config/local.json, which the user writes at init and
# .gitignore excludes by rule.

root = sys.argv[1]
# BOTH PUNCTUATIONS of the annotation, because the convention is read by people. The declaration
# used to be recognised only as "(annotated:", so a line written "(annotated): reason" - the same
# sentence, one character moved - was not an annotation at all and its deliberately-out-of-tree
# path was reported as a dangle.
ANNOT = ("(annotated:", "(annotated)")
ALLOWED_ABSENT = {"config/local.json"}   # created at init, gitignored by rule

SYSTEM = re.compile(r"^/(usr|bin|sbin|dev|tmp|etc|opt|var|proc|Library)(/|$)")
URLISH = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")
PATHY = re.compile(r"(?<![\w./-])((?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+)")
FILEY = re.compile(r"\.(md|json|txt|sh|py|jsonl|yml|yaml|cfg|toml)$")
# THE ANCHOR TOKEN IN EITHER CASE. Upper case alone missed a dead anchor typed in lower case with
# underscores, which is the same dead citation written the way half the tree writes section
# labels. A lower-case anchor has to carry an underscore or a hyphen to qualify, or every ordinary
# word following a filename in prose would be looked up as a section label and reported absent.
CITE = re.compile(r"([A-Za-z0-9_.-]+\.(?:md|json|txt|sh))\s+(?:#\s*)?"
                  r"([A-Z][A-Z0-9_-]{4,}|[a-z][a-z0-9]*(?:[_-][a-z0-9]+)+)")
HOOKISH = re.compile(r"\b([A-Z][A-Z0-9_]*(?:FAKE|STUB|MOCK|HOOK)[A-Z0-9_]*)\b")
ENVREAD = re.compile(r"\$\{?([A-Z][A-Z0-9_]{3,})|environ(?:\.get)?[(\[]\s*\"([A-Z][A-Z0-9_]{3,})\"")
GLOBBY = set("*?{}$|<>()[]\\")

files = []
for sub in ("scripts", "tests"):
    d = os.path.join(root, sub)
    if not os.path.isdir(d):
        continue
    for f in sorted(os.listdir(d)):
        if f.endswith(".sh"):
            files.append(os.path.join(d, f))

problems, tokens, cites, hooks = [], 0, 0, 0

for path in files:
    rel = os.path.relpath(path, root)
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    prose_by_line = {}
    for n, line in enumerate(lines, 1):
        if any(a in line for a in ANNOT):
            continue
        # (a) the prose surfaces: comments, and the text inside printed strings
        prose = ""
        h = line.find("#")
        if h >= 0 and line[:h].count('"') % 2 == 0 and line[:h].count("'") % 2 == 0:
            prose = line[h:]
        for m in re.finditer(r"(printf|echo|die|note)\s+(.+)$", line):
            prose += " " + m.group(2)
        if not prose:
            continue
        prose_by_line[n] = prose
        for m in PATHY.finditer(prose):
            token = m.group(1).rstrip(".,;:!)\"'")
            if SYSTEM.match("/" + token) or URLISH.match(token) or set(token) & GLOBBY:
                continue
            if token.startswith(("http", "n/a")) or "%s" in token or "@" in token:
                continue
            # composed from a shell variable at run time: "$probe/planted.txt" names a scratch
            # file this script creates while it runs, not a path the package ships.
            if m.start(1) > 0 and prose[m.start(1) - 1] in "$" + chr(123):
                continue
            # a path rooted ABOVE the tree is out of tree by construction, and the head test below
            # would wave it through anyway because a parent directory always exists.
            if token == ".." or token.startswith("../"):
                continue
            head = token.split("/")[0]
            if head in ("s", "g", "e", "y", "p", "i", "sed", "tr", "cut", "usr", "bin", "dev", "tmp", "var", "etc"):
                continue
            # ADMITTED TWO WAYS, because one way was a hiding place. A token under a directory this
            # tree has is a claim about this tree - that was the only admission, and it meant a
            # citation of a receipts note under a build directory, or of a rationale note under a
            # docs directory, was never censused at all, purely because no such top-level
            # directory exists to make the citation look relevant. Those are precisely the dangles
            # this row was written for. So a token whose last segment carries
            # a document or code extension is a claim about this tree too, wherever it is rooted.
            # Slash-joined word lists in prose ("install/enable", "and/or") have no extension and
            # still fall out, which is the whole reason the head test was there.
            if not os.path.exists(os.path.join(root, head)) and not FILEY.search(token):
                continue                      # not a claim about this tree at all
            tokens += 1
            if token in ALLOWED_ABSENT or os.path.exists(os.path.join(root, token)):
                continue
            problems.append("%s:%d  prose names a path this tree does not carry: %s" % (rel, n, token))
        # (b) a cited section token must exist in the file it is cited from
        for m in CITE.finditer(prose):
            named, tok = m.group(1), m.group(2)
            cand = None
            for base in (os.path.dirname(path), root):
                p = os.path.normpath(os.path.join(base, named))
                if os.path.exists(p):
                    cand = p
                    break
            if cand is None:
                continue
            cites += 1
            body = open(cand, encoding="utf-8", errors="replace").read()
            if tok in body:
                continue
            loose = tok.replace("-", "").replace("_", "").lower()
            if loose and loose in re.sub(r"[-_\s]", "", body).lower():
                continue
            problems.append("%s:%d  cites %s %s and that file carries no such token"
                            % (rel, n, named, tok))

    # (b2) THE SAME CITATION, WRAPPED. A comment that runs past the column limit puts the file
    # name at the end of one line and the section token at the start of the next, and a per-line
    # scan sees a filename with nothing after it and a bare token with nothing before it. Adjacent
    # prose lines are joined pairwise and re-scanned, so a line wrap is not a hiding place.
    for n in sorted(prose_by_line):
        if n + 1 not in prose_by_line:
            continue
        joined = prose_by_line[n].rstrip() + " " + prose_by_line[n + 1].lstrip().lstrip("#").strip()
        for m in CITE.finditer(joined):
            named, tok = m.group(1), m.group(2)
            if CITE.search(prose_by_line[n]) or CITE.search(prose_by_line[n + 1]):
                continue                      # already scored on its own line
            cand = None
            for base in (os.path.dirname(path), root):
                p2 = os.path.normpath(os.path.join(base, named))
                if os.path.exists(p2):
                    cand = p2
                    break
            if cand is None:
                continue
            cites += 1
            body = open(cand, encoding="utf-8", errors="replace").read()
            if tok in body:
                continue
            loose = tok.replace("-", "").replace("_", "").lower()
            if loose and loose in re.sub(r"[-_\s]", "", body).lower():
                continue
            problems.append("%s:%d  cites %s %s across a line wrap and that file carries no such "
                            "token" % (rel, n, named, tok))

    # (c) hooks: documented but never read, or read and never documented
    #
    # DOCUMENTED MEANS "IN A COMMENT", not "in the header block. The read half already scanned the
    # whole file, so the two halves disagreed about what a script says: a hook named in a comment
    # ten lines below the header was invisible to the documented half and a dead hook there shipped
    # green, while the same name read anywhere fired the undocumented half. A hook a comment names
    # and no code reads is dead wherever the comment sits.
    body_text = "\n".join(lines)
    comment_text = "\n".join(l for l in lines if l.lstrip().startswith("#"))
    documented = set(HOOKISH.findall(comment_text))
    read = set()
    for m in ENVREAD.finditer(body_text):
        read.add(m.group(1) or m.group(2))
    read_hooks = set(x for x in read if HOOKISH.match(x))
    for name in sorted(documented):
        hooks += 1
        if name in read_hooks:
            continue
        prefix = re.match(r"^([A-Z0-9]+_(?:FAKE|STUB|MOCK|HOOK)_)", name)
        if prefix and ('"%s"' % prefix.group(1)) in body_text:
            continue                          # composed from its documented family prefix
        # the last escape: the name occurs somewhere that is NOT a comment, so some code form the
        # env-read pattern does not model is reading it. Measured against the comments, not the
        # header, or a hook documented mid-file would excuse itself with its own comment.
        if body_text.count(name) > comment_text.count(name):
            continue
        problems.append("%s  documents the hook %s and nothing in the file reads it" % (rel, name))
    for name in sorted(read_hooks - documented):
        problems.append("%s  reads the hook %s and the header documents no such hook" % (rel, name))

if problems:
    print("SCRIPT-PROSE REFERENCE PROBLEM(S), %d:" % len(problems))
    for p in problems[:6]:
        print("  " + p)
    raise SystemExit(1)
if tokens < 1:
    print("no path-shaped token was found in any script's prose — a census with nothing to census "
          "is not a pass")
    raise SystemExit(1)
# THE OTHER TWO HALVES WERE ASSERTED OVER NOTHING. Only the path count carried a floor, so the
# same "every one resolving" sentence covered a hook census and a citation census that could both
# be empty — the exact shape this function refuses one line above. The hook half has a floor now.
# The citation half genuinely reads zero on the surface this engine walks, and a floor there would
# be a fix that creates a defect; what it gets instead is a proof that the matcher can still fire,
# constructed here rather than found in the tree, so the zero is a measurement and not a matcher
# that quietly stopped matching.
if hooks < 1:
    print("no documented hook was found in any script's prose — the hook half of this census would "
          "be asserting 'every one resolving' over an empty list")
    raise SystemExit(1)
if not CITE.search("packs/README.md SOME_SECTION"):
    print("the section-citation matcher no longer recognises a citation at all, so the citation "
          "count below describes a matcher that cannot fire rather than a clean surface")
    raise SystemExit(1)
print("%d script file(s) · %d in-tree path(s) in prose · %d section citation(s) on the walked "
      "surface, its matcher proven live on a constructed one · %d documented hook(s), every one "
      "resolving" % (len(files), tokens, cites, hooks))
SCRIPTPROSE_PY

check_script_prose_refs() {
  local out rc
  out=$(python3 "$SCRIPTPROSE" "$PKG_ROOT" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then ok "no_dangling_references_in_script_prose ($out)"
  else bad "no_dangling_references_in_script_prose" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
}

check_exit_codes() {
  # A stated exit-code contract is a claim about every script in the tree. Harvest the codes the
  # scripts can actually take, harvest the codes each surface enumerates, and require the two sets
  # to be equal — including the surfaces that write the claim in words instead of digits.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import os, re, sys
root = sys.argv[1]
TICK = chr(96)          # no literal backtick may appear in a program embedded in $( ): bash 3.2
codes = set()
for f in sorted(os.listdir(os.path.join(root, "scripts"))):
    if not f.endswith(".sh"):
        continue
    body = open(os.path.join(root, "scripts", f), encoding="utf-8", errors="replace").read()
    for m in re.finditer(r"(?<![\w$-])exit\s+(\d+)", body):
        codes.add(int(m.group(1)))
    for m in re.finditer(r"raise SystemExit\((\d+)\)", body):
        codes.add(int(m.group(1)))
codes.discard(0)
WORDS = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6}
CLAIM = re.compile(r"exit (codes?|statuses)[^.\n]{0,80}", re.I)
COUNT = re.compile(r"\b(exactly )?(three|four|five|two)\b\s+(exit\s+)?(codes?|statuses)", re.I)
problems, surfaces = [], 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
    for f in filenames:
        if not (f.endswith(".md") or f.endswith(".sh")):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        if rel.startswith("tests/"):
            continue          # the suite states ITS OWN exit codes, not the scripts' contract
        raw = open(p, encoding="utf-8", errors="replace").read().splitlines()
        for i, first in enumerate(raw):
            # A CONTRACT SENTENCE DOES NOT HAVE TO SAY THE NOUN. "Scripts here exit 0, 1, 2, 3 or
            # 9" states the contract for every script in the tree and never writes the words
            # "exit code", so keying the surface test to the noun alone let a wrong enumeration
            # ship as prose nobody was measuring. The contract CUE below is unchanged and still
            # required, so a line has to be claiming something about every script before either
            # form admits it.
            if not (re.search(r"\bexit\s+(code|status)", first, re.I)
                    or re.search(r"\bexit\s+[0-9]", first, re.I)):
                continue
            if not re.search(r"(contract|for every script|every script here|scripts here)", first, re.I):
                continue
            # A contract sentence wraps. Read forward to the end of its paragraph, or the claim is
            # measured against a third of itself.
            n = i + 1
            chunk = [first]
            for nxt in raw[i + 1:i + 6]:
                if not nxt.strip() or re.match(r"^\s*[-*]\s|^#", nxt):
                    break
                chunk.append(nxt)
            line = " ".join(chunk)
            surfaces += 1
            stated = set(int(x) for x in re.findall(TICK + r"?(\d)" + TICK + "?", line))
            stated.discard(0)
            wm = COUNT.search(line)
            if wm:
                # A COUNT CLAIM IS COUNTED THE WAY A READER COUNTS IT, so zero is in. The
                # enumeration test above drops 0 on both sides deliberately - a surface may or may
                # not spell the clean code out, and comparing sets that disagree about it proves
                # nothing. A claim of the FORM "N exit codes" is different: the contract sentence
                # this tree ships enumerates 0, 1, 2 and 4, so a document restating it as three is
                # wrong, and dropping 0 from the right-hand side made that sentence arithmetically
                # true. That is the claim shape this census exists to stop coming back.
                want = WORDS.get(wm.group(2).lower())
                counted = sorted(codes | {0})
                if want is not None and want != len(counted):
                    problems.append("%s:%d states %s exit codes and the scripts take %d (%s)"
                                    % (rel, n, wm.group(2), len(counted), counted))
                    continue
            if stated and stated != codes:
                problems.append("%s:%d enumerates %s and the scripts take %s"
                                % (rel, n, sorted(stated), sorted(codes)))
if not surfaces:
    print("no surface states the exit-code contract — a contract nobody writes down is not a pass")
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d surface(s) state the contract, every one enumerating the %d code(s) the scripts take: %s"
      % (surfaces, len(codes), sorted(codes)))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "exit_codes ($out)"
  else bad "exit_codes" "$(printf '%s' "$out" | tail -1)"; fi
}

check_alt_tool() {
  # A dependency whose probe accepts an alternative blesses a host that has only the alternative.
  # Every place that then PRESCRIBES a command must name the alternative too, or the host check
  # passes and the documented step dies on the machine the row said was fine.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, re, sys
root = sys.argv[1]
deps = json.load(open(os.path.join(root, "config", "dependencies.json")))["deps"]
pairs = []
for dep_id, row in deps.items():
    probe = row.get("probe") or ""
    tools = re.findall(r"command -v ([A-Za-z0-9_.-]+)", probe)
    if len(tools) > 1:
        pairs.append((dep_id, tools[0], tools[1:]))
if not pairs:
    print("no dependency row accepts an alternative tool — nothing to keep in step, which is not a pass")
    raise SystemExit(1)
problems, sites = [], 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
    for f in filenames:
        if not (f.endswith(".md") or f.endswith(".json")):
            continue
        p = os.path.join(dirpath, f)
        if os.path.basename(p) == "dependencies.json":
            continue
        rel = os.path.relpath(p, root)
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            for dep_id, primary, alts in pairs:
                if not re.search(r"\b%s\b" % re.escape(primary), line):
                    continue
                sites += 1
                if any(re.search(r"\b%s\b" % re.escape(a), line) for a in alts):
                    continue
                problems.append("%s:%d prescribes %s and names none of its accepted alternatives (%s)"
                                % (rel, n, primary, ", ".join(alts)))
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d row(s) accepting an alternative, %d prescribing site(s), every one naming the alternatives"
      % (len(pairs), sites))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "alt_tool ($out)"
  else bad "alt_tool" "$(printf '%s' "$out" | tail -1)"; fi
}

check_seal_scope() {
  # "The seal runs over every package artifact" is a scope claim, and the loop is the scope. Every
  # surface that states what the seal covers must state the enumeration the loop actually walks,
  # and the absolute form is pinned to zero because it is the form that was false.
  local hits n
  hits=$($GREP -rniE 'seal[^.]{0,40}(over|covers)[^.]{0,20}(every|all)[^.]{0,20}(package )?artifacts?' \
           "$PKG_ROOT" --exclude-dir=.git --exclude-dir=tests --exclude-dir=drafts 2>/dev/null | head -3 | tr '\n' ' ')
  n=$($GREP -rlniE 'seal' "$PKG_ROOT/skills" "$PKG_ROOT/references" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    bad "seal_scope" "no surface mentions the seal at all — the scope claim this check pins has no subject"
  elif [ -n "$hits" ]; then
    bad "seal_scope" "the every-artifact overclaim survives: $hits"
  else
    ok "seal_scope ($n surface(s) mention the seal, none of them claims it covers every package artifact)"
  fi
}

check_counts() {
  # A structural count stated in prose is measurable, so it is measured. Two families: a registry
  # section cell must name a file that carries a matching reference and a "carries none at all"
  # list must carry none, and a stated heading count must equal the headings.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import os, re, sys
root = sys.argv[1]
TICK = chr(96)
lib = os.path.join(root, "skills", "gtm-domain-library", "references")
reg = os.path.join(lib, "mf-token-registry.md")
problems, checked = [], 0
if os.path.isdir(lib):
    refs = {}
    for f in sorted(os.listdir(lib)):
        if f.endswith(".md"):
            refs[f] = open(os.path.join(lib, f), encoding="utf-8", errors="replace").read()
    # A benchmark citation is a MEASURED FIGURE, not any tagged claim: a percentage, or one of the
    # registry's own market-figure tokens. Counting tags instead would fail a definitional file for
    # carrying definitions.
    BENCH = re.compile(r"[0-9]+(\.[0-9]+)?\s*%|\bMF:t[0-9]", re.I)
    if os.path.isfile(reg):
        body = open(reg, encoding="utf-8", errors="replace").read()
        for n, line in enumerate(body.splitlines(), 1):
            m = re.search(r"carr(y|ies) none(?: at all)?(?: by design)?", line, re.I)
            if m:
                named = [f for f in refs if f in line]
                checked += 1
                for f in named:
                    hits = len(BENCH.findall(refs[f]))
                    if hits:
                        problems.append("mf-token-registry.md:%d says %s carries none and it carries %d"
                                        % (n, f, hits))
            for cell in re.findall(TICK + r"?([a-z0-9-]+\.md)" + TICK + "?", line):
                if cell in refs and "|" in line:
                    checked += 1
                    if not BENCH.search(refs[cell]):
                        problems.append("mf-token-registry.md:%d assigns a section to %s, which carries "
                                        "no such reference" % (n, cell))
WORDS = {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10}
# A stated count names a KIND of structure, and the count has to match the thing the sentence is
# actually about. Measuring every kind against every heading nearby sets the bar at the widest
# neighbour whatever the sentence says, so a count that is wrong FOR ITS OWN KIND is invisible:
# "seven questions" clears a bound supplied by a twenty-five row list of steps. The kinds this
# library writes are recognisable on the line - a question is a heading that asks one or a
# numbered Question, a step is a numbered heading or a numbered row - so each is measured against
# its own shape. A kind with no recognisable shape keeps the old bound of every heading, which is
# why this can only get stricter, never looser.
KINDS = {
    "question": r"(?:^#{2,4} .*\?[ \t]*$)|(?:^#{2,4}[ \t]+Question[ \t]+\d+\.)|(?:^[ \t]*\d+\.[ \t].*\?[ \t]*$)",
    "step": r"(?:^#{2,4}[ \t]*\d+\.)|(?:^[ \t]*\d+\.[ \t])",
}
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "tests", "drafts")]
    for f in filenames:
        if not f.endswith(".md"):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            m = re.search(r"\b(two|three|four|five|six|seven|eight|nine|ten)[- ](question|step|rung|stage)s?\s+"
                          r"(core|spine|ladder|sequence)\b", line, re.I)
            if not m:
                continue
            checked += 1
            want = WORDS[m.group(1).lower()]
            shape = KINDS.get(m.group(2).lower())
            best = 0
            here = os.path.dirname(p)
            for other in os.listdir(here) if os.path.isdir(here) else []:
                if not other.endswith(".md"):
                    continue
                txt = open(os.path.join(here, other), encoding="utf-8", errors="replace").read()
                if shape:
                    best = max(best, len(re.findall(shape, txt, re.M)))
                else:
                    best = max(best, len(re.findall(r"^#{2,4}\s", txt, re.M)))
            refdir = os.path.join(here, "references")
            if os.path.isdir(refdir):
                for other in os.listdir(refdir):
                    if not other.endswith(".md"):
                        continue
                    txt = open(os.path.join(refdir, other), encoding="utf-8", errors="replace").read()
                    if shape:
                        best = max(best, len(re.findall(shape, txt, re.M)))
                    else:
                        best = max(best, len(re.findall(r"^#{2,4}\s", txt, re.M)),
                                   len(re.findall(r"^\s*\d+\.\s", txt, re.M)))
            if best and want > best:
                problems.append("%s:%d states a %s-%s structure and no file beside it carries more "
                                "than %d of that kind - a stated count is measured against the kind "
                                "it names" % (rel, n, m.group(1), m.group(2), best))
if not checked:
    print("no structural count was found to measure — a counts check with nothing to count is not a pass")
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d structural count(s) and registry cell(s) measured, every one matching the files it names" % checked)
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "counts ($out)"
  else bad "counts" "$(printf '%s' "$out" | tail -1)"; fi
}

check_claim_census() {
  # THE CLAIM CENSUS. A doc-truth fix that edits a line number fixes one instance; a census pins the
  # falsified CLAIM STRING to zero across every surface that ships, so the same sentence cannot
  # come back through another document. Each family below is written as a family, not as the one
  # string that was found, and each names the row that falsified it.
  #
  # SCOPE: the shipped tree. A drafts/ directory is excluded BY NAME, so the pin cannot be
  # gamed by a draft nobody ships — and cannot be tripped by one either.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import os, re, sys
root = sys.argv[1]
TICK = chr(96)
FAMILIES = [
    ("slot mechanism",
     r"(every|each)\s+(market\s+)?(number|figure)[^.\n]{0,60}(labell?ed\s+slot|never\s+a\s+hardcoded)"
     r"|no\s+figure\s+is\s+written\s+inline|slot\s+filled\s+at\s+build\s+time"),
    ("scan coverage",
     r"scans?\s+every\s+(byte|file)|every\s+(byte|file)\s+(in|of)\s+(the\s+)?(tree|package)\s+is\s+scanned"
     r"|covers?\s+every\s+file|no\s+file[^.\n]{0,30}left\s+unscanned"),
    ("hardcoded pattern count",
     r"(list|file)\s+(holds|carries|contains)\s+\d+\s+patterns"),
    ("unconditional log-directory caption",
     r"the\s+(event|usage)\s+log\s+lives\s+here"),
    # The scanner PRINTED, on every run, that the pattern file's header "carries the open
    # decision on how the literal patterns should ship". That decision was later made and the
    # block it referred to was deleted, so the sentence became false while still being printed to
    # every operator. denylist_header_is_current scopes to config/ and could not see a string living
    # in a script, so the claim is pinned here instead, where the walk covers scripts/ too.
    # Written narrowly enough that publish-lint's own "must live outside the package" refusal
    # (a rule it enforces, not a claim about a decision) does not trip it.
    ("open pattern-set decision",
     r"carr(y|ies|ying)\s+the\s+open\s+(decision|ruling|question)"
     r"|open\s+(decision|ruling|question)[^.\n]{0,40}(literal\s+patterns|patterns?\s+should\s+ship)"),
    # And this one, pinned here for the identical reason the family above is: the host check's
    # header promised that its fallback READS THE INSTALLED-PLUGIN REGISTRY DIRECTORY, and a
    # census for any directory-read call in that script returns zero - so a planted rogue server
    # scanned clean while the promise said otherwise. The fix re-words the promise to the one
    # config file the fallback actually reads. That is a doc edit, and a doc edit with no pin is
    # one paste away from coming back; the behaviour half of that defect has a check and the
    # promise half had none. Written narrowly: it takes a READ verb, the registry noun and the object
    # together, so the dependency row that legitimately points at a downstream surface registry
    # (a file this plugin never reads) does not trip it.
    ("fallback registry-directory promise",
     r"(read|reads|reading|scans?|walks?|enumerates?)[^.\n]{0,40}"
     r"(installed-plugin|installed\s+plugin|plugin)\s+registry(\s+director(y|ies))?"
     r"|registry\s+director(y|ies)[^.\n]{0,30}(is\s+read|are\s+read|is\s+scanned|is\s+walked)"),
]
EXCLUDE_DIRS = {".git", "__pycache__", "tests", "drafts"}
EXCLUDE_FILES = {"denylist.txt"}
hits = []
scanned = 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
    for f in sorted(filenames):
        if f in EXCLUDE_FILES or f.endswith((".pyc",)):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        try:
            lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        scanned += 1
        for n, line in enumerate(lines, 1):
            for name, pat in FAMILIES:
                if re.search(pat, line, re.I):
                    hits.append("%s:%d  %s: %.70s" % (rel, n, name, line.strip()))
# one phrase, one referent per document
AMBIGUOUS = ["the pattern file", "the deny-list", "the manifest", "machine-local"]
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
    for f in sorted(filenames):
        if not f.endswith(".md"):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        text = open(p, encoding="utf-8", errors="replace").read()
        for phrase in AMBIGUOUS:
            referents = set()
            for line in text.splitlines():
                if phrase not in line.lower():
                    continue
                for tok in re.findall(TICK + r"([A-Za-z0-9_./-]+\.[a-z]{2,5})" + TICK, line):
                    referents.add(tok)
            if len(referents) > 1:
                hits.append("%s  the phrase %r labels %d different files in one document: %s"
                            % (rel, phrase, len(referents), ", ".join(sorted(referents))))
if scanned < 10:
    print("the census walked %d file(s) — a census over almost nothing is not a pass" % scanned)
    raise SystemExit(1)
if hits:
    print("FALSIFIED CLAIM(S) STILL PRESENT, %d:" % len(hits))
    for h in hits[:5]:
        print("  " + h)
    raise SystemExit(1)
print("%d shipped file(s) censused, %d pinned claim families at zero, no phrase labels two files "
      "in one document" % (scanned, len(FAMILIES)))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "claim_census ($out)"
  else bad "claim_census" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
}

check_abspath() {
  # The narrowed claim and the enforced one, in one check. What is true and enforced is: no
  # machine-specific path and no home-directory path anywhere. The deliberate exceptions — the
  # interpreter lines and the tool pins — are named by ROLE, and the unnarrowed absolute claim is
  # pinned to zero because it was false as worded.
  #
  # AND THE EXCEPTION IS COUNTED RATHER THAN REMEMBERED. This check's own green line used to say
  # "the two tool pins" while the tree carried five pin sites across four tools, so the sentence
  # certifying the allow-set was itself a stale count of it. Both numbers are measured on every run
  # from the same allow-set expression the machine-path scan filters by, which is the only way the
  # words and the enforcement can be the same thing.
  local overclaim machine shebangs misplaced n_she n_files n_pins n_tools allowset
  overclaim=$($GREP -rniE 'no absolute path is ever hardcoded' "$PKG_ROOT" \
                --exclude-dir=.git --exclude-dir=tests --exclude-dir=drafts 2>/dev/null | head -2 | tr '\n' ' ')
  if [ -n "$overclaim" ]; then
    bad "abspath" "the unnarrowed absolute-path claim survives, and the interpreter lines and tool pins falsify it: $overclaim"
    return
  fi
  machine=$($GREP -rnE '(^|[^A-Za-z0-9_/$"])/(Users|home)/[A-Za-z0-9_.-]|\$HOME/[A-Za-z0-9_./-]+|~/[A-Za-z0-9_./-]+' \
              "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null \
            | $GREP -vE '\$HOME/\.(config|local)\b' \
            | $GREP -vF '(annotated:' | head -3 | tr '\n' ' ')
  if [ -n "$machine" ]; then
    bad "abspath" "an absolute machine-specific or home-directory path is hardcoded: $machine"
    return
  fi
  # THE SECOND HALF OF THE ROW, which the first form of this check did not carry: the narrowed
  # claim names the interpreter lines as the deliberate exception, so the ALLOW-SET has to be
  # measured or the exception is a blank cheque. An interpreter line is only an interpreter line
  # on line 1 of its own file; the same string anywhere else is an absolute path in a comment,
  # sitting in the allow-set without being in it. Counted as well as placed, so a deleted
  # interpreter line is a visible failure and not a quieter census.
  allowset='(\[ +-x +"?/(usr/bin|bin|usr/local/bin)/|[A-Za-z_][A-Za-z0-9_]*="?/(usr/bin|bin|usr/local/bin)/)'
  n_pins=$($GREP -rnE "$allowset" "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null | wc -l | tr -d ' ')
  n_tools=$($GREP -rhoE "$allowset"'[a-z0-9_.-]+' "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null \
            | $GREP -oE '[a-z0-9_.-]+$' | sort -u | wc -l | tr -d ' ')
  if [ "$n_pins" -eq 0 ] || [ "$n_tools" -eq 0 ]; then
    bad "abspath" "the tool-pin allow-set censused nothing, so the exception this check names would be certified over an empty set"
    return
  fi
  shebangs=$($GREP -rn '^#!/' "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null)
  misplaced=$(printf '%s\n' "$shebangs" | $GREP -vE '^[^:]+:1:' | $GREP -v '^$' | head -3 | tr '\n' ' ')
  n_she=$(printf '%s\n' "$shebangs" | $GREP -c '^..*$' | tr -d ' ')
  n_files=$(ls "$PKG_ROOT"/scripts/*.sh "$PKG_ROOT"/tests/*.sh 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "$misplaced" ]; then
    bad "abspath" "an absolute interpreter path outside the allow-set: an interpreter line belongs on line 1 of its own script and nowhere else: $misplaced"
  elif [ "$n_she" != "$n_files" ]; then
    bad "abspath" "the absolute interpreter allow-set does not balance: $n_she interpreter line(s) over $n_files script file(s)"
  else
    ok "abspath (the narrowed claim holds: no machine-specific and no home-directory path in any script; the allow-set balances at $n_she interpreter line(s) over $n_files script(s), each on line 1, and the named exceptions are $n_pins tool-pin site(s) across $n_tools distinct tool(s))"
  fi
}

check_md_artifact() {
  # Two rendering artifacts that are cosmetic in the tree and load-bearing in the mouth: a stray
  # block marker mid-sentence inside a read-aloud passage, and a table cell holding nothing but
  # punctuation where a command belongs. A legitimate multi-line block quote must stay green.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import os, re, sys
root = sys.argv[1]
TICK = chr(96)
FENCE = re.compile(r"^\s*(" + TICK * 3 + "|~~~)")
problems, lines_seen = [], 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "tests", "drafts")]
    for f in sorted(filenames):
        if not f.endswith(".md"):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        inside = False
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            line = line.rstrip("\n")
            if FENCE.match(line):
                inside = not inside
                continue
            if inside:
                continue
            lines_seen += 1
            if not line.lstrip().startswith(">") and re.search(r"[a-z,]\s+>\s+[a-z]", line):
                problems.append("%s:%d  a block marker sits mid-sentence: %.60s" % (rel, n, line.strip()))
            if line.count("|") >= 2 and not re.match(r"^\s*\|?\s*:?-{2,}", line.strip()):
                for i, cell in enumerate(line.strip().strip("|").split("|")):
                    c = cell.strip().strip(TICK + "*")
                    if c == "#":
                        continue          # the number-column header idiom, not an empty cell
                    if c and not re.search(r"[A-Za-z0-9]", c):
                        problems.append("%s:%d  a table cell holds only punctuation: %r" % (rel, n, cell.strip()))
                        break
                    # AND THE SAME CELL WITH THE PUNCTUATION TAKEN OUT. The shipped defect was a
                    # bare comma where a command belonged; delete the comma and the row reads
                    # exactly the same way to a person reading it aloud, and it was invisible here.
                    # The LEADING cell is exempt and only the leading cell: an empty top-left
                    # corner is the standard idiom for a comparison table whose first column is
                    # the row label, and this tree ships one.
                    if i > 0 and not c:
                        problems.append("%s:%d  a table cell is empty where the row promises a "
                                        "value: %.60s" % (rel, n, line.strip()))
                        break
if lines_seen < 100:
    print("only %d prose line(s) walked — a rendering census over almost nothing is not a pass" % lines_seen)
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d prose line(s) walked, no mid-sentence block marker and no punctuation-only table cell" % lines_seen)
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "md_artifact ($out)"
  else bad "md_artifact" "$(printf '%s' "$out" | tail -1)"; fi
}

check_env_contract_is_complete() {
  # Where a header CLAIMS completeness about the environment names it reads, the claim is
  # measured. It fires only where such a claim exists: a header that merely enumerates its knobs
  # claims nothing, and firing on it would be a false-failure generator aimed at healthy text.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import os, re, sys
root = sys.argv[1]
TICK = chr(96)
CLAIM = re.compile(r"(and nothing else|nothing else\b|complete list|the whole set|no others?)", re.I)
NS = re.compile(r"\b([A-Z][A-Z0-9]*)_[A-Z0-9_]+\b")
problems, claimed = [], 0
for f in sorted(os.listdir(os.path.join(root, "scripts"))):
    if not f.endswith(".sh"):
        continue
    p = os.path.join(root, "scripts", f)
    lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
    header = []
    for n, line in enumerate(lines, 1):
        if n > 1 and not line.startswith("#"):
            break
        header.append((n, line))
    htext = "\n".join(l for _, l in header)
    m = re.search(r"ENVIRONMENT CONTRACT[^\n]*", htext, re.I)
    if not m or not CLAIM.search(m.group(0)):
        continue
    claimed += 1
    ns = re.findall(TICK + r"([A-Z][A-Z0-9]*)_" + TICK, m.group(0))
    prefixes = set(ns) or {"PKG"}
    body = "\n".join(lines)
    read = set()
    for mm in re.finditer(r"\$\{?([A-Z][A-Z0-9_]{2,})", body):
        read.add(mm.group(1))
    for mm in re.finditer(r"environ(?:\.get)?[(\[]\s*\"([A-Z][A-Z0-9_]{2,})\"", body):
        read.add(mm.group(1))
    listed = set(re.findall(r"\b([A-Z][A-Z0-9_]{3,})\b", htext))
    private = re.findall(TICK + r"([A-Za-z_][A-Za-z0-9_]*)\*" + TICK, htext)
    for name in sorted(read):
        if not any(name.startswith(pre + "_") for pre in prefixes):
            continue
        if name in listed:
            continue
        if any(name.upper().startswith(pv.upper()) for pv in private):
            continue
        problems.append("scripts/%s reads %s in the %s_ namespace and its completeness claim does "
                        "not enumerate it" % (f, name, "/".join(sorted(prefixes))))
if not claimed:
    print("no script header claims completeness about its environment — the check has no subject, "
          "which is not a pass")
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d header(s) claim environment completeness, every name each one reads is enumerated" % claimed)
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "env_contract_is_complete ($out)"
  else bad "env_contract_is_complete" "$(printf '%s' "$out" | tail -1)"; fi
}

check_test_claims_name_a_live_check() {
  # A sentence asserting that something IS TESTED must name a check the suite lists. The live form
  # of this defect was a claim inside a DATA file rather than a document, which a document-only
  # census would walk straight past, so the walk covers .json as well as .md.
  #
  # AND "NAMES A CHECK" MEANS NAMES IT, not contains its letters. Matched as a bare substring, the
  # assertion was satisfied by ordinary prose: several ids are English words or fragments of them,
  # so "tested by the reproducibility harness", "tested by the counts we publish" and "tested by
  # the laddered smoke run" each satisfied it while naming nothing. A claim citing a check is
  # citing an identifier, and the two forms an identifier takes in this package's prose are the
  # only two accepted here: quoted as code, or written in full with its underscores. A one-word id
  # is an English word as well, so it counts only when it is quoted or carries the check_ prefix.
  local out rc names
  names=$(bash "$PKG_ROOT/tests/run-tests.sh" --list 2>/dev/null | tr -d ' ' | tr '\n' ',')
  out=$(python3 - "$PKG_ROOT" "$names" 2>&1 <<'PY'
import os, re, sys
root, names = sys.argv[1], set(x for x in sys.argv[2].split(",") if x)
if not names:
    print("the suite listed no check names — a claim census against an empty roster proves nothing")
    raise SystemExit(1)
ASSERT = re.compile(r"\b(is|are)\s+(exercised|tested)\s+(by|against)\b", re.I)
# the code-quote character is built rather than written: a literal one inside this heredoc, inside
# a command substitution, is a parse error on some shells before this program ever runs
TICK = chr(96)
BACKTICK = re.compile(TICK + r"([^" + TICK + r"]+)" + TICK)

def names_a_check(line):
    quoted = set()
    for m in BACKTICK.finditer(line):
        quoted.update(re.findall(r"[a-z0-9_]+", m.group(1)))
    for nm in names:
        if nm in quoted:
            return True
        if re.search(r"\bcheck_%s\b" % re.escape(nm), line):
            return True
        if "_" not in nm:
            continue
        if re.search(r"\b%s\b" % re.escape(nm), line):
            return True
        for alt in (nm.replace("_", " "), nm.replace("_", "-")):
            if re.search(r"\b%s\b" % re.escape(alt), line, re.I):
                return True
    return False

problems, claims = [], 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "tests", "drafts")]
    for f in sorted(filenames):
        if not (f.endswith(".md") or f.endswith(".json")):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            if not ASSERT.search(line):
                continue
            claims += 1
            if names_a_check(line):
                continue
            problems.append("%s:%d asserts a behaviour is exercised and names no check the suite "
                            "lists: %.70s" % (rel, n, line.strip()))
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d roster entr(y/ies); %d test claim(s), every one naming a check the suite lists as an "
      "identifier rather than merely containing its letters" % (len(names), claims))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "test_claims_name_a_live_check ($out)"
  else bad "test_claims_name_a_live_check" "$(printf '%s' "$out" | tail -1)"; fi
}

# THE SUITE FILE IS NOT EXEMPT; ITS PATTERN LINES ARE.
#
# Both censuses below excluded this whole file by name, and the reason was real: a family regex
# written out in full matches itself, so an unmasked self-scan reddens on its own definition. But
# the cure was four thousand lines wide when the disease was a dozen — every comment, every verdict
# string and every future addition in the largest shipped file rode the exemption, and a
# disclosure sentence pasted in here passed a census whose own verdict said "tree-wide". An
# exemption bigger than its reason is a hole with a justification attached.
#
# So the file is scanned like every other file, against a copy of itself in which exactly the
# self-matching lines are blanked. A line opts out by carrying the marker below on its own end, the
# blanking preserves line numbers so a hit still names its line, and the number of masked lines is
# printed in the verdict — an exemption nobody can count is an exemption nobody can review.
SELF_EXEMPT_MARK='census-subject (exempt)'
suite_self_scan() {   # $1 = ERE; prints this file's matching lines with the masked ones blanked
  local masked="$TMP_ROOT/self-masked.txt"
  $AWK -v m="$SELF_EXEMPT_MARK" 'index($0, m) { print ""; next } { print }' \
    "$HERE/run-tests.sh" > "$masked" 2>/dev/null || return 1
  $GREP -nE "$1" "$masked" 2>/dev/null | head -3 | tr '\n' ' '
}
suite_self_masked_count() {
  $GREP -cF "$SELF_EXEMPT_MARK" "$HERE/run-tests.sh" 2>/dev/null | tr -d ' '
}

check_no_meta_disclosure_phrases() {
  # A phrase family pinned to zero tree-wide. None of these leaks a literal; each one discloses
  # something ABOUT the package's own history or its private surroundings — that an overlay exists
  # and what it holds, that this list was vendored from somewhere, that an internal codename exists,
  # or what a scan found on the machine it was first run on. The pin is a family, not a string, so
  # a re-worded disclosure fails too.
  local hits outside self masked fam_meta fam_outside
  fam_meta='private overlay[^.]{0,40}(exists|carries|holds|lives)|overlay mechanism exists|(vendored|adapted|copied) from an upstream[^.]{0,20}(register|list)|internal case codename|codename for that (company|customer)|(first|initial) run[^.]{0,40}(internal|author|build) (build|machine|host)|on the internal build'   # census-subject (exempt)
  hits=$($GREP -rniE "$fam_meta" \
           "$PKG_ROOT" --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=drafts --exclude=run-tests.sh 2>/dev/null | head -3 | tr '\n' ' ')
  if [ -n "$hits" ]; then
    bad "no_meta_disclosure_phrases" "a meta-disclosure phrase survives: $hits"
    return
  fi
  self=$(suite_self_scan "$fam_meta")
  if [ -n "$self" ]; then
    bad "no_meta_disclosure_phrases" "a meta-disclosure phrase survives in the suite file itself, outside its own pattern definitions: $self"
    return
  fi
  # THE SAME DISCLOSURE WITH THE WORD "overlay" TAKEN OUT. The family above is keyed to the noun,
  # so a sentence saying private literals live outside the package and are passed in at scan   # census-subject (exempt)
  # time said every single thing the banned sentence says and matched nothing. This member is keyed
  # to the CLAIM instead: an indicative statement that private content exists and sits outside the
  # tree. The illustration above carries the mask marker because it IS the class, written out.
  #
  # THE LINE IT MUST NOT CROSS. The tool's own refusal, "A private pattern list must live outside
  # the package, or it is published with it", is NORMATIVE - it says where a list has to be kept,
  # which is a capability sentence, and that is the wording the fix landed on. So the modal forms
  # are filtered out by name, and only the indicative claim about what IS out there fails.
  fam_outside='\b(literal|value|entrie|entry|secret)s?\b[^.]{0,40}\b(live|lives|sit|sits|reside|resides|are kept|are held|are stored|are passed)\b[^.]{0,25}\b(outside|beyond|out of)\b[^.]{0,20}\b(the|this) (package|tree|repo|checkout)\b'   # census-subject (exempt)
  outside=$($GREP -rniE "$fam_outside" \
             "$PKG_ROOT" --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=drafts --exclude=run-tests.sh 2>/dev/null \
           | $GREP -viE '\b(must|should|has to|have to|belongs?|refus|never)\b' | head -3 | tr '\n' ' ')
  if [ -z "$outside" ]; then
    outside=$(suite_self_scan "$fam_outside" | $GREP -viE '\b(must|should|has to|have to|belongs?|refus|never)\b')
  fi
  masked="$(suite_self_masked_count)"
  if [ -n "$outside" ]; then
    bad "no_meta_disclosure_phrases" "an overlay-existence disclosure survives, re-worded around the noun: $outside"
  else
    ok "no_meta_disclosure_phrases (the pinned phrase family is at zero across every file including this one: no overlay-existence sentence, no upstream-register framing, no codename aside, no build-history parenthetical; $masked line(s) of this file are masked as its own pattern definitions)"
  fi
}

check_no_placeholder_governance_notes() {
  # The product's own name is the shipped identity, not a placeholder waiting on a decision. A note
  # saying otherwise is wrong AND it exposes a governance process upstream of the artifact. Pinned
  # to zero as a family, so a paraphrase with a different governance verb fails too.
  local hits self masked fam_placeholder
  fam_placeholder='(placeholder|provisional|working (name|title))[^.]{0,60}(until|pending)[^.]{0,60}(name|naming|ruled|decision)|name[^.]{0,30}(is|stays) (a )?(placeholder|provisional)|(replaced|renamed).{0,60}(published name.{0,20}ruled)'   # census-subject (exempt)
  hits=$($GREP -rniE "$fam_placeholder" \
           "$PKG_ROOT" --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=drafts --exclude=run-tests.sh 2>/dev/null | head -3 | tr '\n' ' ')
  if [ -n "$hits" ]; then
    bad "no_placeholder_governance_notes" "a placeholder-name governance note survives: $hits"
    return
  fi
  self=$(suite_self_scan "$fam_placeholder")
  masked="$(suite_self_masked_count)"
  if [ -n "$self" ]; then
    bad "no_placeholder_governance_notes" "a placeholder-name governance note survives in the suite file itself, outside its own pattern definitions: $self"
  else
    ok "no_placeholder_governance_notes (no surface claims the product's own name is a placeholder awaiting a ruling, this file included; $masked line(s) masked as its own pattern definitions)"   # census-subject (exempt)
  fi
}

check_provenance_claims_are_consistent() {
  # A tree may not carry BOTH adaptation framing and an originality denial over the same material
  # unless an attribution block exists and resolves the two. Whichever way the licence call went,
  # the surfaces have to agree with each other and with the licence file.
  local adapt deny attrib
  adapt=$($GREP -rlniE 'adapted from an? (mit-licensed )?upstream|derived from an upstream pack' \
            "$PKG_ROOT" --exclude-dir=.git --exclude-dir=drafts --exclude=run-tests.sh 2>/dev/null | wc -l | tr -d ' ')
  deny=$($GREP -rlniE '(entirely|wholly|fully) original work|original work with no upstream|no upstream (source|pack|material)' \
           "$PKG_ROOT" --exclude-dir=.git --exclude-dir=drafts --exclude=run-tests.sh 2>/dev/null | wc -l | tr -d ' ')
  # AN ATTRIBUTION BLOCK IS AN ARTIFACT, NOT A WORD. This used to count any of LICENSE, README or
  # AGENTS that merely said "MIT License" or "attribution" anywhere, and the whole conditional
  # above hangs off the number. Delete the copyright line out of LICENSE - the one line that names
  # who is being credited, and the one the licence ruling restored - and the file still says "MIT License" at
  # the top, README still points at "Method provenance", so the count did not move and adaptation
  # framing with nothing resolving it read as resolved. The block is now the LICENCE ARTIFACT: a
  # copyright line naming a holder, or an explicit third-party attribution block. A document that
  # merely points at one is a pointer, and a pointer to a deleted line resolves nothing.
  # (The copyright SYMBOL is deliberately not in this pattern. It is a non-ASCII byte, the tree
  # pins its non-ASCII line census, and adding one here would have moved that pin as a side effect
  # of a test edit. The word form and the "(c) YYYY" form are what this LICENSE and every licence
  # this package could adopt actually carry.)
  attrib=$($GREP -rlniE '^[[:space:]]*copyright([[:space:]]*\([cC]\))?[[:space:]]*[0-9]{4}|^[[:space:]]*\([cC]\)[[:space:]]*[0-9]{4}|third-party (licen[cs]e|attribution) (block|notice)|portions? (copyright|adapted from)' \
             "$PKG_ROOT/LICENSE" "$PKG_ROOT/README.md" "$PKG_ROOT/AGENTS.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$adapt" -gt 0 ] && [ "$deny" -gt 0 ]; then
    bad "provenance_claims_are_consistent" "$adapt surface(s) say the material was adapted from upstream and $deny say it is original: a contradiction an attribution block does not resolve ($attrib present)"
  elif [ "$adapt" -gt 0 ] && [ "$attrib" -eq 0 ]; then
    bad "provenance_claims_are_consistent" "$adapt surface(s) carry adaptation framing and no attribution block resolves it: no copyright line naming a holder and no third-party attribution block survives in LICENSE, README.md or AGENTS.md"
  else
    ok "provenance_claims_are_consistent (adaptation framing on $adapt surface(s), originality claims on $deny, attribution blocks present: $attrib — the three do not contradict)"
  fi
}

check_one_product_name() {
  # Every path segment a script creates on the host - or a document promises it creates - must be
  # the DECLARED plugin name. A second product name hardcoded into a home-directory path is a name
  # the rename mechanism does not know about, which falsifies that mechanism's whole promise. The
  # check reads the COMPOSITION, not a literal.
  #
  # WHY IT ASSERTS UNDER THE PREFIX INSTEAD OF EXEMPTING IT. The first form of this check carved
  # the .config, .local and .cache rungs OUT of the walk, which swallowed the whole
  # HOME/.local/state/<name> family this row is about: a planted second name there shipped green.
  # So the rule is inverted. The XDG rungs are RECOGNISED as prefixes, and the segment UNDER them
  # is the one that has to equal the declared name.
  #
  # THREE FORMS, because the package writes host paths three ways: the shell and prose literal,
  # the XDG literal, and the python join form built on expanduser, whose segments arrive as string
  # literals OR as module-level constants that have to be resolved before the segment can be read.
  # The literal-only form of this check could not see the join form at all.
  #
  # SCOPE: scripts/ and README.md - the code that composes the path and the document that promises
  # it. Passed over by design: a segment composed at run time (a variable, a placeholder, a format
  # slot) is exactly the shape this check wants; a path that stops at the prefix names no product
  # folder at all; and a leaf FILE directly under the home root belongs to whoever wrote it.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, re, sys
root = sys.argv[1]

DQ = chr(34)
SQ = chr(39)
LP = chr(40)
RP = chr(41)
LB = chr(123)
RB = chr(125)
DOLLAR = chr(36)
QUOTES = DQ + SQ
OPENERS = LP + chr(91) + LB
CLOSERS = RP + chr(93) + RB
JOIN = "os.path.join" + LP
EXPAND = "expanduser" + LP
DYNAMIC_CHARS = "<>%*" + DOLLAR + LB

declared = ""
for cand in (os.path.join(root, ".claude-plugin", "plugin.json"), os.path.join(root, "plugin.json")):
    if os.path.isfile(cand):
        declared = (json.load(open(cand)).get("name") or "").strip()
        break
if not declared:
    print("the manifest declares no name, so nothing defines what the one product name is")
    raise SystemExit(1)

XDG_PREFIXES = [(".local", "state"), (".local", "share"), (".local", "bin"),
                (".config",), (".cache",)]
SEG = "A-Za-z0-9_.<>%/" + DOLLAR + LB + RB + "-"
LITERAL = re.compile("[" + DOLLAR + "][" + LB + "]?(?:HOME|XDG_[A-Z]+_HOME)[" + RB + "]?/[" + SEG +
                     "]*|~/[" + SEG + "]*")
LEAF_FILE = re.compile("[.][A-Za-z0-9]{1,6}$")
ASSIGN = re.compile("^[ \\t]*([A-Za-z_][A-Za-z0-9_]*)[ \\t]*=[ \\t]*(.*)$")

problems = []
named = 0


def strip_prefix(segs):
    for pre in XDG_PREFIXES:
        head = tuple((s or "").lower() for s in segs[:len(pre)])
        if head == pre:
            return segs[len(pre):]
    return segs


def verdict(segs, where, whole):
    global named
    segs = strip_prefix([s for s in segs if s not in ("", ".")])
    if not segs:
        return                                 # stops at the prefix: names no product folder
    seg = segs[0]
    if seg is None:
        return                                 # composed at run time from something dynamic
    if any(ch in seg for ch in DYNAMIC_CHARS):
        return                                 # a placeholder or a variable: the wanted shape
    if len(segs) == 1 and LEAF_FILE.search(seg):
        return                                 # a leaf file under the home root, not our folder
    named += 1
    if seg.lstrip(".").lower() != declared.lower():
        problems.append("%s: %s -> the folder under the home or XDG prefix is %s, not the declared "
                        "plugin name %s" % (where, whole, seg, declared))


def is_home_anchor(s):
    j = s.find(EXPAND)
    if j < 0:
        return False
    k = s.find(RP, j)
    return k > 0 and "~" in s[j:k]


def args_of(text, open_idx):
    """Split the call opened at open_idx into its top-level arguments."""
    depth, out, cur, i = 0, [], [], open_idx
    while i < len(text):
        c = text[i]
        if c in OPENERS:
            depth += 1
            if depth == 1:
                i += 1
                continue
        elif c in CLOSERS:
            depth -= 1
            if depth == 0:
                out.append("".join(cur).strip())
                return out
        if depth == 1 and c == ",":
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
        i += 1
    return out


def resolve(arg, consts):
    a = arg.strip()
    if len(a) >= 2 and a[0] in QUOTES and a[-1] == a[0]:
        return a[1:-1]
    return consts.get(a)                       # None = dynamic, and dynamic is fine


def walk_join(text, open_idx, consts):
    """Return whether this join is anchored at the home directory, and its ordered segments."""
    anchored, segs = False, []
    for a in args_of(text, open_idx):
        if is_home_anchor(a):
            anchored = True
            j = a.find(JOIN)
            if j >= 0:
                _sub_anchored, sub = walk_join(a, j + len(JOIN) - 1, consts)
                segs.extend(sub)
            continue
        segs.append(resolve(a, consts))
    return anchored, segs


targets = [("README.md", os.path.join(root, "README.md"))]
sdir = os.path.join(root, "scripts")
if os.path.isdir(sdir):
    for f in sorted(os.listdir(sdir)):
        targets.append(("scripts/" + f, os.path.join(sdir, f)))

walked = 0
for rel, path in targets:
    if not os.path.isfile(path):
        continue
    text = open(path, encoding="utf-8", errors="replace").read()
    walked += 1
    consts = {}
    for ln in text.splitlines():
        m = ASSIGN.match(ln)
        if not m:
            continue
        rest = m.group(2).strip()
        if len(rest) >= 2 and rest[0] in QUOTES:
            end = rest.find(rest[0], 1)
            if end > 0:
                consts[m.group(1)] = rest[1:end]
    for n, line in enumerate(text.splitlines(), 1):
        for mm in LITERAL.finditer(line):
            whole = mm.group(0)
            tail = whole.split("/", 1)[1] if "/" in whole else ""
            verdict(tail.split("/"), "%s:%d" % (rel, n), whole)
    for mm in re.finditer(re.escape(JOIN), text):
        anchored, segs = walk_join(text, mm.end() - 1, consts)
        if anchored:
            n = text.count("\n", 0, mm.start()) + 1
            verdict(segs, "%s:%d" % (rel, n), "a python join anchored at the home directory")

if walked == 0:
    print("no script and no README to read - a walk over nothing is not a pass")
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d surface(s) walked in three path forms, %d host path(s) naming a product folder, every "
      "one of them the declared name %s" % (walked, named, declared))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "one_product_name ($out)"
  else bad "one_product_name" "$(printf '%s' "$out" | tail -1)"; fi
}

check_region_token_census_pinned() {
  # A single-region market fingerprint runs through the library's reference files. It is not
  # removable without rewriting method content, and no pattern can distinguish a legitimately cited
  # home market from a fingerprint — the distinguishing fact is the ABSENCE of other regions. So the
  # accepted risk is pinned instead: the per-file counts are frozen in a committed baseline and any
  # drift fails here, which stops the class GROWING even though it cannot shrink mechanically.
  #
  # AND THE SCOPE IS DECLARED IN THE BASELINE, not hardcoded here. A census bound to one hardcoded
  # directory measures the library and nothing else: every reader-facing document in the package
  # sits outside the tripwire, and a concentration appearing there is the same fact about the same
  # package with no gate watching it. The baseline names the scopes it covers,
  # every document in scope carries a pinned row for every family, and a document in scope with no
  # row is a failure — an unpinned file is an unwatched file.
  local base="$HERE/region-baseline.txt" out rc
  if [ ! -r "$base" ]; then
    bad "region_token_census_pinned" "no committed baseline at tests/region-baseline.txt — an accepted risk with no drift gate is just an unmeasured risk"
    return
  fi
  out=$(python3 - "$PKG_ROOT" "$base" 2>&1 <<'PY'
import os, re, sys
root, base = sys.argv[1], sys.argv[2]
fams, scopes = {}, []
for line in open(base, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("@family "):
        _, name, pat = line.split(" ", 2)
        fams[name] = re.compile(pat, re.I)
    elif line.startswith("@scope "):
        scopes.append(line.split(" ", 1)[1].strip())
pins = {}
for line in open(base, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#") or line.startswith("@"):
        continue
    parts = line.split()
    if len(parts) == 3:
        pins[(parts[0], parts[1])] = int(parts[2])
if not fams or not pins:
    print("the baseline declares no family or no pinned count — an empty pin is not a pin")
    raise SystemExit(1)
if not scopes:
    print("the baseline declares no scope, so this census would walk nothing and say so in a "
          "sentence that sounds like a pass")
    raise SystemExit(1)
docs, missing_scope = [], []
for s in scopes:
    p = os.path.join(root, s)
    if os.path.isdir(p):
        found = sorted(f for f in os.listdir(p) if f.endswith(".md"))
        if not found:
            missing_scope.append(s)
        docs.extend(os.path.join(s, f) for f in found)
    elif os.path.isfile(p) and s.endswith(".md"):
        docs.append(s)
    else:
        missing_scope.append(s)
if missing_scope:
    print("declared scope(s) the census could not walk, so part of the surface went unmeasured "
          "while the rest reported clean: " + ", ".join(missing_scope[:3]))
    raise SystemExit(1)
problems, total = [], 0
for fam, pat in sorted(fams.items()):
    for rel in docs:
        n = len(pat.findall(open(os.path.join(root, rel), encoding="utf-8",
                                 errors="replace").read()))
        want = pins.get((fam, rel))
        if want is None:
            problems.append("%s/%s is in a declared scope and the baseline pins no count for it, "
                            "so it is walked and watched by nothing (it carries %d today)"
                            % (fam, rel, n))
            continue
        total += n
        if n != want:
            problems.append("%s/%s drifted: %d against a pinned %d" % (fam, rel, n, want))
for (fam, rel) in sorted(pins):
    if rel not in docs:
        problems.append("%s/%s is pinned and no declared scope reaches it, so its pin measures "
                        "nothing" % (fam, rel))
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d document(s) across %d declared scope(s), %d family/file pin(s), %d token(s) total, every "
      "count equal to the committed baseline" % (len(docs), len(scopes), len(pins), total))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "region_token_census_pinned ($out)"
  else bad "region_token_census_pinned" "$(printf '%s' "$out" | tail -1)"; fi
}

check_encoding_census() {
  # Two halves in one implementation. The DANGEROUS classes — zero-width characters, bidirectional
  # controls, non-breaking spaces and byte-order marks — must be at zero tree-wide, because each one
  # can make a reader see something other than what a machine executes. Ordinary non-ASCII is not
  # dangerous and is not banned; it is COUNTED, against a committed baseline, so a silent drift is
  # visible. The earlier "no non-ASCII anywhere" sweep line was false; this is the true form of it.
  #
  # THE CLASS IS ASKED FOR BY DEFINITION, NOT LISTED FROM MEMORY. The first form of this check
  # spelled the ban out as a hand-written range table, and the table was narrower than the sentence
  # above it: an Arabic letter mark is a bidirectional control, a word joiner is zero-width, and a
  # narrow no-break space and a figure space are non-breaking spaces — all four are named by the
  # ban and all four walked through it green. A ban whose enforcement is a remembered list is a ban
  # on the members somebody remembered. So the invisible-formatting half is asked of the character
  # database — every character the standard classifies as a format character — and the
  # non-breaking spaces, which the standard classifies as spaces rather than formats, are named
  # explicitly beside it. A soft hyphen is a format character and is therefore covered too.
  #
  # And the detector proves it can see its own class before it certifies a tree: one member of each
  # named family is constructed in memory and fed to the predicate, so a widened ban that stopped
  # matching would fail here rather than certify a clean tree it can no longer inspect. The canary
  # characters are BUILT from their code points and never written as bytes — writing them would put
  # the banned characters into the file that bans them.
  local base="$HERE/encoding-baseline.txt" out rc
  if [ ! -r "$base" ]; then
    bad "encoding_census" "no committed baseline at tests/encoding-baseline.txt — a census with nothing to compare against reports whatever it happens to find"
    return
  fi
  out=$(python3 - "$PKG_ROOT" "$base" 2>&1 <<'PY'
import os, sys, unicodedata
root, base = sys.argv[1], sys.argv[2]
pins = {}
for line in open(base, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    k, _, v = line.partition("=")
    pins[k.strip()] = v.strip()

# The ban, stated as the two things it bans. Everything the standard calls a FORMAT character is
# invisible formatting: that is where zero-width characters, every bidirectional control, the
# byte-order mark and the soft hyphen live, and asking the database is what keeps the enforcement
# equal to the sentence. Non-breaking spaces are classified as spaces, not formats, so they are
# named here by code point \u2014 they are the only members that need naming.
NONBREAKING = {0x00A0, 0x2007, 0x202F}

def dangerous(ch):
    return unicodedata.category(ch) == "Cf" or ord(ch) in NONBREAKING

def describe(ch):
    return "U+%04X %s" % (ord(ch), unicodedata.name(ch, "an unnamed formatting character"))

# One member per named family, built from its code point so no banned byte is ever written here.
CANARIES = {
    "zero-width": 0x200B,
    "zero-width (word joiner)": 0x2060,
    "bidirectional control": 0x202E,
    "bidirectional control (letter mark)": 0x061C,
    "non-breaking space": 0x00A0,
    "non-breaking space (narrow)": 0x202F,
    "non-breaking space (figure)": 0x2007,
    "byte-order mark": 0xFEFF,
    "soft hyphen": 0x00AD,
}
blind = [name for name, cp in sorted(CANARIES.items()) if not dangerous(chr(cp))]
if blind:
    print("the census cannot see members of the class it bans, so a clean verdict from it would "
          "mean nothing: " + ", ".join(blind))
    raise SystemExit(1)

lines_nonascii, files_nonascii, danger = 0, 0, []
walked = 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
    for f in sorted(filenames):
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        try:
            text = open(p, encoding="utf-8", errors="strict").read()
        except (OSError, UnicodeDecodeError):
            danger.append("%s is not readable as UTF-8" % rel)
            continue
        walked += 1
        present = sorted(c for c in set(text) if dangerous(c))
        hit = False
        for n, line in enumerate(text.splitlines(), 1):
            here = [c for c in present if c in line]
            if here:
                danger.append("%s:%d carries %s" % (rel, n, ", ".join(describe(c) for c in here)))
            if any(ord(c) > 127 for c in line):
                lines_nonascii += 1
                hit = True
        if hit:
            files_nonascii += 1
if danger:
    print("DANGEROUS ENCODING: " + "; ".join(danger[:3]))
    raise SystemExit(1)
want_lines, want_files = pins.get("nonascii_lines"), pins.get("nonascii_files")
want_walked = pins.get("walked_files")
if want_lines is None or want_files is None or want_walked is None:
    print("the baseline pins no walked_files / nonascii_lines / nonascii_files total")
    raise SystemExit(1)
# The WALK is pinned as well as its findings. A census that reads fewer files than it used to
# reports a smaller number for every class it counts, and a shrinking walk looks exactly like a
# cleaner tree from the outside.
if str(walked) != want_walked:
    print("the census walked %d file(s) against a pinned %s — a walk that changed size measures a "
          "different tree, so its counts below say nothing about this one"
          % (walked, want_walked))
    raise SystemExit(1)
if str(lines_nonascii) != want_lines or str(files_nonascii) != want_files:
    print("the census drifted from its baseline: %d non-ASCII line(s) in %d file(s), pinned at %s "
          "in %s" % (lines_nonascii, files_nonascii, want_lines, want_files))
    raise SystemExit(1)
print("%d file(s) walked, its pinned count · dangerous classes 0, asked of the character database "
      "and proven against one member of each named family · %d non-ASCII line(s) across %d "
      "file(s), equal to the committed baseline" % (walked, lines_nonascii, files_nonascii))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "encoding_census ($out)"
  else bad "encoding_census" "$(printf '%s' "$out" | tail -1)"; fi
}

check_raw_html_inventory_is_pinned() {
  # Three of this package's documents carry raw HTML and the rest carry none. Nothing in this
  # package models a renderer, and vendoring one to prove a page renders correctly would be a
  # larger and staler dependency than the risk — so rendering fidelity is proved by a human preview
  # on the publish checklist, and the MECHANISABLE half is closed here: a committed per-file
  # inventory, with every file not listed held at zero and every file listed required to exist.
  #
  # The counter reads element OPENERS, attributes and all. A counter that matches only the bare
  # opening-tag form misses the attribute-carrying one, which is precisely the shape a naive count
  # walks past.
  local out rc
  out=$(python3 - "$PKG_ROOT" "$HERE/raw-html-inventory.txt" 2>&1 <<'PY'
import os, re, sys
root, inv_path = sys.argv[1], sys.argv[2]
TICK = chr(96)
if not os.path.isfile(inv_path):
    print("no committed inventory at tests/%s — an unpinned inventory permits anything"
          % os.path.basename(inv_path))
    raise SystemExit(1)
pins = {}
for line in open(inv_path, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    path, _, count = line.rpartition(" ")
    pins[path.strip()] = int(count)
# The tag name must be followed by whitespace, a slash or the closing angle bracket. Without that
# boundary an ordinary prose placeholder of the shape <a,b,c> counts as an anchor element.
OPENER = re.compile(r"<\s*(details|summary|div|table|tr|td|th|img|picture|source|br|p|span|b|i|kbd|"
                    r"sub|sup|a)(\s[^>]*)?/?>", re.I)
FENCE = re.compile(r"^\s*(" + TICK * 3 + "|~~~)")
problems, walked, total = [], 0, 0
seen = set()
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
    for f in sorted(filenames):
        if not f.endswith(".md"):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        inside, n = False, 0
        for line in open(p, encoding="utf-8", errors="replace").read().splitlines():
            if FENCE.match(line):
                inside = not inside
                continue
            if inside:
                continue
            n += len(OPENER.findall(line))
        walked += 1
        total += n
        seen.add(rel)
        want = pins.get(rel, 0)
        if n != want:
            problems.append("%s carries %d raw HTML element(s) and the inventory pins %d" % (rel, n, want))
# AND A PINNED FILE HAS TO BE THERE. An inventory that tolerates a missing subject is an inventory
# a deleted document walks out from under: the line stays, nothing is measured against it, and the
# census prints the same green over a smaller tree.
for rel in sorted(pins):
    if rel not in seen:
        problems.append("%s is pinned in the inventory and is not in the tree, so its pin measures "
                        "nothing" % rel)
if not walked:
    print("no document was walked — an inventory over nothing is not a pass")
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d document(s) walked, %d raw HTML element(s) in total, every per-file count equal to the "
      "committed inventory" % (walked, total))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "raw_html_inventory_is_pinned ($out)"
  else bad "raw_html_inventory_is_pinned" "$(printf '%s' "$out" | tail -1)"; fi
}

check_references_resolve
check_references_link_floor
check_root_and_manifest_refs
check_script_prose_refs
check_exit_codes
check_alt_tool
check_seal_scope
check_counts
check_claim_census
check_abspath
check_md_artifact
check_env_contract_is_complete
check_test_claims_name_a_live_check
check_no_meta_disclosure_phrases
check_no_placeholder_governance_notes
check_provenance_claims_are_consistent
check_one_product_name
check_region_token_census_pinned
check_encoding_census
check_raw_html_inventory_is_pinned

# --- install and first run: the path a stranger actually walks ---
banner "install-and-first-run"

check_manifest_is_installable() {
  # The manifest has to be where the harness reads it, parse, and carry the keys a validator
  # requires. Nothing in this package's own machinery reads it, so nothing else would notice if it
  # moved back — which is exactly why this assertion exists rather than being implied by a green
  # suite somewhere else.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, sys
root = sys.argv[1]
nested = os.path.join(root, ".claude-plugin", "plugin.json")
at_root = os.path.join(root, "plugin.json")
if not os.path.isfile(nested):
    print("no manifest at .claude-plugin/plugin.json — the standard install path cannot work")
    raise SystemExit(1)
if os.path.isfile(at_root):
    print("a second manifest sits at the package root; two manifests can disagree and only one is read")
    raise SystemExit(1)
try:
    man = json.load(open(nested))
except ValueError as e:
    print("the manifest does not parse: %s" % e)
    raise SystemExit(1)
missing = [k for k in ("name", "version", "description") if not man.get(k)]
if missing:
    print("the manifest is missing required key(s): %s" % ", ".join(missing))
    raise SystemExit(1)
# AND NO DOCUMENT MAY DESCRIBE AN INSTALL THIS CHECK FORBIDS. Moving the manifest is what makes
# the standard install work, and a surface telling a reader to copy the manifest to the
# package root sends them to the one layout this check refuses two assertions above. The census is
# a pin rather than a line-number fix, because the sentence lives in more than one document and a
# doc edit with no pin comes back.
import re
bad_docs = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "drafts", "tests")]
    for f in sorted(filenames):
        if not f.endswith(".md"):
            continue
        p = os.path.join(dirpath, f)
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            if re.search(r"(cop(y|ying)|plac(e|ing)|put|move|moving)[^.]{0,40}plugin\.json"
                         r"[^.]{0,40}(package )?root"
                         r"|plugin\.json\s+(at|in|to)\s+the\s+(package\s+)?root", line, re.I):
                bad_docs.append("%s:%d %s" % (os.path.relpath(p, root), n, line.strip()[:60]))
if bad_docs:
    print("document(s) describing an install path the layout no longer supports: %s"
          % "; ".join(bad_docs[:3]))
    raise SystemExit(1)
print("manifest at .claude-plugin/plugin.json, parses, name=%s version=%s; no document describes "
      "the root-level install the move replaced" % (man["name"], man["version"]))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "manifest_is_installable ($out)"
  else bad "manifest_is_installable" "$(printf '%s' "$out" | tail -1)"; fi
}

check_publish_identity_declared() {
  # A package that names nobody as its author and nobody as its licence holder is not a publishable
  # artifact, and the harness's own validator says so in the output people paste as a passing
  # control. Three assertions: the author is declared and is not a placeholder token, the licence
  # names the same party, and the two do not silently diverge.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import json, os, re, sys
root = sys.argv[1]
man_path = os.path.join(root, ".claude-plugin", "plugin.json")
if not os.path.isfile(man_path):
    man_path = os.path.join(root, "plugin.json")
man = json.load(open(man_path))
author = man.get("author")
if isinstance(author, dict):
    author = author.get("name")
if not author or not str(author).strip():
    print("the manifest declares no author — the harness validator warns about exactly this")
    raise SystemExit(1)
if re.search(r"\[.*\]|<.*>|TODO|TBD|your name|put your", str(author), re.I):
    print("the author field holds a placeholder token: %r" % author)
    raise SystemExit(1)
lic = os.path.join(root, "LICENSE")
if not os.path.isfile(lic):
    print("no LICENSE file, so no copyright holder is declared anywhere")
    raise SystemExit(1)
text = open(lic, encoding="utf-8", errors="replace").read()
m = re.search(r"Copyright\s*(\(c\)|©)?\s*[0-9]{4}(-[0-9]{4})?\s+(.+)", text)
if not m:
    print("the LICENSE carries no copyright line naming a holder")
    raise SystemExit(1)
holder = m.group(3).strip().rstrip(".")
if re.search(r"the .* authors$", holder, re.I) and holder.lower() not in str(author).lower():
    print("the licence holder %r is a non-entity and does not match the declared author %r"
          % (holder, author))
    raise SystemExit(1)
a = re.sub(r"[^a-z0-9]", "", str(author).lower())
h = re.sub(r"[^a-z0-9]", "", holder.lower())
if a not in h and h not in a:
    print("the manifest author %r and the licence holder %r name different parties" % (author, holder))
    raise SystemExit(1)
print("author %r, licence holder %r, no placeholder token" % (author, holder))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "publish_identity_declared ($out)"
  else bad "publish_identity_declared" "$(printf '%s' "$out" | tail -1)"; fi
}

check_shipped_scripts_are_executable() {
  # The mode that matters is the one in the INDEX, not the one on this disk: a script can be
  # executable here and ship at 644, which is exactly how it happened. Two shipped documents invoke
  # one of these by bare path, so the permission-denied path is reachable exactly as documented.
  local out rc mode f base bad_files="" n=0
  if git -C "$PKG_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r line; do
      mode="${line%% *}"; base="${line#* }"
      n=$((n + 1))
      [ "$mode" = "100755" ] || bad_files="$bad_files $base($mode)"
    done < <(git -C "$PKG_ROOT" ls-files -s -- 'scripts/*.sh' 'tests/*.sh' 2>/dev/null \
             | $AWK '{print $1" "$4}')
    # TWO MORE WAYS A SCRIPT IS "NOT EXECUTABLE WHERE IT LANDS", both invisible to an enumeration
    # that starts from the index. A script sitting on the author disk and NOT tracked at all runs
    # perfectly here and does not exist in any clone - the same green-here-red-there shape as the
    # missing mode bit, one step earlier. And a document that tells a reader to run a bare path is
    # making a promise about that path: if it names a script the index does not carry at 100755,
    # the documented command is a permission error or a not-found for everyone but the author.
    # Each of the two extra harvests carries its own counter and its own floor. Neither one reports
    # a census: they accumulate PROBLEMS, and an accumulator that stays empty because its harvest
    # was empty prints exactly what a clean tree prints. A broken glob or a regex that stopped
    # matching would read as "nothing wrong here" in both.
    local untracked="" ondisk doc_bad="" cited n_disk=0 n_cited=0
    for f in "$PKG_ROOT"/scripts/*.sh "$PKG_ROOT"/tests/*.sh; do
      [ -f "$f" ] || continue
      n_disk=$((n_disk + 1))
      ondisk="${f#"$PKG_ROOT"/}"
      git -C "$PKG_ROOT" ls-files --error-unmatch -- "$ondisk" >/dev/null 2>&1 \
        || untracked="$untracked $ondisk"
    done
    for cited in $($GREP -rhoE '(^|[^`/A-Za-z0-9_.-])scripts/[a-z0-9-]+\.sh' "$PKG_ROOT" \
                     --include='*.md' --exclude-dir=.git --exclude-dir=drafts 2>/dev/null \
                   | $GREP -oE 'scripts/[a-z0-9-]+\.sh' | sort -u); do
      n_cited=$((n_cited + 1))
      [ "100755" = "$(git -C "$PKG_ROOT" ls-files -s -- "$cited" 2>/dev/null | $AWK '{print $1}')" ] \
        || doc_bad="$doc_bad $cited"
    done
    if [ "$n" -eq 0 ]; then
      bad "shipped_scripts_are_executable" "the index lists no script at all — an empty enumeration is not a pass"
    elif [ "$n_disk" -eq 0 ]; then
      bad "shipped_scripts_are_executable" "no script was found on disk, so the tracked-versus-present comparison ran over nothing and would have printed the same green over a tree with no scripts in it"
    elif [ "$n_cited" -eq 0 ]; then
      bad "shipped_scripts_are_executable" "no document cites a script by bare path, so the half of this check that holds documents to their own invocations harvested nothing and asserted over it"
    elif [ -n "$bad_files" ]; then
      bad "shipped_scripts_are_executable" "script(s) that ship without the executable bit IN THE INDEX:$bad_files"
    elif [ -n "$untracked" ]; then
      bad "shipped_scripts_are_executable" "script(s) present on this disk and absent from the index, so they are executable here and do not exist in any clone:$untracked"
    elif [ -n "$doc_bad" ]; then
      bad "shipped_scripts_are_executable" "document(s) prescribe a bare-path invocation of script(s) the index does not carry at 100755:$doc_bad"
    else
      ok "shipped_scripts_are_executable ($n scripts, every one 100755 in the index and tracked; $n_disk present on disk and $n_cited cited by bare path in a document, every citation naming one of them)"
    fi
    return
  fi
  for f in "$PKG_ROOT"/scripts/*.sh "$PKG_ROOT"/tests/*.sh; do
    [ -f "$f" ] || continue
    n=$((n + 1))
    [ -x "$f" ] || bad_files="$bad_files ${f#"$PKG_ROOT"/}"
  done
  if [ "$n" -eq 0 ]; then
    bad "shipped_scripts_are_executable" "no script was enumerated — an empty enumeration is not a pass"
  elif [ -n "$bad_files" ]; then
    bad "shipped_scripts_are_executable" "script(s) without the executable bit:$bad_files"
  else
    ok "shipped_scripts_are_executable ($n scripts executable ON DISK; this tree is not a checkout, so the index form of this assertion could not run)"
  fi
}

# -- the one network surface, and the single address it is allowed to read --------------------
# WHAT THE SIBLING CANNOT SEE. check_no_transmission_path holds a NAMED SET to zero: the config
# schema, the log writer and the setup skill. That set was the whole story while nothing in this
# tree could reach a network at all, and "0 call forms" was true of the package only because it
# was true of the subset that happened to be scanned. It stopped being the same sentence the day
# one script began reading a public file, and a call form beyond a scanned set is a call form
# nobody watches. So this check asks the opposite-shaped question, over the WHOLE tree: how many
# places here can reach a network, and is each one the place this package declared?
#
# WHY NOT WIDEN THE SIBLING INSTEAD. Its first assertion bans the transfer tool by token outright.
# Widening it to cover this script would mean exempting that token, which blunts the guard standing
# over the usage-log surface - the one surface whose entire promise is that it has no destination.
# Two checks with two scopes keep both sentences true.
#
# THE ALLOWLIST, AND THE REASON FOR IT, recorded here beside the assertion rather than in a table
# somewhere else. The one address is this package's own published manifest, read so the plugin can
# tell somebody their copy is behind. It is admitted BY ITS EXACT STRING and never by shape, so a
# second destination - or this same host with a different path - is a failure and not a variant.
# The meta-schema declaration the sibling strips by exact string is the precedent for the form.
#
# WHAT IS ASSERTED, in four parts. (a) exactly one file in the tree carries a network call form,
# and it is the declared one, which also answers the narrower question about scripts/; (b) that
# file carries exactly one address literal and it equals the allowlisted string; (c) the read is a
# plain one - no flag on it that would attach a body, change the method, upload a file or follow a
# redirect, because a followed redirect moves the destination at run time where nothing static can
# see it; (d) the address is a CONSTANT on one line, assigned once, with no expansion anywhere on
# that line - an environment-substitutable destination would make an exact-string allowlist
# decorative.
#
# THE CONTROLS RUN BEFORE THE VERDICT, on copies held in memory rather than on any file. Seven
# defects are planted into the declared surface and this check's own predicate is run over each
# one: a second destination on the same host and on another, the one address swapped for a
# different path on that host, a body, a method, a followed redirect, and the constant turned into
# an environment read. Every one of them must be reported. A control that does not fire is not a
# control, and a predicate that cannot be shown failing has not been shown to do anything.
check_one_network_surface() {
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import os, re, sys

root = sys.argv[1]

# The call forms that can reach a network, written as joined fragments so that THIS file does not
# carry the tokens it bans. That is load-bearing rather than tidy here: the walk below reads every
# file in the tree, and the suite is one of them.
NET = ("c" "url|w" "get|net" "cat|\\bnc[ \t]|te" "lnet|\\bf" "tp\\b|\\bs" "cp\\b|rs" "ync|"
       "\\bss" "h[ \t]|u" "rllib|urlo" "pen|re" "quests\\.|http" "lib|http\\.cl" "ient|"
       "so" "cket\\.|web" "socket|xml" "http|f" "etch\\(")
NETRX = re.compile(NET, re.I)

# THE ONE ADDRESS. Same joined form, same reason.
ALLOWED_URL = ("ht" "tps://raw.githubusercontent.com/"
               "nad" "erel" "ewa"
               "/Product-to-Prod/main/.claude-plugin/plugin.json")
SURFACE = os.path.join("scripts", "update-check.sh")

# The excluded set is assembled rather than typed: a literal backtick inside a here-document that
# sits in a command substitution is read by the shell as a substitution of its own, which is why
# the sibling checks in this file spell one chr(96) too.
URLRX = re.compile("[A-Za-z][A-Za-z0-9+.-]*://[^\\s\"'" + chr(96) + ")>]+")
# Case-SENSITIVE, and that is the point: -F is a form upload and -f is a failure mode, and the
# declared read carries -f today. A case-blind list would fail the very line it is written for.
SENDRX = re.compile(r"(?:^|\s)(-d|--data(?:-[a-z]+)?|-X|--request|-T|--upload-file|-F|--form"
                    r"|-L|--location)(?:\s|=|$)"
                    # A bundled short-flag cluster smuggles the same letters past the standalone
                    # form (-fsSL redirects exactly as -L does), so any single-dash cluster
                    # carrying one of the send/redirect letters fails too. The declared read's
                    # own cluster (-fsS) carries none of them, which is why it stays green.
                    r"|(?:^|\s)-[A-Za-z]*[dXTFL][A-Za-z]*(?:\s|=|$)")
ASSIGNRX = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)=")


def scan(tree):
    """tree: {root-relative path -> text}. Returns the list of things wrong with it."""
    problems = []
    carriers = sorted(p for p, t in tree.items() if NETRX.search(t))
    for p in carriers:
        if p == SURFACE:
            continue
        n = next(i for i, l in enumerate(tree[p].splitlines(), 1) if NETRX.search(l))
        problems.append("%s:%d carries a network call form and is not the one declared surface"
                        % (p, n))
    if SURFACE not in carriers:
        problems.append("%s carries no network call form at all, so the file this allowlist is "
                        "written for is not the one doing the reading" % SURFACE)
        return problems
    text = tree[SURFACE]
    lines = text.splitlines()
    urls = URLRX.findall(text)
    if len(urls) != 1:
        problems.append("%s carries %d address literal(s) and the allowlist admits exactly one: %s"
                        % (SURFACE, len(urls), ", ".join(sorted(set(urls))[:3])))
    elif urls[0] != ALLOWED_URL:
        problems.append("%s reads an address the allowlist does not admit by exact string: %s"
                        % (SURFACE, urls[0]))
    for n, line in enumerate(lines, 1):
        if not NETRX.search(line):
            continue
        m = SENDRX.search(line)
        if m:
            problems.append("%s:%d the read carries %s, so it is no longer the plain read this "
                            "exemption is for" % (SURFACE, n, m.group(1)))
    holders = [(n, l) for n, l in enumerate(lines, 1) if URLRX.search(l)]
    if len(holders) != 1:
        problems.append("%s spreads its destination over %d line(s), and a constant on one line is "
                        "the only thing an exact-string allowlist can be checked against"
                        % (SURFACE, len(holders)))
    else:
        n, line = holders[0]
        m = ASSIGNRX.match(line)
        if not m:
            problems.append("%s:%d the address is not a plain assignment, so what it resolves to at "
                            "run time is not what this check read" % (SURFACE, n))
        elif "$" in line:
            problems.append("%s:%d the address line carries an expansion, so the environment can "
                            "substitute the destination and this allowlist is decorative"
                            % (SURFACE, n))
        else:
            name = m.group(1)
            again = [i for i, l in enumerate(lines, 1)
                     if i != n and re.match(r"^\s*%s=" % re.escape(name), l)]
            if again:
                problems.append("%s: the destination variable %s is assigned again at line(s) %s, "
                                "so the constant this check read is not the one that runs"
                                % (SURFACE, name, again))
    return problems


real, unreadable = {}, []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
    for f in sorted(filenames):
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        try:
            real[rel] = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            unreadable.append(rel)
if len(real) < 40:
    print("the walk read %d file(s) under %s - an empty or truncated walk is not a clean verdict"
          % (len(real), root))
    raise SystemExit(1)
if unreadable:
    print("unreadable file(s), and an unreadable file is not a clean one: %s" % unreadable[:3])
    raise SystemExit(1)
if SURFACE not in real:
    print("%s is not in this tree, so the file the allowlist names does not exist" % SURFACE)
    raise SystemExit(1)

SWAPPED = ALLOWED_URL.replace("/main/", "/some-other-branch/")
OTHER_HOST = "ht" "tps://example.invalid/.claude-plugin/plugin.json"
CONTROLS = [
    ("a second destination on the same host",
     lambda t: t + "\n_pkg_alt=\"%s\"\n" % SWAPPED),
    ("a second destination on another host",
     lambda t: t + "\n_pkg_alt=\"%s\"\n" % OTHER_HOST),
    ("the one address swapped for another path on that same host",
     lambda t: t.replace(ALLOWED_URL, SWAPPED)),
    ("a body attached to the read", lambda t: t.replace(" --max-time", " -d '' --max-time")),
    ("a method set on the read", lambda t: t.replace(" --max-time", " -X POST --max-time")),
    ("redirects followed", lambda t: t.replace(" --max-time", " -L --max-time")),
    ("the constant turned into an environment read",
     lambda t: t.replace('="%s"' % ALLOWED_URL, '="${PKG_UPDATE_URL:-%s}"' % ALLOWED_URL)),
]

dead, silent = [], []
for label, mutate in CONTROLS:
    planted = dict(real)
    planted[SURFACE] = mutate(real[SURFACE])
    if planted[SURFACE] == real[SURFACE]:
        dead.append(label)
    elif not scan(planted):
        silent.append(label)
if dead:
    print("control(s) that changed nothing, so they proved nothing: %s" % "; ".join(dead))
    raise SystemExit(1)
if silent:
    print("planted defect(s) this check did not report: %s" % "; ".join(silent))
    raise SystemExit(1)

problems = scan(real)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)

in_scripts = sorted(p for p in real if p.startswith("scripts" + os.sep) and NETRX.search(real[p]))
print("%d file(s) walked, %d of them carrying a network call form: %s, the one declared surface "
      "(%d in scripts/, and it is that same file). It reads one address, admitted by exact string "
      "and not by shape, as a plain constant assigned once with no expansion on its line. %d "
      "planted defect(s) - a second destination on this host and on another, a swapped path, a "
      "body, a method, a followed redirect, an environment-substitutable constant - were each "
      "reported before this verdict"
      % (len(real), 1, SURFACE, len(in_scripts), len(CONTROLS)))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "update_check_is_the_one_network_surface ($out)"
  else bad "update_check_is_the_one_network_surface" "$(printf '%s' "$out" | tail -1)"; fi
}

check_rungs() {
  # Every install option is a rung, and a rung has to hold: each command the documents tell an
  # option to run must be satisfiable from what that option actually delivers. The option that
  # copies only the skills folder cannot run the setup wizard to completion, so it has to say so —
  # and the wizard's own STOP has to tell whoever lands on it how to continue.
  local readme="$PKG_ROOT/README.md" wiz="$PKG_ROOT/skills/init/SKILL.md" problems=""
  [ -f "$readme" ] && [ -f "$wiz" ] || { bad "rungs" "README.md or the setup skill is missing, so the install ladder cannot be read"; return; }
  # SCOPED, NOT ANYWHERE-IN-FILE: the recovery has to live inside the STOP block itself, and it has
  # to name the option as the ladder writes it. An anywhere-in-file grep passed on a neighbouring
  # sentence that merely contained the words, so deleting the recovery shipped green.
  if ! $GREP -A4 'STOP:' "$wiz" 2>/dev/null | $GREP -qiE 'move to install option 3'; then
    problems="$problems no-recovery-line-in-the-STOP-block"
  fi
  local out
  out=$(python3 - "$readme" 2>&1 <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
paras = re.split(r"\n\s*\n", text)
opts = [p for p in paras if re.search(r"^\s*(\d+\.|\*\*?Option\s*\d)", p, re.M | re.I)]
partial = []
for p in paras:
    if re.search(r"skills?[ -]only|copy (just |only )?the skills", p, re.I):
        if not re.search(r"cannot|can't|will not|won't|does not|doesn't|limit|without", p, re.I):
            partial.append(" ".join(p.split())[:70])
if not opts and not partial:
    print("no install option was found to read — an empty ladder is not a pass")
    raise SystemExit(1)
if partial:
    print("an install option describes a skills-only copy and never names what it cannot do: %s"
          % partial[0])
    raise SystemExit(1)
print("%d install option block(s), every partial-copy option naming its limit" % max(len(opts), 1))
PY
)
  if [ $? -ne 0 ]; then problems="$problems $(printf '%s' "$out" | tail -1 | tr ' ' '-')"; fi
  if [ -z "$problems" ]; then
    ok "rungs (every install option's commands are satisfiable from what it delivers, and the wizard's STOP names the way forward)"
  else
    bad "rungs" "the install ladder does not hold:$problems"
  fi
}

check_ladder() {
  # One ladder, composed in one place, stated on four surfaces. The code appends a per-plugin folder
  # to the state and config directories; every surface that writes the ladder down has to carry the
  # same rungs in the same order, or a user consents against a path the tool will not use.
  local out rc
  out=$(python3 - "$PKG_ROOT" 2>&1 <<'PY'
import os, re, sys
root = sys.argv[1]
src = open(os.path.join(root, "scripts", "telemetry.sh"), encoding="utf-8", errors="replace").read()
m = re.search(r'_pkg_slug="([^"]+)"', src)
if not m:
    print("the writer declares no per-plugin folder name, so there is no ladder to compare against")
    raise SystemExit(1)
slug = m.group(1)
# what may legally follow a rung: the slug itself, or a placeholder standing in for it
OK_TAIL = re.compile(r"^/(%s\b|<slug>|\$|\{|%%s|\.\.\.)" % re.escape(slug))
RUNG = re.compile(r"(\.local/state|\.config)(?=/|\b)")
# the same three rungs as WORDS, with the order the code composes them
PROSE_RUNGS = {"home directory": 1, "your home": 1, "the home": 1,
               "state directory": 2, "config directory": 2,
               "plugin folder": 3, "per-plugin folder": 3, "plugin directory": 3}
PROSE_LOG = re.compile(r"\b(log|logs|usage log|log path|log directory|event log)\b")
problems, surfaces = [], 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "drafts")]
    for f in sorted(filenames):
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, root)
        if rel.startswith("tests/"):
            continue
        try:
            lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for n, line in enumerate(lines, 1):
            for mm in RUNG.finditer(line):
                surfaces += 1
                tail = line[mm.end():]
                if not tail or not tail.startswith("/"):
                    continue          # the rung named on its own, not a composed path
                if OK_TAIL.match(tail):
                    continue
                problems.append("%s:%d states %s%s without the per-plugin folder"
                                % (rel, n, mm.group(1), tail[:24]))
            # THE LADDER WRITTEN IN WORDS, which is how a reader most often meets it and which a
            # path-shaped scan cannot see at all. "Logs go to the plugin folder inside the state
            # directory inside the home" names the same three rungs the code composes, in the
            # opposite order, and a user who follows it looks in the wrong place. So a sentence
            # that names two or more rungs in words has to name them in the order the code builds
            # them, and a sentence that states where the log lives has to include the per-plugin
            # folder - the rung this whole rule is about.
            low = line.lower()
            if PROSE_LOG.search(low):
                pos = [(low.find(w), w) for w in PROSE_RUNGS if low.find(w) >= 0]
                pos.sort()
                if len(pos) >= 2:
                    order = [PROSE_RUNGS[w] for _, w in pos]
                    surfaces += 1
                    if order != sorted(order):
                        problems.append("%s:%d states the ladder in words in the wrong order (%s); "
                                        "the code composes home, then the state or config "
                                        "directory, then the per-plugin folder"
                                        % (rel, n, ", ".join(w for _, w in pos)))
                    elif not any(PROSE_RUNGS[w] == 3 for _, w in pos):
                        problems.append("%s:%d states where the log lives and never names the "
                                        "per-plugin folder: %.60s" % (rel, n, line.strip()))
if not surfaces:
    print("no surface states the config or log ladder — nothing to keep in step, which is not a pass")
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d ladder mention(s) across the shipped surfaces, every composed path carrying the "
      "per-plugin folder %r" % (surfaces, slug))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "ladder ($out)"
  else bad "ladder" "$(printf '%s' "$out" | tail -1)"; fi
}

# THE WIZARD GOLDEN. The setup wizard quotes what the tool prints, and a reader is told to match it
# literally. Two checks, falsifiable in OPPOSITE directions against ONE source of truth:
#   wizard_output_matches_golden   the live tool must still produce the golden's lines
#   wizard_quotes_match_golden     the document must quote the golden byte for byte
# Deriving the expectation live in both directions would be vacuous — it would compare the tool to
# itself — which is why the golden is a committed file and each check can be broken on its own.
golden_file() {
  local c
  for c in "$PKG_ROOT/references/wizard-expected.txt" "$HERE/wizard-expected.txt"; do
    [ -r "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# BOTH CHECKS COUNT, AND BOTH COUNT AGAINST THE SAME PINNED NUMBER. Each assertion below is of the
# form "every line of the golden ...", which is a statement about a list the checks read from the
# file under test — so a golden emptied of its payload makes both statements vacuously true, and a
# golden emptied of MOST of its payload leaves both green while the thing they guard has shrunk.
# One check used to count and floor at zero and the other counted nothing at all, so the pair could
# not see either form. golden_lines in tests/expected-checks.txt is the second opinion neither
# check can derive from the golden, and both compare against it.
check_wizard_output_matches_golden() {
  local g live home missing="" line n=0 want
  g="$(golden_file)" || { bad "wizard_output_matches_golden" "no committed golden at references/wizard-expected.txt (or tests/wizard-expected.txt) — the wizard's verification step quotes text nothing pins, which is the state in which it can never pass"; return; }
  want="$(expect_val golden_lines)"
  if [ -z "$want" ]; then
    bad "wizard_output_matches_golden" "tests/expected-checks.txt pins no golden_lines count, so 'every line of the golden' is an assertion over a list the golden itself decides the length of"
    return
  fi
  home="$TMP/golden-home"; mkdir -p "$home"
  live=$(env -i PATH="$PATH" HOME="$home" TMPDIR="$TMP" \
         bash "$PKG_ROOT/scripts/telemetry.sh" status 2>&1
         env -i PATH="$PATH" HOME="$home" TMPDIR="$TMP" \
         bash "$PKG_ROOT/scripts/telemetry.sh" consent off "golden check" 2>&1)
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    n=$((n + 1))
    printf '%s' "$live" | $GREP -qF -- "$line" || missing="$missing [$line]"
  done < "$g"
  if [ "$n" -ne "$want" ]; then
    bad "wizard_output_matches_golden" "the golden carries $n payload line(s) against a pinned $want — a golden that shrank takes this assertion down with it, and a golden that grew was pinned by nobody"
  elif [ -z "$missing" ]; then
    ok "wizard_output_matches_golden (all $n line(s) of the committed golden, its pinned count, are still produced by the tool)"
  else
    bad "wizard_output_matches_golden" "the tool no longer prints golden line(s):$missing"
  fi
}

check_wizard_quotes_match_golden() {
  local g wiz="$PKG_ROOT/skills/init/SKILL.md" missing="" line n=0 want
  g="$(golden_file)" || { bad "wizard_quotes_match_golden" "no committed golden at references/wizard-expected.txt (or tests/wizard-expected.txt) — nothing pins the text the wizard tells a reader to match"; return; }
  [ -f "$wiz" ] || { bad "wizard_quotes_match_golden" "no setup skill to compare the golden against"; return; }
  want="$(expect_val golden_lines)"
  if [ -z "$want" ]; then
    bad "wizard_quotes_match_golden" "tests/expected-checks.txt pins no golden_lines count, so this check would assert over whatever the golden happens to hold"
    return
  fi
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    n=$((n + 1))
    $GREP -qF -- "$line" "$wiz" || missing="$missing [$line]"
  done < "$g"
  if [ "$n" -ne "$want" ]; then
    bad "wizard_quotes_match_golden" "the golden carries $n payload line(s) against a pinned $want — a partial gutting leaves both golden checks green over a shorter list, which is the state this pin exists to make visible"
  elif [ -z "$missing" ]; then
    ok "wizard_quotes_match_golden (all $n golden line(s), its pinned count, quoted byte-for-byte in the setup skill)"
  else
    bad "wizard_quotes_match_golden" "the setup skill does not quote golden line(s):$missing"
  fi
}

check_manifest_is_installable
check_publish_identity_declared
check_shipped_scripts_are_executable
check_one_network_surface
check_rungs
check_ladder
check_wizard_output_matches_golden
check_wizard_quotes_match_golden

# --- repo history: what the repository remembers about itself ---
banner "repo-history"

check_commit_messages_are_clean() {
  # A commit message is a published byte. Subjects, bodies, trailers, tag annotations and branch
  # names all travel with a plain clone, and none of them is covered by a scan that walks the
  # working tree. This runs the SHIPPED scanner over the harvested history, so the rules are the
  # same rules — and in maintainer mode, with the private overlay attached, it is the same check
  # that catches a private build id pasted into a subject line.
  # AND THE COMMIT IDS STAY OUT OF THE SCANNED BYTES, which is the whole reason the harvest has the
  # shape it has. The first form of this check wrote the full id at the head of every message with
  # %H, straight into the file the scanner then read — and the shipped pattern set bans any token of
  # forty characters or more, which is exactly what a full commit id is. The result was a check that
  # reported a hit for every commit in any repository, so it could not go green on a clean history
  # and its red said nothing about the history it was reading. The release gate had already written
  # down the avoidance ("a gate that fails on its own harvesting is a gate nobody keeps"); this is
  # the same construction, so the two gates read the same history the same way:
  #
  #   ONE FILE PER COMMIT AND FIELD, the id in the FILE NAME and never in the bytes. A hit then
  #   names the commit and the field it sits in with no index to keep in step, and the harvest
  #   cannot manufacture a hit of its own — the id in the name is abbreviated and is never scanned.
  #
  # AND ALL FOUR IDENTITY FIELDS ARE HARVESTED, names and addresses alike. The addresses used to be
  # left out as the release gate's call to make, on the reading that this check "reads the same
  # fields it does" — and that sentence stopped being true the moment the release gate started
  # reading them, which is the drift a parity claim is supposed to catch rather than cause. It is
  # also wrong on this check's own premise: a published byte is whatever travels with every clone,
  # and %ae/%ce travel with every clone. A default address is a machine login at a machine hostname.
  #
  # ADDRESSES ARE HARVESTED SPLIT AT THE @, one part per line, labelled, for exactly the reason the
  # commit ids live in the file names: an ADDRESS SHAPE is itself one of the shipped deny patterns,
  # so harvesting the whole string would make this check fail on every commit of every repository —
  # the never-passable form this check was just repaired out of. Split, the shape cannot fire while
  # every identity, host, machine and vendor pattern still gets its shot at both halves. What this
  # deliberately does not do is judge an address for being an address. Same construction as the
  # release gate's, so the two gates read the same history the same way.
  local work out rc n n_refs sha short refname flat
  if ! git -C "$PKG_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    bad "commit_messages_are_clean" "this tree is not a checkout, so the history the release gate publishes cannot be read — a gate that cannot run has not been passed"
    return
  fi
  work="$TMP/history"; mkdir -p "$work"
  n=0
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    short=$(git -C "$PKG_ROOT" rev-parse --short "$sha" 2>/dev/null || printf 'unknown')
    git -C "$PKG_ROOT" log -1 --format='%s' "$sha" > "$work/commit-$short-subject.txt" 2>/dev/null
    git -C "$PKG_ROOT" log -1 --format='%b' "$sha" > "$work/commit-$short-body-and-trailers.txt" 2>/dev/null
    git -C "$PKG_ROOT" log -1 --format='%an%n%cn' "$sha" > "$work/commit-$short-author-names.txt" 2>/dev/null
    git -C "$PKG_ROOT" log -1 --format='author-address %ae%ncommitter-address %ce' "$sha" \
      | tr '@' '\n' > "$work/commit-$short-author-addresses.txt" 2>/dev/null
    n=$((n + 1))
  done < <(git -C "$PKG_ROOT" rev-list HEAD 2>/dev/null)
  n_refs=0
  while IFS= read -r refname; do
    [ -n "$refname" ] || continue
    flat=$(printf '%s' "$refname" | tr '/' '_')
    git -C "$PKG_ROOT" for-each-ref --format='%(refname:short)%0a%(contents)' "$refname" \
      > "$work/ref-$flat-annotation.txt" 2>/dev/null
    n_refs=$((n_refs + 1))
  done < <(git -C "$PKG_ROOT" for-each-ref --format='%(refname)' 2>/dev/null)
  if [ "$n" -eq 0 ]; then
    bad "commit_messages_are_clean" "no commit message could be harvested — a history gate over nothing is not a pass"
    return
  fi
  if [ "$n_refs" -eq 0 ]; then
    bad "commit_messages_are_clean" "no ref annotation could be harvested, so the half of this gate that reads tag and branch annotations ran over an empty directory"
    return
  fi
  out=$(bash "$PKG_ROOT/scripts/publish-lint.sh" --denylist "$PKG_ROOT/config/denylist.txt" "$work" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then
    ok "commit_messages_are_clean ($n commit(s) and $n_refs ref annotation(s) scanned with the shipped pattern set, all four identity fields included with the addresses split at the @, the commit ids in the file names and never in the scanned bytes, no hit)"
  elif [ $rc -eq 1 ]; then
    bad "commit_messages_are_clean" "a commit message, trailer, author or committer name, an author or committer address, or a ref annotation carries a banned token, named below as commit-<id>-<field> (an address hit names the half of the address it sits in, because addresses are harvested split at the @): $(printf '%s' "$out" | $GREP -m2 ':.*\[' | tr '\n' ' ')"
  else
    bad "commit_messages_are_clean" "the scanner could not run over the harvested history (rc=$rc) — never a clean verdict"
  fi
}

check_commit_messages_are_clean

# --- the release gates: what the tool that tags and publishes refuses to do ---
banner "release-gates"

# A SCRATCH CHECKOUT the release script can be pointed at. The script derives its package root from
# its own location and runs its gates over the working tree, so the only honest way to exercise it
# is a real copy in a real repository. Both checks below build one, and neither ever reaches the
# tag/push/publish block: every assertion is about a gate that stops the run before it.
#
# The scratch bin holds a stub for the release CLI. That tool is used exactly once, at the very end,
# to create the release page — a step no assertion here reaches. The stub exists only so the
# prerequisite probe passes on a machine that has never installed it, which is what keeps these two
# checks runnable from a cold clone.
release_fixture() {  # $1 = destination root; leaves a committed checkout there, or returns non-zero
  local dest="$1"
  mkdir -p "$dest/bin" || return 1
  # the shebang and the address below are ASSEMBLED, so this file's own bytes stay clean under the
  # scanner it ships with: a literal interpreter path is a hardcoded tool path to one check, and a
  # literal address is a banned token to another.
  fixture_write "$dest/bin/gh" "$(printf '#!/%s/sh' bin)" 'echo "stub release CLI: this run never reaches the publish step" >&2' 'exit 1' || return 1
  chmod +x "$dest/bin/gh" || return 1
  cp -R "$PKG_ROOT" "$dest/pkg" 2>/dev/null || return 1
  chmod -R u+w "$dest/pkg" 2>/dev/null
  rm -rf "$dest/pkg/.git"
  ( cd "$dest/pkg" \
    && git init -q . \
    && git config user.email "$(printf 'fixture%sexample.invalid' '@')" \
    && git config user.name "release fixture" \
    && git add -A \
    && git commit -q -m "release fixture: one ordinary commit" ) >/dev/null 2>&1 || return 1
  return 0
}

check_release_runs_the_history_gate() {
  # Nothing in the package reads git metadata, and the release script publishes a page generated
  # from that unread metadata. So the FIRST thing the release does is lint every commit message,
  # trailer, author name and ref annotation reachable from the head, and die on any hit naming the
  # commit and the field. Proved over a scratch checkout with a planted subject line: gate 1 must
  # be the gate that stops it. The positive half is proved by a second scratch checkout whose
  # history is clean, where the run reaches and passes gate 1 before anything else runs.
  local rel work out rc misses="" ov ver
  if ! command -v git >/dev/null 2>&1; then
    bad "release_runs_the_history_gate" "git is not on the command path, so the history the release gate publishes cannot be built or read — a gate that cannot run has not been passed"
    return
  fi
  # THE VERSION IS READ FROM THE MANIFEST, not invented. The release refuses a tag that disagrees
  # with the declared version, and that refusal fires before gate 1 — so a fixture carrying an
  # arbitrary version number would prove the wrong refusal and report the history gate as broken.
  ver=$($GREP -oE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' \
          "$PKG_ROOT/.claude-plugin/plugin.json" 2>/dev/null \
        | $GREP -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -z "$ver" ]; then
    bad "release_runs_the_history_gate" "the manifest declares no version, so this check cannot ask the release for a tag the release will accept"
    return
  fi
  $GREP -qE 'gate 1 of 3 - commit-message lint' "$PKG_ROOT/scripts/release.sh" || \
    misses="$misses [the commit-message lint is not the first of the release gates]"
  $GREP -qE 'gate 1 of 3 FAILED' "$PKG_ROOT/scripts/release.sh" || \
    misses="$misses [nothing dies when the history lint finds a hit, so the gate reports rather than stops]"
  work="$TMP/relhist"; mkdir -p "$work"
  fixture_write "$work/outside-overlay.txt" '# synthetic overlay fixture. No real private literal appears here.' 'zzsynthetic-release-entry' || {
    bad "release_runs_the_history_gate" "could not write the synthetic overlay fixture"; return; }
  ov="$work/outside-overlay.txt"
  if ! release_fixture "$work/dirty"; then
    bad "release_runs_the_history_gate" "could not build the scratch checkout the release gate has to run over"
    return
  fi
  rel="$work/dirty/pkg/scripts/release.sh"
  ( cd "$work/dirty/pkg" \
    && git commit -q --allow-empty -m "note: /$(printf 'U%ss' 'ser')/somebody/private.txt" ) >/dev/null 2>&1 || {
    bad "release_runs_the_history_gate" "could not plant a commit message for the history gate to catch"; return; }
  out=$(PATH="$work/dirty/bin:$PATH" bash "$rel" "v$ver" --overlay "$ov" --dry-run 2>&1); rc=$?
  [ "$rc" = 1 ] || misses="$misses [a planted commit message did not stop the release (exit $rc)]"
  printf '%s' "$out" | $GREP -q 'gate 1 of 3 FAILED' || \
    misses="$misses [the run did not die at gate 1, so the history is not the first thing the release reads]"
  printf '%s' "$out" | $GREP -q 'gate 2 of 3' && \
    misses="$misses [the run carried on to the confidentiality scan after the history gate failed]"
  printf '%s' "$out" | $GREP -q 'Nothing was tagged, pushed or published' || \
    misses="$misses [the failure does not say that nothing was tagged, pushed or published]"
  # the positive half: a clean history reaches and passes gate 1 before any other gate runs
  if ! release_fixture "$work/clean"; then
    bad "release_runs_the_history_gate" "could not build the clean-history scratch checkout"
    return
  fi
  printf 'note: /%s/somebody/planted.txt\n' "$(printf 'U%ss' 'ser')" > "$work/clean/pkg/LEAK-FOR-GATE-2.md"
  ( cd "$work/clean/pkg" && git add -A && git commit -q -m "fixture: a leak for the second gate to stop on" ) >/dev/null 2>&1
  out=$(PATH="$work/clean/bin:$PATH" bash "$work/clean/pkg/scripts/release.sh" "v$ver" --overlay "$ov" --dry-run 2>&1); rc=$?
  printf '%s' "$out" | $GREP -q 'gate 1 of 3 PASSED' || \
    misses="$misses [a clean history did not pass gate 1, so the gate cannot distinguish a bad message from any message]"
  printf '%s' "$out" | $GREP -qE 'harvested [0-9]+ commit' || \
    misses="$misses [the gate never says how much history it harvested, so a harvest of nothing would read like a pass]"
  if [ -z "$misses" ]; then
    ok "release_runs_the_history_gate (the commit-message lint is the release's first gate: a planted subject line stops the run at gate 1 with nothing tagged, and a clean history passes it and names the number of commits harvested)"
  else
    bad "release_runs_the_history_gate" "the release does not gate on the history it publishes:$misses"
  fi
}

check_release_runs_the_history_gate

# --- the suite's own floor: the checks that keep the checks honest ---
banner "suite-floor"

check_harvest_floor() {
  # A loop over a sub-command's output, or over a glob, passes vacuously the moment the list is
  # empty: the body never runs and the check reports success over nothing. Every harvesting site in
  # this file must carry a counter and a floor, and this is the census that says so.
  #
  # WHAT "FLOORED" HAS TO MEAN, and what the first form of this census settled for. It read a flat
  # window of the following lines and accepted any floor-shaped text inside it, so a site was
  # credited by whatever happened to be pasted nearby: the counter of an unrelated loop below it,
  # or the declaration line of the NEXT function. The same loop passed or failed depending only on
  # where it was pasted, which makes the census a measure of layout rather than of floors. So the
  # attribution is structural now, on two axes at once:
  #
  #   SCOPE      a floor may only credit a site inside the SAME check function. Nothing across a
  #              function boundary counts, because nothing across a function boundary runs.
  #   OWNERSHIP  the floor has to name the counter THIS loop's own body increments. A neighbour's
  #              counter compared to zero says nothing about whether this harvest was empty.
  #
  # A site that legitimately cannot carry a counter says so on its own line, in the form
  # "(unfloored: <reason>)", and the excused count is printed rather than absorbed.
  local out rc
  out=$(python3 - "$HERE" 2>&1 <<'PY'
import os, re, sys
here = sys.argv[1]
path = os.path.join(here, "run-tests.sh")
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
base = os.path.basename(path)
HARVEST = re.compile(r"^\s*(for\s+\w+\s+in\s+(\$\(|[^\n]*/[^\n]*\*)|while\s+IFS=.*read)")
HEREDOC_OPEN = re.compile(r"<<-?\s*[\"\']?([A-Za-z_][A-Za-z0-9_]*)[\"\']?\s*$")
FUNC_OPEN = re.compile(r"^([a-z_][a-z0-9_]*)\(\)\s*\{")
# X=$((X + 1)) and ((X++)) / ((X += 1)) — an increment of the counter's OWN name, never of another
COUNTER = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)=\$\(\(\s*\1\s*\+\s*1\s*\)\)"
                     r"|\(\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:\+\+|\+=\s*1)\s*\)\)")
LOOP_OPEN = re.compile(r"^\s*(for|while|until)\b")
LOOP_CLOSE = re.compile(r"^\s*done\b")
EXCUSED = re.compile(r"\(unfloored:\s*\S")

def floor_of(name):
    return re.compile(r"\"?\$\{?%s\}?\"?\s*(-eq|-ne|-lt|-le|-gt|-ge)\s+\"?\$?\{?[A-Za-z0-9_]"
                      % re.escape(name))

# A quoted shell body passed to bash -c is a program of its own with its own floors; reading its
# loops as top-level harvest sites would report a floor that is there, just outside the window.
INNER = 0
HEREDOC = None
skip = [False] * len(lines)
spans, fn_name, fn_start = [], None, 0
for i, line in enumerate(lines):
    if HEREDOC is not None:
        skip[i] = True
        if line.strip() == HEREDOC:
            HEREDOC = None
        continue
    hm = HEREDOC_OPEN.search(line)
    if hm:
        HEREDOC = hm.group(1); skip[i] = True; continue
    if re.search(r"bash -c '$", line):
        INNER = 1; skip[i] = True; continue
    if INNER and re.match(r"^\s*' _ ", line):
        INNER = 0; skip[i] = True; continue
    if INNER:
        skip[i] = True; continue
    m = FUNC_OPEN.match(line)
    if m:
        if fn_name is not None:
            spans.append((fn_name, fn_start, i - 1))
        fn_name, fn_start = m.group(1), i
        continue
    if line == "}" and fn_name is not None:
        spans.append((fn_name, fn_start, i)); fn_name = None
if fn_name is not None:
    spans.append((fn_name, fn_start, len(lines) - 1))

def enclosing(i):
    for name, a, b in spans:
        if a <= i <= b:
            return name, a, b
    return None, None, None

sites, excused, unfloored = 0, 0, []
for i, line in enumerate(lines):
    if skip[i] or not HARVEST.match(line):
        continue
    sites += 1
    if EXCUSED.search(line):
        excused += 1
        continue
    name, a, b = enclosing(i)
    if name is None:
        unfloored.append("%s:%d  harvests outside any check function, where no floor can be "
                         "attributed to it at all" % (base, i + 1))
        continue
    depth, end = 1, b
    for j in range(i + 1, b + 1):
        if skip[j]:
            continue
        if LOOP_CLOSE.match(lines[j]):
            depth -= 1
            if depth == 0:
                end = j
                break
        elif LOOP_OPEN.match(lines[j]):
            depth += 1
    counters = set()
    for j in range(i, end + 1):
        for m in COUNTER.finditer(lines[j]):
            counters.add(m.group(1) or m.group(2))
    if not counters:
        unfloored.append("%s:%d  in %s(): the loop body increments no counter of its own, so an "
                         "empty harvest reports exactly what a clean one reports"
                         % (base, i + 1, name))
        continue
    body = "\n".join(lines[a:b + 1])
    if not any(floor_of(c).search(body) for c in sorted(counters)):
        unfloored.append("%s:%d  in %s(): counter(s) %s are incremented and never compared inside "
                         "the same function, so this site is floored only by a neighbour's number"
                         % (base, i + 1, name, "/".join(sorted(counters))))
if len(spans) < 20:
    print("the census resolved only %d function scope(s) in this file — it has stopped reading the "
          "structure it attributes floors against" % len(spans))
    raise SystemExit(1)
if sites == 0:
    print("no harvesting site was found in the suite — the census has nothing to census")
    raise SystemExit(1)
if unfloored:
    print("harvest site(s) with no count floor of their own: " + "; ".join(unfloored[:3]))
    raise SystemExit(1)
print("%d harvesting site(s) across %d function scope(s), every one counted and floored by its own "
      "counter inside its own function, %d excused by name" % (sites, len(spans), excused))
PY
)
  rc=$?
  if [ $rc -eq 0 ]; then ok "harvest_floor ($out)"
  else bad "harvest_floor" "$(printf '%s' "$out" | tail -1)"; fi
}

check_temp_dirs_honor_tmpdir() {
  # A sandbox where only the platform's temp location is writable is a real place to run this, and
  # a site that hardcodes another one fails there for no reason. Both halves: every scratch
  # directory honours the platform variable, and every failure message after one carries the cause
  # the tool printed rather than a bare "could not".
  local sites bare causeless needle
  # the needle is assembled, so this check's own source lines are not census subjects
  needle="$(printf '%s%s' 'mktemp' ' -d ')"
  sites=$($GREP -rnF "$needle" "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null | wc -l | tr -d ' ')
  bare=$($GREP -rnF "$needle" "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null \
         | $GREP -v 'TMPDIR' | head -3 | tr '\n' ' ')
  if [ "$sites" -eq 0 ]; then
    bad "temp_dirs_honor_tmpdir" "no scratch-directory site was found — the census has nothing to census"
    return
  fi
  if [ -n "$bare" ]; then
    bad "temp_dirs_honor_tmpdir" "scratch site(s) ignoring the platform temp variable: $bare"
    return
  fi
  causeless=$($GREP -rn -A2 -F "$needle" "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null \
              | $GREP -iE 'cannot create a temporary directory' | $GREP -v '\$' | head -2 | tr '\n' ' ')
  if [ -n "$causeless" ]; then
    bad "temp_dirs_honor_tmpdir" "a scratch failure message discards the tool's own diagnosis, so the operator learns nothing about why: $causeless"
  else
    ok "temp_dirs_honor_tmpdir ($sites scratch site(s), every one honouring the platform variable and carrying the captured cause on failure)"
  fi
}

check_no_hardcoded_tool_paths() {
  # A check that hardcodes an absolute path to its search tool, and swallows that tool's failure,
  # certifies "nothing found" when the truth is "nothing ran". Tools are resolved ONCE, at the top
  # of each file, on a line that says so; every other site uses the resolved name.
  # EXEMPT, by shape and not by file: a line that RESOLVES a tool — an executability test or an
  # assignment — is the repair for this class, not an instance of it. Everything else that names an
  # absolute tool path is a call, and a call is what swallows a tool failure as a clean verdict.
  local hits
  hits=$($GREP -rnE '(^|[^A-Za-z0-9_/-])/(usr/bin|bin|usr/local/bin)/[a-z0-9_.-]+' \
           "$PKG_ROOT/scripts" "$PKG_ROOT/tests" 2>/dev/null \
         | $GREP -vF 'tool-resolver (exempt)' | $GREP -vF '(annotated:' \
         | $GREP -vE '^[^:]+:[0-9]+:#!' \
         | $GREP -vE '(\[ +-x +"?/(usr/bin|bin|usr/local/bin)/|[A-Za-z_][A-Za-z0-9_]*="?/(usr/bin|bin|usr/local/bin)/)' \
         | head -4 | tr '\n' ' ')
  if [ -n "$hits" ]; then
    bad "no_hardcoded_tool_paths" "tool path(s) hardcoded outside the one resolver in their file: $hits"
  else
    ok "no_hardcoded_tool_paths (every tool is resolved once per file on an annotated line; no check body carries a hardcoded tool path)"
  fi
}

check_failure_details_name_themselves() {
  # This file's own rule is that each failure names itself. A check that diagnoses its failure by
  # re-running a NARROWER program prints an all-whitespace reason for its likeliest failures, which
  # is the rule broken by the code that states it. Two halves: no reporting call may carry a blank
  # or whitespace-only detail, and every failure recorded during THIS run carried a real one.
  local out rc blanks
  out=$(python3 - "$HERE/run-tests.sh" 2>&1 <<'PY'
import re, sys
path = sys.argv[1]
problems, calls = [], 0
for n, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
    for m in re.finditer(r'\b(bad|skip)\s+"([^"]*)"(\s+"([^"]*)")?', line):
        calls += 1
        label, detail = m.group(2), m.group(4)
        if not label.strip():
            problems.append("%d: a reporting call with no label at all" % n)
            continue
        if m.group(3) is not None and not (detail or "").strip():
            problems.append("%d: %s reports a blank detail" % (n, label.split()[0]))
if calls < 10:
    print("only %d reporting call(s) found — the census did not read this file" % calls)
    raise SystemExit(1)
if problems:
    print("; ".join(problems[:3]))
    raise SystemExit(1)
print("%d reporting call(s), every one naming its assertion with a non-blank detail" % calls)
PY
)
  rc=$?
  if [ $rc -ne 0 ]; then
    bad "failure_details_name_themselves" "$(printf '%s' "$out" | tail -1)"
    return
  fi
  blanks=$($AWK -F'|' '$3=="fail" && $4 ~ /^[[:space:]]*$/ {print $1}' "$LEDGER" | tr '\n' ' ')
  if [ -n "$blanks" ]; then
    bad "failure_details_name_themselves" "check(s) failed this run with an empty reason: $blanks"
  else
    ok "failure_details_name_themselves ($out; every failure recorded this run carried a reason)"
  fi
}

check_reporter_helpers_return_zero() {
  # The classic trailing-conditional trap: a helper whose last statement is a test returns that
  # test's status, so a one-argument call returns non-zero. Harmless only until somebody adds strict
  # error mode, at which point the suite dies inside its own reporter. Sourced in a subshell and
  # called both ways.
  local probe rc1 rc2
  probe="$TMP/reporters.sh"
  $GREP -nE '^(ok|bad|skip|note|banner)\(\)' "$HERE/run-tests.sh" | sed 's/^[0-9]*://' > "$probe"
  if [ ! -s "$probe" ]; then
    bad "reporter_helpers_return_zero" "no reporter helper definition could be extracted — the assertion had nothing to source"
    return
  fi
  # The two probe labels are passed as variables on purpose: written as literals they would read as
  # two more reported check ids to --list, which harvests exactly this call shape.
  local one two
  one="reporter probe, one argument"; two="reporter probe, two arguments"
  ( set +u
    PASS=0; FAIL=0; SKIP=0; SECTION=""; LEDGER=""
    _record() { :; }
    . "$probe" >/dev/null 2>&1
    bad "$one" >/dev/null 2>&1 ) ; rc1=$?
  ( set +u
    PASS=0; FAIL=0; SKIP=0; SECTION=""; LEDGER=""
    _record() { :; }
    . "$probe" >/dev/null 2>&1
    bad "$two" "a detail" >/dev/null 2>&1 ) ; rc2=$?
  if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ]; then
    ok "reporter_helpers_return_zero (the reporters return 0 with one argument and with two)"
  else
    bad "reporter_helpers_return_zero" "a reporter returned non-zero: one-argument rc=$rc1, two-argument rc=$rc2 — the trailing-conditional trap is live"
  fi
}

check_list_flag_rejects_junk() {
  # A mistyped flag must not look like a successful run. Listing the checks with trailing junk is a
  # usage error, exactly as junk without the flag already is.
  local rc_list rc_junk rc_bare
  bash "$HERE/run-tests.sh" --list >/dev/null 2>&1; rc_list=$?
  bash "$HERE/run-tests.sh" --list nonsense >/dev/null 2>&1; rc_junk=$?
  bash "$HERE/run-tests.sh" nonsense >/dev/null 2>&1; rc_bare=$?
  if [ "$rc_list" -eq 0 ] && [ "$rc_junk" -eq 2 ] && [ "$rc_bare" -eq 2 ]; then
    ok "list_flag_rejects_junk (the bare flag lists and exits 0; trailing junk and junk alone are both usage errors)"
  else
    bad "list_flag_rejects_junk" "argument handling: --list rc=$rc_list (want 0), --list junk rc=$rc_junk (want 2), junk rc=$rc_bare (want 2)"
  fi
}

check_fixture_writes_are_guarded() {
  # A read-only checkout is a real place to run this. A fixture copied out of one inherits the
  # source's mode, the append dies, and the diagnosis accuses the code under test. Both halves: the
  # copies go through the permission-clean helper, and the helper actually produces a writable file
  # from a read-only source.
  local src dst raw
  raw=$($GREP -nE '^\s*cp "\$(PKG_ROOT|PKG)[^"]*" "\$(TMP|work)' "$HERE/run-tests.sh" \
        | $GREP -v 'fixture_copy' | head -3 | tr '\n' ' ')
  if [ -n "$raw" ]; then
    bad "fixture_writes_are_guarded" "fixture copy site(s) that bypass the permission-clean helper: $raw"
    return
  fi
  src="$TMP/ro-source.txt"; dst="$TMP/ro-copy.txt"
  printf 'read-only source\n' > "$src" && chmod 444 "$src" || {
    bad "fixture_writes_are_guarded" "could not build the read-only source fixture"; return; }
  if ! fixture_copy "$src" "$dst" >/dev/null 2>&1; then
    chmod 644 "$src" 2>/dev/null
    bad "fixture_writes_are_guarded" "the permission-clean copy failed on a read-only source, which is the case it exists for"
    return
  fi
  if printf 'appended\n' >> "$dst" 2>/dev/null; then
    chmod 644 "$src" 2>/dev/null
    ok "fixture_writes_are_guarded (every fixture copy goes through the permission-clean helper, and a copy of a read-only source is writable)"
  else
    chmod 644 "$src" 2>/dev/null
    bad "fixture_writes_are_guarded" "a fixture copied from a read-only source is still not writable — the append would die and blame the code under test"
  fi
}

check_env_var_honors_caller() {
  # The one environment name this suite reads is its own package root. It must be in the package's
  # declared namespace, it must HONOUR a value the caller set (or the documented skip branch can
  # never fire and a caller's value is silently discarded), and it must be read after it is set.
  #
  # AND THE HONOURED VALUE HAS TO BE ACCOUNTED FOR. Honouring the caller is what makes the skip
  # branch reachable, and it is also what lets five consent checks report on a DIFFERENT checkout
  # while every printed line — verdicts, section banner, summary — stays identical to a run over
  # this one. A missing directory was already defended; a valid foreign one was not, and silence
  # was the whole defect. So the parity is asserted here, the measured root is named in the failure
  # and in the verdict, and a caller who means it says so with PKG_ALLOW_FOREIGN_ROOT=yes.
  local decl foreign
  decl=$($GREP -nE '^export [A-Z_]+="?\$\{[A-Z_]+:-' "$HERE/run-tests.sh" | head -1)
  foreign=$($GREP -nE '^export [A-Z][A-Z0-9_]*=' "$HERE/run-tests.sh" \
            | $GREP -vE '^[0-9]+:export (PKG_|PM_|HOME=|PATH=|TMPDIR=)' | head -2 | tr '\n' ' ')
  if [ -n "$foreign" ]; then
    bad "env_var_honors_caller" "this suite exports an environment name outside the package's declared namespaces: $foreign"
  elif [ -z "$decl" ]; then
    bad "env_var_honors_caller" "the package-root variable is exported unconditionally, so a caller-set value is silently discarded and the documented skip branch can never fire"
  elif [ "$PKG" != "$PKG_ROOT" ] && [ "${PKG_ALLOW_FOREIGN_ROOT:-}" != "yes" ]; then
    bad "env_var_honors_caller" "the consent checks measured $PKG while this suite is $PKG_ROOT, so a green report here would be about another tree — set PKG_ALLOW_FOREIGN_ROOT=yes to say that re-aiming is deliberate"
  elif [ "$PKG" != "$PKG_ROOT" ]; then
    ok "env_var_honors_caller (the package-root variable honours a caller-set value: ${decl%%:*} of this file; the consent checks were deliberately re-aimed at $PKG, not $PKG_ROOT)"
  else
    ok "env_var_honors_caller (the package-root variable is in the declared namespace and honours a caller-set value: ${decl%%:*} of this file; the consent checks measured this package's own root, $PKG_ROOT)"
  fi
}

check_suite_ran_every_check() {
  # THE ANCHOR. Everything above can be green and the run still be a lie, in four ways this check
  # closes: a block that SKIPPED (five checks vanish and the summary says nothing), a check whose
  # invocation was deleted, a check ADDED without anyone updating the pinned file, and a check that
  # printed nothing at all. The expected roster — every check's name and the section it prints
  # under — lives in tests/expected-checks.txt, so the suite cannot answer this question out of its
  # own pocket.
  local total pinned observed missing extra wrong_section skipped dup
  total="$(expect_val total)"
  if [ -z "$total" ] || [ ! -r "$EXPECT" ]; then
    bad "suite_ran_every_check" "tests/expected-checks.txt is missing or pins no total — a suite that counts its own checks pins nothing"
    return
  fi
  # This check's own line is added to a COPY of the ledger, never to the ledger: writing it back
  # would double-count the moment the assertion below fails and reports itself.
  local seen="$TMP_ROOT/ledger-with-self.psv"
  cp "$LEDGER" "$seen" 2>/dev/null
  printf '%s|%s|%s|%s\n' "suite_ran_every_check" "$SECTION" "pass" "" >> "$seen"
  pinned=$($GREP -E '^check ' "$EXPECT" | $AWK '{print $2"|"$3}' | sort)
  observed=$($AWK -F'|' 'NF {print $1"|"$2}' "$seen" | sort)
  skipped=$($AWK -F'|' '$3=="skip" {print $1}' "$seen" | tr '\n' ' ')
  missing=$(comm -23 <(printf '%s\n' "$pinned" | $AWK -F'|' '{print $1}' | sort -u) \
                     <(printf '%s\n' "$observed" | $AWK -F'|' '{print $1}' | sort -u) | tr '\n' ' ')
  extra=$(comm -13 <(printf '%s\n' "$pinned" | $AWK -F'|' '{print $1}' | sort -u) \
                   <(printf '%s\n' "$observed" | $AWK -F'|' '{print $1}' | sort -u) | tr '\n' ' ')
  wrong_section=$(comm -13 <(printf '%s\n' "$pinned") <(printf '%s\n' "$observed" | sort -u) | tr '\n' ' ')
  dup=$($AWK -F'|' 'NF {print $1}' "$seen" | sort | uniq -d | tr '\n' ' ')
  local ran; ran=$($AWK -F'|' 'NF {print $1}' "$seen" | wc -l | tr -d ' ')
  # -- THE STATIC HALF, and why the ledger alone was not enough --------------------------------
  # Everything above reads the LEDGER: what this run reported. That answers "did every pinned
  # check report", and it is blind to the opposite question - "did this file grow a reporting id
  # nobody pinned". Four ways a rogue id hides from a ledger, all four measured: a reporting call
  # appended below the final `exit 0` never executes, a check function defined after its own
  # invocation is a command-not-found and reports nothing, a re-labelled failure only speaks when
  # that check actually fails, and a bare printf of a verdict line never touches a reporter at
  # all. Every one of them is nevertheless VISIBLE IN THE FILE, so the second assertion is static:
  # the id set the --list harvest reads out of the reporting calls must equal the pinned roster,
  # exactly, in both directions. That is the rule's own wording - the first token of every printed
  # verdict has to be a pinned name - asserted where it can actually be seen.
  local listed pinned_names harvest_extra harvest_missing rogue
  pinned_names=$(printf '%s\n' "$pinned" | $AWK -F'|' '{print $1}' | sort -u)
  listed=$($GREP -ohE '\b(ok|bad) "[a-z0-9_]+' "$HERE/run-tests.sh" | sed -E 's/^.*"//' | sort -u)
  harvest_extra=$(comm -13 <(printf '%s\n' "$pinned_names") <(printf '%s\n' "$listed") | tr '\n' ' ')
  harvest_missing=$(comm -23 <(printf '%s\n' "$pinned_names") <(printf '%s\n' "$listed") | tr '\n' ' ')
  # and the verdict grammar itself: only the three reporters may print a verdict-first line. A
  # printf that emits one carries no check name, so nothing downstream can attribute it.
  rogue=$($GREP -nE "(^|[;{&|][[:space:]]*)(printf|echo)[[:space:]]+[^;]*['\"][[:space:]]*(PASS|FAIL|SKIP|not ok)([[:space:]]|\\\\n)" \
            "$HERE/run-tests.sh" | $GREP -vE ':[[:space:]]*(ok|bad|skip)\(\)' | head -3 | tr '\n' ' ')
  if [ -n "$skipped" ]; then
    bad "suite_ran_every_check" "check(s) SKIPPED, so this run is not a full run: $skipped"
  elif [ -n "$missing" ]; then
    bad "suite_ran_every_check" "pinned check(s) that never reported: $missing"
  elif [ -n "$extra" ]; then
    bad "suite_ran_every_check" "check(s) reported that the pinned file does not list: $extra"
  elif [ -n "$dup" ]; then
    bad "suite_ran_every_check" "check(s) reported more than once: $dup"
  elif [ -n "$wrong_section" ]; then
    bad "suite_ran_every_check" "check(s) printed under a section the pinned file does not give them: $wrong_section"
  elif [ "$ran" != "$total" ]; then
    bad "suite_ran_every_check" "$ran check(s) reported against a pinned total of $total"
  elif [ -n "$PKG" ] && [ -d "$PKG" ] && [ "${TEL_RAN:-0}" -ne 5 ]; then
    # THE ONE NUMBER THE LEDGER CANNOT SEE. Each consent check increments this counter as its last
    # statement, so a return inserted anywhere after its reporting call leaves the check PRESENT in
    # the ledger and its tail unrun. The block printed the count and nobody compared it, which made
    # it a number that announced its own drift to a reader and to no assertion.
    bad "suite_ran_every_check" "the consent-telemetry block reached the end of ${TEL_RAN:-0} of its 5 checks, so one of them reported a verdict and then returned before finishing"
  elif [ -n "$harvest_extra" ]; then
    bad "suite_ran_every_check" "the file carries reporting label(s) the pinned file does not list, so a run can report an id nobody pinned: $harvest_extra"
  elif [ -n "$harvest_missing" ]; then
    bad "suite_ran_every_check" "pinned check(s) that no reporting call in this file can ever print: $harvest_missing"
  elif [ -n "$rogue" ]; then
    bad "suite_ran_every_check" "verdict line(s) printed outside the three reporters, carrying no check name at all: $rogue"
  else
    ok "suite_ran_every_check ($ran of a pinned $total, every name and section from tests/expected-checks.txt, 0 skipped; the harvested label set equals the pinned roster and no verdict line is printed outside the reporters)"
  fi
}

check_harvest_floor
check_temp_dirs_honor_tmpdir
check_no_hardcoded_tool_paths
check_failure_details_name_themselves
check_reporter_helpers_return_zero
check_list_flag_rejects_junk
check_fixture_writes_are_guarded
check_env_var_honors_caller
check_suite_ran_every_check

printf '\n== %s passed · %s failed · %s skipped ==\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] && [ "$SKIP" -eq 0 ] || exit 1
exit 0
