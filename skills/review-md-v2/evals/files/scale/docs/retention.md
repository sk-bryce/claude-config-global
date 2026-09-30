# Retention

Beacon keeps two kinds of data: raw samples, exactly as they were ingested, and aggregates, which
hold one value per series per five minutes.

## How long data is kept

| Data | Kept for | Setting |
| --- | --- | --- |
| Raw samples | 15 days | `raw_retention_days` |
| Aggregates | 400 days | `aggregate_retention_days` |

Both limits are measured from the sample's own timestamp, not from the time Beacon received it.

## How data is removed

The compactor removes expired blocks. It runs one compaction cycle every 2 hours by default
(`compaction_interval`), and each cycle does two things:

1. It merges raw blocks older than two hours into aggregate blocks.
2. It deletes every raw block whose newest sample is past `raw_retention_days`, and every aggregate
   block whose newest sample is past `aggregate_retention_days`.

A block is deleted whole, so a block can outlive its limit by up to one block span (two hours)
plus one compaction cycle.

## Querying old data

A query over a range older than 15 days reads aggregates only. The dashboard shows a notice on any
panel that has switched to aggregates, because short spikes inside a five-minute window are no
longer visible there.

## Changing the limits

Raising a limit keeps data that has not yet been deleted; it cannot bring back data a cycle has
already removed. Lowering a limit takes effect on the next compaction cycle after a restart.
