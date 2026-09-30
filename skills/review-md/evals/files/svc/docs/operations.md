# Operations

Day-to-day running of a ledgerd node: routine checks, draining, log rotation, and rolling back a
release. For a first install, see [Deploying ledgerd](deploy.md).

If a release misbehaves, go straight to [Rolling back](#rolling-back).

## Before any change

- Confirm the previous deploy finished and no drain is in progress.
- Check that disk usage under `/var/lib/ledgerd` is below 80 percent.
- Announce the change window in the ledger-ops channel.

## Daily checks

- Check `GET /healthz` on every node.
- Confirm that log rotation ran overnight. You will recieve a page if it fails two nights in a row.
- Watch the write queue depth on the metrics port. If it stays high, see
  [Tuning max_batch](#tuning-max_batch).

## Drain a node

Draining stops a node accepting writes and flushes the commit buffer to its shards.

Send `POST /v2/drain`, then wait for the the queue to empty before you stop the process.

To stop ledgerd, send `SIGTERM`. Sending `kill -9` is the nuclear option and skips the flush.

### Checks

- `GET /healthz` still returns `200 OK`.
- The write queue depth reads 0.

## Tuning max_batch

`queue.max_batch` caps how many entries one flush writes. The shipped value is 500. Raise it only
if flushes fall behind at the default `queue.flush_interval`.

## Log rotation

`scripts/rotate.sh` runs nightly from cron. It keeps rotated logs for 14 days by default; pass
`--keep-days` to change that, or `--dry-run` to see what it would delete.

## Rolling back

1. Drain the node as described in [Drain a node](#drain-a-node).
2. Point `/usr/local/bin/ledgerd` back at the previous release under `/opt/ledgerd/releases/`.
3. Restart the service with `systemctl restart ledgerd`.
4. Work through [the rollback checks](#checks-1).

### Checks

- `GET /healthz` returns `200 OK`.
- New entries appear in `GET /v2/accounts/{id}/entries`.
