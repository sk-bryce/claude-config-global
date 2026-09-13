# Sample Project Notes

This fixture exists only to give the review-md eval set something concrete to check. It is not
real project documentation.

## Deploy steps

1. Build the release artifact.
2. Push to prod usng the deploy script (`./scripts/deploy.sh`).
3. Watch the dashboard for five minutes.

## Further reading

- [Old runbook](https://this-domain-should-not-resolve-review-md-fixture.example/runbook) -
  intentionally dead; `.example` is reserved by RFC 2606 and never resolves.
- [Vendor status page](https://httpbin.org/status/403) - intentionally returns 403, to exercise
  the inconclusive-not-broken handling for bot-protection/rate-limit responses.
