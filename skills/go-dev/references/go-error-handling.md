---
created: 2026-08-05
updated: 2026-09-19
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
