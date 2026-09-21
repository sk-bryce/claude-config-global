---
created: 2026-08-21
updated: 2026-09-21
---

# Public Repo Hygiene

Read this before adding or editing any git-tracked file in this configuration repository. This
repository targets a public remote, so a client name, an employer domain, a home-directory path, or
a session identifier written into a tracked file is published the moment it is pushed.

Scope is the working tree: what gets written into tracked files from now on. Commit history and
commit identity are a separate problem this policy does not address, and a rule applied going
forward does not clean anything already committed.

## What Must Never Enter A Tracked File

| Category | Examples of what this means |
| --- | --- |
| Client and engagement identifiers | A client or project name, an internal codename, or an abbreviation that names one - an initialism in a config directory name says which engagement as clearly as spelling it out |
| Employer identifiers | A company name where it implies who the author works for, an internal domain, an internal hostname |
| Email addresses | Any real address, work or personal |
| Personal names | Other people's names. The repository owner's own name in git metadata is expected and is not the target here |
| Absolute home paths | `/Users/<name>/...`, `/home/<name>/...`, and the projects-directory spelling of the same thing (`-Users-<name>--claude`) |
| Machine identifiers | The local username, the machine's hostname, a device serial |
| Session state | Session and conversation UUIDs, transcript filenames, project-directory hashes |
| Credentials | API keys and tokens of any provider, even expired ones, and anything key-shaped |
| Internal references | Internal URLs, ticket and issue IDs from a private tracker, Slack channel or workspace names |

## Neutral Substitutes To Use Instead

These are the conventions already in use in this repository. Reach for one of these rather than
inventing a new placeholder, so the substitutions stay consistent and greppable:

- **A second config directory**: `~/.claude-work`, the neutral name
  `docs/multi-account-claude-code.md` uses. Never a name that identifies the engagement.
- **A home directory in prose or a document**: `~/...`, or an angle-bracket placeholder
  (`/Users/<name>/...`). The check exempts angle-bracket placeholders by construction, since they
  cannot be mistaken for a real path.
- **A home directory in a script**: `$HOME`, `~`, or `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` when the
  path is inside the config directory. This is the portability idiom the repository already uses,
  and it is the same fix.
- **A fixture path**: a synthetic path under `/tmp` that the fixture's own runner creates, the way
  `scripts/statusline-tests/` does. A fixture asserting against the author's real home directory
  only passes on the author's machine anyway.
- **A placeholder identity**: the reserved example domains (`example.com`, `example.invalid`) and
  `/Users/example/...`. Both are exempt from the check.
- **A machine path or a transcript you need to refer to**: describe it instead of naming it. A
  local transcript path is not readable from the remote, so the exact value buys a reader nothing a
  description does not - the convention is to replace a reference like this with a description
  rather than remove it outright.

## When The Real Value Is Genuinely Needed

Route it to untracked state. The repository already has four places for this, in rough order of
preference:

1. A gitignored file, the way `scrub-patterns.local` holds this check's own
   project-specific patterns.
2. `settings.local.json`, for Claude Code settings that are true of one machine only.
3. Per-machine hook registration - the pattern `scripts/replicate.sh` uses, where the tracked
   script takes its target directories from the untracked `.git/hooks/replicate-targets.sh` that
   its hooks exec, rather than hardcoding which accounts exist.
4. Auto memory, for a machine-local fact an agent discovered rather than one the config depends on.

What is never acceptable is a tracked file carrying the real value with a note asking the reader to
disregard it. Publishing it is the harm; the note does not undo it.

## The Mechanical Check

`scripts/scrub-check.sh` enforces the categories above that can be recognized by shape. It is
read-only and exits non-zero on findings, and `scripts/pre-commit-check.sh` runs it so a commit
carrying a finding is blocked.

It reads tracked file content and nothing else. A commit message is not a tracked file, so none of
what follows applies to one - `scripts/commit-msg-check.sh` is the gate for those, and it calls
this script rather than restating its patterns.

Both take `--repo <dir>`, which scans a different checkout instead of this one, so a repository
wanting this same gate can borrow these scripts rather than copy them - a second copy drifts
silently, since a scrub check that has stopped matching still exits 0. What a borrower installs is
one hand-written hook and nothing else:

```sh
exec "<path-to-this-repo>/scripts/pre-commit-check.sh" --repo "$(git rev-parse --show-toplevel)"
```

`scripts/setup.sh` writes the same line for this repository, so there is one shape to keep right
rather than two. By hand in a borrower: registering a hook in someone else's repository is the act
`decisions/0003-hooks-and-scripts-authoring-policy.md` reserves for that repository's owner.
Whether a borrower still uses it is theirs to track - nothing here holds a
list, which is also why `--repo` counts as a stable interface: a borrower has no way to notice if
it changes shape.

