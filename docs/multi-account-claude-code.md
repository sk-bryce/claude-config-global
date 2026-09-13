---
audience: human
created: 2026-08-19
updated: 2026-08-21
---

# Working With Multiple Claude Code Accounts

Claude Code has no account switcher. Running two or more accounts on one machine works by
pointing the `CLAUDE_CONFIG_DIR` environment variable at a different directory per account: that
directory selects which account's configuration and credentials Claude Code uses, and everything
else follows from it. What it does *not* change is anything the server owns, quota included -
see Gotcha 4.9.

Two terms, used consistently below. A **profile** is one config directory plus the account
logged into it. The **default profile** is the one you get with `CLAUDE_CONFIG_DIR` unset, whose
config directory is `~/.claude`; it is a profile like any other, and it keeps working unchanged
once you add more.

The setup itself is three lines of shell. Most of what can go wrong is macOS-specific and
undocumented, because on macOS the credential does not live in the config directory at all - it
lives in the login Keychain, under a service name derived from that directory's path. Section 4
is the part worth reading before you trust a second account with anything.

Setup instructions cover macOS and Linux. Windows uses the same `CLAUDE_CONFIG_DIR` mechanism
and the same documented file-based credential storage as Linux (Appendix B), but its setup steps
are not covered here.

## 1. What `CLAUDE_CONFIG_DIR` Actually Moves

| State | Default (variable unset) | With `CLAUDE_CONFIG_DIR=DIR` |
| --- | --- | --- |
| `settings.json`, `agents/`, `skills/`, `commands/`, `projects/`, history, caches | `~/.claude/` | `DIR/` |
| OAuth session, MCP (Model Context Protocol) server definitions at user and local scope, per-project trust state (`.claude.json`) | `~/.claude.json` | `DIR/.claude.json` |
| Credentials on macOS | Keychain, service `Claude Code-credentials` | Keychain, service `Claude Code-credentials-<hash8>` |
| Credentials on Linux and Windows | `~/.claude/.credentials.json`, mode `0600` | `DIR/.credentials.json` |
| Rate limits, usage, subscription plan | Server side, per account | Server side, per account |

Three things in that table catch people out:

- **`.claude.json` is a sibling of `~/.claude`, not a file inside it.** With no
  `CLAUDE_CONFIG_DIR` set it sits at `$HOME/.claude.json`; with the variable set it moves
  *inside* the config directory, to `DIR/.claude.json`. Any script that hardcodes
  `~/.claude.json` keeps reading the default profile's session no matter which account is
  actually running.
- **Only Linux and Windows put credentials in the config directory.** The documentation says so
  explicitly. On macOS the config directory holds no credential at all, which is why the Keychain
  naming in Appendix A matters.
- **Quota is not isolated by any of this.** Rate limits and plan entitlements belong to the
  account on the server, not to the directory (Gotcha 4.9).

Everything under the config directory is otherwise a full, independent copy. A skill, agent,
hook, or setting installed for one profile does not exist for the other until you put it there -
with one caveat covered in Gotcha 4.5.

## 2. Setup on macOS

Requires Claude Code 2.1.144 or later, reported by a third-party profile manager as the version
where config-directory-scoped Keychain entries appeared (see References; Anthropic documents
neither the scoping nor a version floor for it). On anything older, every profile shares one
Keychain entry and only one account can be logged in at a time.

```bash
mkdir -p "$HOME/.claude-work"

# in ~/.zshrc
alias claude-work='CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude'
```

Open a new shell, run `claude-work`, and complete `/login` as the second account. Then confirm,
in that session, that `/status` names the account you expect.

Use `"$HOME/..."` rather than a bare `~`, and never a trailing slash. The literal string you
assign is hashed into the Keychain service name, so two spellings of the same directory are two
different profiles as far as credential lookup is concerned (Gotcha 4.1).

To confirm the scoped Keychain entry exists without printing the secret:

