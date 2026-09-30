---
title: Configuration reference
updated: 2026-03-02
---

# Configuration reference

ledgerd reads `/etc/ledgerd/ledgerd.yaml` at startup. The copy in `config/ledgerd.yaml` holds the
shipped defaults. As of March 2026, the current release is ledgerd 2.2.

## server

| Key | Default | Meaning |
| --- | --- | --- |
| `server.listen_addr` | `0.0.0.0` | Address the HTTP API binds. |
| `server.port` | `8420` | Port the HTTP API listens on. |
| `server.read_timeout` | `15s` | Longest time to read one request. |
| `server.write_timeout` | `15s` | Longest time to write one response. |

## storage

| Key | Default | Meaning |
| --- | --- | --- |
| `storage.data_dir` | `/var/lib/ledgerd` | Root directory for the shards. |
| `storage.shard_count` | `16` | Number of shards. Set it before the first start. |
| `storage.fsync` | `always` | Whether each flush is synced to disk. |

## queue

| Key | Default | Meaning |
| --- | --- | --- |
| `queue.max_batch` | `500` | Most entries written by one flush. |
| `queue.flush_interval` | `500ms` | Longest time an entry waits before a flush. |

Entries wait in the write queue until one of these limits is reached. A slow flush is logged as a
warning; see [logging](#loging).

## logging

| Key | Default | Meaning |
| --- | --- | --- |
| `logging.dir` | `/var/log/ledgerd` | Log directory. `scripts/rotate.sh` prunes it. |
| `logging.level` | `info` | Lowest level written. |
| `logging.format` | `json` | Log line format. |

## metrics

| Key | Default | Meaning |
| --- | --- | --- |
| `metrics.port` | `9420` | Port for the metrics endpoint, separate from the API port. |
