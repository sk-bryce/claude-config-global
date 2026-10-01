#!/usr/bin/env bash
#
# link-recheck-tests/run.sh - regression suite for scripts/link-recheck-hook.sh's review mode
# (link-recheck-hook.sh --review ...), plus two cases that pin hook mode's behavior unchanged.
#
# Every probed case is served by a local python3 http.server on 127.0.0.1, so a live-network flake
# can never cause a false pass or a false failure here. Each case's expected stdout is exact, after
# replacing the temp directory with the literal string $T and the server port with the literal
# string $PORT.
#
# Usage: bash scripts/link-recheck-tests/run.sh    (exits 0 only when every case passes)
#   LINK_RECHECK overrides the script under test (used to run this suite against a baseline copy).

set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LINK="${LINK_RECHECK:-$ROOT/scripts/link-recheck-hook.sh}"
export LINK_REVIEW_MAX_TIME=2

T="$(mktemp -d)"
SERVER_PID=""
cleanup() {
  [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null
  rm -rf "$T"
}
trap cleanup EXIT

PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"

# --- Local test server ------------------------------------------------------------------------
cat > "$T/server.py" <<'PY'
import http.server
import sys
import time


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/ok":
            self.send_response(200)
            self.end_headers()
        elif self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/ok")
            self.end_headers()
        elif self.path == "/missing":
            self.send_response(404)
            self.end_headers()
        elif self.path == "/gone":
            self.send_response(410)
            self.end_headers()
        elif self.path == "/forbidden":
            self.send_response(403)
            self.end_headers()
        elif self.path == "/ratelimit":
            self.send_response(429)
            self.end_headers()
        elif self.path == "/error":
            self.send_response(500)
            self.end_headers()
        elif self.path == "/hang":
            time.sleep(5)
            self.send_response(200)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PY

python3 "$T/server.py" "$PORT" >/dev/null 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 50); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/ok" 2>/dev/null)"
  [[ "$code" == "200" ]] && break
  sleep 0.1
done

pass=0
total=0

# run_case NAME EXPECTED COMMAND...
#   Runs COMMAND, compares its stdout exactly with EXPECTED after replacing the temp directory
#   with the literal string $T and the server port with the literal string $PORT.
run_case() {
  local name="$1" expected="$2" actual
  shift 2
  total=$((total + 1))
  actual="$("$@" 2>/dev/null | sed "s|$T|\$T|g; s|$PORT|\$PORT|g")"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1)); printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$name" "$expected" "$actual"
  fi
}

# --- Fixtures ------------------------------------------------------------------------------------

