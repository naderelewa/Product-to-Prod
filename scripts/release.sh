#!/usr/bin/env bash
# release.sh — cut a versioned release of this package: every gate first, then the tag.
#
# ORDER IS THE WHOLE POINT. A release is the moment this tree stops being local and becomes bytes
# other people hold, so nothing is tagged, pushed or published until ALL THREE gates have passed on
# the tree and the history as they stand:
#   gate 1  the commit-message lint    every commit reachable from the head, plus every ref's
#                                      annotation, scanned with the shipped pattern set
#   gate 2  scripts/publish-lint.sh    the confidentiality scan; it reads the package minus the two
#                                      files it names as excluded (the pattern file, and the
#                                      machine-local config when one exists)
#   gate 3  tests/run-tests.sh         the package's own suite
# Any one of them non-zero and this script stops, with that gate's own output as the last thing on
# screen, and exits 1. There is no skip flag, on purpose: a gate with an override is a gate that
# gets overridden on the day it matters most.
#
# WHY THE HISTORY IS A GATE. A commit subject, body, trailer or tag annotation is a published byte:
# it copies into every plain clone, and no scan of the working tree can see it. It runs FIRST
# because it is the cheapest of the three and because a tag over a dirty history cannot be recalled.
#
# MAINTAINER MODE. Cutting a release is a maintainer act, so this script runs the full-strength
# pattern set: --overlay is REQUIRED and the run hard-dies without it, with the mode printed in the
# gate banner. An overlay that is missing, unreadable, or stored inside the package is refused
# rather than skipped — a release that quietly falls back to the public patterns alone is the weak
# scan wearing the strong scan's verdict. Nothing else in this package requires an overlay: a fresh
# clone runs the suite and the scanner directly, and neither asks for one.
#
# Usage:
#   scripts/release.sh vX.Y.Z --overlay FILE           run every gate, then tag, push, release
#   scripts/release.sh vX.Y.Z --overlay FILE --dry-run run every gate, print the three commands
#   scripts/release.sh --help
#
#   --overlay FILE   private pattern overlay, from OUTSIDE this tree (repeatable; required)
#
# WHAT RUNS once every gate is green — three commands, in this order, each checked before the next
# is attempted:
#   git tag <version>
#   git push origin refs/tags/<version>   (surgical: only this release's tag, never stray local tags)
#   gh release create <version> --generate-notes
# The remote and the repository are whatever this checkout already points at. This script names no
# owner and no repository: a release tool that hardcodes where it publishes publishes to the wrong
# place the first time somebody reuses it.
#
# REFUSALS BEFORE THE GATES (exit 2, checked first so an operator learns in a second rather than
# after a full suite run):
#   - a version argument that is not shaped vX.Y.Z — that string becomes the tag, the release name
#     and the version people cite, so it is validated before anything else happens
#   - git, or the gh CLI, not on the command path
#   - the package is not inside a checkout at all
#   - uncommitted changes in the checkout — the two gates run over the WORKING TREE, so if that
#     tree differs from the commit being tagged, the tag would name bytes no gate ever saw
#   - the tag already exists — moving a tag rewrites what somebody may already have downloaded
#   - the tag and the plugin manifest name different versions — a tag saying one thing and the file
#     the installer reads saying another leaves the reader to guess which release they hold
#
# IF A STEP FAILS after the gates: a failed push removes the local tag again, so a retry starts from
# a clean state and nothing half-released is left behind. A failed release creation leaves the
# pushed tag in place and prints the one command that finishes the job — the tag is the part other
# tooling reads, and silently deleting a pushed tag is worse than an unfinished release page.
#
# Exit: 0 = released (or, with --dry-run, every gate green and nothing changed) - 1 = a gate failed
# or a release step failed - 2 = usage error or an unmet prerequisite.
#
# Dependencies: git and the gh CLI. Everything else is this package's own two scripts.
# PATHS: the package root is resolved from this script's own location, so it runs from any working
# directory and holds no path that is only true on one machine.

set -u

SELF_PATH=$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")
PKG_ROOT=$(dirname "$(dirname "$SELF_PATH")")

LINT="$PKG_ROOT/scripts/publish-lint.sh"
SUITE="$PKG_ROOT/tests/run-tests.sh"

say() { printf 'release: %s\n' "$1"; }
die() { printf 'release: %s\n' "$2" >&2; exit "$1"; }

