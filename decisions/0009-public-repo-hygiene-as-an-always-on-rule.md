---
created: 2026-08-21
updated: 2026-08-31
---

# 9. Public repo hygiene is an always-on rule plus a commit gate, not a skill

- Status: Accepted
- Date: 2026-08-21
- Deciders: repository owner
- Related: `reference/public-repo-hygiene.md`, `reference/context-file-authoring.md`,
  `decisions/0003-hooks-and-scripts-authoring-policy.md`,
  `decisions/0004-document-generation-as-always-on-rule.md`, `specs/behaviors.md`

## Context

This repository targets a public remote. A human audit of every tracked file catches the sites
that carry a local username, an absolute workspace path, a config-directory abbreviation naming a
specific engagement, or session UUIDs. But such an audit is a one-time pass: nothing prevents the
same content from being reintroduced by the next edit, and the value of the scrub decays to zero
the first time it is.

The question was where the rule preventing recurrence should live.

`reference/context-file-authoring.md`'s routing table settles half of it: a rule that must fire with
zero exceptions belongs in a check, because context-file content is delivered as a user message and
an agent can read a rule and still deviate from it. But the categories are not all mechanically
recognizable - a client name is only identifiable to someone who knows it is one - so a check alone
cannot carry the policy either.

One constraint shaped the implementation more than any other: the detector cannot carry the values
it looks for. A committed list of client and employer names would be precisely the leak it exists to
prevent.

## Decision

Deliver this as an always-on rule with a mechanical gate underneath it, following the same
three-pointer shape `decisions/0004` used for document generation. No dedicated skill.

1. The full policy lives in `reference/public-repo-hygiene.md` - categories, the neutral substitutes
   already in use, where a real value goes when one is genuinely needed, and what the check does and
   does not cover. Classified as an internally-authored operational protocol, hence `reference/`.
2. A `CLAUDE.md` Repository Maintenance bullet points at that file. That section is already gated
   on the working directory being a checkout of this repository, so the rule costs other projects
   one line of context and nothing else.
3. `scripts/scrub-check.sh` detects the mechanically recognizable categories, and
   `scripts/pre-commit-check.sh` runs it as a third check beside the existing JSON-validity and
   projection-drift ones, invoked as `scrub-check.sh --staged` so it reads the bytes being
   committed. Reading the staged bytes matters: a working-tree scan lets a staged secret through
   whenever the file is tidied after staging. The correct-bytes behavior sits behind a flag that
   the hook always passes, rather than being the default: the hook is written once by
   `scripts/setup.sh` and never typed again, while the bare command is what a human types ad hoc and
   should answer the ad hoc question ("is this repository clean?"). Defaulting to the audit also
   fails in the safe direction, since a full-tree scan can only over-report relative to a staged
   one.

Scope is the working tree only. Commit history and commit identity are excluded deliberately: they
are a one-time remediation with a different risk profile (a history rewrite, and an author-email
change that interacts with GPG signing), not a rule about what to write next.

The detector's patterns come from three sources, of which only the first is committed: structural
patterns matching shapes rather than values; literals derived at run time from the current
environment (username, short hostname, git-configured email and its domain); and
`scrub-patterns.local`, gitignored, holding project- and client-specific regexes. This is the
same tracked-logic/untracked-configuration split `scripts/replicate.sh` already uses for its target
directories.

That file sits at the repository root, not beside the script that reads it, and its absence is a
hard error rather than a silent skip. Both choices follow from the same reasoning. The root
`.gitignore` opens with `/*`, so every unwhitelisted root entry is ignored structurally, where
anything under the whitelisted `scripts/` is tracked unless an explicit ignore line survives - and
the failure mode of losing that line is publishing the client-name list the check exists to
protect. A guarantee that holds by construction beats one that depends on a rule nobody re-reads.
Likewise, a check that passes quietly on a machine with no pattern file reports a clean tree it
cannot vouch for; structural coverage alone is exactly the partial coverage that looks adequate
until a client name reaches the remote. It therefore exits 2 and names the fix. An empty or
comments-only file is accepted and means "no project-specific tokens" - a deliberate answer, where
a missing file is an unanswered question. `scrub-check.sh` does not create it: it writes nothing at
all, because a tool that materializes files from inside a pre-commit hook is a bad surprise, so
`scripts/setup.sh` owns creation.

## Consequences

- A commit reintroducing a scrubbed identifier is blocked at the point a human is already reviewing
  the diff, rather than discovered after a push.
- The check inherits `pre-commit-check.sh`'s known limit: the git hook is untracked and local-only,
  so a fresh clone is unprotected until it is reinstalled. This is why the README gained a
  setup-after-cloning section rather than leaving the reinstall caveat buried in its `scripts/`
  list.
- The gate is inert on any machine where nobody has installed the hook. The tracked logic is the
  deliverable and the registration is local-only by nature, so a machine with no `pre-commit` entry
  under `.git/hooks/` runs no scrub check at all. Installing it is the user's explicit act rather
  than an agent's, per `decisions/0003`. This is the strongest argument for the setup-state
  detection described below.
- Three files must name the categories to document them - the policy, this record, and the script
  that spells the patterns out - and none of them needs an exemption: a placeholder and a regex
  source do not match the patterns, so all three scan clean on their own terms. The script carries
  no path allowlist for them: an allowlist would exempt no actual finding, and its own entry would
  be the widest hole available, since a real value pasted into `scrub-check.sh` would be invisible
  to the check it implements. Keeping those three clean is the standing requirement instead.
- The check is only as good as `scrub-patterns.local`, which is per-machine. Failing closed on its
  absence converts "silently weaker coverage" into "the commit is blocked until you answer", which
  is the right trade for a gate whose whole purpose is preventing an irreversible publication - at
  the cost that a fresh clone cannot commit at all until `scripts/setup.sh` has been run.
- Registration state asserted in a spec file and verified nowhere is how a hook recorded as
  registered goes missing without anything noticing, so it is not asserted that way here.
  `scripts/setup.sh --check` answers the question with evidence (see `specs/behaviors.md`'s
  Machine Setup section), and a `SessionStart` hook runs it at the start of every session whose cwd
  is inside this repository (see that file's Session Setup Check section). Drift on a machine
  nobody opens a session on is still found only when someone looks.

## Alternatives considered

- **A dedicated skill.** Rejected: a skill loads when invoked, and this rule has to hold on every
  edit to the repository. It would also spend always-loaded description budget in every session, in
  every project, for a rule that applies in one directory - the same reasoning as `decisions/0004`.
- **A registered `PreToolUse` hook, flagging a Write or Edit live.** Rejected: it fires on every
  tool call in every session, including in unrelated projects, to guard a repository the author
  commits to deliberately. The commit is the natural gate, and `specs/behaviors.md`'s Pre-commit
  Drift Check section already records why a git hook is a materially different risk class from a
  lifecycle hook.
- **The written policy with no check at all.** Rejected on the authority of this repository's own
  `reference/context-file-authoring.md`: advice an agent can deviate from is the wrong mechanism for
  a rule with no acceptable exceptions.
- **Committing the client-name patterns so a fresh clone inherits full coverage.** Rejected as
  self-defeating.

## References

- `reference/public-repo-hygiene.md` - the operational policy this rule delivers.
