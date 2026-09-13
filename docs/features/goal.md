---
audience: human
created: 2026-08-24
updated: 2026-08-24
---

# `/goal`: How It Actually Works

`/goal <condition>` keeps a Claude Code session running turn after turn until a *separate*
model agrees the condition holds. It is not a planning tool, not a prompt, and not a memory of
intent. It is a session-scoped Stop hook with a natural-language predicate attached.

Almost every surprise with `/goal` traces back to one fact:

> The evaluator has no tools. It reads the conversation transcript and nothing else.
> It cannot run your tests, open a file, or check git. It can only judge what Claude already
> printed into the transcript.

Everything in the "Writing a condition" and "Why it probably did not work" sections below
follows from that.

## Mental model

```
/goal <condition>
      |
      +-- registers a session-scoped Stop hook of type "prompt", prompt = your condition verbatim
      +-- appends a kickoff meta-message telling Claude to treat the condition as its directive
      +-- immediately starts a turn (you do not send a separate prompt)

after every turn that ends:
      transcript + condition  ->  small fast model (Haiku on the Claude API)  ->  JSON verdict
                                                                            |
        {"ok": true,  "reason": ...}                 -> goal met, hook removed, turn ends
        {"ok": false, "reason": ...}                 -> turn is blocked, Claude runs again
        {"ok": false, "impossible": true, ...}       -> goal failed, hook removed, turn ends
```

The verbatim system prompt the evaluator runs under (extracted from the v2.1.240 bundle):

> You are evaluating a stop-condition hook in Claude Code. Read the conversation transcript
> carefully, then judge whether the user-provided condition is satisfied. [...] Always include a
> "reason" field, quoting specific text from the transcript whenever possible. If the transcript
> does not contain clear evidence that the condition is satisfied, return
> `{"ok": false, "reason": "insufficient evidence in transcript"}`.

Note the default: **absence of evidence is scored as not-met.** The evaluator is biased toward
keeping you in the loop, not toward letting you out of it.

On a not-met verdict, the main model receives the reason back as a blocking message shaped
`Stop: [<your condition>]: <reason>`. That reason string is the *entire* steering signal for the
next turn. A vague reason produces a vague next turn.

## Command surface

| Invocation | Effect |
| --- | --- |
| `/goal <condition>` | Sets the goal, replaces any active one, and starts a turn immediately |
| `/goal` | Status panel: condition, elapsed time, turns evaluated, token spend, and the "Last check" reason |
| `/goal clear` | Removes the active goal. Prints `Goal cleared: <condition>` or `No goal set` |
| `/clear` | Starting a new conversation also drops the goal |

`stop`, `off`, `reset`, `none`, and `cancel` are accepted aliases for `clear`.

Hard limits and defaults, read out of the bundle:

- Condition length cap: **4000 characters**. Over that, the command refuses with a count.
- One goal per session. Setting a second supersedes the first silently.
- Evaluator model: the configured **small fast model** (Haiku on the Claude API). Override with
  `ANTHROPIC_DEFAULT_HAIKU_MODEL`, but note that variable also swaps the model behind the `haiku`
  alias and all background functionality, so it is not a `/goal`-only knob.
- Transcript budget for the evaluator: **50% of the evaluator model's context** (so ~100K tokens
  at a 200K window). Beyond that, earlier messages are dropped and the evaluator is explicitly
  instructed to answer "insufficient evidence in transcript" if the proof may have been in the
  truncated prefix.
