#!/usr/bin/env bash
#
# publish-lint.sh - fail-closed scan of this package for anything that must never be published:
# machine-specific paths, personal identifiers, credentials and credential shapes, host
# fingerprints, third-party account identifiers, and private internal codenames.
#
# Exit codes:
#   0  clean
#   1  one or more hits (each printed with file, line, the pattern that fired, and the matched text)
#   2  usage error, unreadable target, or an unusable pattern set (fail-closed, never a silent pass)
#
# Usage:
#   scripts/publish-lint.sh [PATH]              scan PATH (default: this package's root)
#   scripts/publish-lint.sh --denylist FILE     use FILE instead of config/denylist.txt
#   scripts/publish-lint.sh --extra FILE        overlay extra patterns (repeatable; see OVERLAYS)
#   scripts/publish-lint.sh --self-test         prove the scanner actually fires
#   scripts/publish-lint.sh --list              print the effective pattern + allow set, exit 0
#                                               (overlay entries are listed redacted - see OVERLAYS)
#   scripts/publish-lint.sh --help
#
# PATTERN SET: config/denylist.txt is the authority. This script holds NO patterns of its own, on
# purpose: the list is data, reviewable in one place, editable without touching code, and
# reproducible by hand with the grep line printed in that file's header. An unreadable, missing, or
# pattern-free deny-list is exit 2 - a scanner that cannot prove it loaded its rules must never
# report "clean".
#
# PATTERN LINES ARE BYTE-VALIDATED at load, and the loaded count is cross-checked against the hand
# grep line that deny-list's own header prints. One trailing space is part of the pattern and stops
# it matching anything it used to match; one carriage return on every line (a CRLF file) loads each
# blank line as a rule and appends a CR to every real one, so the printed count goes UP while the
# whole set goes blind. Both are refused by file and line. A count the parser and the hand form
# disagree about is an error, not a rounding difference.
#
# CASE: patterns match case-INSENSITIVELY by default, because brand names, personal names and hex
# values leak in any casing. A pattern whose CASE IS THE SIGNAL is written `!cs:<pattern>` and is
# matched case-sensitively - an account identifier shaped `PREFIX-[A-Z0-9]{6,}` matched loosely
# fires on every lowercase word with that prefix, and a scanner that cries wolf gets switched off.
#
# ALLOW DIRECTIVES: the deny-list may carry `#!allow <token> :: <scope>` lines. A hit is excused
# only when the EXACT text the pattern matched equals an allowed token (case-insensitively) AND the
# file is inside that directive's scope (`*`, or a comma-separated list of root-relative globs).
# Matching is span-exact, never substring-erasure, so allowing a public brand name can never excuse
# a longer private codename that merely contains it - that codename's own pattern still fires.
# Allows are PROVENANCE-AWARE: a directive read from the public list never excuses a hit raised by a
# pattern read from an overlay, so the public file cannot disarm the stricter rules loaded beside
# it; a directive read from an overlay may excuse either. A token carrying a path separator is
# refused at load, naming its file and line: no legitimate directive needs one, and a directive that
# excuses a path excuses the class this scan exists to catch. Every excused span is reported with
# its file, its pattern and the token that excused it, so silence is never the report.
#
# SELF-EXCLUSION: the deny-list file is the one file not scanned against the deny patterns, because
# it *is* the patterns and would match itself on every line. The machine-local config the documented
# first run creates is pruned by name for the same reason - it is a file the user writes, not a file
# this package ships. THREE MORE CLASSES never reach the scan because git does not publish them:
# everything below `.git/`, anything under a `__pycache__/` directory, and any `*.pyc` file. All
# FIVE exclusions are COUNTED AND PRINTED on every run rather than left implicit - an exclusion
# nobody counts is an exclusion nobody can audit, and three of these five used to shrink the
# coverage number in silence. Everything else under the root is scanned, this script included -
# which is why the self-test's deliberate samples are assembled at run time from parts instead of
# being written out in this file.
#
# SYMLINKS are walked, censused and matched. A link is never followed - what it points at is either
# inside this tree (walked on its own) or outside it (not ours to publish) - but git publishes a
# symlink as a blob whose CONTENT IS THE TARGET PATH, so that target string is a published byte and
# is matched as one. A link left out of the walk is a machine path published as a file nobody read.
#
# OVERLAYS: --extra loads additional patterns (one per line, same format) from OUTSIDE the scanned
# tree - for literals an operator will not commit even to a private repo. A file inside the scanned
# tree is refused, and the refusal resolves a LEAF SYMLINK first: the directory was always resolved
# and the final component appended verbatim, so an out-of-tree link pointing at an in-tree list
# walked straight past the guard while the private list stayed in the published tree. An overlay
# that is unreadable, or that yields no pattern at all, is exit 2 rather than a run whose output is
# byte-identical to one with no overlay attached: that silence is the weak scan wearing the strong
# scan's verdict. Each overlay's loaded count is printed by INDEX. Overlay entries are never echoed:
# --list prints them as `[overlay #N] (redacted)`, and so does every line that has to name the
# pattern that fired.
#
# OUTPUT: a hit prints the MATCHED TEXT only, never the whole line, so running this in a shared
# build log cannot turn a one-line finding into a wider disclosure.
#
# COVERAGE IS AN ASSERTION, NOT AN ASSUMPTION: a file is counted as scanned only once it is proven
# readable and decodable by the same tool that scans it. Anything else lands in a printed
# `unscannable:` census and is a hard error - counting bytes nobody matched is how a scan certifies
# what it never read. A run that scans no file at all is an error too, not a clean verdict.
# THE WALK ITSELF IS HELD TO THE SAME RULE, three ways, because a directory this run could not
# descend into used to vanish from the tree with no trace but a line on standard error:
#   1. the walk's own EXIT STATUS and diagnostics are captured and read - through a process
#      substitution both are structurally invisible, and a dropped subtree scans as "clean";
#   2. every DIRECTORY is censused for readability and traversability independently of what the
#      lister reported, so an unreadable one is named by its own path either way;
#   3. the walk's PARITY is asserted: every path the lister returned is accounted for exactly once -
#      scanned, censused as unscannable, or counted under one of the five printed exclusions. A path
#      that falls through every branch is a byte this scan never read and never admitted to skipping.
# The scratch directory those numbers are written in is validated before the cleanup trap is armed,
# and proven writable before anything is scanned: an unwritable temp turns "no pattern file" into
# "no match" and every file in the tree comes back clean with every counter intact.
#
# TOOLS: the search tool, the file lister and the sorter are resolved to system binaries when
# present. A shell function or alias named "grep" on the running machine can silently swallow
# matches; a shimmed "find" yields "scanned 0 files ... clean". A silent zero from a scanner like
# this one is the worst failure mode it has, so every pattern is validated at load and every search
# tool status is checked instead of being read as "no match".

