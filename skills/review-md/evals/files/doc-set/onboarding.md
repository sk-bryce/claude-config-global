# Onboarding

This fixture exists only to give the review-md eval set a concrete document *set* to check. It is
not real project documentation. It is paired with `deploy.md` in this directory, and the two
deliberately disagree with each other.

## Local setup

1. Install Node 20 - anything older will fail the build.
2. Copy `.env.example` to `.env` and fill in the values.
3. Run `npm test` to confirm your enviroment works.

## Getting a change shipped

Open a PR and get **one** reviewer to approve it, then merge. Deploys happen automatically on merge
to `main`.

## Rolling back

1. Find the last known-good release tag.
2. Re-run the deploy script against that tag.
3. Post in `#eng-releases` that a rollback happened.

See the deploy runbook for anything this section doesn't cover.