usage() {
  cat <<'USAGE'
usage: scripts/release.sh vX.Y.Z --overlay FILE [--overlay FILE…] [--dry-run]

Runs every release gate, then tags and publishes:
  gate 1  the commit-message lint  every reachable commit + every ref annotation
  gate 2  scripts/publish-lint.sh  confidentiality scan of the package, minus the two files it
                                   names as excluded (the pattern file, the machine-local config)
  gate 3  tests/run-tests.sh       the package's own suite
  then    git tag vX.Y.Z  ->  git push origin refs/tags/vX.Y.Z  ->  gh release create vX.Y.Z --generate-notes

  --overlay   private pattern overlay from outside this tree; REQUIRED (maintainer mode), repeatable
  --dry-run   run every gate and print the three commands; change nothing
  --help      this text

exit: 0 released (or dry run passed) - 1 a gate or a release step failed - 2 usage / prerequisite
USAGE
}

# ── arguments ────────────────────────────────────────────────────────────────────────────────
VERSION=""
DRY_RUN=0
OVERLAYS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --overlay) [ $# -ge 2 ] || { usage >&2; die 2 "--overlay needs a file"; }; OVERLAYS+=("$2"); shift 2 ;;
    -*) usage >&2; die 2 "unknown option: $1" ;;
    *)
      [ -z "$VERSION" ] || die 2 "more than one version given ($VERSION and $1) — exactly one"
      VERSION="$1"; shift ;;
  esac
done

[ -n "$VERSION" ] || { usage >&2; die 2 "no version given — one argument, shaped vX.Y.Z"; }

# Shape check in plain shell rather than a pattern match through an external tool: a scanner that
# silently answers "matched" would let a malformed tag through, and this is the one string the whole
# release is named after.
version_is_wellformed() {  # v + three dot-separated runs of digits, nothing else
  local raw="$1" body major minor patch rest part
  body="${raw#v}"
  [ "v$body" = "$raw" ] || return 1
  major="${body%%.*}"; rest="${body#*.}"
  [ "$rest" != "$body" ] || return 1
  minor="${rest%%.*}"; patch="${rest#*.}"
  [ "$patch" != "$rest" ] || return 1
  for part in "$major" "$minor" "$patch"; do
    case "$part" in ''|*[!0-9]*) return 1 ;; esac
  done
  return 0
}

version_is_wellformed "$VERSION" || \
  die 2 "version must be shaped vX.Y.Z with numeric parts (for example v0.1.2), got: $VERSION"

# ── prerequisites ────────────────────────────────────────────────────────────────────────────
command -v git >/dev/null 2>&1 || die 2 "git is not on the command path"
command -v gh  >/dev/null 2>&1 || die 2 "the gh CLI is not on the command path — it creates the release"

[ -f "$LINT" ]  || die 2 "missing gate 2: ${LINT#"$PKG_ROOT"/} (a release without the leak scan is not a release)"
[ -f "$SUITE" ] || die 2 "missing gate 3: ${SUITE#"$PKG_ROOT"/} (a release without the suite is not a release)"

# ── maintainer mode: the private overlay is required, and every failure here is a hard stop ──
# A missing, unreadable or in-tree overlay must never degrade into "run the public patterns and
# print PASSED": that is the weak scan wearing the strong scan's verdict, which is the exact
# failure this gate exists to prevent.
[ "${#OVERLAYS[@]}" -gt 0 ] || die 2 "MAINTAINER MODE: no --overlay given. Cutting a release runs the
         full-strength pattern set, so the private overlay is required — pass --overlay <file>
         pointing at a pattern file OUTSIDE this tree. There is no flag to skip it."
