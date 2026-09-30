# Ingest

Samples reach Beacon in two ways: the scraper pulls them from registered targets, and services
push them to the API. Both paths end in the ingest component, which validates each sample before
the write-ahead log accepts it.

## Scraping

The scraper pulls from each registered target every 30 seconds by default (`scrape_interval`). A
scrape that takes longer than 10 seconds (`scrape_timeout`) is abandoned, and the target's `up`
series records a 0 for that interval.

## Pushing

A service that cannot be scraped pushes batches to the API. One batch holds at most 5,000 samples
(`ingest_max_batch_size`); a larger batch is rejected whole, and the service should split it.

## What ingest rejects

Ingest rejects a sample when:

- its series has more than 30 labels (`ingest_max_labels`);
- its timestamp is more than one hour in the future;
- its value is not a number.

Rejected samples are counted in `beacon_ingest_errors_total` and never reach the write-ahead log.

## After ingest

Accepted raw samples remain queryable for 30 days, after which only the aggregates are left.

## Granting read access to a new team

A new team asks the observability team for Viewer accounts. The observability team creates one
account per engineer and one service account for the team's automation, then sends the team lead
the list of accounts so the lead can raise any that need Editor.