- Consecutive-block cap: **8** (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`). See "Safety valves".
- Background check-in interval: **30 minutes**, doubling to a ceiling of 4x
  (`CLAUDE_CODE_GOAL_CHECKIN_MINUTES`, `0` disables).

## Writing a condition that actually terminates

A condition that survives many turns has three parts:

1. **One measurable end state.** A test result, an exit code, a file count, an empty queue.
2. **The stated check that proves it.** How Claude should surface the evidence:
   `npm test exits 0`, `git status is clean`, `rg -c TODO src/ returns 0`.
3. **The constraints that matter.** What must not change on the way there.

Good:

```
/goal `pytest tests/auth` exits 0 and `ruff check .` is clean, shown by running both
commands at the end; do not modify any file outside src/auth/
```

Bad, and why:

| Condition | Failure mode |
| --- | --- |
| `refactor the auth module` | No end state. The evaluator can never say yes. Runs to the block cap forever. |
| `the code is clean and well tested` | Subjective. Verdict flips turn to turn on the same evidence. |
| `all tests pass` (never run in the transcript) | Evidence never enters the transcript, so it is permanently "insufficient evidence". |
| `the CI job on GitHub is green` | Requires a tool the evaluator does not have; only satisfiable if Claude pastes the result. |
| a 3-page spec pasted as the condition | Every clause must hold simultaneously; one soft clause pins it open forever. |

Two techniques that pay for themselves:

- **Add a bound.** Include `or stop after 20 turns` / `or stop after 45 minutes` in the condition
  itself. Claude reports progress against the clause each turn and the evaluator reads it from
  the transcript. This is the only in-band way to cap a run.
- **Name the proof artifact.** "...and print the final `pytest` summary line as the last thing you
  do" makes the evidence unmissable to a transcript-only judge.

## Why it probably did not work the way you expected

Ranked by how often each one bites.

1. **You wrote a task, not a predicate.** `/goal` reads as an instruction ("do X"), but it is
   evaluated as a question ("is X true?"). An imperative with no observable end state loops until
   the block cap.
2. **The proof never reached the transcript.** Claude fixed the thing but did not re-run the
   check, so the evaluator saw nothing and returned not-met. Claude then re-fixed the already
   fixed thing. Always name the command whose output constitutes proof.
3. **The condition referenced something that does not exist in this session.** The known-bad case
   is naming plugin or project slash commands that are not registered here: the evaluator keeps
   looking for an invocation that can never happen. This produced a real infinite loop
   (anthropics/claude-code#58348, since closed). The same applies to files, branches, and
   services Claude cannot reach.
4. **The session got long and the evidence was truncated away.** Once the transcript exceeds half
   the evaluator's window, the prefix is dropped, and the evaluator is instructed to fall back to
   "insufficient evidence". A goal that was satisfied 200 turns ago can start reading as unmet.
5. **You expected it to plan.** It does not. The kickoff message tells Claude to acknowledge the
   goal and immediately start working, explicitly *not* to ask you what to do. If you wanted a
   plan first, run planning to completion and set the goal afterward.
6. **You expected it to run unattended.** `/goal` does not change your permission mode. In manual
   mode every unapproved tool call still stops and asks. Pair it with auto mode if you intend to
   walk away.
7. **You expected `/goal clear` to stop an in-flight turn.** It removes the hook; it does not
   interrupt the turn currently running. Ctrl+C does that.
8. **You set it in plan mode.** Nothing blocks a typed `/goal` in plan mode, but Claude cannot
   make the edits that would satisfy most conditions, so it will block on every turn end. (The
   model-proposed path *is* gated on plan mode; the typed one is not.)

## Safety valves

These exist so a bad condition costs you tokens rather than your afternoon. Know all four.

**Consecutive-block cap.** If a turn ends with no tool use and the evaluator blocks it, 8 times
in a row, Claude Code overrides the hook, prints a warning, and hands control back. The goal stays
set and evaluation resumes on your next prompt. Raise or disable with
`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`. The counter resets whenever a turn actually does tool work,
which is why a genuinely productive goal can run far past 8 turns.

**Impossible verdict.** The evaluator may return `{"ok": false, "impossible": true}`, which
clears the goal and records a failed entry. Its instructions are deliberately conservative: it is
told that "the assistant claiming the goal is impossible is evidence, not proof", and to prefer a
plain not-met when in doubt. Do not rely on it as your exit.

**Unrecoverable errors clear the goal.** Exactly four classes: authentication failure (only when
Claude Code manages its own credentials, not when a host does), exhausted credit balance, a
context overflow auto-compaction could not clear, and an unavailable model. You get
`Goal cleared after an unrecoverable error (...). Run /goal again to continue.` Everything else,
including rate limits and overloaded servers, leaves the goal active.

**Ctrl+C.** Always available, and the only thing that stops a turn mid-flight.

## Background work defers evaluation

If a subagent or background shell is still running when a turn ends, evaluation is skipped for
that turn entirely (the debug log says `[goal] evaluation deferred - background work still
running`). It resumes at the end of the next turn that finishes clean.

Once background work has held the goal for 30 minutes, a check-in fires: Claude Code lists the
running tasks and asks Claude to read their output, keep waiting if they are progressing, or fix
or kill anything stuck. Later check-ins back off by doubling, capped at 4x the base interval
(30 min, then 60, then 120, then every 120). In an interactive session a due check-in can start a
turn on its own while you are idle; in `-p` it only arrives at a turn end.

`CLAUDE_CODE_GOAL_CHECKIN_MINUTES` sets the base interval and scales the rest. `0` turns
check-ins off, which is worth knowing if you routinely park long background jobs.

## Non-interactive use

```bash
claude -p "/goal CHANGELOG.md has an entry for every PR merged this week" \
  --output-format stream-json --verbose
```

The whole loop runs inside the single invocation. With plain text output nothing prints until the
run finishes, so a multi-turn goal looks hung; `--output-format stream-json --verbose` is
effectively mandatory here. Ctrl+C is the abort.

This is also where an unbounded condition is most expensive: nobody is watching, and the block
cap only fires on tool-less turns. Put a turn bound in the condition.

## Model-proposed goals

Claude can propose a goal via the internal `ProposeGoal` tool. The approval dialog reads
"Claude proposes a goal", and approving is equivalent to your typing `/goal`. The proposal is
non-blocking: Claude keeps working while it sits there, and if you decline it is not told.

Controlled by the `modelProposedGoals` setting:

| Value | Behavior |
| --- | --- |
| `auto` (default) | Claude decides per proposal whether to ask; it may set a goal directly when your own words stated the outcome |
| `alwaysAsk` | Every proposed goal goes through the approval dialog |
| `disabled` | The tool is off entirely |

A typed `/goal` is unaffected by this setting. Set `disabled` if you want the goal loop to be
something only you can start.

## Interactions worth knowing

- **Subagents are unaffected.** The hook is registered on `Stop`, and evaluation is skipped when
  an agent ID is present. A subagent finishing does not trigger goal evaluation.
- **Compaction.** The goal survives compaction (it lives in session state, not the transcript),
  but the *evidence* may not. Re-establish proof after a compact rather than assuming the
  evaluator still remembers it.
- **Resume.** A still-active goal is restored on `--continue`, `--resume <id|name>`, and the
  session picker. The condition carries over with origin `restored`; the turn count, timer, and
  token-spend baseline all reset to zero. Achieved and cleared goals are not restored. (The docs
  note the session-picker route only began restoring in v2.1.239.)
- **Auto mode** removes per-tool prompts; `/goal` removes per-turn prompts. They compose, and
  that combination is the actual "walk away" configuration.
- **`/loop`** re-runs on a time interval regardless of state; `/goal` re-runs until a predicate
  holds. Use `/loop` for polling, `/goal` for convergence.
- **A hand-written Stop hook** in settings does everything `/goal` does, plus it can run a
  deterministic script instead of a model, and it persists across sessions. Reach for it when the
  check is mechanical (exit codes, file existence) rather than judgmental.

## Availability

`/goal` is part of the hooks system, so it inherits the hooks trust rule and refuses to run when:

- the workspace is untrusted (`/goal is only available in trusted workspaces...`), or
- hooks are restricted: `disableAllHooks: true` after precedence, or `allowManagedHooksOnly` in
  managed settings (`/goal can't run while hooks are restricted...`).

It says which of the two is blocking rather than failing silently. In safe mode, settings-file
hooks are suspended but session hooks created by `/goal` still run.

## Cost

Every turn end adds one small fast model call over the (truncated) transcript. Per call that is
cheap, but it is proportional to transcript size and it fires on *every* turn, so a long goal on
a long session is not free. The `/goal` status panel reports cumulative token spend since the
goal was set, which is the number to watch.

## Quick reference

| Knob | Default | Purpose |
| --- | --- | --- |
| `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` | `8` | Consecutive tool-less blocked turn-ends before override |
| `CLAUDE_CODE_GOAL_CHECKIN_MINUTES` | `30` | Base background check-in interval; `0` disables |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | provider default | Evaluator model (also changes `haiku` alias and background work) |
| `modelProposedGoals` (setting) | `auto` | Whether Claude may propose goals, and whether it must ask |
| condition length | 4000 chars | Hard cap enforced by the command |

## Do / do not

**Do**

- Phrase the condition as a checkable claim, and name the command that proves it.
- Include a turn or time bound in the condition for anything unattended.
- Run `/goal` bare when a run feels stuck; the "Last check" reason tells you exactly what the
  evaluator is still waiting for.
- Set the goal *after* planning, not instead of it.
- Combine with auto mode when you actually intend to leave.

**Do not**

- Do not paste a multi-clause spec as the condition. Pick the one clause that gates completion.
- Do not reference skills, commands, files, or services that are not reachable in this session.
- Do not rely on the "impossible" verdict as your escape hatch; it is deliberately hard to reach.
- Do not assume `/goal clear` interrupts the running turn. It does not; Ctrl+C does.
- Do not set a goal on a session already near its context limit. Truncation will start eating the
  evidence the evaluator needs.

## References

- Keep Claude working toward a goal (official docs): https://code.claude.com/docs/en/goal
- Prompt-based hooks: https://code.claude.com/docs/en/hooks-guide#prompt-based-hooks
- Hooks reference (`disableAllHooks`, disabling hooks): https://code.claude.com/docs/en/hooks
- Model configuration and the small fast model: https://code.claude.com/docs/en/model-config
- Auto mode: https://code.claude.com/docs/en/auto-mode-config
- `/loop` and scheduling comparison: https://code.claude.com/docs/en/scheduled-tasks
- Environment variables: https://code.claude.com/docs/en/env-vars
- Issue #58348, `/goal` stop hook infinite loop with unregistered skills:
  https://github.com/anthropics/claude-code/issues/58348
- Behavioral details (constants, evaluator system prompt, verdict schema, block-cap reset,
  check-in backoff) verified directly against the Claude Code v2.1.240 bundle at
  `~/.local/share/claude/versions/2.1.240`.
