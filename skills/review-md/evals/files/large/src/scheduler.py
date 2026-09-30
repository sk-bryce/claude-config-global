"""Retry policy for the Ferry job scheduler."""

DEFAULT_MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 20


def max_retries(config):
    """Return the retry limit from the [jobs] table, or the default."""
    jobs = config.get("jobs", {})
    return int(jobs.get("max_retries", DEFAULT_MAX_RETRIES))


def retry_delay(attempt):
    """Seconds to wait before retry number `attempt` (1-based).

    The first retry waits RETRY_BACKOFF_SECONDS; each later one waits twice
    as long as the one before it.
    """
    return RETRY_BACKOFF_SECONDS * (2 ** (attempt - 1))


def should_retry(config, attempts_made):
    """True while a failed run has retries left."""
    return attempts_made < max_retries(config)
