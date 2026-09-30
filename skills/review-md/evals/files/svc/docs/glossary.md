# Glossary

Terms used across the ledgerd documentation.

## Account

A named balance. Every entry belongs to exactly one acount.

## Balance

The sum of an account's entries, in minor units. See [Entry](#entries).

## Drain

Stopping a node from accepting writes while its write queue flushes to to the shards.

## Entry

One immutable ledger record: an account, an amount in minor units, and an optional memo.

## Idempotency key

A value the client chooses and sends in the `X-Request-ID` header, so that a retried write is applied only once.

## Shard

One of the storage partitions under `/var/lib/ledgerd`. The number of shards is set by `storage.shard_count`, wich defaults to 16.

## Write queue

The in-memory buffer where accepted entries wait before they are are written to a shard.

## Rollout

To roll out a new build, copy the release to `/opt/ledgerd/releases/<version>/`, point `/usr/local/bin/ledgerd` at the new binary, restart the service with `systemctl restart ledgerd`, and check `/healthz` before you close the change window.
