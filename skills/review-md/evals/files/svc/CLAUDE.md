# ledgerd

Guidance for working in this repository.

- `config/ledgerd.yaml` holds the shipped defaults. Documentation that states a default must
  match it.
- `specs/api.md` is the source of truth for the HTTP API. `docs/api.md` is generated from it, so
  change the spec first and regenerate.
- Operational scripts live in `scripts/`. Keep each script's usage header current when you change
  its flags.
- The Go client lives in `src/client.go`.