cat > "$T/ok.md" <<EOF
[a](http://127.0.0.1:$PORT/ok)
EOF

cat > "$T/redirect.md" <<EOF
[a](http://127.0.0.1:$PORT/redirect)
EOF

cat > "$T/missing.md" <<EOF
[a](http://127.0.0.1:$PORT/missing)
EOF

cat > "$T/gone.md" <<EOF
[a](http://127.0.0.1:$PORT/gone)
EOF

cat > "$T/forbidden.md" <<EOF
[a](http://127.0.0.1:$PORT/forbidden)
EOF

cat > "$T/ratelimit.md" <<EOF
[a](http://127.0.0.1:$PORT/ratelimit)
EOF

cat > "$T/error.md" <<EOF
[a](http://127.0.0.1:$PORT/error)
EOF

cat > "$T/hang.md" <<EOF
[a](http://127.0.0.1:$PORT/hang)
EOF

cat > "$T/dns.md" <<'MD'
[a](http://rmv2-test.invalid/)
MD

cat > "$T/refused.md" <<'MD'
[a](http://127.0.0.1:1/)
MD

cat > "$T/fenced.md" <<EOF
~~~text
\`\`\`
[a](http://127.0.0.1:$PORT/ok)
~~~
EOF

cat > "$T/inline-code.md" <<EOF
Text \`[a](http://127.0.0.1:$PORT/ok)\` here.
EOF

cat > "$T/ftp.md" <<'MD'
[a](ftp://example.com/file)
MD

cat > "$T/mailto-mixed.md" <<EOF
[a](mailto:test@example.com)

[b](http://127.0.0.1:$PORT/ok)
EOF

cat > "$T/refdef.md" <<EOF
[label]: http://127.0.0.1:$PORT/ok
EOF

cat > "$T/autolink.md" <<EOF
<http://127.0.0.1:$PORT/ok>
EOF

cat > "$T/quoted-title.md" <<EOF
[a](http://127.0.0.1:$PORT/ok "Title")
EOF

cat > "$T/angle-target.md" <<EOF
[a](<http://127.0.0.1:$PORT/ok>)
EOF

cat > "$T/image.md" <<EOF
![alt](http://127.0.0.1:$PORT/ok)
EOF

cat > "$T/not-markdown.txt" <<'TXT'
hello
TXT

cat > "$T/references-rule-no-ref.md" <<EOF
[a](http://127.0.0.1:$PORT/ok)
EOF

cat > "$T/references-rule-with-ref.md" <<EOF
# References

[a](http://127.0.0.1:$PORT/ok)
EOF

cat > "$T/hook-broken.md" <<EOF
## References

[x](http://127.0.0.1:$PORT/missing)
EOF

cat > "$T/hook-clean.md" <<EOF
[x](http://127.0.0.1:$PORT/missing)
EOF

# --- Review mode: probed results -----------------------------------------------------------------

run_case "ok" $'$T/ok.md\t1\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review "$T/ok.md"

run_case "ok-via-redirect" $'$T/redirect.md\t1\thttp://127.0.0.1:$PORT/redirect\tok' \
  "$LINK" --review "$T/redirect.md"

run_case "broken-404" $'$T/missing.md\t1\thttp://127.0.0.1:$PORT/missing\tbroken' \
  "$LINK" --review "$T/missing.md"

run_case "broken-410" $'$T/gone.md\t1\thttp://127.0.0.1:$PORT/gone\tbroken' \
  "$LINK" --review "$T/gone.md"

run_case "inconclusive-403" $'$T/forbidden.md\t1\thttp://127.0.0.1:$PORT/forbidden\tinconclusive' \
  "$LINK" --review "$T/forbidden.md"

run_case "inconclusive-429" $'$T/ratelimit.md\t1\thttp://127.0.0.1:$PORT/ratelimit\tinconclusive' \
  "$LINK" --review "$T/ratelimit.md"

run_case "inconclusive-500" $'$T/error.md\t1\thttp://127.0.0.1:$PORT/error\tinconclusive' \
  "$LINK" --review "$T/error.md"

run_case "inconclusive-hang-after-retry" $'$T/hang.md\t1\thttp://127.0.0.1:$PORT/hang\tinconclusive' \
  "$LINK" --review "$T/hang.md"

run_case "broken-dns" $'$T/dns.md\t1\thttp://rmv2-test.invalid/\tbroken' \
  "$LINK" --review "$T/dns.md"

run_case "broken-connection-refused" $'$T/refused.md\t1\thttp://127.0.0.1:1/\tbroken' \
  "$LINK" --review "$T/refused.md"

# --- Review mode: skipped links -------------------------------------------------------------------

run_case "skipped-fenced-code" $'$T/fenced.md\t3\thttp://127.0.0.1:$PORT/ok\tskipped:fenced-code' \
  "$LINK" --review "$T/fenced.md"

run_case "skipped-inline-code" $'$T/inline-code.md\t1\thttp://127.0.0.1:$PORT/ok\tskipped:inline-code' \
  "$LINK" --review "$T/inline-code.md"

run_case "skipped-unsupported-scheme" $'$T/ftp.md\t1\tftp://example.com/file\tskipped:unsupported-scheme' \
  "$LINK" --review "$T/ftp.md"

run_case "no-row-for-mailto" $'$T/mailto-mixed.md\t3\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review "$T/mailto-mixed.md"

# --- Review mode: link forms, each probed -----------------------------------------------------

run_case "reference-definition" $'$T/refdef.md\t1\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review "$T/refdef.md"

run_case "autolink" $'$T/autolink.md\t1\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review "$T/autolink.md"

run_case "quoted-title" $'$T/quoted-title.md\t1\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review "$T/quoted-title.md"

run_case "angle-bracket-target" $'$T/angle-target.md\t1\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review "$T/angle-target.md"

run_case "image-link" $'$T/image.md\t1\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review "$T/image.md"

# --- Review mode: file-level results ---------------------------------------------------------

run_case "skipped-missing-file" $'$T/does-not-exist.md\t0\t-\tskipped:missing-file' \
  "$LINK" --review "$T/does-not-exist.md"

run_case "skipped-not-markdown" $'$T/not-markdown.txt\t0\t-\tskipped:not-markdown' \
  "$LINK" --review "$T/not-markdown.txt"

# --- Review mode: --references-rule -----------------------------------------------------------

run_case "references-rule-no-references" \
  $'$T/references-rule-no-ref.md\t1\thttp://127.0.0.1:$PORT/ok\tok\n$T/references-rule-no-ref.md\t1\thttp://127.0.0.1:$PORT/ok\tno-references' \
  "$LINK" --review --references-rule "$T/references-rule-no-ref.md"

run_case "references-rule-heading-present" \
  $'$T/references-rule-with-ref.md\t3\thttp://127.0.0.1:$PORT/ok\tok' \
  "$LINK" --review --references-rule "$T/references-rule-with-ref.md"

# --- Hook mode: unchanged behavior -------------------------------------------------------------

# shellcheck disable=SC2016 # single-quoted on purpose: $PORT must stay literal, not expand here.
run_case "hook-mode-broken" 'link-recheck: http://127.0.0.1:$PORT/missing [404] BROKEN (404)' \
  "$LINK" "$T/hook-broken.md"

run_case "hook-mode-no-references-heading" '' \
  "$LINK" "$T/hook-clean.md"

# --- Non-run_case assertions --------------------------------------------------------------------

# review mode with no file argument: exit status 2, a usage line on stderr.
total=$((total + 1))
usage_err="$("$LINK" --review 2>&1 >/dev/null)"
usage_status=$?
if [[ "$usage_status" -eq 2 && -n "$usage_err" ]]; then
  pass=$((pass + 1)); printf 'ok   review-no-file-usage\n'
else
  printf 'FAIL review-no-file-usage\n--- exit status: %s\n--- stderr\n%s\n' "$usage_status" "$usage_err"
fi

# the /hang case above must have taken at least 4 seconds, proving the one retry at
# LINK_REVIEW_MAX_TIME=2 (2 attempts x ~2s each).
total=$((total + 1))
start=$(date +%s)
"$LINK" --review "$T/hang.md" >/dev/null 2>&1
end=$(date +%s)
elapsed=$((end - start))
if [[ "$elapsed" -ge 4 ]]; then
  pass=$((pass + 1)); printf 'ok   hang-retry-timing\n'
else
  printf 'FAIL hang-retry-timing\n--- elapsed: %ss (expected >= 4s)\n' "$elapsed"
fi

# review mode reads and writes no freshness state: the script's own cache directory is unchanged.
total=$((total + 1))
state_dir="$(dirname "$(dirname "$LINK")")/cache/link-recheck"
before=""
[[ -d "$state_dir" ]] && before="$(ls -l "$state_dir" 2>/dev/null)"
"$LINK" --review "$T/ok.md" >/dev/null 2>&1
after=""
[[ -d "$state_dir" ]] && after="$(ls -l "$state_dir" 2>/dev/null)"
if [[ "$before" == "$after" ]]; then
  pass=$((pass + 1)); printf 'ok   review-mode-state-unchanged\n'
else
  printf 'FAIL review-mode-state-unchanged\n--- before\n%s\n--- after\n%s\n' "$before" "$after"
fi

# review mode fails loudly on an internal failure (here: a required command is missing) instead
# of exiting 0 having never checked anything.
total=$((total + 1))
MINPATH_DIR="$T/minpath"
mkdir -p "$MINPATH_DIR"
ln -sf "$BASH" "$MINPATH_DIR/bash"
cat > "$T/internal-failure.md" <<EOF
[a](http://127.0.0.1:$PORT/ok)
EOF
internal_err="$(PATH="$MINPATH_DIR" "$LINK" --review "$T/internal-failure.md" 2>&1 >/dev/null)"
internal_status=$?
if [[ "$internal_status" -eq 1 && "$internal_err" == "link-recheck-hook.sh: "* ]]; then
  pass=$((pass + 1)); printf 'ok   review-mode-internal-failure-is-loud\n'
else
  printf 'FAIL review-mode-internal-failure-is-loud\n--- exit status: %s\n--- stderr\n%s\n' "$internal_status" "$internal_err"
fi

printf '%s/%s passed\n' "$pass" "$total"
[[ "$pass" -eq "$total" ]]