```bash
CLAUDE_DIR="$HOME/.claude-work"
security find-generic-password \
  -s "Claude Code-credentials-$(printf '%s' "$CLAUDE_DIR" | shasum -a 256 | cut -c1-8)" \
  >/dev/null 2>&1 && echo "scoped entry present" || echo "scoped entry MISSING"
```

Two details matter here. The absence of `-w` is deliberate: this reports presence only and never
emits the token. And the path is spelled out in a variable rather than read from the environment,
so the check gives a true answer even when run from a shell where `CLAUDE_CONFIG_DIR` is unset -
an unset variable hashes the empty string and reports a miss for every profile.

## 3. Setup on Linux

Identical shell setup, simpler mechanics. There is no Keychain, and the documented behavior is
the whole behavior:

```bash
mkdir -p "$HOME/.claude-work"
chmod 700 "$HOME/.claude-work"

# in ~/.bashrc or ~/.zshrc
alias claude-work='CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude'
```

After `/login`, the credential is written to `$HOME/.claude-work/.credentials.json` with mode
`0600`. Because it is a plain file holding a live OAuth token:

- Keep the containing directory at `700`, and never commit or dotfile-sync the config directory
  without excluding `.credentials.json`.
- Backup tooling that copies the config directory copies a working credential with it.
- Do not copy the file between profiles to save a login - see Gotcha 4.8.

Gotchas 4.1, 4.2, 4.3, and 4.10 below are macOS-specific and do not apply here: Linux
filesystems are case-sensitive by default, and no hashed Keychain service name is involved. The
rest apply on both platforms.

## 4. Gotchas

Ordered by how likely each is to bite.

### 4.1 The exact string you set is part of the profile's identity (macOS)

The Keychain service name ends in the first 8 hex characters of the SHA-256 of the config
directory path, taken as the literal string in the environment. Three spellings of one directory,
with the suffix each produces:

| String hashed | Service-name suffix |
| --- | --- |
| `/Users/example/.claude-work` | `dd1118a7` |
| `~/.claude-work` | `250d1b22` |
| `/Users/example/.claude-work/` | `16c171f6` |

Adding a trailing slash, switching between `~` and an absolute path in a context that does not
expand the tilde, or moving the directory therefore produces a service name that does not exist,
and Claude Code behaves as though you had never logged in. The fix is to restore the original
spelling or to log in again under the new one; nothing is lost either way, but it is confusing
the first time. Appendix A has the one-liner for computing the suffix for your own path.

### 4.2 A second reader of the credential can silently serve the wrong account (macOS)

The unscoped `Claude Code-credentials` entry still exists alongside the scoped ones - it is what
the default profile uses. Any tool that reads the Keychain itself (a status line, a usage
dashboard, a wrapper script) and falls back to that bare entry gets whichever account logged in
most recently, regardless of which profile is actually running. The failure is silent
and looks like correct data. Appendix C is a worked example.

If you write such a tool: derive the scoped service name, and treat a miss as a hard error rather
than as a reason to fall back to the unscoped entry.

### 4.3 macOS never writes `.credentials.json`, and will not read one

Claude Code on macOS stores credentials only in the Keychain. A valid `.credentials.json` placed
in the config directory by hand is ignored, and the CLI prompts for `/login` instead - reported
as issue #29816 and closed as not planned.

The practical consequence is SSH and headless use. The login Keychain is locked in an SSH session
because it is not bound to the GUI login session, so a remote `claude` on a Mac cannot reach its
own credential and has no file to fall back to. Workaround: mint a long-lived token per account
with `claude setup-token` and export it as `CLAUDE_CODE_OAUTH_TOKEN` in that account's
environment. Such a token can only make model requests: it cannot establish Remote Control
sessions (driving a session from another device) or fetch claude.ai connectors (the hosted MCP
integrations tied to your claude.ai login), both of which need a full login credential.

### 4.4 Environment credentials outrank the login you just completed

