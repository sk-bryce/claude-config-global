---
created: 2026-08-05
updated: 2026-09-19
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild. They are not house style. House declaration and naming style lives in
> `go-style-preferences.md` and governs new code you write.
# Go Performance Optimization

**When to read**: Optimizing performance, working with I/O readers, profiling code

---

## Profiling First

**Always profile before optimizing**:

```bash
# CPU profile
go test -bench=. -cpuprofile=cpu.prof

# Memory profile
go test -bench=. -memprofile=mem.prof

# Analyze profiles
go tool pprof cpu.prof
go tool pprof mem.prof
```

---

## I/O: Readers and Buffers

Most `io.Reader` streams are consumable once - reading advances internal state and a consumed reader cannot be re-read.

### Reusing Readers for HTTP Requests

**For HTTP requests with body reuse** (retries, redirects):

```go
// GOOD: Keep original payload, create fresh readers
func (c *Client) PostWithRetry(ctx context.Context, url string, data []byte) error {
 // Keep data as []byte, create fresh body for each attempt
 for attempt := 1; attempt <= 3; attempt++ {
  req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
  if err != nil {
   return fmt.Errorf("create request: %w", err)
  }

  // Configure GetBody for automatic retries/redirects
  req.GetBody = func() (io.ReadCloser, error) {
   return io.NopCloser(bytes.NewReader(data)), nil
  }

  resp, err := c.httpClient.Do(req)
  if err == nil {
   defer resp.Body.Close()
   if resp.StatusCode < 500 {
    return nil // Success or client error
   }
  }

  // Retry on server error
  time.Sleep(time.Second * time.Duration(attempt))
 }

 return fmt.Errorf("all retry attempts failed")
}

// AVOID: Reusing consumed request body
func (c *Client) PostWithRetry(ctx context.Context, url string, body io.Reader) error {
 req, _ := http.NewRequestWithContext(ctx, http.MethodPost, url, body)

 // First attempt consumes the body
 resp, err := c.httpClient.Do(req)
 if err != nil {
  // Retry won't work - body is consumed!
  resp2, _ := c.httpClient.Do(req) // BAD - body is empty now
  // ...
 }
 return nil
}
```

### Streaming with `io.Pipe`

Streams data through `io.Pipe` without buffering the full payload:

```go
// GOOD: Streaming with pipe
func StreamData(ctx context.Context) error {
 pr, pw := io.Pipe()

 // Writer goroutine
 go func() {
  defer pw.Close()

  for i := 0; i < 1000; i++ {
   data := fmt.Sprintf("chunk %d\n", i)
   if _, err := pw.Write([]byte(data)); err != nil {
    pw.CloseWithError(err)
    return
   }

   // Check for cancellation
   select {
   case <-ctx.Done():
    pw.CloseWithError(ctx.Err())
    return
   default:
   }
  }
 }()

 // Reader side (maybe HTTP request body)
 req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.example.com/upload", pr)
 if err != nil {
  return fmt.Errorf("create request: %w", err)
 }

 // Send the request
 resp, err := http.DefaultClient.Do(req)
 if err != nil {
  return fmt.Errorf("send request: %w", err)
 }
 defer resp.Body.Close()

 return nil
}
```

### Streaming Multipart Form Data

**When streaming multipart data, writes MUST be sequential** (not parallel or out-of-order):

```go
// GOOD: Sequential multipart writes with pipe
func UploadFiles(ctx context.Context, files []File) error {
 pr, pw := io.Pipe()

 // Create multipart writer
 mw := multipart.NewWriter(pw)

 // Writer goroutine - writes MUST be sequential
 go func() {
  defer pw.Close()
  defer mw.Close()

  // Write fields and files IN ORDER
  for _, file := range files {
   // Write file field
   part, err := mw.CreateFormFile("files", file.Name)
   if err != nil {
    pw.CloseWithError(fmt.Errorf("create form file: %w", err))
    return
   }

   // Write file data
   if _, err := io.Copy(part, file.Reader); err != nil {
    pw.CloseWithError(fmt.Errorf("copy file data: %w", err))
    return
   }
  }

  // Close multipart writer BEFORE closing pipe writer
  if err := mw.Close(); err != nil {
   pw.CloseWithError(err)
   return
  }
 }()

 // Create request with pipe reader as body
 url := "https://api.example.com/upload"
 req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, pr)
 if err != nil {
  return fmt.Errorf("create request: %w", err)
 }

 // CRITICAL: Set Content-Type from multipart writer
 req.Header.Set("Content-Type", mw.FormDataContentType())

 // Send request
 resp, err := http.DefaultClient.Do(req)
 if err != nil {
  return fmt.Errorf("send request: %w", err)
 }
 defer resp.Body.Close()

 return nil
}

// AVOID: Parallel writes to multipart (corrupts stream!)
func BadUploadFiles(files []File) error {
 pr, pw := io.Pipe()
 mw := multipart.NewWriter(pw)

 go func() {
  var wg sync.WaitGroup
  for _, file := range files {
   wg.Add(1)
   go func(f File) {
    defer wg.Done()
    part, _ := mw.CreateFormFile("files", f.Name)
    io.Copy(part, f.Reader) // BAD - parallel writes corrupt multipart!
   }(file)
  }
  wg.Wait()
  mw.Close()
  pw.Close()
 }()

 // This will fail - multipart stream is corrupted
 // ...
}
```
</content>