LINT_EXTRA=()
for ov in ${OVERLAYS+"${OVERLAYS[@]}"}; do
  [ -e "$ov" ] || die 2 "MAINTAINER MODE: the overlay does not exist: $ov (a release gate that cannot load its overlay has not run)"
  [ -f "$ov" ] || die 2 "MAINTAINER MODE: the overlay is not a regular file: $ov"
  [ -r "$ov" ] || die 2 "MAINTAINER MODE: the overlay is not readable: $ov — this is a hard stop, never a skip"
  ov_abs=$(cd "$(dirname "$ov")" && pwd -P)/$(basename "$ov")
  case "$ov_abs" in
    "$PKG_ROOT"/*) die 2 "MAINTAINER MODE: the overlay lives inside the package ($ov). A private pattern list stored in the tree is published with it — keep it outside, or it is not private" ;;
  esac
  LINT_EXTRA+=(--extra "$ov_abs")
done

git -C "$PKG_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  die 2 "this package is not inside a checkout — initialise one and commit before releasing"

DIRTY=$(git -C "$PKG_ROOT" status --porcelain 2>/dev/null)
[ -z "$DIRTY" ] || die 2 "the checkout has uncommitted changes. The gates below run over the working
         tree, so tagging now would name a commit the gates never saw. Commit or stash first:
$(printf '%s\n' "$DIRTY" | sed 's/^/           /')"

if git -C "$PKG_ROOT" rev-parse -q --verify "refs/tags/$VERSION" >/dev/null 2>&1; then
  die 2 "tag $VERSION already exists — pick the next version rather than moving a tag somebody may already hold"
fi

# ── the tag and the manifest must agree ──────────────────────────────────────────────────────
# Refusing to move an existing tag stops the worst move; it does not stop the quiet one. Nothing
# here bound the version string the package DECLARES to the version being minted, so a tag cut over
# a manifest that still names the previous release passed every gate and shipped two answers to
# "which version is this?" — one in the tag, one in the file the installer reads. Consumers resolve
# that ambiguity by guessing. The bump belongs in the same commit as the release, so it is checked
# before any gate runs rather than discovered after the tag is pushed.
MANIFEST="$PKG_ROOT/.claude-plugin/plugin.json"
[ -f "$MANIFEST" ] || MANIFEST="$PKG_ROOT/plugin.json"
[ -f "$MANIFEST" ] || die 2 "no plugin manifest found (.claude-plugin/plugin.json or plugin.json) — a
         release names a version and nothing here declares one, so the tag could not be checked
         against it. Nothing was tagged, pushed or published."
MAN_VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -1)
[ -n "$MAN_VERSION" ] || die 2 "the manifest ${MANIFEST#"$PKG_ROOT"/} declares no version string, so
         nothing can be checked against the tag $VERSION. A manifest without a version is not a
         releasable package. Nothing was tagged, pushed or published."
[ "$MAN_VERSION" = "${VERSION#v}" ] || die 2 "the tag and the manifest disagree: this run would mint
         $VERSION while ${MANIFEST#"$PKG_ROOT"/} declares version $MAN_VERSION. A tag and a manifest
         that name different versions ship two answers to the same question and the reader has to
         guess. Bump the manifest (and anything that quotes it) in the same commit as the release,
         then run this again. Nothing was tagged, pushed or published."

say "releasing $VERSION from $(basename "$PKG_ROOT")/ — MAINTAINER MODE (${#OVERLAYS[@]} private overlay file(s) attached; paths are not printed) — gates first"

if ! WORK=$(mktemp -d "${TMPDIR:-/tmp}/release-gate.XXXXXX" 2>/dev/null); then
  # capture the tool's own diagnosis: "could not" with no cause teaches the operator nothing
  cause=$(mktemp -d "${TMPDIR:-/tmp}/release-gate.XXXXXX" 2>&1 >/dev/null)
  die 2 "cannot create a temporary directory under ${TMPDIR:-/tmp}: $cause"
fi
trap 'rm -rf "$WORK"' EXIT

# ── gate 1: the commit-message lint ───────────────────────────────────────────────────────────
# The history is harvested into ONE FILE PER COMMIT AND FIELD, named for that commit and that
# field, so a hit from the shipped scanner names the commit and the field it sits in without any
# index to keep in step. Commit ids are in the FILE NAMES and never in the scanned bytes: an
# abbreviated id is itself a token some pattern sets catch, and a gate that fails on its own
# harvesting is a gate nobody keeps. Author and committer NAMES **and ADDRESSES** are harvested.
# The addresses used to be left out as "git's own metadata this gate is not the place to rule on",
# and that reasoning does not survive this gate's own premise a few lines below: a published byte is
# whatever travels with every clone, and %ae/%ce travel with every clone. The one real identity this
# repository ever leaked sat in exactly those two fields and was caught by a hand amend, never by
# this gate. A default address is a machine login at a machine hostname; that is the class here.
#
# ADDRESSES ARE HARVESTED SPLIT AT THE @, one part per line, for the same reason the commit ids live
# in the file names: an ADDRESS SHAPE is itself one of the shipped deny patterns, so harvesting the
# whole string would make this gate fail on every commit of every repository — red forever, saying
# nothing about the history it read. Split, the shape cannot fire while every identity, host,
# machine and vendor pattern gets its shot at both halves, which is where the class that bit this
# repository lives. What this deliberately does NOT do is judge an address for being an address:
# that is the one pattern the field cannot be held to.
printf '\n== gate 1 of 3 - commit-message lint (MAINTAINER MODE: %s overlay file(s)) ==\n' "${#OVERLAYS[@]}"
HIST="$WORK/history"; mkdir -p "$HIST"
NCOMMITS=0
while IFS= read -r sha; do
  [ -n "$sha" ] || continue
  short=$(git -C "$PKG_ROOT" rev-parse --short "$sha" 2>/dev/null || printf 'unknown')
  git -C "$PKG_ROOT" log -1 --format='%s' "$sha" > "$HIST/commit-$short-subject.txt" 2>/dev/null
  git -C "$PKG_ROOT" log -1 --format='%b' "$sha" > "$HIST/commit-$short-body-and-trailers.txt" 2>/dev/null
  git -C "$PKG_ROOT" log -1 --format='%an%n%cn' "$sha" > "$HIST/commit-$short-author-names.txt" 2>/dev/null
  git -C "$PKG_ROOT" log -1 --format='author-address %ae%ncommitter-address %ce' "$sha" \
    | tr '@' '\n' > "$HIST/commit-$short-author-addresses.txt" 2>/dev/null
  NCOMMITS=$((NCOMMITS + 1))
done < <(git -C "$PKG_ROOT" rev-list HEAD 2>/dev/null)

NREFS=0
while IFS= read -r refname; do
  [ -n "$refname" ] || continue
  flat=$(printf '%s' "$refname" | tr '/' '_')
  git -C "$PKG_ROOT" for-each-ref --format='%(refname:short)%0a%(contents)' "$refname" \
    > "$HIST/ref-$flat-annotation.txt" 2>/dev/null
  NREFS=$((NREFS + 1))
done < <(git -C "$PKG_ROOT" for-each-ref --format='%(refname)' 2>/dev/null)

if [ "$NCOMMITS" -eq 0 ]; then
  die 1 "gate 1 of 3 FAILED — no commit message could be harvested. A history gate over nothing is
         not a pass. Nothing was tagged, pushed or published."
fi
say "harvested $NCOMMITS commit(s) and $NREFS ref annotation(s)"
if bash "$LINT" --denylist "$PKG_ROOT/config/denylist.txt" ${LINT_EXTRA+"${LINT_EXTRA[@]}"} "$HIST"; then
  say "gate 1 of 3 PASSED"
else
  die 1 "gate 1 of 3 FAILED — a commit message, trailer, author or committer NAME, an author or
         committer ADDRESS, or a ref annotation carries a banned token. Each hit above names the
         commit and the field it is in (commit-<id>-<field>); an address hit names the half of the
         address it sits in, because addresses are harvested split at the @.
         All of these are published bytes: they travel with every clone and no scan of the working
         tree can reach them. Rewrite the history before tagging (git's own identity fields need
         `git rebase --exec` or a filter, not an edit of the message).
         Nothing was tagged, pushed or published."
fi

# ── gate 2: the confidentiality scan ─────────────────────────────────────────────────────────
printf '\n== gate 2 of 3 - confidentiality scan (scripts/publish-lint.sh, MAINTAINER MODE: %s overlay file(s)) ==\n' "${#OVERLAYS[@]}"
if bash "$LINT" ${LINT_EXTRA+"${LINT_EXTRA[@]}"}; then
  say "gate 2 of 3 PASSED"
else
  die 1 "gate 2 of 3 FAILED — publish-lint exited non-zero. Every hit above must be gone before this
         package can be tagged. Nothing was tagged, pushed or published."
fi

# ── gate 3: the package's own suite ──────────────────────────────────────────────────────────
printf '\n== gate 3 of 3 - package self-tests (tests/run-tests.sh) ==\n'
if bash "$SUITE"; then
  say "gate 3 of 3 PASSED"
else
  die 1 "gate 3 of 3 FAILED — the package suite exited non-zero. Nothing was tagged, pushed or published."
fi

# ── the release itself ───────────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  printf '\n== dry run - every gate green, so this is what a real run would do, in order ==\n'
  printf '  git tag %s\n' "$VERSION"
  printf '  git push origin refs/tags/%s\n' "$VERSION"
  printf '  gh release create %s --generate-notes\n' "$VERSION"
  say "dry run complete: nothing tagged, nothing pushed, nothing published"
  exit 0
fi

printf '\n== releasing %s ==\n' "$VERSION"

git -C "$PKG_ROOT" tag "$VERSION" || \
  die 1 "could not create the tag $VERSION — nothing was pushed or published"
say "tagged $VERSION"

if ! git -C "$PKG_ROOT" push origin "refs/tags/$VERSION"; then
  git -C "$PKG_ROOT" tag -d "$VERSION" >/dev/null 2>&1
  die 1 "pushing the tag failed. The local tag was deleted again so a retry starts clean, and
         nothing was published."
fi
say "pushed the tag"

if ! ( cd "$PKG_ROOT" && gh release create "$VERSION" --generate-notes ); then
  printf 'release: the tag %s is pushed, but creating the release page failed.\n' "$VERSION" >&2
  printf '         The tag is left in place - it is the part other tooling reads. Finish by running\n' >&2
  printf '           gh release create %s --generate-notes\n' "$VERSION" >&2
  exit 1
fi

say "released $VERSION"
exit 0