set -uo pipefail

GREP=grep
if [ -x /usr/bin/grep ]; then GREP=/usr/bin/grep; fi
FIND=find
if [ -x /usr/bin/find ]; then FIND=/usr/bin/find; fi
SORT=sort
if [ -x /usr/bin/sort ]; then SORT=/usr/bin/sort; fi

SELF_PATH=$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")
PKG_ROOT=$(dirname "$(dirname "$SELF_PATH")")

DENYLIST=""
EXTRA_FILES=()
SELF_TEST=0
LIST_ONLY=0
ROOT=""

die() { printf 'publish-lint: %s\n' "$1" >&2; exit 2; }
usage() { $GREP -E '^#( |$)' "$SELF_PATH" | sed 's/^#\{1\} \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --denylist) [ $# -ge 2 ] || die "--denylist needs a file"; DENYLIST="$2"; shift 2 ;;
    --extra) [ $# -ge 2 ] || die "--extra needs a file"; EXTRA_FILES+=("$2"); shift 2 ;;
    --self-test) SELF_TEST=1; shift ;;
    --list) LIST_ONLY=1; shift ;;
    -*) die "unknown option: $1" ;;
    *) [ -z "$ROOT" ] || die "more than one path given"; ROOT="$1"; shift ;;
  esac
done

[ -n "$ROOT" ] || ROOT="$PKG_ROOT"
[ -d "$ROOT" ] || die "not a directory: $ROOT"
ROOT=$(cd "$ROOT" && pwd -P)

[ -n "$DENYLIST" ] || DENYLIST="$PKG_ROOT/config/denylist.txt"
[ -f "$DENYLIST" ] || die "deny-list not found: $DENYLIST (a scan without its rules is not a pass)"
[ -r "$DENYLIST" ] || die "deny-list not readable: $DENYLIST"
DENYLIST=$(cd "$(dirname "$DENYLIST")" && pwd -P)/$(basename "$DENYLIST")

TMPBASE="${TMPDIR:-/tmp}"   # the same base the template below uses, held once for the checks after it
if ! WORK=$(mktemp -d "${TMPDIR:-/tmp}/publish-lint.XXXXXX" 2>/dev/null); then
  # capture the tool's own diagnosis: "could not" with no cause teaches the operator nothing
  cause=$(mktemp -d "${TMPDIR:-/tmp}/publish-lint.XXXXXX" 2>&1 >/dev/null)
  die "cannot create a temporary directory under ${TMPDIR:-/tmp}: $cause"
fi
# THE CLEANUP TRAP IS ARMED ONLY OVER A PATH THIS RUN PROVABLY CREATED. `rm -rf "$WORK"` over an
# unvalidated value deletes whatever that value happens to name, and the value comes from a tool
# resolved off the command path. Shape, kind, emptiness and writability are checked FIRST, and every
# failure here is a refusal BEFORE the trap exists rather than a deletion after it. Nothing is
# removed on these refusals on purpose: a directory this run cannot prove it made is not this run's
# to delete, and one empty directory left behind is the cheaper mistake.
case "$WORK" in "$TMPBASE"/*) : ;; *) die "the temporary directory is not under $TMPBASE ($WORK) - refusing to arm a cleanup trap over a path this run cannot prove it created" ;; esac
case "${WORK##*/}" in publish-lint.??????) : ;; *) die "the temporary directory is not the one this run asked for ($WORK) - refusing to arm a cleanup trap over a path this run cannot prove it created" ;; esac
[ -d "$WORK" ] || die "the temporary path is not a directory: $WORK"
[ -z "$($FIND "$WORK" -mindepth 1 -maxdepth 1 -print 2>/dev/null | head -1)" ] || \
  die "the temporary directory $WORK already holds something - it existed before this run, so it is not this run's to write in or to delete"
