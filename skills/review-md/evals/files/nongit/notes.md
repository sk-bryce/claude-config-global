# Backup notes

## How backups run

`backup.sh` archives the `notes` directory into `backups/`, as one `notes-YYYYMMDD.tar.gz` file
per day. Set `BACKUP_DIR` to write the archives somewhere else, or pass a different source
directory as the first argument.

## Retention

The script keeps 30 days of archives and deletes anything older each time it runs.

## Restoring

To restore one day's notes, extract its archive into an empty directory:

```sh
mkdir restore
tar -xzf backups/notes-20260301.tar.gz -C restore
```
