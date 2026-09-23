---
created: 2026-08-05
updated: 2026-09-23
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild, unless a section says it is written in house style. Upstream examples are not house
> style. House declaration and naming style lives in `go-style-preferences.md` and governs
> new code you write.
# Go HTTP Patterns

**When to read**: Building HTTP clients or servers, working with requests/responses

---

## HTTP Client Patterns

### Critical Rules for HTTP Clients

**1. Client struct holds only configuration, not per-request state.**

```go
// GOOD: Client stores only configuration and dependencies
type Client struct {
 baseURL    string
 httpClient *http.Client
 apiKey     string
}

// AVOID: Don't store per-request state
type Client struct {
 baseURL    string
 httpClient *http.Client
 request    *http.Request  // BAD - request-specific state
 params     url.Values     // BAD - request-specific state
}
```

**2. Never store `*http.Request` in the client struct; build one per call.**

```go
// GOOD: Create request per method call
func (c *Client) GetUser(ctx context.Context, userID string) (*User, error) {
 url := fmt.Sprintf("%s/users/%s", c.baseURL, userID)
 req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
 if err != nil {
  return nil, fmt.Errorf("create request: %w", err)
 }

 req.Header.Set("Authorization", "Bearer "+c.apiKey)
 req.Header.Set("Content-Type", "application/json")

 resp, err := c.httpClient.Do(req)
 if err != nil {
  return nil, fmt.Errorf("execute request: %w", err)
 }
 defer resp.Body.Close()

 // ... parse response ...
}

// AVOID: Storing request in struct
type BadClient struct {
 httpClient *http.Client
 request    *http.Request // BAD!
}

func (c *BadClient) GetUser(ctx context.Context, userID string) (*User, error) {
 // Reusing the same request is wrong!
 c.request.URL.Path = "/users/" + userID
 resp, err := c.httpClient.Do(c.request)
 // ...
}
```

**3. Methods take `context.Context` and build the request locally.**

```go
// GOOD: Context + parameters, build request locally
func (c *Client) CreateUser(ctx context.Context, user *User) (*User, error) {
 body, err := json.Marshal(user)
 if err != nil {
  return nil, fmt.Errorf("marshal user: %w", err)
 }

 url := c.baseURL + "/users"
 req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
 if err != nil {
  return nil, fmt.Errorf("create request: %w", err)
 }

 req.Header.Set("Authorization", "Bearer "+c.apiKey)
 req.Header.Set("Content-Type", "application/json")

 resp, err := c.httpClient.Do(req)
 if err != nil {
  return nil, fmt.Errorf("execute request: %w", err)
 }
 defer resp.Body.Close()

 // ... parse response ...
 return createdUser, nil
}
```

**4. Extract repeated request-building logic (like setting auth headers) into an unexported helper.**

```go
// GOOD: Helper function for common request setup
func (c *Client) newRequest(ctx context.Context, method, path string, body io.Reader) (*http.Request, error) {
 url := c.baseURL + path
 req, err := http.NewRequestWithContext(ctx, method, url, body)
 if err != nil {
  return nil, err
 }

 // Common headers
 req.Header.Set("Authorization", "Bearer "+c.apiKey)
 req.Header.Set("Content-Type", "application/json")
 req.Header.Set("User-Agent", "my-client/1.0")

 return req, nil
}

// Use helper in methods
func (c *Client) GetUser(ctx context.Context, userID string) (*User, error) {
 req, err := c.newRequest(ctx, http.MethodGet, "/users/"+userID, nil)
 if err != nil {
  return nil, fmt.Errorf("create request: %w", err)
 }

 resp, err := c.httpClient.Do(req)
 // ... rest of implementation ...
}
```

**5. Configure `*http.Client` with a timeout and pooled transport; a zero-value client has no timeout.**

```go
// GOOD: Properly configured HTTP client
func NewClient(baseURL, apiKey string) *Client {
 return &Client{
  baseURL: baseURL,
  apiKey:  apiKey,
  httpClient: &http.Client{
   Timeout: 30 * time.Second,
   Transport: &http.Transport{
    MaxIdleConns:        100,
    MaxIdleConnsPerHost: 10,
    IdleConnTimeout:     90 * time.Second,
   },
  },
 }
}
```

`Client.Timeout` is a backstop: one ceiling shared by every call the client makes, and it cannot
tell a slow endpoint from a fast one or see that the caller has given up. Set the per-call
deadline on the request's context instead, and keep the client timeout as the outer limit:

```go
// GOOD: Per-call deadline on the context; the caller's cancellation still applies
func (c *Client) GetUser(ctx context.Context, userID string) (*User, error) {
 ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
 defer cancel()

 req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/users/"+userID, nil)
 if err != nil {
  return nil, fmt.Errorf("create request: %w", err)
 }
 // ... send with c.httpClient.Do(req) and handle the response as in rule 6 ...
}
```

**6. Close the body and check the status code before decoding; do not assume success.**

```go
// GOOD: Always defer close and check error
resp, err := c.httpClient.Do(req)
if err != nil {
 return fmt.Errorf("execute request: %w", err)
}
defer resp.Body.Close()

// Check status code
if resp.StatusCode != http.StatusOK {
 body, _ := io.ReadAll(resp.Body)
 return fmt.Errorf("unexpected status %d: %s", resp.StatusCode, body)
}

// Parse response
var result User
if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
 return fmt.Errorf("decode response: %w", err)
}
```