if ! ( : > "$WORK/.writeprobe" ) 2>/dev/null || [ ! -f "$WORK/.writeprobe" ]; then
  die "cannot write inside the temporary directory $WORK - the pattern files, the walk and the hit
     list all live there, and a scan whose rules never got written matches nothing and reports clean"
fi
rm -f "$WORK/.writeprobe"
trap 'rm -rf "$WORK"' EXIT

# --- load the pattern set + the allow directives ---
CR=$(printf '\r')     # the byte the CRLF check below looks for, held once so no line has to carry it
PATTERNS=()
PCASE=()          # per pattern: "i" = case-insensitive (default), "s" = case-sensitive
PSRC=()           # per pattern: "public" (the deny-list) or "overlay" (an --extra file)
PCLASS=()         # per pattern: the class id declared by the `#@class` line above its section
ALLOW_TOKENS=()
ALLOW_SCOPES=()
ALLOW_SRC=()      # per directive: the list it came from, so a public allow cannot cross to an overlay
DECLARED_CLASSES=""   # class ids declared by the PUBLIC list, in declaration order

validate_pattern() {  # $1 = pattern, $2 = file label, $3 = line number
  # A pattern the search tool cannot compile makes that tool exit with an error, and an error read
  # as "no match" is a leak reported as clean. Compile every pattern once, here, against nothing.
  local err
  err=$($GREP -qE -- "$1" /dev/null 2>&1)
  case $? in
    0|1) return 0 ;;
  esac
  die "$2 line $3: unusable pattern, the search tool rejected it${err:+ ($err)} - a rule set that cannot be USED is as blind as one that never loaded: $1"
}

