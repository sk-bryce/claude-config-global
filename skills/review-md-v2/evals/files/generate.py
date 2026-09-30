"""Builders for the two workspaces whose documentation is too large to keep by hand.

scale(root): writes the metric and setting reference pages under root/docs/reference/.
large(root): expands each line of exactly {{FILLER:<n>}} in root/docs/handbook.md into n
reference subsections.

Standard library only. Output is deterministic, and running either builder again over an already
built tree leaves every byte unchanged.
"""
import pathlib
import re

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------


def _write(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = text.encode("ascii")
    if path.is_file() and path.read_bytes() == data:
        return
    path.write_bytes(data)


def _wrap(text, width=100):
    """Wrap one paragraph of prose to `width` columns."""
    words = text.split()
    lines = []
    cur = ""
    for w in words:
        if not cur:
            cur = w
        elif len(cur) + 1 + len(w) <= width:
            cur = cur + " " + w
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return "\n".join(lines)


def _paras(*paragraphs):
    return "\n\n".join(_wrap(p) for p in paragraphs)


# ---------------------------------------------------------------------------
# scale: Beacon metric and setting reference pages
# ---------------------------------------------------------------------------

# (key, alert name part, display name, what the component does, what one operation is)
COMPONENTS = [
    ("scraper", "Scraper", "scraper",
     "pulls samples from each registered target on the scrape interval",
     "one scrape of one target"),
    ("ingest", "Ingest", "ingest component",
     "validates scraped and pushed samples before the write-ahead log accepts them",
     "the validation of one batch of samples"),
    ("wal", "Wal", "write-ahead log",
     "makes accepted samples durable on disk before they are added to a block",
     "one append of a batch of samples to the current log segment"),
    ("compactor", "Compactor", "compactor",
     "merges raw blocks into aggregate blocks and removes blocks past their retention limit",
     "one compaction cycle"),
    ("query", "Query", "query engine",
     "answers range and instant queries from the dashboard and the HTTP API",
     "one query, from parsing to the last returned series"),
    ("rules", "Rules", "rules engine",
     "evaluates recording and alerting rules on the rule evaluation interval",
     "one evaluation of one rule group"),
    ("notifier", "Notifier", "notifier",
     "delivers alert notifications to the configured receivers",
     "one delivery attempt of one notification"),
    ("api", "Api", "API",
     "serves the HTTP API used by the dashboard and by automation",
     "one HTTP request"),
]

# (suffix, type, unit, what it counts or reports)
MEASURES = [
    ("operations_total", "counter", "operations",
     "counts every operation the {name} completes, whatever its outcome"),
    ("errors_total", "counter", "operations",
     "counts the operations of the {name} that ended in an error"),
    ("duration_seconds", "histogram", "seconds",
     "records how long each operation of the {name} takes"),
    ("queue_depth", "gauge", "items",
     "reports how many items are waiting for the {name} to pick them up"),
    ("bytes_total", "counter", "bytes",
     "counts the bytes the {name} has read or written"),
    ("last_success_timestamp_seconds", "gauge", "seconds since the Unix epoch",
     "reports the time at which the {name} last finished an operation without an error"),
    ("in_flight", "gauge", "operations",
     "reports how many operations of the {name} are running at this moment"),
    ("cancelled_total", "counter", "operations",
     "counts the operations of the {name} that were stopped before they finished, for example "
     "by a timeout or by a server shutdown"),
]

# What a change in each measure usually means, keyed by suffix.
CHANGES = {
    "operations_total": [
        "A rising rate means more work is reaching the {name}: more targets, more pushed "
        "batches, more queries, or more rules, depending on what feeds it. That is normal after "
        "a new service starts sending data or a new dashboard goes into use.",
        "A rate that falls to zero means the {name} has stopped doing work. Check "
        "`beacon_{key}_last_success_timestamp_seconds` next: if it is still recent, the "
        "component may simply be idle; if it is old, the component is stuck or down.",
        "Always read this rate next to the error rate. A steady operations rate with a rising "
        "error rate is a failure; a rising operations rate with a steady error ratio is load.",
    ],
    "errors_total": [
        "A rising error rate means more of the {name}'s operations are failing. Break it down by "
        "the `reason` label first: one reason that dominates usually points at one cause, such "
        "as one bad source of input, while an even spread across reasons points "
        "at the host, the disk, or the network.",
        "Compare the error rate with `beacon_{key}_operations_total`. A few errors a minute on a "
        "busy component can be well under 5 percent and need no action; the same count on a "
        "quiet component can be most of its work.",
        "Errors that start right after a restart and then stop are usually operations that were "
        "cut off by the restart itself, and they show up in `beacon_{key}_cancelled_total` as "
        "well.",
    ],
    "duration_seconds": [
        "A rising high quantile with a steady operations rate usually means something the {name} "
        "depends on has slowed down, such as the disk or the network, rather than more load.",
        "A rising high quantile together with a rising operations rate usually means load: the "
        "component is doing more work at once and each piece takes longer. Check "
        "`beacon_{key}_in_flight` to see how many operations overlap.",
        "A falling duration is not always good news. If it comes with a rising error rate, "
        "operations may be failing fast instead of finishing.",
    ],
    "queue_depth": [
        "A small, steady queue is normal: items arrive in bursts, and the {name} works through "
        "each burst before the next one.",
        "A queue that keeps growing means the {name} cannot keep up with what arrives. Check "
        "`beacon_{key}_duration_seconds` to see whether each operation has become slower, and "
        "`beacon_{key}_operations_total` to see whether more work is arriving.",
        "A queue that drops to zero and stays there on a busy instance can mean the work is no "
        "longer reaching the {name} at all. Compare with the operations rate before you treat it "
        "as healthy.",
    ],
    "bytes_total": [
        "The byte rate follows data volume. A step change usually means a new source of data, "
        "such as a new service sending many more series, or an old one that has stopped.",
        "Break the rate down by the `direction` label. Reads and writes that move together are "
        "ordinary work; reads that grow while writes stay flat can mean the {name} is repeating "
        "work, for example after errors.",
        "Compare the byte rate with the operations rate to get the average size of one "
        "operation. A sudden rise in that size is worth tracing to the source that caused it.",
    ],
    "last_success_timestamp_seconds": [
        "The age of this value, the current time minus the value, is how long ago the {name} "
        "last finished an operation without an error. On a busy instance it stays within a few "
        "seconds or minutes.",
        "An age that keeps growing means the {name} has stopped succeeding. Past 15 minutes the "
        "standard stale alert fires. Check `beacon_{key}_errors_total` to tell a failing "
        "component from an idle one.",
        "After a restart the value starts again from the first successful operation, so a "
        "freshly started instance can look stale for a short time until its first operation "
        "finishes.",
    ],
    "in_flight": [
        "The in-flight count is bounded by how much work the {name} runs at once. It moves up "
        "and down with load, and a busy instance seldom sits at zero for long.",
        "A count that stays high while `beacon_{key}_operations_total` stays flat means "
        "operations are starting and not finishing. That usually points at a hung dependency, "
        "such as a target or a disk that stopped responding.",
        "When the count rises together with `beacon_{key}_duration_seconds`, operations are "
        "overlapping because each one takes longer. Look for the slow dependency first.",
    ],
    "cancelled_total": [
        "A short burst of cancellations during a restart is normal: the server stops operations "
        "that are still running when it shuts down.",
        "A steady rate of cancellations outside restarts usually means operations are running "
        "into a timeout. Compare the rate with the high quantiles of "
        "`beacon_{key}_duration_seconds`; if they sit near the timeout, the timeout or the "
        "workload needs a look.",
        "Cancelled operations are not counted as errors, so a component can cancel a lot of work "
        "without its error alert firing. Chart this metric next to the error rate on the {name} "
        "panel.",
    ],
}

# (name, component key, kind, default, what it controls, how to choose a value)
SETTINGS = [
    ("scrape_interval", "scraper", "duration", "30s",
     "how often the scraper pulls samples from each registered target",
     "A shorter interval gives finer-grained data and costs more scrapes and more storage per "
     "hour. A longer one saves that cost, but changes shorter than the interval are no longer "
     "seen."),
    ("scrape_timeout", "scraper", "duration", "10s",
     "how long the scraper waits for one target before it abandons that scrape",
     "Keep the timeout below the scrape interval, so that a slow target is abandoned before its "
     "next scrape is due. A longer timeout tolerates slow targets; a shorter one frees the scraper "
     "sooner."),
    ("ingest_max_batch_size", "ingest", "count", "5000",
     "the largest number of samples one pushed batch may hold",
     "Raising the value lets services push larger batches, and uses more memory while ingest "
     "validates each one. Lowering it protects the server from very large batches, at the cost "
     "of making services split their pushes."),
    ("ingest_max_labels", "ingest", "count", "30",
     "the largest number of labels one series may carry",
     "Raising the value accepts series with more labels, and each extra label adds to the memory "
     "every series costs. Lowering it rejects more series at ingest."),
    ("wal_segment_size", "wal", "size", "128MiB",
     "the size at which the write-ahead log closes its current segment and opens a new one",
     "A larger size means fewer, bigger segment files, which are cheaper to manage but slower to "
     "replay after a crash. A smaller size means more files and a faster replay."),
    ("wal_fsync_interval", "wal", "duration", "1s",
     "how often the write-ahead log flushes appended samples to disk",
     "A shorter interval loses fewer samples if the host crashes, and costs more disk writes. A "
     "longer one writes less often, and a crash can lose up to one interval of samples."),
    ("raw_retention_days", "compactor", "count", "15",
     "how many days raw samples are kept before the compactor deletes them",
     "Raising the value keeps raw samples longer and uses more disk. Lowering it frees disk on "
     "the first compaction cycle after a restart. Raising it cannot bring back samples that were "
     "already deleted; see the [retention policy](../retention.md)."),
    ("aggregate_retention_days", "compactor", "count", "400",
     "how many days aggregates are kept before the compactor deletes them",
     "Raising the value keeps aggregates longer and uses more disk. Lowering it frees disk on the "
     "first compaction cycle after a restart. Raising it cannot bring back aggregates that were "
     "already deleted; see the [retention policy](../retention.md)."),
    ("compaction_interval", "compactor", "duration", "2h",
     "how often the compactor starts a compaction cycle",
     "A shorter interval removes expired blocks sooner and spends more disk and processor time on "
     "compaction. A longer one does the same work in fewer, larger cycles."),
    ("query_timeout", "query", "duration", "2m",
     "how long one query may run before the query engine stops it",
     "A longer timeout lets slow, wide queries finish, and lets one heavy query hold resources "
     "for longer. A shorter one protects other users of the query engine and stops more of the "
     "heavy queries."),
    ("query_max_series", "query", "count", "50000",
     "the largest number of series one query may return",
     "Raising the value allows wider queries, and uses more memory for each one. Lowering it "
     "protects the query engine, at the cost of refusing queries that match many series."),
    ("rule_evaluation_interval", "rules", "duration", "1m",
     "how often the rules engine evaluates each rule group",
     "A shorter interval makes alerts fire sooner after a problem starts, and costs more query "
     "work per hour. A longer one saves that work and delays every alert by up to one interval."),
    ("notifier_group_wait", "notifier", "duration", "30s",
     "how long the notifier waits to collect related alerts into one notification",
     "A shorter wait delivers the first notification sooner and sends more separate "
     "notifications. A longer one sends fewer, fuller notifications a little later."),
    ("notifier_retry_limit", "notifier", "count", "4",
     "how many times the notifier retries a failed delivery before it gives up",
     "Raising the value gives a failing receiver more chances, and delays the moment the notifier "
     "gives up on a notification. Lowering it gives up sooner."),
    ("api_listen_port", "api", "port", "9400",
     "the TCP port the API listens on",
     "Change the port only together with every client that reaches the API, such as the "
     "dashboard and the automation that pushes samples, since they stop reaching the API until "
     "they use the new port."),
    ("api_request_timeout", "api", "duration", "30s",
     "how long the API waits for one request to finish before it returns an error",
     "A longer timeout lets slow requests finish, and holds a connection open for longer. A "
     "shorter one frees connections sooner and returns more errors on slow requests."),
]

_COMPONENTS_BY_KEY = {c[0]: c for c in COMPONENTS}


def _metric_name(comp_key, suffix):
    return "beacon_%s_%s" % (comp_key, suffix)


def _reading_section(mtype, metric, unit):
    if mtype == "counter":
        return _paras(
            "This metric is a counter. Its value only goes up while the server runs, and it starts "
            "again from zero when the server restarts. The raw value is rarely useful on its own; "
            "read it as a rate over a window instead.",
            "A rate over five minutes gives the number of %s per second, averaged over that "
            "window. A longer window smooths out short bursts; a shorter one shows them but is "
            "noisier. The query engine handles the reset at a restart for you when you use a rate "
            "function, so a restart does not show up as a drop." % unit,
            "When you compare two instances, compare their rates rather than their raw values. "
            "Two instances that started at different times hold very different totals even when "
            "they do the same amount of work.",
        )
    if mtype == "gauge":
        return _paras(
            "This metric is a gauge. Its value can go up and down, and each sample is the value "
            "at the moment of the scrape. Read it directly, or take the maximum or average over a "
            "window when you want one number for a period.",
            "Because a gauge is sampled, a change that starts and ends between two scrapes does "
            "not appear at all. At the default scrape interval of 30 seconds, anything shorter "
            "than that can be missed.",
            "When you compare instances, compare the values directly: unlike a counter, a gauge "
            "does not depend on how long the instance has been running.",
        )
    return _paras(
        "This metric is a histogram. Each observation falls into a bucket, and the metric exports "
        "one counter per bucket (with the `le` label giving the bucket's upper bound), plus a sum "
        "and a count of all observations.",
        "Read it as a quantile over a window: the 99th percentile over five minutes answers how "
        "long the slowest one percent of operations took in that window. The quantile is an "
        "estimate, and it is only as fine as the bucket bounds around it.",
        "The sum divided by the count gives the mean duration. The mean hides a slow tail, so use "
        "it next to a high quantile rather than instead of one.",
    )


def _queries_section(mtype, metric, comp_key):
    if mtype == "counter":
        lines = [
            "sum by (instance) (rate(%s[5m]))" % metric,
            "sum(rate(%s[1h]))" % metric,
        ]
        if metric.endswith("_errors_total"):
            lines.append(
                "sum(rate(%s[10m])) / sum(rate(beacon_%s_operations_total[10m]))"
                % (metric, comp_key)
            )
    elif mtype == "gauge":
        if metric.endswith("_last_success_timestamp_seconds"):
            lines = [
                "time() - max by (instance) (%s)" % metric,
                "min(time() - %s)" % metric,
            ]
        else:
            lines = [
                "max by (instance) (%s)" % metric,
                "avg_over_time(%s[15m])" % metric,
            ]
    else:
        lines = [
            "histogram_quantile(0.99, sum by (le) (rate(%s_bucket[5m])))" % metric,
            "histogram_quantile(0.5, sum by (le) (rate(%s_bucket[5m])))" % metric,
            "sum(rate(%s_sum[5m])) / sum(rate(%s_count[5m]))" % (metric, metric),
        ]
    return "```text\n" + "\n".join(lines) + "\n```"


def _labels_table(suffix):
    rows = [("`instance`", "The Beacon server instance that exported the sample.")]
    if suffix == "errors_total":
        rows.append(("`reason`", "A short, fixed code for the kind of error, such as `timeout` "
                     "or `invalid`."))
    if suffix == "duration_seconds":
        rows.append(("`le`", "On the bucket series only: the bucket's upper bound in seconds."))
    if suffix == "bytes_total":
        rows.append(("`direction`", "`read` for bytes read and `write` for bytes written."))
    out = ["| Label | Meaning |", "| --- | --- |"]
    for name, meaning in rows:
        out.append("| %s | %s |" % (name, meaning))
    return "\n".join(out)


def _alert_section(comp, suffix):
    key, alert_part, name, _does, _op = comp
    if suffix == "errors_total":
        return _paras(
            "The standard alert `Beacon%sErrorsHigh` uses this metric. It fires when more than 5 "
            "percent of the %s's operations end in an error for 10 minutes. The ratio is this "
            "metric's rate divided by the rate of `beacon_%s_operations_total`." % (alert_part, name, key),
            "When it fires, look at the `reason` label first: one reason dominating usually points "
            "at one cause, while an even spread points at the host or the network.",
        )
    if suffix == "last_success_timestamp_seconds":
        return _paras(
            "The standard alert `Beacon%sStale` uses this metric. It fires when the %s's last "
            "successful operation is more than 15 minutes old." % (alert_part, name),
            "A stale component is often idle rather than broken, for example on an instance that "
            "has no work routed to it. Check the operations rate before you treat it as an outage.",
        )
    return _paras(
        "No standard alert uses this metric directly. It is charted on the %s panel of the "
        "server overview dashboard, next to the metrics the standard alerts use." % name,
    )


def _metric_page(comp, measure):
    key, _alert_part, name, does, op = comp
    suffix, mtype, unit, what = measure
    metric = _metric_name(key, suffix)
    what = what.format(name=name)
    siblings = [_metric_name(key, m[0]) for m in MEASURES if m[0] != suffix]
    settings = [s[0] for s in SETTINGS if s[1] == key]
    parts = [
        "# `%s`" % metric,
        _paras("This page describes `%s`, one of the metrics the Beacon server exports about its "
               "own %s." % (metric, name)),
        "## Summary",
        "\n".join([
            "| Field | Value |",
            "| --- | --- |",
            "| Name | `%s` |" % metric,
            "| Type | %s |" % mtype,
            "| Unit | %s |" % unit,
            "| Component | %s |" % name,
        ]),
        "## What it measures",
        _paras(
            "The %s %s. One operation of the %s is %s." % (name, does, name, op),
            "This metric %s. Every Beacon server instance exports it, including an instance "
            "where the %s is idle." % (what, name),
        ),
        "## Labels",
        _labels_table(suffix),
        "## Reading the value",
        _reading_section(mtype, metric, unit),
        "## Example queries",
        _queries_section(mtype, metric, key),
        "## When the value changes",
        _paras(*[c.format(name=name, key=key) for c in CHANGES[suffix]]),
        "## Alerts",
        _alert_section(comp, suffix),
        "## Retention",
        _paras(
            "Samples of this metric are stored like any other series, so they follow the "
            "[retention policy](../retention.md): raw samples first, then aggregates for "
            "long-range queries. A query over an old range therefore reads five-minute aggregates "
            "and can miss short changes."
        ),
        "## Related metrics",
        "\n".join("- [`%s`](%s.md)" % (s, s) for s in siblings),
        "## Related settings",
        "\n".join("- [`%s`](%s.md)" % (s, s) for s in settings),
    ]
    return metric, "\n\n".join(parts) + "\n"


_KIND_TEXT = {
    "duration": ("a duration: a whole number followed by a unit, `s` for seconds, `m` for "
                 "minutes, or `h` for hours"),
    "size": "a size: a whole number followed by `KiB`, `MiB`, or `GiB`",
    "count": "a whole number",
    "port": "a TCP port number",
}


def _choosing_section(kind, default, choosing):
    return _paras(
        "The value is %s. The default is `%s`." % (_KIND_TEXT[kind], default),
        choosing,
        "Change the value in small steps, and watch the component's metrics for a day after "
        "each step.",
    )


def _setting_page(setting):
    sname, comp_key, kind, default, controls, choosing = setting
    comp = _COMPONENTS_BY_KEY[comp_key]
    _key, _alert_part, name, does, _op = comp
    metrics = [_metric_name(comp_key, m[0]) for m in MEASURES]
    parts = [
        "# `%s`" % sname,
        _paras("This page describes the `%s` server setting, which belongs to the %s." % (sname, name)),
        "## Summary",
        "\n".join([
            "| Field | Value |",
            "| --- | --- |",
            "| Setting | `%s` |" % sname,
            "| Component | %s |" % name,
            "| Kind | %s |" % kind,
            "| Default | `%s` |" % default,
        ]),
        "## What it controls",
        _paras(
            "This setting controls %s." % controls,
            "The %s %s, so this value shapes how that work is paced and bounded." % (name, does),
        ),
        "## Choosing a value",
        _choosing_section(kind, default, choosing),
        "## Changing it",
        _paras(
            "Set the value in the `settings` block of the server configuration, then restart the "
            "Beacon server; a running server does not pick up a changed value. The new value "
            "applies from the first cycle after the restart.",
            "Changing a setting needs the Operator role. Record the old value before you change "
            "it, so that you can put it back if the component's metrics get worse.",
        ),
        "## Checking the change",
        _paras(
            "After the restart, open the %s panel of the server overview dashboard and compare "
            "the next day with the day before the change. The operations rate, the error rate, "
            "and the high quantiles of the duration histogram show most effects of a new value."
            % name,
            "If the error rate rises or the duration quantiles climb after the change, put the "
            "old value back and restart again before you try a smaller step.",
        ),
        "## Related metrics",
        "\n".join("- [`%s`](%s.md)" % (m, m) for m in metrics),
    ]
    return sname, "\n\n".join(parts) + "\n"


def _reference_index(metric_names, setting_names):
    parts = [
        "# Reference",
        _paras(
            "These pages describe every metric the Beacon server exports about itself and every "
            "server setting. Each metric page gives the metric's type, unit, labels, and example "
            "queries; each setting page gives the setting's default and what it controls."
        ),
        "## Metrics",
        "\n".join("- [`%s`](%s.md)" % (m, m) for m in metric_names),
        "## Settings",
        "\n".join("- [`%s`](%s.md)" % (s, s) for s in setting_names),
    ]
    return "\n\n".join(parts) + "\n"


def scale(root):
    """Write the Beacon reference pages under root/docs/reference/."""
    ref = pathlib.Path(root) / "docs" / "reference"
    metric_names = []
    for comp in COMPONENTS:
        for measure in MEASURES:
            name, text = _metric_page(comp, measure)
            metric_names.append(name)
            _write(ref / (name + ".md"), text)
    setting_names = []
    for setting in SETTINGS:
        name, text = _setting_page(setting)
        setting_names.append(name)
        _write(ref / (name + ".md"), text)
    _write(ref / "index.md", _reference_index(metric_names, setting_names))


# ---------------------------------------------------------------------------
# large: Ferry handbook subsections
# ---------------------------------------------------------------------------

QUEUE_WORKERS = {"default": 8, "bulk": 4, "urgent": 2}

QUEUE_NOTES = {
    "default": "It runs on the `default` queue, which has 8 workers and takes most everyday work.",
    "bulk": ("It runs on the `bulk` queue, which has 4 workers of its own, so a long run here "
             "never holds up `default` or `urgent` work."),
    "urgent": ("It runs on the `urgent` queue, which has 2 workers kept free for short, "
               "time-sensitive work."),
}

# (name, owner team, queue, cron schedule, schedule in words, what it does)
JOBS = [
    ("invoice-rollup", "billing", "bulk", "15 2 * * *", "every day at 02:15",
     "adds up the previous day's invoices into one summary row per account"),
    ("payment-reconcile", "billing", "default", "30 3 * * *", "every day at 03:30",
     "matches the previous day's card payments against the processor's settlement report"),
    ("dunning-notices", "billing", "default", "0 9 * * 1-5", "at 09:00 on weekdays",
     "sends reminders for invoices that are more than 14 days overdue"),
    ("tax-export", "billing", "bulk", "0 4 1 * *", "at 04:00 on the first day of each month",
     "exports the previous month's taxable sales for the finance team"),
    ("search-reindex", "search", "bulk", "0 1 * * 0", "every Sunday at 01:00",
     "rebuilds the product search index from the catalog database"),
    ("search-delta", "search", "default", "*/10 * * * *", "every 10 minutes",
     "adds catalog changes from the last 10 minutes to the search index"),
    ("synonym-refresh", "search", "default", "0 6 * * *", "every day at 06:00",
     "reloads the search synonym list that the merchandising team maintains"),
    ("session-sweep", "identity", "default", "0 * * * *", "every hour, on the hour",
     "deletes login sessions that expired more than one day ago"),
    ("token-revoke-sync", "identity", "urgent", "*/5 * * * *", "every 5 minutes",
     "pushes newly revoked API tokens to every edge node"),
    ("password-expiry-mail", "identity", "default", "0 8 * * *", "every day at 08:00",
     "emails accounts whose passwords expire within the next 7 days"),
    ("audit-archive", "identity", "bulk", "30 0 * * *", "every day at 00:30",
     "moves audit log entries older than 90 days to cold storage"),
    ("stock-sync", "catalog", "urgent", "*/2 * * * *", "every 2 minutes",
     "copies warehouse stock levels into the catalog so product pages show current stock"),
    ("price-import", "catalog", "default", "0 5 * * *", "every day at 05:00",
     "imports the next day's prices from the pricing team's upload area"),
    ("image-resize", "catalog", "bulk", "0 */3 * * *", "every 3 hours",
     "creates thumbnail and zoom sizes for newly uploaded product images"),
    ("feed-export", "catalog", "bulk", "0 2 * * *", "every day at 02:00",
     "writes the product feed that partner marketplaces download"),
    ("orphan-image-cleanup", "catalog", "bulk", "0 3 * * 6", "every Saturday at 03:00",
     "removes stored images that no product refers to any more"),
    ("order-digest", "fulfilment", "default", "0 7 * * *", "every day at 07:00",
     "sends each warehouse a digest of the orders it must ship that day"),
    ("carrier-label-retry", "fulfilment", "urgent", "*/15 * * * *", "every 15 minutes",
     "requests shipping labels again for orders whose first label request failed"),
    ("delivery-status-poll", "fulfilment", "default", "*/20 * * * *", "every 20 minutes",
     "asks each carrier for status updates on parcels that are still in transit"),
    ("returns-close", "fulfilment", "default", "0 22 * * *", "every day at 22:00",
     "closes return requests whose parcels arrived back more than 3 days ago"),
    ("warehouse-snapshot", "fulfilment", "bulk", "45 23 * * *", "every day at 23:45",
     "records each warehouse's stock at the end of the day for the finance team"),
    ("usage-metering", "platform", "default", "5 * * * *", "every hour at five past",
     "totals each customer's API calls for the previous hour"),
    ("cert-expiry-check", "platform", "default", "0 10 * * *", "every day at 10:00",
     "warns the platform team about TLS certificates that expire within 21 days"),
    ("backup-verify", "platform", "bulk", "0 5 * * 0", "every Sunday at 05:00",
     "restores the most recent database backup to a scratch host and checks that it opens"),
    ("dns-drift-report", "platform", "default", "30 9 * * 1", "every Monday at 09:30",
     "compares live DNS records with the records the platform team expects"),
    ("log-compress", "platform", "bulk", "15 0 * * *", "every day at 00:15",
     "compresses the previous day's application logs"),
    ("newsletter-send", "marketing", "bulk", "0 10 * * 2", "every Tuesday at 10:00",
     "sends the weekly newsletter to subscribed customers"),
    ("coupon-expire", "marketing", "default", "0 0 * * *", "every day at midnight",
     "marks coupons past their end date as expired"),
    ("campaign-stats", "marketing", "default", "0 */6 * * *", "every 6 hours",
     "refreshes the open and click counts shown on the campaign dashboard"),
    ("unsubscribe-sync", "marketing", "urgent", "*/10 * * * *", "every 10 minutes",
     "pushes new unsubscribe requests to the email provider"),
]

# (queue, condition key)
ALERT_CONDITIONS = ["Backlog", "Stalled", "FailureRate", "RetrySpike", "WorkersMissing"]
BACKLOG_LIMITS = {"default": 200, "bulk": 500, "urgent": 20}

# (code, title, cause, fix)
ERRORS = [
    ("FRY-101", "Unknown job",
     "The run names a job the scheduler does not know. The name is usually misspelled.",
     "Check the name against the job list in this handbook and submit it again."),
    ("FRY-102", "Unknown queue",
     "The run asks for a queue that has no `[queues.<name>]` table in `config/ferry.toml`.",
     "Submit it again with `--queue` set to `default`, `bulk`, or `urgent`."),
    ("FRY-103", "Queue full",
     "The queue already holds the most runs it will accept, and the scheduler refused this one.",
     "Wait for the queue to shrink, or submit the run to another queue with `--queue`."),
    ("FRY-104", "Scheduler draining",
     "The scheduler is draining and does not start new runs.",
     "Wait for the maintenance to finish and the scheduler to restart, then submit again."),
    ("FRY-105", "Worker lost",
     "The worker running the job stopped without reporting a result, usually because its host "
     "restarted.",
     "The scheduler retries the run on its own; act only if the retries also fail."),
    ("FRY-106", "Step timed out",
     "One step of the job ran longer than the job allows for that step.",
     "Look in the day's log for the step name, then ask the owning team whether the input "
     "was larger than usual."),
    ("FRY-107", "Retries exhausted",
     "The run failed on every attempt the retry limit allowed, and the scheduler marked it failed.",
     "Read the error code of the last attempt in the log and follow its entry here."),
    ("FRY-108", "Upstream unavailable",
     "A service the job depends on refused the connection or did not answer.",
     "Check that service's status first; resubmit the job once it is healthy again."),
    ("FRY-109", "Permission denied",
     "The job's credentials were refused by a service it calls.",
     "Ask the owning team to renew the job's credentials, then submit the job again."),
    ("FRY-110", "Input missing",
     "A file or table the job reads did not exist when the job started.",
     "Check whether the job that produces that input ran; run it first if it did not."),
    ("FRY-111", "Output conflict",
     "The job found output from an earlier run of the same period and stopped rather than "
     "overwrite it.",
     "Ask the owning team whether the earlier output is complete before you remove it."),
    ("FRY-112", "Disk full",
     "The worker host ran out of disk space while the job wrote to it.",
     "Free space on the host, then submit the job again."),
    ("FRY-113", "Out of memory",
     "The worker host killed the job because it used more memory than the host allows.",
     "Ask the owning team whether the input was larger than usual, and whether the run can be "
     "split into smaller periods."),
    ("FRY-114", "Duplicate run",
     "A run of the same job for the same period was already in progress, so the scheduler "
     "refused the second one.",
     "Wait for the first run to finish; check `scripts/ferryctl.sh status` to see it."),
    ("FRY-115", "Invalid schedule",
     "The job's schedule is not a valid cron expression, so the scheduler could not work out "
     "the next run time.",
     "Ask the owning team to correct the schedule; runs submitted by hand still work."),
    ("FRY-116", "Configuration unreadable",
     "`ferryd` could not parse `config/ferry.toml` at startup.",
     "Put back the previous copy of the file, restart the scheduler, and then find the mistake "
     "in the new version."),
    ("FRY-117", "Clock skew",
     "The worker host's clock differs from the scheduler's by more than one minute, so the run's "
     "times could not be recorded reliably.",
     "Ask the platform team to fix time keeping on that host, then submit the job again."),
    ("FRY-118", "Arguments too large",
     "The run's arguments were larger than the scheduler accepts for one run.",
     "Ask the owning team to pass a reference to the data instead of the data itself."),
    ("FRY-119", "Lock held",
     "Another run held the lock the job needs on a shared resource, such as one table or one "
     "storage area.",
     "Nothing, in most cases: the other run releases the lock when it finishes."),
    ("FRY-120", "Call timed out",
     "A call from the job to another service took longer than the job allows for one call.",
     "Check that service's latency first; resubmit the job once the service answers normally."),
]


def _job_entry(job):
    name, team, queue, cron, when, does = job
    lines = [
        "### Job: %s" % name,
        "",
        _wrap("Owner: the %s team. Queue: `%s`. Schedule: `%s` (%s UTC)." % (team, queue, cron, when)),
        "",
        _paras(
            "The %s job %s. %s" % (name, does, QUEUE_NOTES[queue]),
            "When a run fails, the scheduler retries it under the retry settings in "
            "`config/ferry.toml`, with the wait doubling between attempts. If every attempt "
            "fails, the run is marked failed and the %s team is told." % team,
        ),
        "",
        "To run it by hand outside its schedule:",
        "",
        "```sh",
        "scripts/ferryctl.sh submit --queue %s %s" % (queue, name),
        "```",
        "",
        _wrap("Add `--dry-run` first if you only want to see what the run would do. Ask the %s "
              "team before you run it twice for the same period." % team),
        "",
        _paras(
            "While a run is in progress, `scripts/ferryctl.sh status` lists it under the `%s` "
            "queue with the time it started. A run that has gone on much longer than usual is "
            "worth a look before it trips the queue's stalled alert." % queue,
            "If a run fails, find it in the day's log file under `/var/log/ferry`, read the error "
            "code on its last attempt, and follow that code's entry under Troubleshooting. When "
            "the cause is something the %s team owns, hand the run's log lines to them." % team,
        ),
    ]
    return "\n".join(lines)


def _alert_entry(queue, condition):
    alert = "Ferry%sQueue%s" % (queue.capitalize(), condition)
    workers = QUEUE_WORKERS[queue]
    if condition == "Backlog":
        when = ("more than %d runs have been waiting on the `%s` queue for 15 minutes"
                % (BACKLOG_LIMITS[queue], queue))
        means = ("work is arriving faster than the queue's %d workers finish it. A large "
                 "scheduled job, or many runs submitted by hand at once, is the usual cause."
                 % workers)
        check = ("Run `scripts/ferryctl.sh status` and look at which jobs are waiting. If one job "
                 "dominates, ask its owning team whether its runs can wait.")
    elif condition == "Stalled":
        when = ("no run on the `%s` queue has finished for 30 minutes while runs are waiting"
                % queue)
        means = ("every one of the queue's %d workers is busy with a run that is not making "
                 "progress, or the workers have stopped." % workers)
        check = ("Run `scripts/ferryctl.sh status` to see what each worker is running, then look "
                 "for those runs in the day's log file under `/var/log/ferry`.")
    elif condition == "FailureRate":
        when = "more than 10 percent of the runs on the `%s` queue failed over the last hour" % queue
        means = ("something the queue's jobs share is failing, such as a database or an upstream "
                 "service, rather than one job.")
        check = ("Find the error codes of the failed runs in the day's log file under "
                 "`/var/log/ferry` and follow their entries under Troubleshooting.")
    elif condition == "WorkersMissing":
        when = ("fewer than %d workers of the `%s` queue have reported to the scheduler for 5 "
                "minutes" % (workers, queue))
        means = ("a worker host has stopped or lost its connection to the scheduler. The queue "
                 "keeps running on the workers that are left, only more slowly.")
        check = ("Run `scripts/ferryctl.sh status` to see how many workers the queue has now, "
                 "then ask the platform team about the host that is missing.")
    else:
        when = "more than 50 retries started on the `%s` queue in 10 minutes" % queue
        means = ("many runs are failing and being retried at once. The retries themselves take "
                 "worker time, so this alert often comes just before a backlog alert.")
        check = ("Find the error code the retried runs share in the day's log file under "
                 "`/var/log/ferry`. If an upstream service is down, drain the scheduler with "
                 "`scripts/ferryctl.sh drain` until it is back.")
    lines = [
        "### Alert: %s" % alert,
        "",
        _wrap("Fires when %s." % when),
        "",
        _wrap("What it usually means: %s" % means),
        "",
        _wrap("What to check first: %s" % check),
        "",
        _wrap("Silence this alert only while you work on its cause, and say in the silence which "
              "runs or hosts you are waiting on."),
        "",
        _wrap("If it keeps firing: tell the owning teams of the jobs involved, and note in the "
              "incident channel which runs you drained or resubmitted, so nobody submits the "
              "same run twice."),
        "",
        _wrap("Other alerts for the `%s` queue: %s."
              % (queue, ", ".join("`Ferry%sQueue%s`" % (queue.capitalize(), c)
                                  for c in ALERT_CONDITIONS if c != condition))),
    ]
    return "\n".join(lines)


RETRIED_CODES = {"FRY-105", "FRY-106", "FRY-108", "FRY-110", "FRY-112", "FRY-119", "FRY-120"}


def _error_entry(err):
    code, title, cause, fix = err
    if code in RETRIED_CODES:
        retried = ("Retried automatically: yes. The scheduler retries a run that fails with this "
                   "code, with the wait doubling between attempts, and reports it only when the "
                   "retries run out.")
    else:
        retried = ("Retried automatically: no. Retrying would fail the same way, so the "
                   "scheduler marks the run failed at once.")
    lines = [
        "### %s: %s" % (code, title),
        "",
        _wrap("Cause: %s" % cause),
        "",
        _wrap(retried),
        "",
        _wrap("What to do: %s" % fix),
        "",
        _wrap("The log line for this error starts with `%s` and names the job and the run. Search "
              "the day's log file for the run to see the attempts that came before it." % code),
    ]
    return "\n".join(lines)


def _alert_items():
    return [(q, c) for q in ("default", "bulk", "urgent") for c in ALERT_CONDITIONS]


_SECTION_KINDS = {
    "## Running jobs": ("jobs", lambda: JOBS, _job_entry),
    "## Operations": ("alerts", _alert_items, lambda item: _alert_entry(*item)),
    "## Troubleshooting": ("errors", lambda: ERRORS, _error_entry),
}

_FILLER_RE = re.compile(r"^\{\{FILLER:(\d+)\}\}$")


def large(root):
    """Expand the {{FILLER:<n>}} lines of root/docs/handbook.md."""
    path = pathlib.Path(root) / "docs" / "handbook.md"
    text = path.read_bytes().decode("ascii")
    out = []
    section = None
    for line in text.split("\n"):
        if line.startswith("## "):
            section = line
        m = _FILLER_RE.match(line)
        if not m:
            out.append(line)
            continue
        n = int(m.group(1))
        if section not in _SECTION_KINDS:
            raise ValueError("no subsection kind for the section %r" % section)
        _kind, items_fn, render = _SECTION_KINDS[section]
        items = items_fn()
        if n > len(items):
            raise ValueError("%d subsections asked for under %r, only %d exist"
                             % (n, section, len(items)))
        out.append("\n\n".join(render(item) for item in items[:n]))
    _write(path, "\n".join(out))