Claude Code's authentication precedence puts cloud provider variables, `ANTHROPIC_AUTH_TOKEN`,
`ANTHROPIC_API_KEY`, `apiKeyHelper`, and `CLAUDE_CODE_OAUTH_TOKEN` all *above* the subscription
credential from `/login`. One of these exported globally in a shell profile applies to every
account you launch, so both profiles quietly bill the same credential and `/login` appears to
have had no effect. Run `/status` when an account behaves unexpectedly: an `API key` row appears
when a key is in use.

This also means a `CLAUDE_CODE_OAUTH_TOKEN` set for the SSH workaround in Gotcha 4.3 must be
scoped to that one account's environment, never exported globally.

### 4.5 The config directory may not fully replace `~/.claude`

`CLAUDE_CONFIG_DIR` is an override in intent, but issue #30230 reports Claude Code loading
`CLAUDE.md` from *both* the custom directory and `~/.claude/` in the same session, and was closed
as not planned. The reporter expects the same merging to affect `settings.json`, `skills/`, and
`hooks/`, though only the `CLAUDE.md` case is demonstrated there.

Treat this as version-dependent and check it yourself rather than assuming either behavior:
run `/context` or `/memory` in a profile session and see whether `~/.claude/CLAUDE.md` appears
alongside the profile's own. If it does, the consequence is larger than wasted tokens - hooks and
permissions from your default profile may be in force under the other one.

### 4.6 Running sessions keep the account they started with

`CLAUDE_CONFIG_DIR` is read at launch. Changing the variable, or logging in elsewhere, does not
migrate a session already in progress; it affects only newly started ones.

### 4.7 Shared configuration is not automatic, and symlinks are a poor way to get it

Each config directory is a separate tree, so skills, agents, hooks, and settings have to be
replicated deliberately. The tempting shortcut is to symlink the config directory, or individual
files inside it, at a canonical copy. Claude Code handles symlinked config paths
inconsistently, across several separate reports:

