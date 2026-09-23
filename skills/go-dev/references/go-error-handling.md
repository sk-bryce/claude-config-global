---
created: 2026-08-05
updated: 2026-09-23
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild. They are not house style. House declaration and naming style lives in
> `go-style-preferences.md` and governs new code you write.
# Go Error Handling Patterns

**When to read**: Working with errors, error handling, panic recovery

---

## Error Wrapping (Modern Pattern)

Wraps the lookup error with `%w` so the chain stays intact for `errors.Is` and `errors.As`.

```go
func (r *Repository) GetUser(ctx context.Context, id string) (*User, error) {
 user, err := r.db.QueryUser(ctx, id)
 if err != nil {
  // Wrap with context - preserves original error
  return nil, fmt.Errorf("get user %s: %w", id, err)
 }
 return user, nil
}
```

---

## Sentinel Errors

**Define domain errors as sentinels**:

```go
package user

import "errors"

// Domain errors
var (
 ErrNotFound      = errors.New("user not found")
 ErrInvalidEmail  = errors.New("invalid email address")
 ErrDuplicate     = errors.New("user already exists")
)

func (r *Repository) GetUser(ctx context.Context, id string) (*User, error) {
 user, err := r.db.Find(ctx, id)
 if err != nil {
  if isNotFoundError(err) {
   return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
  }
  return nil, fmt.Errorf("query user %s: %w", id, err)
 }
 return user, nil
}
```

---

## Error Classification with `errors.Is` and `errors.As`

**Use `errors.Is` to check wrapped errors**:

```go
func HandleGetUser(w http.ResponseWriter, r *http.Request) {
 user, err := service.GetUser(r.Context(), userID)
 if err != nil {
  switch {
  case errors.Is(err, user.ErrNotFound):
   writeError(w, http.StatusNotFound, "User not found")
  case errors.Is(err, user.ErrInvalidEmail):
   writeError(w, http.StatusBadRequest, "Invalid email")
  default:
   writeError(w, http.StatusInternalServerError, "Internal error")
  }
  return
 }

 writeJSON(w, http.StatusOK, user)
}
```

**Use `errors.As` to extract error types**:

```go
type ValidationError struct {
 Field string
 Msg   string
}

func (e *ValidationError) Error() string {
 return fmt.Sprintf("%s: %s", e.Field, e.Msg)
}

func HandleRequest(w http.ResponseWriter, r *http.Request) {
 err := service.Process(r.Context(), data)
 if err != nil {
  var validationErr *ValidationError
  if errors.As(err, &validationErr) {
   // Handle validation error specifically
   writeError(w, http.StatusBadRequest, validationErr.Error())
   return
  }
  // Handle other errors
  writeError(w, http.StatusInternalServerError, "Internal error")
  return
 }
}
```

---

## Errors From Deferred Close

Whether it is safe to discard the error from a deferred `Close` depends on which direction the
handle moves data. A file or reader opened only for reading is nearly harmless to close and
ignore, so `defer f.Close()` is normal, accepted Go practice there. On anything being written,
a file, a buffered writer, a network connection, or an HTTP request body you are sending,
`Close` is often where a buffered-write or flush failure actually surfaces. Discarding that
error means the function can report success for data that never reached the disk or the wire.

**Capture the close error with a named return**:

```go
func writeReport(path string) (err error) {
 var reportFile *os.File
 reportFile, err = os.Create(path)
 if err != nil {
  return fmt.Errorf("create report %s: %w", path, err)
 }
 defer func() {
  var closeErr = reportFile.Close()
  if closeErr != nil && err == nil {
   err = fmt.Errorf("close report %s: %w", path, closeErr)
  }
 }()
 // ... write the report body to reportFile here ...
 return err
}
```

The deferred closure only assigns to `err` when `err` is still nil, so a real error from the
body of the function is never masked by a close error that happened afterward.

For a read-only handle, skip all of this: a bare `defer f.Close()` is the right call, and the
named-return pattern there would only clutter the read path.

If you deliberately want to discard a close error, write `defer func() { _ = f.Close() }()`
instead of a bare `defer f.Close()`: it states the intent explicitly and keeps a linter such as
`errcheck` from flagging the ignored return.

**When both errors matter, keep both with `errors.Join`** (Go 1.20+). The pattern above keeps
the first error and drops a later close error. If the close error is worth reporting even when
the body already failed, join them instead:

```go
 defer func() {
  var closeErr = reportFile.Close()
  if closeErr != nil {
   err = errors.Join(err, fmt.Errorf("close report %s: %w", path, closeErr))
  }
 }()
```

---

## Combining Several Errors With `errors.Join`

`errors.Join(errs ...error)` (Go 1.20+) combines several errors into one. It discards nil
arguments and returns nil when every argument is nil, including when it is called with an empty
slice, so it can wrap a collection loop without a length check:

```go
func closeAll(closers []io.Closer) error {
 var closeErrors []error
 for _, closer := range closers {
  if err := closer.Close(); err != nil {
   closeErrors = append(closeErrors, err)
  }
 }
 return errors.Join(closeErrors...)
}
```

`errors.Is` and `errors.As` search every joined error, so a caller can still match any one
sentinel inside the result. The same is true of `fmt.Errorf` with more than one `%w` verb, which
is the better choice when you want a single line of context around the errors rather than a list.

Three things to know before reaching for it:

- **The message is multi-line.** `Error()` joins the parts with newlines. That reads well in a
  terminal but can break a line-oriented log format; pass the error to the logger as a field
  (`zap.Error(err)`) rather than interpolating it into a message string.
- **Even one error comes back wrapped.** `errors.Join(nil, ErrNotFound)` is not `==`
  `ErrNotFound`. Compare with `errors.Is`, never with `==`, which is already the rule for any
  wrapped error.
- **It is not a substitute for `%w` context.** Joining adds no description of what was being
  done. Wrap each error with `fmt.Errorf("...: %w", err)` first, then join the wrapped errors.

It pairs naturally with the collect-every-error worker pool in `go-concurrency.md`: that function
returns `[]error`, and a caller that wants a single `error` can return
`errors.Join(collectedErrors...)`.