load_list() {  # $1 = file, $2 = label for errors, $3 = provenance ("public" or "overlay")
  local line lineno=0 src="$3" class=""
  # An unreadable list makes the redirect below fail with one line on standard error and an empty
  # loop body: zero rules loaded, nothing said, and the caller cannot tell that run apart from one
  # where the file held nothing to load.
  [ -r "$1" ] || die "$2: the pattern list is not readable - a scan that cannot prove it loaded its rules must never report clean"
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    # BYTE VALIDATION, before the line is read as anything else. A carriage return rides invisibly
    # at the end of every line of a CRLF file: each blank line loads as a "pattern", the printed
    # count goes UP, and every real pattern gains a trailing CR that stops it matching. Refused by
    # file and line - and the line itself is never echoed, because this loader also reads overlays.
    case "$line" in
      *"$CR"*) die "$2 line $lineno: the line carries a carriage return. A CRLF pattern file loads every blank line as a rule and appends a CR to every real one, so the count rises while the whole set goes blind. Convert the file to LF endings." ;;
    esac
    case "$line" in
      '#!allow '*)
        line="${line#\#!allow }"
        local tok="${line%%::*}" scope="${line#*::}"
        [ "$tok" != "$line" ] || scope='*'
        tok="$(printf '%s' "$tok" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        scope="$(printf '%s' "$scope" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -n "$tok" ] || die "$2 line $lineno: an #!allow directive has no token"
        case "$tok" in
          */*) die "$2 line $lineno: the allow token carries a path separator ($tok). No legitimate directive needs one, and a directive that excuses a path excuses the class this scan exists to catch" ;;
        esac
        [ -n "$scope" ] || scope='*'
        ALLOW_TOKENS+=("$tok"); ALLOW_SCOPES+=("$scope"); ALLOW_SRC+=("$src") ;;
      '#@class '*)
        class="$(printf '%s' "${line#\#@class }" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        case "$src" in public) DECLARED_CLASSES="$DECLARED_CLASSES $class" ;; esac ;;
      ''|'#'*) : ;;
      *)
        # A trailing blank is PART of the pattern and silently kills it: the rule still loads, the
        # count still reads right, the self-test still passes on its siblings, and the one thing
        # that pattern used to catch stops being caught. Refused by file and line; a deliberate
        # trailing space is written [[:space:]], which says so.
        case "$line" in
          *[[:space:]]) die "$2 line $lineno: the pattern line ends in whitespace. That blank is part of the pattern and stops it matching what it used to match, while every printed count stays green. Delete it, or write it as [[:space:]] if it is deliberate." ;;
        esac
        local rx="$line" kind="i"
        case "$line" in '!cs:'*) rx="${line#\!cs:}"; kind="s" ;; esac
        validate_pattern "$rx" "$2" "$lineno"
        PATTERNS+=("$rx"); PCASE+=("$kind"); PSRC+=("$src"); PCLASS+=("$class") ;;
    esac
  done < "$1"
}

load_list "$DENYLIST" "$DENYLIST" public
DENY_COUNT=${#PATTERNS[@]}
[ "$DENY_COUNT" -gt 0 ] || die "no patterns loaded from $DENYLIST (fail-closed: an empty rule set is an error)"

# COUNT CROSS-CHECK, against the very hand form the deny-list's own header prints for reviewers.
# The parser and that one line have to agree on how many rules the file holds. They disagree the
# moment a line is not what it looks like - the CRLF file that loaded 26 rules out of 20 real ones
# raised every printed count while the set went blind - and a number two readers dispute is not a
# number anybody can review.
HAND_COUNT=$($GREP -cvE '^[[:space:]]*(#|$)' "$DENYLIST" 2>/dev/null | tr -d ' ')
[ "${HAND_COUNT:-x}" = "$DENY_COUNT" ] || \
  die "$DENYLIST holds ${HAND_COUNT:-no} rule line(s) by the hand cross-check printed in its own header and this run loaded $DENY_COUNT - a pattern set its two readers disagree about is not a pattern set anybody can review"

EXTRA_COUNT=0
EXTRA_N=0
for ef in ${EXTRA_FILES+"${EXTRA_FILES[@]}"}; do
  EXTRA_N=$((EXTRA_N + 1))
  [ -e "$ef" ] || die "extra pattern file not found: $ef"
  ef_abs=$(cd "$(dirname "$ef")" && pwd -P)/$(basename "$ef")
  # THE LEAF IS RESOLVED TOO. `pwd -P` resolves the directory and the final component was appended
  # verbatim, so a link sitting outside the tree and pointing at a list INSIDE it satisfied the
  # refusal below while the private list stayed in the package that gets published.
  hops=0
  while [ -L "$ef_abs" ]; do
    hops=$((hops + 1))
    [ "$hops" -le 40 ] || die "--extra: more than 40 symlink hops from $ef - refusing to follow a link loop"
    lnk=$(readlink "$ef_abs" 2>/dev/null)
    [ -n "$lnk" ] || die "--extra: could not read the symlink $ef - an overlay whose real path cannot be resolved cannot be proven to live outside the scanned tree"
    case "$lnk" in
      /*) ef_abs="$lnk" ;;
      *)  ef_abs="$(dirname "$ef_abs")/$lnk" ;;
    esac
    ef_abs=$(cd "$(dirname "$ef_abs")" 2>/dev/null && pwd -P)/$(basename "$ef_abs") || \
      die "--extra: $ef resolves through a directory this run cannot enter"
  done
  [ -f "$ef_abs" ] || die "extra pattern file is not a regular file: $ef"
  case "$ef_abs" in
    "$ROOT"/*) die "refusing an --extra list stored inside the scanned tree ($ef). A private pattern list must live outside the package, or it is published with it." ;;
  esac
  [ -r "$ef_abs" ] || die "extra pattern file is not readable: $ef - the overlay carries the strictest literals in the run, and a run that drops it prints output identical to one that never had it"
  before=${#PATTERNS[@]}
  before_allow=${#ALLOW_TOKENS[@]}
  load_list "$ef_abs" "$ef_abs" overlay
  added=$(( ${#PATTERNS[@]} - before ))
  added_allow=$(( ${#ALLOW_TOKENS[@]} - before_allow ))
  # AN OVERLAY THAT CONTRIBUTES NOTHING IS NOT AN OVERLAY. Comment-only, empty, or read to the end
  # with nothing loaded: the summary line, the counts and the verdict all come out byte-identical to
  # a run with no --extra at all, and nothing on screen tells the operator the strict rules never
  # arrived. Directives count as a contribution beside patterns - an overlay may legitimately carry
  # allows alone, and the provenance rule exists precisely so it can. The counts are asserted and
  # then PRINTED, by index - never by path, never by content.
  [ $(( added + added_allow )) -gt 0 ] || die "--extra: overlay #$EXTRA_N loaded 0 patterns and 0 allow directives. A run whose overlay contributes no rule is the public scan wearing maintainer mode's verdict, and its output cannot be told from a run with no overlay at all"
  printf 'publish-lint: overlay #%s loaded %s pattern(s) and %s allow directive(s)\n' "$EXTRA_N" "$added" "$added_allow"
  EXTRA_COUNT=$(( EXTRA_COUNT + added ))
done

PATFILE_I="$WORK/patterns-i"; PATFILE_S="$WORK/patterns-s"
: > "$PATFILE_I" || die "cannot write the case-insensitive pattern file under $WORK"
: > "$PATFILE_S" || die "cannot write the case-sensitive pattern file under $WORK"
i=0
while [ $i -lt ${#PATTERNS[@]} ]; do
  if [ "${PCASE[$i]}" = "s" ]; then printf '%s\n' "${PATTERNS[$i]}" >> "$PATFILE_S"
  else printf '%s\n' "${PATTERNS[$i]}" >> "$PATFILE_I"; fi
  i=$((i+1))
done
# THE WRITES ARE COUNTED BACK. These two files ARE the scan: the match loop reads "no pattern file"
# as "nothing to match", so a temp that stops accepting writes after mktemp succeeded - a full disk,
# a tmpfs gone read-only mid-run - produces a walk that matches nothing over every file in the tree
# and reports clean with every counter intact. The rules that made it to disk are counted before
# anything is scanned.
WRITTEN=$(( $(wc -l < "$PATFILE_I" | tr -d ' ') + $(wc -l < "$PATFILE_S" | tr -d ' ') ))
[ "$WRITTEN" -eq "${#PATTERNS[@]}" ] || \
  die "only $WRITTEN of ${#PATTERNS[@]} loaded pattern(s) reached the scratch pattern files under $WORK - a scan whose rules never got written matches nothing and reports clean"

# --- redaction: an overlay entry is referred to by its index, never echoed. Listing the loaded ---
# --- set with an overlay attached would print every private literal into whatever log is open  ---
pattern_display() {  # $1 = pattern index
  local i=0 n=0
  if [ "${PSRC[$1]}" != "overlay" ]; then printf '%s' "${PATTERNS[$1]}"; return 0; fi
  while [ $i -le "$1" ]; do
    if [ "${PSRC[$i]}" = "overlay" ]; then n=$((n + 1)); fi
    i=$((i + 1))
  done
  printf '[overlay #%s] (redacted)' "$n"
}

allow_display() {  # $1 = allow index
  local i=0 n=0
  if [ "${ALLOW_SRC[$1]}" != "overlay" ]; then printf '%s' "${ALLOW_TOKENS[$1]}"; return 0; fi
  while [ $i -le "$1" ]; do
    if [ "${ALLOW_SRC[$i]}" = "overlay" ]; then n=$((n + 1)); fi
    i=$((i + 1))
  done
  printf '[overlay #%s] (redacted)' "$n"
}

if [ "$LIST_ONLY" -eq 1 ]; then
  printf 'deny patterns (%s from %s' "$DENY_COUNT" "${DENYLIST#"$ROOT"/}"
  [ "$EXTRA_COUNT" -eq 0 ] && printf ')\n' || printf ' + %s from overlays, listed redacted)\n' "$EXTRA_COUNT"
  i=0
  while [ $i -lt ${#PATTERNS[@]} ]; do
    printf '  [%s] %s\n' "${PCASE[$i]}" "$(pattern_display "$i")"; i=$((i+1))
  done
  printf 'allow directives (%s)\n' "${#ALLOW_TOKENS[@]}"
  i=0; while [ $i -lt ${#ALLOW_TOKENS[@]} ]; do
    if [ "${ALLOW_SRC[$i]}" = "overlay" ]; then
      printf '  %s\n' "$(allow_display "$i")"
    else
      printf '  %s :: %s\n' "${ALLOW_TOKENS[$i]}" "${ALLOW_SCOPES[$i]}"
    fi
    i=$((i+1))
  done
  exit 0
fi

# --- allow evaluation: span-exact token, scope-checked path ---
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

EXCUSED_BY=""     # set by span_allowed: the directive that excused the span, for the report line
EXCUSED_SRC=""    # and which list that directive came from, so a private token is never echoed

span_allowed() {  # $1 = matched span, $2 = root-relative path, $3 = the firing pattern's provenance
  local span_lc; span_lc=$(lc "$1")
  local i=0 tok scope one hit=1
  EXCUSED_BY=""; EXCUSED_SRC=""
  while [ $i -lt ${#ALLOW_TOKENS[@]} ]; do
    # PROVENANCE: a directive from the public list may never excuse a hit raised by an overlay
    # pattern. Allows apply to the merged set, so without this the public file can neuter the
    # stricter rules loaded beside it and the run still prints clean.
    if [ "$3" = "overlay" ] && [ "${ALLOW_SRC[$i]}" != "overlay" ]; then i=$((i+1)); continue; fi
    tok=$(lc "${ALLOW_TOKENS[$i]}"); scope="${ALLOW_SCOPES[$i]}"
    if [ "$span_lc" = "$tok" ]; then
      if [ "$scope" = '*' ]; then EXCUSED_BY="$(allow_display "$i")"; EXCUSED_SRC="${ALLOW_SRC[$i]}"; return 0; fi
      # The scope list is SPLIT on commas and must never be EXPANDED against the caller's working
      # directory: unquoted, a glob scope matches whatever happens to sit beside the caller, so the
      # same tree, list and directive give clean from one directory and fail from another.
      local IFS=','
      set -f
      for one in $scope; do
        one="$(printf '%s' "$one" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        case "$2" in $one) hit=0; break ;; esac
      done
      set +f
      if [ "$hit" -eq 0 ]; then EXCUSED_BY="$(allow_display "$i")"; EXCUSED_SRC="${ALLOW_SRC[$i]}"; return 0; fi
    fi
    i=$((i+1))
  done
  return 1
}

HITS=0; FILES=0; ALLOWED=0; UNSCANNABLE=0; PRUNED_LOCAL=0
SKIPPED_DENY=0; EX_GIT=0; EX_CACHE=0; DIRS=0; SYMLINKS=0
UNSCANNABLE_LIST=""
SYMLINK_LIST=""
FIRED_CLASSES=""

scan_tree() {  # $1 = root to walk, $2 = deny-list path to skip (may be empty)
  local root="$1" skip="$2" f rel hitline lineno span rx k idx grc any shown tgt frc walked acct
  # THE WALK IS READ FOR ITS STATUS, NOT ONLY FOR ITS LINES. A lister that cannot descend into a
  # directory exits non-zero and says so on standard error; through a process substitution both are
  # structurally invisible and the subtree simply disappears from a run that still prints a census
  # of zero and a clean verdict. Captured to a file: the pipeline's status covers the sorter too,
  # the diagnostics are kept for the message, and a redirect that cannot be written fails here
  # rather than becoming an empty walk.
  $FIND "$root" \( -type d -o -type f -o -type l \) -print 2>"$WORK/walkerr" | $SORT > "$WORK/walk"
  frc=$?
  [ -f "$WORK/walk" ] || die "the walk under $WORK could not be written - a file lister whose output goes nowhere yields a scan of nothing"
  walked=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    walked=$((walked + 1))
    [ "$f" = "$root" ] && { DIRS=$((DIRS + 1)); continue; }
    rel="${f#"$root"/}"
    # EXCLUDED BY NAME - three classes git does not publish. They are COUNTED here rather than
    # dropped by the lister, because an exclusion nobody counts is an exclusion nobody can audit:
    # these three used to shrink the coverage number in silence while the header claimed there were
    # only two exclusions and that everything else under the root was scanned.
    case "$rel" in
      .git|.git/*) EX_GIT=$((EX_GIT + 1)); continue ;;
      __pycache__|__pycache__/*|*/__pycache__|*/__pycache__/*|*.pyc) EX_CACHE=$((EX_CACHE + 1)); continue ;;
    esac
    # DIRECTORIES are censused for readability and traversability INDEPENDENTLY of whatever the
    # lister's own status said. One unreadable directory takes its whole subtree out of the walk,
    # and the only trace is a line on standard error nobody reads; here it is named by its own path.
    if [ ! -L "$f" ] && [ -d "$f" ]; then
      if [ -r "$f" ] && [ -x "$f" ]; then DIRS=$((DIRS + 1))
      else UNSCANNABLE=$((UNSCANNABLE + 1)); UNSCANNABLE_LIST="$UNSCANNABLE_LIST $rel/(unreadable directory)"; fi
      continue
    fi
    [ -n "$skip" ] && [ "$f" = "$skip" ] && { SKIPPED_DENY=$((SKIPPED_DENY + 1)); continue; }
    # The machine-local config the documented first run creates is the USER's file, not a shipped
    # one. Pruned by name, before the count, so the coverage arithmetic balances by the sum instead
    # of by two exclusion lists somebody has to keep identical. The same content in a tracked file
    # still fails: this prunes one name, it does not widen the rules.
    case "$rel" in config/local.json) PRUNED_LOCAL=$((PRUNED_LOCAL + 1)); continue ;; esac
    # A SYMLINK IS PUBLISHED AS ITS TARGET PATH: git stores the target string as the blob's whole
    # content. So the target is scanned as the published byte it is, and the link is never followed
    # - what it points at is either inside this tree (walked on its own) or outside it (not ours to
    # publish). Left out of the walk, a link is a machine path published as a file nobody read.
    if [ -L "$f" ]; then
      tgt=$(readlink "$f" 2>/dev/null)
      [ -n "$tgt" ] || die "could not read the symlink target of $rel - a link whose target cannot be read cannot be certified as publishing nothing"
      # The census names the LINK, never its target: a target is exactly the kind of string this
      # scan exists to find, and printing it whole would turn one census line into the wider
      # disclosure the OUTPUT rule above refuses. A target that fires is reported like any other
      # hit - matched span only.
      SYMLINKS=$((SYMLINKS + 1)); SYMLINK_LIST="$SYMLINK_LIST $rel"
      printf '%s\n' "$tgt" > "$WORK/linktarget" || \
        die "could not write the link-target probe under $WORK while scanning $rel"
      f="$WORK/linktarget"; rel="$rel (symlink target)"
    fi
    # Readability and decodability are proven BEFORE the file is counted. An unreadable, UTF-16 or
    # NUL-bearing file scans clean against every pattern, and counting it certifies bytes nobody
    # matched. The probe is the same tool with the same flags the scan uses, so "scannable" means
    # exactly "this scan could read it".
    if [ ! -r "$f" ]; then
      UNSCANNABLE=$((UNSCANNABLE + 1)); UNSCANNABLE_LIST="$UNSCANNABLE_LIST $rel(unreadable)"; continue
    fi
    if [ -s "$f" ] && ! $GREP -Iq -e '' -- "$f" 2>/dev/null; then
      UNSCANNABLE=$((UNSCANNABLE + 1)); UNSCANNABLE_LIST="$UNSCANNABLE_LIST $rel(undecodable)"; continue
    fi
    FILES=$((FILES + 1))
    # cheap gate: anything at all in this file, either casing set? A non-zero status from the search
    # tool is the tool ERRORING, which is not the same thing as "no match" and is never read as one.
    any=1
    if [ -s "$PATFILE_I" ]; then
      $GREP -IqEif "$PATFILE_I" -- "$f" 2>"$WORK/err"; grc=$?
      [ "$grc" -le 1 ] || die "the search tool failed on $rel (status $grc): $(tr '\n' ' ' < "$WORK/err")"
      if [ "$grc" -eq 0 ]; then any=0; fi
    fi
    if [ "$any" -ne 0 ] && [ -s "$PATFILE_S" ]; then
      $GREP -IqEf "$PATFILE_S" -- "$f" 2>"$WORK/err"; grc=$?
      [ "$grc" -le 1 ] || die "the search tool failed on $rel (status $grc): $(tr '\n' ' ' < "$WORK/err")"
      if [ "$grc" -eq 0 ]; then any=0; fi
    fi
    [ "$any" -eq 0 ] || continue
    idx=0
    while [ $idx -lt ${#PATTERNS[@]} ]; do
      rx="${PATTERNS[$idx]}"; k="${PCASE[$idx]}"
      rm -f "$WORK/hits" 2>/dev/null
      if [ "$k" = "s" ]; then $GREP -InEo -- "$rx" "$f" > "$WORK/hits" 2>"$WORK/err"
      else $GREP -IinEo -- "$rx" "$f" > "$WORK/hits" 2>"$WORK/err"; fi
      grc=$?
      [ "$grc" -le 1 ] || die "the search tool failed on $rel with pattern $(pattern_display "$idx") (status $grc): $(tr '\n' ' ' < "$WORK/err")"
      # A redirect that could not be written also returns 1, which the loop below reads as "no hit".
      # The file has to exist, or the pattern never ran and the silence means nothing.
      [ -f "$WORK/hits" ] || die "the hit list under $WORK could not be written while scanning $rel - the scratch directory stopped accepting writes mid-run, and every pattern from here on would report no match"
      while IFS= read -r hitline; do
        [ -n "$hitline" ] || continue
        lineno="${hitline%%:*}"; span="${hitline#*:}"
        if span_allowed "$span" "$rel" "${PSRC[$idx]}"; then
          ALLOWED=$((ALLOWED + 1))
          # An excused span is REPORTED, never silent: file, pattern and the token that excused it.
          # A span excused by an OVERLAY directive is the private token itself (matching is
          # span-exact), so it is named by its index and never echoed.
          shown="$(printf '%s' "$span" | cut -c1-120)"
          if [ "$EXCUSED_SRC" = "overlay" ]; then shown="(redacted)"; fi
          printf 'excused %s:%s: [%s] %s (allowed by %s)\n' \
            "$rel" "$lineno" "$(pattern_display "$idx")" "$shown" "$EXCUSED_BY"
          continue
        fi
        HITS=$((HITS + 1))
        FIRED_CLASSES="$FIRED_CLASSES ${PCLASS[$idx]}"
        printf '%s:%s: [%s] %s\n' "$rel" "$lineno" "$(pattern_display "$idx")" "$(printf '%s' "$span" | cut -c1-120)"
      done < "$WORK/hits"
      idx=$((idx+1))
    done
  done < "$WORK/walk"

  # WALK PARITY. Every path the lister returned is accounted for exactly once: scanned, censused as
  # unscannable, or counted under one of the five printed exclusions. The sum IS the check - a path
  # that falls through every branch above is a byte this scan never read and never admitted to
  # skipping, which is the shape every silent-coverage-loss defect here has taken.
  acct=$(( FILES + UNSCANNABLE + PRUNED_LOCAL + SKIPPED_DENY + EX_GIT + EX_CACHE + DIRS ))
  [ "$acct" -eq "$walked" ] || \
    die "walk parity: the file lister returned $walked path(s) under $root and $acct were accounted for (scanned $FILES, unscannable $UNSCANNABLE, excluded $((PRUNED_LOCAL + SKIPPED_DENY + EX_GIT + EX_CACHE)), directories $DIRS). A path that is neither scanned nor named as skipped is a byte nobody read"

  # The lister's own verdict on the walk, read last so the directory census above gets to name the
  # ordinary cause first. An unexplained failure is a hard error: a walk that could not read part of
  # the tree cannot certify the whole of it.
  if [ "$frc" -ne 0 ] || [ -s "$WORK/walkerr" ]; then
    [ "$UNSCANNABLE" -gt 0 ] || \
      die "the file lister failed while walking $root (status $frc): $(tr '\n' ' ' < "$WORK/walkerr") - a walk that could not read part of the tree cannot certify the whole of it"
  fi
}

# --- self-test: the planted samples are ASSEMBLED HERE, never written literally, so this file ---
# --- stays clean under its own scan while still proving the scanner fires                     ---
# --- ONE SAMPLE PER DECLARED CLASS, and every declared class must fire. A floor of "some hits" ---
# --- passes with a whole class deleted, because a pristine run yields more hits than the floor.---
if [ "$SELF_TEST" -eq 1 ]; then
  probe="$WORK/probe"; mkdir -p "$probe"
  u=$(printf 'U%ss' 'ser'); at=$(printf '%s' '@')
  planted=0
  : > "$probe/planted.txt"
  for cls in $DECLARED_CLASSES; do
    case "$cls" in
      machine-paths)  printf 'path: /%s/somebody/notes.txt\n' "$u" >> "$probe/planted.txt" ;;
      platform-ids)   printf 'container: %s-%s%s\n' 'GTM' 'AB' 'C1234' >> "$probe/planted.txt" ;;
      network-hosts)  printf 'endpoint: %s.%s.%s.%s:%s\n' '10' '0' '0' '1' '8080' >> "$probe/planted.txt" ;;
      secret-shapes)  printf 'contact: person%sexample.com\n' "$at" >> "$probe/planted.txt" ;;
      trace-ids)      printf 'trace: %s-%s-%s-%s-%s\n' 'deadbeef' '1234' '5678' '9abc' 'deadbeefcafe' >> "$probe/planted.txt" ;;
      *) die "the deny-list declares the class '$cls' and this self-test carries no sample for it. A class nobody plants against is a class nobody proved the scanner can catch - add the sample here in the same change that adds the class" ;;
    esac
    planted=$((planted + 1))
  done
  [ "$planted" -gt 0 ] || die "the deny-list declares no pattern class at all, so the self-test has nothing to plant - an unclassed rule set cannot be proven to fire"
  printf 'a line with nothing findable in it at all\n' > "$probe/clean.txt"
  HITS=0; FILES=0; ALLOWED=0; UNSCANNABLE=0; UNSCANNABLE_LIST=""; FIRED_CLASSES=""
  PRUNED_LOCAL=0; SKIPPED_DENY=0; EX_GIT=0; EX_CACHE=0; DIRS=0; SYMLINKS=0; SYMLINK_LIST=""
  scan_tree "$probe" ""
  missed=""
  for cls in $DECLARED_CLASSES; do
    case " $FIRED_CLASSES " in *" $cls "*) : ;; *) missed="$missed $cls" ;; esac
  done
  if [ -z "$missed" ] && [ "$HITS" -ge "$planted" ]; then
    printf -- '--\npublish-lint self-test: PASS (%s declared class(es), every one fired; %s planted hits across %s files, %s patterns loaded)\n' \
      "$planted" "$HITS" "$FILES" "$DENY_COUNT"
    exit 0
  fi
  printf -- '--\npublish-lint self-test: FAIL (%s declared class(es), %s planted hits; class(es) that never fired:%s)\n' \
    "$planted" "$HITS" "${missed:- none}" >&2
  exit 2
fi

# --- the real scan ---
scan_tree "$ROOT" "$DENYLIST"

printf -- '--\n'
printf 'scanned %s files under %s/ against %s deny patterns' "$FILES" "${ROOT##*/}" "$DENY_COUNT"
[ "$EXTRA_COUNT" -gt 0 ] && printf ' + %s overlay patterns' "$EXTRA_COUNT"
printf ' (%s allow directives, %s span(s) excused)\n' "${#ALLOW_TOKENS[@]}" "$ALLOWED"
printf 'unscannable: %s\n' "$UNSCANNABLE"
printf 'walked %s path(s): %s scanned, %s directories, %s excluded by name, %s unscannable\n' \
  "$(( FILES + UNSCANNABLE + PRUNED_LOCAL + SKIPPED_DENY + EX_GIT + EX_CACHE + DIRS ))" \
  "$FILES" "$DIRS" "$(( PRUNED_LOCAL + SKIPPED_DENY + EX_GIT + EX_CACHE ))" "$UNSCANNABLE"
