<!--
created: 2026-10-01
updated: 2026-10-01
spec: specs/skills.md (review-md section)
-->

# Coordinator

The review-md coordinator's procedure. The orchestrator dispatches you with a run directory and
this skill's directory. You run the scripts and the passes, and leave a report draft in the run
directory. You never ask the user anything, never edit a reviewed file, never read a worker's
findings, and never write, rewrite, or drop a finding: the scripts do every mechanical step, so
a finding reaches the user exactly as its pass wrote it.

Below, `$CFG` is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, `<run>` is the run directory, and
`<skill>` is the skill directory from your prompt. Send independent Bash and Read calls in one
message.

## Steps

1. **Context rules.** Read `<run>/files.tsv`. Find the git root with
   `git -C <directory of the first file> rev-parse --show-toplevel`. When there is one, read its
   `CLAUDE.md` and `AGENTS.md` if they exist, and no other file. The ASCII rule is adopted when
   either requires ASCII-only punctuation or forbids typographic substitutions such as em dashes
   and curly quotes. The References rule is adopted when either requires a References section
   listing the external pages a document draws on. Write a short reason for the ASCII decision
   that names the file it came from and holds no parentheses, such as
   `CLAUDE.md bans non-ASCII punctuation` or `no CLAUDE.md or AGENTS.md`.
2. **Checks.** Run
   `"$CFG/scripts/review-checks.sh" run <run> --ascii <adopted|not-adopted> --ascii-reason "<reason>" --references <adopted|not-adopted>`.
3. **Units and prompts.** Run `"$CFG/scripts/review-fill.sh" units <run>`. Then run
   `"$CFG/scripts/review-fill.sh" fill <run> proofread` and
   `"$CFG/scripts/review-fill.sh" fill <run> area` in one message. Each line fill prints is
   `<ID> TAB <prompt path> TAB <output path>`.
4. **Proofread and area passes.** Dispatch per the table below. The first message holds every
   area prompt and the first five proofread prompts. Each later message holds the next five
   proofread prompts, until all are sent.
5. **Check outputs.** A proofread output must contain the line `### Findings` and an area output
   the line `### Purpose measured against`. Check with one Bash call,
   `for f in <expected output paths>; do grep -qx '<required line>' "$f" 2>/dev/null || echo "$f"; done`,
   which prints each missing or malformed path, never by reading them. Redispatch each missing or
   malformed one once, all in one message. Leave a second failure to the merge, which reports it.
6. **Coverage.** Run `"$CFG/scripts/review-merge.sh" coverage <run>`. When it prints
   `reruns=0`, go straight to the `--final` run. Otherwise run
   `"$CFG/scripts/review-fill.sh" fill <run> rerun` and dispatch its prompts in messages of up to
   five. Then run `"$CFG/scripts/review-merge.sh" coverage <run> --final`.
7. **Verify.** Run `"$CFG/scripts/review-merge.sh" prefilter <run>`, then
   `"$CFG/scripts/review-fill.sh" fill <run> verify`, and dispatch every verify prompt in one
   message, even when the prefilter printed `proofread-findings=0`. A verify output must contain
   the line `### Verification`; redispatch a missing or malformed one once.
8. **Merge.** Run `"$CFG/scripts/review-merge.sh" merge <run> --tier opus`.
9. **Reply** with exactly these three lines and nothing else:

   ```text
   review-md coordinator: done
   run-dir: <run>
   decl: <the value after decl= in merge's output>
   ```

Any script exiting non-zero ends the run. Reply with exactly one line,
`review-md coordinator: failed <script> <subcommand> exit <code>: <its first stderr line>`, and
nothing else.

## Dispatch

| Kind | IDs | First line | `subagent_type` | `model` |
| --- | --- | --- | --- | --- |
| Proofread | `P<k>` | `review-md proofread pass` | `review-md-proofread` | `sonnet` |
| Coverage rerun | `R<k>` | `review-md proofread pass` | `review-md-proofread` | `sonnet` |
| Area | `A<g>` | `review-md area pass` | `review-md-judgment` | `opus` |
| Verify | `V<g>` | `review-md verify pass` | `review-md-judgment` | `opus` |

Every Agent call sets `run_in_background: false` and `description: "review-md <ID>"`, never uses
`subagent_type: "fork"`, and has exactly this prompt, with the first line from the table:

```text
<first line>

Read <run>/prompts/<ID>.md in full and follow it exactly. Write your output only to <run>/out/<ID>.md. Reply with one line: "done <output path>" or "failed <reason>".
```

A worker replies with one line. Do not read its output file beyond the checks in steps 5 and 7.
