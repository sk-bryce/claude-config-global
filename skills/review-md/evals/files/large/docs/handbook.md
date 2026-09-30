# Ferry handbook

This handbook is for engineers who run Ferry, the scheduler behind our nightly and on-demand batch
work. It covers starting the scheduler, configuring it, running jobs, day-to-day operations, and
troubleshooting failed runs.

## Getting started

Ferry has two parts: the scheduler daemon, `ferryd`, and the control script,
`scripts/ferryctl.sh`. The daemon reads its settings from `config/ferry.toml` once, at startup.

To start the scheduler with the default configuration:

```sh
scripts/ferryctl.sh start
```

To start it with a different configuration file, pass `--config` with the file's path.

The scheduler listens on port 8080 by default.
The health endpoint listens on port 9171, one above the main port, so a load balancer can probe it
without touching the job API.

To check that the scheduler is up and see how busy each queue is:

```sh
scripts/ferryctl.sh status
```

To stop the scheduler, run `scripts/ferryctl.sh stop`. Stopping sends `ferryd` a termination
signal; runs already in progress are allowed to finish. To stop taking new work before you stop the
scheduler, drain it first (see Operations).

## Configuration

All settings live in `config/ferry.toml`, and `ferryd` reads the file only at startup, so restart
the scheduler after any change.

### Server

The `[server]` table sets three values:

- `port`: the port for the job API, which `scripts/ferryctl.sh` talks to.
- `health_port`: the port for the health endpoint.
- `log_dir`: where the scheduler writes its logs, one file per day. The shipped value is
  `/var/log/ferry`.

### Queues

Each queue has its own table, `[queues.<name>]`, with one setting, `workers`: how many runs from
that queue may execute at once. The shipped queues are `default` with 8 workers, `bulk` with 4, and
`urgent` with 2. Workers are not shared between queues, so a full `bulk` queue never slows
`urgent` work.

### Retries

The `[jobs]` table holds `max_retries`, the number of times the scheduler retries a failed run
before it marks the run failed.
When `max_retries` is unset, the scheduler retries a failed run up to 5 times.
Each retry waits twice as long as the one before it, starting at 20 seconds.

## Running jobs

Every job has a name and runs on one queue. The scheduler starts scheduled jobs on their own, and
you can submit any job by hand:

```sh
scripts/ferryctl.sh submit --queue urgent invoice-rollup
```

When `--queue` is left out, the run goes to the `default` queue. Add `--dry-run` to see what the
run would do without starting it.
Add `--wait` to make the command block until the run finishes and exit with the run's status.

The scheduled jobs are listed below, one entry per job, with the team that owns it, its queue, and
its schedule. Schedules are in cron syntax and in UTC.

{{FILLER:30}}

## Operations

### Draining

Drain the scheduler before maintenance:

```sh
scripts/ferryctl.sh drain
```

Draining stops the scheduler from starting new runs and waits for running ones to finish, for up to
300 seconds by default. Pass `--timeout` with a number of seconds to wait longer.

### Logs

Scheduler logs are written to `/var/lib/ferry/logs`, one file per day.

### Changing settings

Before you change a setting, copy `config/ferry.yaml` aside so you can put the old version back if
the change goes wrong. Then edit the file, restart the scheduler, and run
`scripts/ferryctl.sh status` to confirm every queue came back with the expected workers.

### Alerts

The alerts below cover each queue. Each entry says when it fires, what it usually means, and what
to check first.

{{FILLER:15}}

## Troubleshooting

Start with `scripts/ferryctl.sh status` and the day's log file. When a run failed, the log line for
the failure carries an error code; the entries below explain each code.

If a run failed with an error that occured before its first step started, the job never ran, and
submitting it again is safe.

{{FILLER:20}}
