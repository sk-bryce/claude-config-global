# Vale setup

## Install

```bash
brew install vale
```

Or download a release binary from https://github.com/errata-ai/vale/releases.

## Verify

```bash
vale --version
```

## Config

A project's own `.vale.ini` at the git root wins. Otherwise review-md uses
`assets/vale/.vale.ini`, which runs only Vale's built-in `Vale` style, with spelling, terms, and
avoid-lists turned off.

## References

- [Introduction | Vale](https://vale.sh/docs/)
- [DavidAnson/markdownlint](https://github.com/DavidAnson/markdownlint)
