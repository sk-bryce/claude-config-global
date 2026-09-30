---
title: HTTP API
spec: specs/api.md (Endpoints)
---

# ledgerd HTTP API

This page is generated from `specs/api.md`. It lists every endpoint the ledgerd HTTP API serves.
Request and response bodies are JSON, and amounts are integers in minor units.

## Append an entry

`POST /v2/entries` appends one entry and returns `200 OK`. The response body holds the new entry's
`id`. Send an `Idempotency-Key` header so that a retried request is applied only once.

## Read a balance

`GET /v2/accounts/{id}/balance` returns the account's current balance with `200 OK`.

## List entries

`GET /v2/accounts/{id}/entries` lists the account's entries, newest first. `limit` defaults to 50
and can be raised to 1000.

## Drain a node

`POST /v2/drain` stops the node accepting writes and flushes the write queue to the shards. It
returns `202 Accepted`.

## Health

`GET /healthz` returns `200 OK` while the node is live.
