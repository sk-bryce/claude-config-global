---
created: 2026-08-05
updated: 2026-09-19
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild. They are not house style. House declaration and naming style lives in
> `go-style-preferences.md` and governs new code you write.
# Go Context Patterns

**When to read**: Working with context.Context, cancellation, timeouts, request-scoped values

---

## Context for Cancellation and Timeouts

HTTP handler: derive ctx from the request; it cancels automatically if the client disconnects.

```go
func (s *Server) handleGetUser(w http.ResponseWriter, r *http.Request) {
 // Use request context - automatically canceled if client disconnects
 ctx := r.Context()

 user, err := s.service.GetUser(ctx, userIDFromRequest(r))
 if err != nil {
  writeError(w, err)
  return
 }

 writeJSON(w, http.StatusOK, user)
}
```

Add a deadline for the operation and defer the cancel immediately.

```go
func (s *Service) GetUser(ctx context.Context, id string) (*User, error) {
 // Set a deadline for this operation
 ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
 defer cancel()

 user, err := s.repo.FindByID(ctx, id)
 if err != nil {
  return nil, fmt.Errorf("get user: %w", err)
 }
 return user, nil
}
```

Check ctx.Done() before each iteration in a long-running loop, not just once at entry.

```go
func ProcessBatch(ctx context.Context, items []Item) error {
 for _, item := range items {
  // Check if canceled
  select {
  case <-ctx.Done():
   return ctx.Err()
  default:
  }

  if err := processItem(ctx, item); err != nil {
   return fmt.Errorf("process item %v: %w", item.ID, err)
  }
 }
 return nil
}
```

---

## Context Values (Use Sparingly)

Use context values only for request-scoped metadata (request/trace IDs, auth info, deadlines) - never for optional parameters, dependencies, or configuration. A typed, unexported key type avoids collisions with other packages' context keys:

```go
// contextkeys/keys.go
package contextkeys

type contextKey string

const (
 RequestIDKey contextKey = "request_id"
 UserIDKey    contextKey = "user_id"
)

// Use helpers to avoid exposing the key type
func WithRequestID(ctx context.Context, id string) context.Context {
 return context.WithValue(ctx, RequestIDKey, id)
}

func RequestID(ctx context.Context) (string, bool) {
 id, ok := ctx.Value(RequestIDKey).(string)
 return id, ok
}
```
