[Back to the README](../README.md) · the full data-custody proof for the local usage log.

# The usage log

Short version: off by default, local only, bounded at about one megabyte, and this build ships no transmission path. Everything below is the proof.

This plugin can keep a small log of what it did. **It is off until you turn it on, and it never
leaves your machine.**

**What it is.** One line per event, in plain text: a UTC timestamp, an event name, and a few
class words, `result=ok`, `phase=p2`, `findings=3`. It records **what kind of thing happened**
and how long it took. It is there so that when something goes wrong you can see what ran, in
order, instead of reconstructing it from memory.

**What it can never contain.** Your content, your document titles, and real paths. That is
enforced by the writer rather than promised by it: a value is stored only if it is a bare
`[A-Za-z0-9_.:-]` token of at most 64 characters, and `/` is not in that set, so a path cannot
be recorded even by a call site that passes one in error. A value that fails the test is stored
as `?`, **whole**; the length limit rejects rather than truncates, so a long path can never land
as a shortened-but-real path prefix. If a run passes an id so its events can be grouped, what
lands on disk is a 12-character digest of it, not the id.

**Where it lives.** In a directory resolved from your environment, `PKG_DATA_DIR`, else
`$XDG_STATE_HOME/product2prod`, else `$HOME/.local/state/product2prod`, as `telemetry.jsonl`,
plus one previous generation named `telemetry.jsonl.1`. The setting and the consent record live in
this plugin's machine-local config (`PKG_CONFIG`, else `$XDG_CONFIG_HOME/product2prod/config.json`,
else `$HOME/.config/product2prod/config.json`), outside the plugin, outside any repo the plugin
writes, and never committed. The directory that was actually used is **recorded** when you consent,
which is what makes the log removable by rule later instead of by a guess.

**Off by default, and off means there is no file.** With no config, or with any value other than
exactly `local`, the writer returns before it would create a directory. Nothing is captured and
nothing exists to read. Turning it on happens at one numbered consent step in the `init` skill,
which defaults to **NO**, states the file, the cap and the contents before it asks, and records
your answer as a timestamp with the words you used. Declining is a supported configuration, not a
degraded one: every other part of this plugin works exactly the same.

**Bounded, with no cleanup job.** 512 KiB per generation, 2 generations, about 1 MB, forever. The
check runs on every write, and the previous generation is replaced rather than accumulated, so
there is nothing to sweep up and nothing that has to run for the ceiling to hold. Raise
`telemetry.max_bytes` if you want a longer history.

**Nothing is sent anywhere, and there is no setting that would change that.** This build ships no
transmission path at all: no mode to switch, no destination to name, no background process, nothing
on a timer. If a future version can send anything anywhere, it will be its own feature with its own
consent gate, not a value you could flip in a config file.

**Turning it off, and deleting it.** Three commands, and both destructive ones are **dry run by
default**: without `--apply` they print exactly what they would remove and change nothing.

```bash
# stop recording; keep the log file and the record of your consent
scripts/telemetry.sh consent off

# delete the log and clear this feature's own keys, every other setting is left alone
scripts/telemetry.sh purge --apply

# delete the log AND this plugin's whole config file, which holds your other answers too
scripts/telemetry.sh uninstall --apply --confirm "apply uninstall"
```

`consent off` stops it. `purge` also deletes what was already written and forgets that you ever
said yes. `uninstall` additionally removes the config file. Both removal paths act only on the
directory that was **recorded** at consent time, and on two exact file names inside it, never on a
glob, and never on a path matched by shape. If nothing was recorded, nothing is removed and the
command says so rather than guessing.

`scripts/telemetry.sh status` prints, at any time, what is on, where the log is, how big it is, and
the ceiling in force. A value it cannot read prints as `unknown (<reason>)`, never as `0`.

One case is narrower than that rule, so it is written down rather than discovered: if the log
**directory** itself is unreadable, status prints both generations as `absent` rather than as
`unknown`, and purge still exits 0 and still ends with `done.`. In that run purge prints
`skipped ... (already absent)` for each file name and a `left ... (not empty ...)` line for the
directory, and it clears the recorded directory from the config, which means a log that survived
inside that directory is no longer removable by rule. Make the directory readable again before you
purge if you want the file itself removed.

**Found a bug?** Open an issue, or a pull request, on the repository this plugin came from. If you
turned the usage log on, and it is off until you do, the file at the path `status` prints is the
fastest way to show what actually ran, and it is safe to hand over: it holds only the event classes
described above, never your content, never your document titles, never a real path.
