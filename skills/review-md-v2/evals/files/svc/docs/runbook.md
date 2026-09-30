# Runbook: ledgerd node alerts

Use this page when a ledgerd node alerts. Work through the sections in order.

## Check the node

1. Check health with `curl -fsS http://127.0.0.1:8080/healthz`.
2. Read the latest log file under `/var/log/ledgerd`.
3. Check the write queue depth on the metrics port, `9420`.

ledgerd binds `0.0.0.0` by default, so it answers on every interface even though the client defaults to `127.0.0.1`.

## Restart the node

1. Drain the node with `POST /v2/drain` and wait for it to return `202 Accepted`.
2. Run `scripts/reset-state.sh` to mark the node's local state as reset.
3. Restart the service with `systemctl restart ledgerd`.

The write queue is persisted to disk, so a restart never loses queued entries (verified 2026-05-01).

## Escalate

If the node is not healthy 10 minutes after the restart, page the storage on-call engineer.