- Slash commands are not discovered when `.claude` is a symlink (#10522).
- Skills in a symlinked `skills/` directory fail validation, while `CLAUDE.md` and
  `settings.json` in the same setup work (#25367).
- Writing to a symlinked settings file replaces the symlink with a regular file, silently
  ending the sharing (#40857).

A mirroring script is the safer shape: rsync the shared subpaths into each config directory, and
write each one a `CLAUDE.md` that carries a copy of your canonical instructions, so every profile
loads the same content with no symlink anywhere. The tidier-looking alternative - a small stub that
`@`-imports the canonical file by absolute path - is worse than it appears. It leaves every profile
dependent on that file never moving: rename or relocate it and each profile silently loads no
global instructions at all, with no error to notice. It also resolves any relative path written
inside those instructions against the canonical file's own directory rather than the profile's,
which quietly defeats the point of mirroring whatever those paths refer to. And Anthropic documents
the `## Compact Instructions` convention against `CLAUDE.md`'s own text without saying whether it
reaches into an `@`-imported file, so a copy avoids betting on that too. What a copy costs is a
staleness window between syncs - the same window every other mirrored path already has. Mirror
only shared configuration, never `.credentials.json`, `.claude.json`, `projects/`, or history.

### 4.8 Never copy credentials between profiles

Copying a Keychain item or a `.credentials.json` from one profile to another appears to work and
then fails at an unpredictable moment: refresh tokens rotate, and the profile that refreshes
second finds its copy invalidated. It also erases the isolation the whole setup exists to
provide. Log in once per profile instead.

### 4.9 Limits and account-bound features follow the account, not the directory

Rate limit windows, usage, and plan entitlements are server-side properties of the account. They
survive `/clear`, are unaffected by which config directory you are in, and are shared across
every session running under that account anywhere. Separate directories buy isolation of
configuration and credentials, not of quota.

### 4.10 Pick one casing and keep it (macOS)

The default macOS filesystem is case-insensitive but SHA-256 is not: `~/.claude-work` and
`~/.claude-WORK` are one directory with two different service names (`dd1118a7` and `5cd76b62`
for the absolute forms). Lowercase everywhere is the simplest rule.

## 5. Confirming Which Account You Are On

In rough order of directness:

- **`/status`** inside the session. Shows the login method, the account, and an `API key` row
  when an environment credential has taken over (Gotcha 4.4).
- **`jq -r '.oauthAccount.organizationName' "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"`** from
  outside a session. The `:-$HOME` default is load-bearing: an unset variable means the default
  profile, whose file is `$HOME/.claude.json`, and a bare `"$CLAUDE_CONFIG_DIR/..."` would
  resolve to `/.claude.json` at the filesystem root instead. The organization name is
  absent for an individual (non-organization) account, or where no login has happened.
- **The Keychain presence check** in section 2, when the question is specifically whether a
  given profile's credential exists.
- **A status line**, if you run one that reports account identity. Make sure it resolves identity
  and usage from the same scoped source before trusting it - that is exactly the failure in
  Appendix C.

## Appendix A: How the macOS Keychain Service Name Is Derived

None of this is documented; the authentication documentation says only that on macOS credentials
are stored in the encrypted macOS Keychain. The behavior described below was determined from a
shipped Claude Code 2.1.236 build and confirmed against live Keychain entries on a machine
running two profiles.

A profile's Keychain service name is built from three parts: a fixed `Claude Code` prefix, a
`-credentials` subkey for the login credential, and a scoping suffix. In a production build the
result is therefore `Claude Code-credentials-<hash8>`, where `<hash8>` is the first 8 hex
characters of the SHA-256 of the config directory path. Development and custom-endpoint builds
insert an extra `-local-oauth` or `-custom-oauth` segment before the subkey; production builds
insert nothing.

What determines the suffix:

- The path that gets hashed is the resolved config directory: `CLAUDE_CONFIG_DIR` when set,
  `~/.claude` otherwise.
- The suffix is empty - meaning the shared, unscoped `Claude Code-credentials` entry - when
  `CLAUDE_CONFIG_DIR` is unset or empty and `CLAUDE_SECURESTORAGE_CONFIG_DIR` is undefined. On
  that path the resolved directory never reaches the hash at all.
- `CLAUDE_SECURESTORAGE_CONFIG_DIR`, when defined, takes over completely: its value is what gets
  hashed, and setting it to the empty string forces the unscoped entry even while
  `CLAUDE_CONFIG_DIR` is set. It exists to decouple secure storage from the config directory, and
  is what third-party profile managers pass alongside `CLAUDE_CONFIG_DIR`.
- A value supplied through `CLAUDE_SECURESTORAGE_CONFIG_DIR` is NFC-normalized before hashing, so
  composed and decomposed Unicode spellings of a directory name agree. Whether the
  `CLAUDE_CONFIG_DIR` path normalizes the same way was not determined. ASCII paths are unaffected
  either way.

To compute the suffix for a given profile:

```bash
printf '%s' "$HOME/.claude-work" | shasum -a 256 | cut -c1-8
# -> the suffix of that profile's "Claude Code-credentials-<hash8>" Keychain entry
```

`security dump-keychain` lists the service names actually present, which is the other half of the
comparison. On a machine with one extra profile configured, expect to see both a scoped
`Claude Code-credentials-<hash8>` entry and the unscoped `Claude Code-credentials` entry
belonging to the default profile.

**Treat all of this as observed, not promised.** It is an undocumented implementation detail of
one version and can change without notice. Anything depending on it should degrade safely when
the lookup misses, rather than falling back to a different account's credential.

## Appendix B: Credential Storage by Platform

| Platform | Location | Scoped by `CLAUDE_CONFIG_DIR` | Documented |
| --- | --- | --- | --- |
| macOS | login Keychain, generic password | Yes, via the SHA-256 service suffix in Appendix A | Storage location yes, scoping no |
| Linux | `~/.claude/.credentials.json`, mode `0600` | Yes, moves to `DIR/.credentials.json` | Yes |
| Windows | `%USERPROFILE%\.claude\.credentials.json`, inheriting the access controls of the Windows user account's home directory | Yes, moves to `DIR\.credentials.json` | Yes |

Notes:

- Claude Code manages these through `/login` and `/logout` only.
- macOS has no file fallback in either direction: it neither writes nor reads
  `.credentials.json` (Gotcha 4.3).
- The Keychain lookup can fail as `keychain_locked` distinctly from an authentication failure,
  which is the SSH case in Gotcha 4.3.

## Appendix C: Case Study - A Status Line Showing the Wrong Account's Usage

A worked example of Gotcha 4.2, from a custom `statusLine` script that displayed the active
account's organization name alongside its rate-limit usage.

**Symptom.** The status line rendered one organization's name next to the *other* account's usage
and limits. Both halves looked plausible on their own, so the line read as correct.

**Cause.** The organization name came from the active profile's `.claude.json`, correctly scoped
by `CLAUDE_CONFIG_DIR`. The usage figures came from an API call authenticated with a token the
script resolved itself, and its resolution order was, in effect, "config-dir
`.credentials.json`, then the Keychain". On macOS that file never exists (Gotcha 4.3), so every
profile fell through to the single unscoped `Claude Code-credentials` entry, and whichever
account had logged in most recently won for all of them.

**Fix.** On macOS with `CLAUDE_CONFIG_DIR` set, derive the scoped service name per Appendix A and
try *only* that. A miss became a hard error rather than a fallback: when the profile has clearly
completed a login (its `.claude.json` carries an `oauthAccount`) but the expected Keychain entry
is absent, the usage figures are replaced by a red `withheld` marker and an error row naming the
entry that was looked for. One more trap surfaced during the fix - the script's on-disk response
cache was keyed by config directory rather than by account, so it could still hold the other
account's data. A withheld credential now bypasses that cache entirely, fresh or stale.

**Transferable lesson.** For any display that pairs an identity label with account data, resolve
both from the same scoped source, and prefer showing nothing over showing something plausible. An
alternative fix - minting a per-profile `CLAUDE_CODE_OAUTH_TOKEN` via `claude setup-token` and
exporting it from each shell alias - was considered and rejected: it works, but it introduces a
second credential to provision and rotate for a problem the scoped lookup already solves. It
remains the fallback if the undocumented scoping in Appendix A ever stops holding.

## References

### Official Documentation

- [Authentication](https://code.claude.com/docs/en/authentication) - Anthropic; credential
  storage locations per platform, the `CLAUDE_CONFIG_DIR` note for Linux and Windows,
  authentication precedence, and `claude setup-token` (including the model-requests-only
  limitation cited in Gotcha 4.3).
- [Settings](https://code.claude.com/docs/en/settings) - Anthropic; what `~/.claude/` and
  `~/.claude.json` each hold.

### Issue Reports

- [#29816: SSH sessions require re-login despite valid `.credentials.json`](https://github.com/anthropics/claude-code/issues/29816) -
  closed as not planned. Source for Gotcha 4.3.
- [#30230: `CLAUDE_CONFIG_DIR` does not replace `~/.claude`](https://github.com/anthropics/claude-code/issues/30230) -
  closed as not planned. Source for Gotcha 4.5.
- [#10522: Slash commands not recognized when `.claude` is a symlink](https://github.com/anthropics/claude-code/issues/10522) -
  closed. Source for Gotcha 4.7.
- [#25367: Custom skills via symlinked `skills/` fail validation](https://github.com/anthropics/claude-code/issues/25367) -
  closed as duplicate. Source for Gotcha 4.7.
- [#40857: Writing to a symlinked file replaces the symlink](https://github.com/anthropics/claude-code/issues/40857) -
  closed as not planned. Source for Gotcha 4.7.

### Third-Party Tooling

- [hamzarehmandeveloper/claude-account](https://github.com/hamzarehmandeveloper/claude-account) -
  profile switcher; source for the Claude Code 2.1.144 version floor on config-scoped Keychain
  entries, and for pairing `CLAUDE_SECURESTORAGE_CONFIG_DIR` with `CLAUDE_CONFIG_DIR`.
