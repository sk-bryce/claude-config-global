# ledgerd architecture

This page describes how ledgerd's components talk to each other, for new maintainers.

## Components

- The HTTP API accepts requests on the port set in `config/ledgerd.yaml`. The endpoints are
  defined in `specs/api.md`.
- The write queue buffers accepted entries in memory.
- The storage layer writes flushed entries to one of the shards under `/var/lib/ledgerd`.
- The Go client in `src/client.go` is how other services call the API.

## Request flow

A `POST /v2/entries` request is validated, placed on the write queue, and acknowledged once the
queue accepts it. Fields marked [optional] in the API specification may be left out of the body.

## The client

The Go client retries a failed request 3 times. It waits 200 ms before the first retry and doubles
the wait before each later one. Every write carries an `Idempotency-Key` header, so a retry that
reaches the server twice is applied once.

The client package also carries a small generic helper for transforming batches of entries:

```go
func Map[T any](xs []T, f func(T) T) []T {
	out := make([]T, 0, len(xs))
	for _, x := range xs {
		out = append(out, f(x))
	}
	return out
}
```

## The write queue

The queue flushes when it holds `queue.max_batch` entries or when `queue.flush_interval` has
passed, whichever comes first. A drain stops new writes and flushes whatever is left; the
procedure is in [Draining a node](operations.md#draining-a-node).

Queue depth and flush latency are charted on the
[queue dashboard](https://grafana.ledgerd.invalid/d/queue-depth).

## Storage layout

Each shard lives in its own directory, `/var/lib/ledgerd/<shard>/`, named by the shard number:

```text
/var/lib/ledgerd/<shard>/
    segments/
    index/
```

## References

- [Storage design notes](https://wiki.ledgerd.invalid/storage-design)
- [Upstream status page](https://httpbin.org/status/403)
