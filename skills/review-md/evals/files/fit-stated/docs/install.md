# Installing notectl

This page walks a new operator through installing notectl on a fresh host.

## Prerequisites

- Go 1.22 or later.
- `make` and `git`.

## Get the source

```sh
git clone <repository-url> notectl
cd notectl
```

## Build

Run `make build`. It compiles `./cmd/notectl` and writes the binary to `bin/notectl`.

## Run in development mode

`make dev` runs notectl from source with `config/dev.toml` and the `--verbose` flag, so each start
prints the config file it loaded.

## Run the tests

`make test` runs `go test ./...` across the module.

## Clean up

`make clean` removes the `bin/` directory.

## Install the binary

Download the release archive for your platform from the project's releases page and unpack it.
From the unpacked directory, run `sudo ./install.sh notectl`. The script copies the binary to
`/usr/local/bin/notectl`. When `/etc/notectl/notectl.toml` does not exist yet, it also installs the
default config from `config/notectl.toml` there.
