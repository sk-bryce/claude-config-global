# sync_inventory

Reads a CSV inventory feed and updates the `on_hand` column of the `items` table in
`storefront.db`.

## Usage

    ./sync_inventory.py [FEED_URL]

With no argument it uses the default feed URL compiled into the script. The feed must be a CSV
with at least the columns `sku` and `qty`.

## Behaviour

- Rows are applied in batches of 500, with a commit after each batch.
- A SKU present in the feed but absent from `items` is silently skipped: the `UPDATE` matches no
  row and the script does not report it.
- A SKU present in `items` but absent from the feed is left at its previous value.
- The script prints a one-line summary on completion.

## Operational notes

- Runs from cron on the app host. See `crontab.fragment`.
- Takes roughly 40 seconds against the current feed size.
- There is no dry-run mode.