[ "$SYMLINKS" -eq 0 ] || \
  printf 'symlinks: %s, each matched by its target path - the bytes git publishes for a link:%s\n' \
    "$SYMLINKS" "$SYMLINK_LIST"
case "$DENYLIST" in
  "$ROOT"/*)
    printf 'NOT scanned: %s - it holds the patterns themselves, so it would match itself\n' "${DENYLIST#"$ROOT"/}"
    printf '             on every line.\n' ;;
esac
[ "$PRUNED_LOCAL" -eq 0 ] || \
  printf 'NOT scanned: config/local.json - the machine-local file the documented first run writes.\n'
[ "$EX_GIT" -eq 0 ] || \
  printf 'NOT scanned: %s path(s) below .git/ - the checkout%ss own database, which git never publishes.\n' "$EX_GIT" "'"
[ "$EX_CACHE" -eq 0 ] || \
  printf 'NOT scanned: %s path(s) named __pycache__/ or *.pyc - interpreter cache, excluded by .gitignore.\n' "$EX_CACHE"

if [ "$UNSCANNABLE" -gt 0 ]; then
  printf 'RESULT: FAIL, %s path(s) the scanning tool could not read or decode:%s\n' \
    "$UNSCANNABLE" "$UNSCANNABLE_LIST" >&2
  printf '        A path nobody could match is not a path that scanned clean. Fix the permission,\n' >&2
  printf '        re-encode the file, or take it out of the published tree.\n' >&2
  exit 2
fi

[ "$FILES" -ge 1 ] || die "scanned 0 files under $ROOT - a walk that covered nothing is not a clean verdict"

if [ "$HITS" -gt 0 ]; then
  printf 'RESULT: FAIL, %s hit(s)\n' "$HITS"
  exit 1
fi
printf 'RESULT: clean\n'
exit 0