The one exception is the commit-message gate, which `scripts/setup.sh --repo <dir>` writes into
another repository for you:

```sh
scripts/setup.sh --repo ~/src/some-project              # trailer check only
scripts/setup.sh --repo ~/src/some-project --with-scrub # and scan the message for leaks
```

That is not a loosening of the rule above. The owner typing that command is the explicit,
in-the-moment act the decision requires, exactly as typing `setup.sh` is; what stays forbidden is
an agent running either. It exists as a command rather than a pasted line because the message gate
is wanted in ordinary work repositories that have nothing to do with a public remote - the
`Co-Authored-By` rule is universal - and a line pasted into each of them is a copy that drifts.
The scrub half stays opt-in for the mirror reason: the patterns it applies are written for THIS
repository's remote, and a private work repository should not inherit them by default.

The gate may INSPECT a borrowed repository, never EXECUTE anything out of one. That is what decides
which checks travel: the leak checks do, and so does validating a `settings.json`, since `jq` only
reads it, while the projection check does not - running it would execute whatever sits at the
target's `scripts/sync.sh`.

The pattern and test files below always come from THIS repository's main checkout, because they
are gitignored and so absent from a linked worktree.

Run bare, `scrub-check.sh` audits every tracked file as it exists in the working tree - the
question you actually have ad hoc, "is this repository clean?". `--all` is an explicit synonym, and
explicit paths check those files in the working tree.

The commit gate passes **`--staged`**, which checks the bytes git is about to commit rather than the
working tree. That is not a refinement, it is the difference between blocking a leak and waving it
through: stage a file containing a secret, tidy the file afterwards, and a working-tree scan passes
while the secret commits. The mirror case blocks a clean staged version because of an unrelated
dirty edit, and partial staging (`git add -p`) hits both routinely. Findings are still reported
under their real repository path, and the line numbers refer to the version being committed.

The flag sits on the hook rather than on the human because the hook is written once by
`scripts/setup.sh` and never typed again, while the bare command gets typed repeatedly - and
defaulting to the wider scan fails in the safe direction, since a full-tree audit can only
over-report relative to a staged one.

It deliberately carries no sensitive values of its own, because a committed list of client and
employer names would be the leak it exists to prevent. Its patterns come from three places:

- **Structural patterns**, committed, matching shapes rather than values: absolute home paths,
  projects-path spellings, UUIDs, credential prefixes, email addresses.
- **Machine-derived literals**, computed at run time and never written down: the current username,
  the short hostname, and the git-configured email address and its domain. Values generic enough to
  appear as ordinary prose are dropped rather than searched for, so a username like `admin` does not
  bury real findings under noise.
- **`scrub-patterns.local`** at THIS repository's main checkout, gitignored, one extended regex per
  line, `#` for comments. This is where client and engagement tokens go. Add one the moment a new
  name enters your vocabulary; the script cannot catch a name it has never been told about.

  Its absence is a hard error (exit 2), not a silent skip. Structural coverage on its own is the
  kind of partial coverage that looks adequate right up until a client name reaches a public
  remote, so the check refuses to run rather than reporting a clean tree it cannot vouch for. An
  empty or comments-only file is fine and means "no project-specific tokens" - a deliberate answer,
  where a missing file is an unanswered question. `scripts/setup.sh` creates it; `scrub-check.sh`
  never writes anything, since a tool that materializes files from inside a pre-commit hook is a
  bad surprise.

  It needs no `.gitignore` rule. The root `.gitignore` opens with `/*`, which ignores every root
  entry not explicitly whitelisted, so a file there cannot be committed by accident - a structural
  guarantee rather than a rule someone could delete. That is why it lives at the root rather than
  beside the script that reads it: everything under the whitelisted `scripts/` is tracked unless an
  explicit ignore line says otherwise, and the failure mode of losing that line is silent
  publication of exactly the list this check exists to protect.

What it cannot catch: a client name with no pattern for it, a paraphrase that identifies someone
without naming them, and anything requiring judgment about whether a detail is identifying. Those
stay a human's job at review time, which is why the `CLAUDE.md` rule exists alongside the check
rather than being replaced by it.

Three files must name these categories in order to document them - this file,
`decisions/0009-public-repo-hygiene-as-an-always-on-rule.md`, and `scripts/scrub-check.sh` itself,
which spells the patterns out. None of them is exempted, and none needs to be: a placeholder and a
regex source do not match the patterns, so all three scan clean on their own terms. Keep it that
way rather than reaching for an exemption. The script carried a path allowlist covering these three
until 2026-08-30, removed because it had never exempted a finding and its own entry was the widest
hole available - a real value pasted into the detector would have been invisible to the check it
implements.
