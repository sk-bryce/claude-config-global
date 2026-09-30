# Deploying ledgerd

This page covers a routine production deploy of ledgerd and how to roll it back. For day-to-day
running of a node, see [Operations](operations.md).

We deploy on Tuesdays and Thursdays — never on a Friday, and never during month-end close.

## Before you start

- Confirm the previous deploy finished and no drain is in progress.
- Check that disk usage under `/var/lib/ledgerd` is below 80 percent.
- Announce the change window in the ledger-ops channel.

## Install the release

1. Copy the release to `/opt/ledgerd/releases/<version>/`.
2. Point `/usr/local/bin/ledgerd` at the new binary.
3. Copy `config/ledgerd.yaml` to `/etc/ledgerd/ledgerd.yaml` if the node has no configuration yet.
4. Restart the service with `systemctl restart ledgerd`.
5. Check health with `curl -fsS http://127.0.0.1:8080/healthz`.

Once started, ledgerd serves its HTTP API on port 8080.

Release artifacts are also listed on the [release mirror](https://httpbin.org/status/403).

## Log rotation

Add a nightly cron entry that runs `scripts/rotate-logs.sh` as the ledgerd user.

Rotated logs are kept for 30 days and then deleted.

## Rolling back

If the new release misbehaves, drain the node, point `/usr/local/bin/ledgerd` back at the
previus release, and restart the service. The configuration file does not change between
releases, so leave `/etc/ledgerd/ledgerd.yaml` as it is.
