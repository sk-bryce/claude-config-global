# Deploy Playbook

This fixture exists only to give the review-md eval set a concrete document *set* to check. It is
not real project documentation. It is paired with `onboarding.md` in this directory, and the two
deliberately disagree with each other.

## Prerequisites

Node 18 is required. Newer versions are not supported by the deploy tooling.

## Shipping a change

Every PR needs **two** approving reviewers before it can be merged. Merges to `main` deploy
automatically.

## Rolling back

1. Find the last known-good release tag.
2. Re-run the deploy script against that tag.
3. Post in `#eng-releases` that a rollback happened.

## Further reading

- The onboarding doc covers local setup; this playbook covers everything after the PR is open.
