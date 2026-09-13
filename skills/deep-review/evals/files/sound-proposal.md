# Proposal: use `npm ci` for CI installs

## Problem

CI installs run `npm install`, which re-resolves declared ranges and will
update `package-lock.json` in place when a newer version satisfies a range.
Three build failures in the last month came from a transitive dependency
publishing a breaking patch release between a green local run and a red CI
run: CI installed a version nobody had ever run locally. Each cost roughly
half a day to diagnose, because the failure surfaced far from its cause.

## Proposal

Change the CI install step from `npm install` to `npm ci`. `npm ci` installs
exactly the tree recorded in the committed `package-lock.json` and fails if the
lockfile and `package.json` disagree, rather than resolving ranges afresh.
Dependency updates then arrive as an explicit lockfile change in a pull
request, where they are visible and get a CI run of their own.

## Alternatives considered

- **Do nothing.** Rejected: the failure recurred three times in one month, and
  the diagnosis cost is high because the symptom is remote from the cause.
- **Pin every dependency to an exact version in `package.json`.** Rejected: all
  three failures came from a transitive dependency, which manifest pinning does
  not constrain at all, so it would have prevented none of them. It also
  duplicates what the lockfile already records.
- **Add a scheduled nightly rebuild to catch drift earlier.** Rejected as a
  substitute: it detects breakage sooner but does not stop it reaching a pull
  request. Worth adding later as a complement, since pinning makes upstream
  drift invisible until someone bumps the lockfile.
- **Adopt a dependency-update bot (Dependabot or Renovate).** Not rejected, but
  sequenced second: it is the natural complement once installs are pinned,
  because it turns each drift event into a reviewed, already-CI'd PR. It does
  not help until CI stops re-resolving, so it is the next change, not this one.

## Cost

Dependency updates no longer arrive silently, so someone must land a lockfile
bump to pick up a patch release, including security patches. This is the
intended tradeoff: the update becomes a reviewed change rather than an ambient
one. Until the update bot lands, that job belongs to the on-call engineer as
part of the existing weekly rotation. A PR that edits `package.json` without
regenerating the lockfile will now fail at install rather than silently
re-resolving, which is the intended behavior.

## Rollout

There is one CI install site, in `.github/workflows/ci.yml` line 24 (confirmed
by grep across `.github/`, `Dockerfile`, `Makefile`, and `scripts/`). Change
that one command in a single pull request. Reversible by reverting that line;
no data migration and no change to local developer workflows.

## Definition of done

Zero transitive-drift build failures over the eight weeks after merge. A single
recurrence in that window means the diagnosis was wrong and this change should
be reverted rather than tightened further.
