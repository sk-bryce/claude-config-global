# Beacon documentation

Beacon is the metrics service that collects samples from our hosts and services, stores them, and
answers queries from the dashboard and the HTTP API. These pages describe how Beacon handles data
and who may do what with it.

## Components

Beacon runs as one server process made of eight components:

- the scraper, which pulls samples from each registered target;
- ingest, which validates scraped and pushed samples;
- the write-ahead log (WAL), which makes accepted samples durable;
- the compactor, which merges raw blocks into aggregate blocks and removes expired ones;
- the query engine, which answers range and instant queries;
- the rules engine, which evaluates recording and alerting rules;
- the notifier, which delivers alert notifications;
- the API, which serves the dashboard and automation.

## Policies

- [Ingest](ingest.md): how samples reach Beacon and what it rejects.
- [Retention](retention.md): how long raw and aggregate data is kept.
- [Alerting](alerting.md): the standard alerts and how they are routed.
- [Access](access.md): roles and what each one may do.

Raw samples are kept for 15 days. Aggregates are kept for about 13 months, which covers a full
year-over-year comparison.

## Reference

The pages under `reference/` describe each metric Beacon exports about itself and each server
setting. Start from `reference/index.md`.

## Changing settings

Settings live in the `settings` block of the server configuration. A restart of the Beacon server
applies a changed value. Each setting's reference page gives its default and what it controls.
