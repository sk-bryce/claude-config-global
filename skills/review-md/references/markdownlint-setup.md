# markdownlint setup

## Install

```bash
npm install -g markdownlint-cli
```

Homebrew alternative:

```bash
brew install markdownlint-cli
```

## Verify

```bash
markdownlint --version
```

## Config

A project's own `.markdownlint.json`, `.markdownlint.jsonc`, `.markdownlint.yaml`, or
`.markdownlint.yml` at the git root wins. Otherwise review-md uses `assets/markdownlint.jsonc`,
which enables only rules that catch errors, not style opinions.

review-md never runs markdownlint with `--fix`.

## References

- [DavidAnson/markdownlint](https://github.com/DavidAnson/markdownlint)
