# tally

`tally` counts the lines in each file that contain a word, and prints a total.

## Install

Copy `bin/tally.sh` to a directory on your `PATH` and make it executable:

```sh
install -m 0755 bin/tally.sh ~/.local/bin/tally.sh
```

It needs only Bash and `grep`.

## Usage

```text
tally.sh [-i] WORD FILE...
```

See [the usage guide](docs/usage.md) for the options, the output format, and the exit status.