### HTTP Client Checklist

**Do**:

- Client struct contains only: base URL, `*http.Client`, auth credentials, configuration
- Methods accept `context.Context` as first parameter
- Create fresh `*http.Request` per method call
- Set headers on the request instance you're sending
- Close response bodies with `defer resp.Body.Close()`
- Handle errors appropriately at each step

**Never**:

- NEVER store `*http.Request` in the client struct
- NEVER cache request-specific state (params, body, headers) in client fields

---

## HTTP Server and Routing

### Go Version-Specific Routing

**Go 1.22+ Enhanced ServeMux**:

If `go >= 1.22` in your `go.mod`, prefer the enhanced `net/http.ServeMux` with pattern-based routing and method matching.

```go
// Modern pattern (Go 1.22+) - method and path patterns
func NewServer() *http.Server {
 mux := http.NewServeMux()

 // Method-specific routes with path parameters
 mux.HandleFunc("GET /users/{id}", handleGetUser)
 mux.HandleFunc("POST /users", handleCreateUser)
 mux.HandleFunc("PUT /users/{id}", handleUpdateUser)
 mux.HandleFunc("DELETE /users/{id}", handleDeleteUser)

 // Wildcard patterns
 mux.HandleFunc("GET /files/{path...}", handleFiles)

 return &http.Server{
  Addr:    ":8080",
  Handler: mux,
 }
}

// Extract path parameters
func handleGetUser(w http.ResponseWriter, r *http.Request) {
 // Go 1.22+ - path parameters available
 userID := r.PathValue("id")

 // Use the ID
 user, err := getUser(r.Context(), userID)
 // ...
}
```

**Pre-Go 1.22 Pattern**:

For `go < 1.22`, use classic `ServeMux` and handle methods/paths manually:

```go
// Classic pattern (Go < 1.22) - manual method checking
func NewServer() *http.Server {
 mux := http.NewServeMux()

 // Register path, check method inside handler
 mux.HandleFunc("/users/", handleUsers)

 return &http.Server{
  Addr:    ":8080",
  Handler: mux,
 }
}

func handleUsers(w http.ResponseWriter, r *http.Request) {
 // Manual method checking
 switch r.Method {
 case http.MethodGet:
  // Extract ID from path manually
  id := strings.TrimPrefix(r.URL.Path, "/users/")
  handleGetUser(w, r, id)

 case http.MethodPost:
  handleCreateUser(w, r)

 default:
  http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
 }
}
```

**When to use which**:

- Check your `go.mod` file's Go version directive
- If `go 1.22` or higher, use enhanced `ServeMux` with pattern-based routing
- If `go 1.21` or lower, use classic `ServeMux` with manual method handling (or justify a third-party router)

### HTTP Handler Best Practices

**Handler signature**:

```go
// Standard handler function
func handleGetUser(w http.ResponseWriter, r *http.Request) {
 ctx := r.Context()

 // Get user ID from path (Go 1.22+) or URL
 userID := r.PathValue("id")  // Go 1.22+
 // OR
 // userID := strings.TrimPrefix(r.URL.Path, "/users/")  // Pre-1.22

 user, err := service.GetUser(ctx, userID)
 if err != nil {
  writeError(w, err)
  return
 }

 writeJSON(w, http.StatusOK, user)
}
```

**Helper functions for responses**:

```go
// JSON response helper
func writeJSON(w http.ResponseWriter, status int, v interface{}) {
 w.Header().Set("Content-Type", "application/json")
 w.WriteHeader(status)
 if err := json.NewEncoder(w).Encode(v); err != nil {
  // Log error but can't change status code now
  log.Printf("encode response: %v", err)
 }
}

// Error response helper
func writeError(w http.ResponseWriter, err error) {
 status := http.StatusInternalServerError
 message := "Internal server error"

 // Map domain errors to HTTP status codes
 switch {
 case errors.Is(err, user.ErrNotFound):
  status = http.StatusNotFound
  message = "User not found"
 case errors.Is(err, user.ErrInvalidInput):
  status = http.StatusBadRequest
  message = err.Error()
 }

 http.Error(w, message, status)
}
```

This example uses the standard `log` package for brevity; it is not the house logging
position. See `go-style-preferences.md` for the authority on logging: `go.uber.org/zap` with
typed fields and an injected logger.

**Middleware pattern**:

```go
// Middleware type
type Middleware func(http.Handler) http.Handler

// Logging middleware
func LoggingMiddleware(next http.Handler) http.Handler {
 return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  start := time.Now()
  log.Printf("%s %s", r.Method, r.URL.Path)

  next.ServeHTTP(w, r)

  log.Printf("completed in %v", time.Since(start))
 })
}

// Apply middleware
mux := http.NewServeMux()
mux.HandleFunc("GET /users/{id}", handleGetUser)

handler := LoggingMiddleware(mux)
http.ListenAndServe(":8080", handler)
```

This example uses the standard `log` package for brevity; it is not the house logging
position. See `go-style-preferences.md` for the authority on logging: `go.uber.org/zap` with
typed fields and an injected logger. In a real service, request logging middleware should
take the logger as a dependency rather than calling a package-level logger, so the middleware
stays testable and the sink stays configurable.
