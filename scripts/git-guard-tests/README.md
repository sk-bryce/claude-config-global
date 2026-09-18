# destructive-git-guard.sh test suite

Assertion suite for `../destructive-git-guard.sh`. Run it after any change to that script:

```sh
scripts/git-guard-tests/run.sh              # test scripts/destructive-git-guard.sh
scripts/git-guard-tests/run.sh <path>       # test a specific copy, e.g. one in a worktree
```

Exit status is the result: `0` every case passed, `1` at least one failed, `2` the harness itself
could not run (no `jq`, or no guard script at the given path). A harness that cannot run reports
`2` rather than `0` - that is the one place this suite deliberately does not fail open, because
the thing it is testing already does.

## Why this is a tracked harness and not an ad-hoc one

The guard fails open by design: on anything it cannot parse it emits nothing and exits 0, so the
tool call proceeds. See `specs/behaviors.md`'s Destructive Git Guard section for why that tradeoff
was chosen. The cost of it is that **a completely broken guard and a working guard are
indistinguishable on every allowed command** - both emit nothing and exit 0. Nothing surfaces the
difference at runtime, so a guard can sit silently disabled for as long as nobody happens to run a
destructive command and notice it went through.

That is not hypothetical. On 2026-09-13 the guard was found to be inspecting only commands whose
string began literally with `git <subcommand>`, which left every rule in it bypassable by moving
the git call off the front of the string. The rewrite that fixed that then introduced two more
defects, each of which silently disabled the entire script again, and each caught only by running
cases like these:

- A bare `while read` discarded the final unterminated segment, so any command containing no shell
  separator - which is most commands - was never inspected at all.
- A whitespace-anchored fast-path test missed `git` preceded by a paren, so `(git stash drop)`
  slipped through.

Neither is visible by reading the regexes, and neither would have been caught by a fail-closed
policy either: both exited 0 through the script's normal path, not an error path. Tests are the
control that actually covers this class of defect.

## Layout

Everything is inline in `run.sh`; there are no fixture files. A case here is one command string
plus an expected verdict, so checking each in as its own file would add indirection without adding
coverage. This is the one place this suite departs from `../statusline-tests/`, whose cases are
multi-field JSON payloads that genuinely need to be files.

Cases are grouped and labeled by the acceptance criterion in `specs/behaviors.md` that each group
pins. **Those criteria and this file are meant to stay in step**: adding a rule to the guard means
adding the criterion there and the case here.

## What is covered

- Force-push in every form: flag before or after the remote, `-f`, `--force-with-lease`, and a
  leading `+` on a refspec (git's documented per-ref equivalent of `--force`).
- Position independence: the git call after `&&`, `;`, `|`, inside subshell parens, and on a later
  line of a multi-line command.
- Git's own pre-subcommand global options (`-C`, `-c`, `--no-pager`, and combinations) skipped
  rather than mistaken for the subcommand, with the matching allow cases so the skip does not
  become a blanket pass.
- Leading environment assignments (`GIT_DIR=... git ...`) and command wrappers that take a command
  as their argument (`env`, `time`, `sudo`, `nohup`, `command`, `xargs`, ...), including the two
  interleaved, with allow cases so the skip does not become a blanket pass. The one wrapper form
  that is *not* covered (`xargs -n 1 git ...`, where the option's value is not a dash-token) is
  asserted as `allow` so the limitation reads as a known gap rather than as coverage.
- Redirections (`2>&1`) not splitting a command away from its own flags.
- The rest of the guarded set: bare-dot `checkout`/`restore`, remote-branch deletion, `clean`
  flag clusters, `branch -D`, `stash drop`/`clear`, `filter-branch`, `reflog expire --all`,
  `commit --no-verify`/`--no-gpg-sign`, `rebase -i`.
- Config overrides that reproduce a denied flag: `commit.gpgsign` set false and `core.hooksPath`
  set at all, in every form the collector understands (`-c k=v`, `-ck=v`, `--config-env=`, paired
  `GIT_CONFIG_KEY_n`/`GIT_CONFIG_VALUE_n`). Paired with allow cases for `commit.gpgsign=true`, an
  unrelated key, and the near-miss key `commit.gpgsignoff`, so the match stays exact. Two further
  cases pin the collector rather than a rule - a glob character in a config value, and a segment
  with no config tokens at all - each alongside a guarded command that must still be denied,
  because both failure modes break the scan for every later rule rather than for themselves.
- `git config` writes of the same two keys, at every scope and in both the classic flag forms and
  the `set`/`unset` subcommand forms, plus `--unset`/`--unset-all`. The paired allow cases matter
  more than usual here: the key and value are read positionally, so an off-by-one would turn every
  `git config --get` into a deny and make the guard intolerable to work alongside. Four of them
  put a scope flag *after* the key (`git config --get core.hooksPath --global`), which is the
  shape that actually produced that false positive once - a read whose key is the last token does
  not exercise the value slot at all.
- Allow cases throughout, including everyday git, flag-shaped text inside quoted commit messages,
  and non-git commands that merely mention a guarded flag. These carry as much weight as the deny
  cases: a guard that blocks legitimate work gets disabled, and then protects nothing.
- Robustness: unparsable stdin, empty stdin, a non-`Bash` `tool_name`, and `jq` genuinely absent
  from `PATH`. The last builds a stub `PATH` holding `bash`/`sed`/`cat` but no `jq`; do not
  "simplify" it to clearing `PATH`, which removes `bash` itself and makes the case pass on a
  command-not-found error while proving nothing.

## Checking the suite can still fail

A suite that cannot fail is worse than no suite, so confirm it detects breakage in both directions
after changing it. Point it at a stub that denies nothing and every deny case should fail; point it
at one that denies everything and every allow case should fail:

```sh
printf '#!/usr/bin/env bash\nexit 0\n' > /tmp/nullguard.sh
scripts/git-guard-tests/run.sh /tmp/nullguard.sh      # expect: ~74 failures, exit 1
```
