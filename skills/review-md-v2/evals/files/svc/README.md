# ledgerd

ledgerd is a small append-only ledger service with an HTTP API and a Go client.

## Layout

- `config/ledgerd.yaml`: the shipped default configuration.
- `docs/`: documentation for operators and maintainers.
- `scripts/`: operational scripts for log rotation and local state reset.
- `specs/api.md`: the HTTP API specification.
- `src/client.go`: the Go client.

## Documentation

- [Deploying ledgerd](docs/deploy.md)
- [Operations](docs/operations.md)
- [Configuration reference](docs/config.md)
- [Architecture](docs/architecture.md)
- [HTTP API](docs/api.md)
- [Runbook](docs/runbook.md)
- [Glossary](docs/glossary.md)
