---
created: 2026-08-05
updated: 2026-09-23
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild. They are not house style. House declaration and naming style lives in
> `go-style-preferences.md` and governs new code you write.
# Concurrency

## Goroutines: Keep Them Short and Owned

Request-scoped goroutine with a bounded lifecycle via context cancellation:

```go
func (s *Server) HandleRequest(w http.ResponseWriter, r *http.Request) {
 ctx := r.Context()

 // Goroutine lives for the duration of this request
 resultCh := make(chan Result, 1)
 go func() {
  result := s.computeExpensiveResult(ctx)
  resultCh <- result
 }()

 select {
 case <-ctx.Done():
  writeError(w, http.StatusRequestTimeout, "Request canceled")
 case result := <-resultCh:
  writeJSON(w, http.StatusOK, result)
 }
}
```

Anti-pattern: spawning one goroutine per message with no bound can create thousands of them:

```go
// BAD: Creates goroutines without bounds
func (s *Service) ProcessMessages(messages <-chan Message) {
 for msg := range messages {
  go s.process(msg) // Can create thousands of goroutines!
 }
}
```

## Using `errgroup` for Parallel Operations

**Modern pattern for fan-out/fan-in with error handling**:

```go
import "golang.org/x/sync/errgroup"

func (s *Service) FetchDashboard(ctx context.Context, userID string) (*Dashboard, error) {
 g, ctx := errgroup.WithContext(ctx)

 var user *User
 var posts []*Post
 var stats *Stats

 // Fetch user
 g.Go(func() error {
  u, err := s.userRepo.Get(ctx, userID)
  if err != nil {
   return fmt.Errorf("get user: %w", err)
  }
  user = u
  return nil
 })

 // Fetch posts concurrently
 g.Go(func() error {
  p, err := s.postRepo.ListByUser(ctx, userID)
  if err != nil {
   return fmt.Errorf("list posts: %w", err)
  }
  posts = p
  return nil
 })

 // Fetch stats concurrently
 g.Go(func() error {
  st, err := s.statsRepo.GetUserStats(ctx, userID)
  if err != nil {
   return fmt.Errorf("get stats: %w", err)
  }
  stats = st
  return nil
 })

 // Wait for all to complete (or first error)
 if err := g.Wait(); err != nil {
  return nil, err
 }

 return &Dashboard{
  User:  user,
  Posts: posts,
  Stats: stats,
 }, nil
}
```

**Benefits of `errgroup`**:

- Automatic cancellation on first error
- Clean error handling
- Waits for all goroutines to complete
- Context propagation

## Worker Pool Pattern

**Use when you have many tasks and want to bound concurrency**:

```go
func ProcessJobs(ctx context.Context, jobs <-chan Job, workers int) error {
 g, ctx := errgroup.WithContext(ctx)

 // Start worker pool
 for i := 0; i < workers; i++ {
  g.Go(func() error {
   for {
    select {
    case <-ctx.Done():
     return ctx.Err()
    case job, ok := <-jobs:
     if !ok {
      return nil // Channel closed, worker exits
     }
     if err := processJob(ctx, job); err != nil {
      return fmt.Errorf("process job %s: %w", job.ID, err)
     }
    }
   }
  })
 }

 return g.Wait()
}
```

## Collecting Every Error While Still Cancelling

`errgroup` is the right tool when the first error should stop everything: `g.Wait()` returns
that one error and the rest of the work never completes. When the caller needs a full list of
what failed, not just the first failure, you need a different shape instead. The trap in
hand-rolling that collector is losing cancellation along the way: without it, a single early
failure no longer stops the remaining queued or in-flight work.

```go
func ProcessAllJobs(parentCtx context.Context, jobs <-chan Job, workerCount int) []error {
 var ctx, cancel = context.WithCancel(parentCtx)
 defer cancel()

 var waitGroup sync.WaitGroup
 var collectorMutex sync.Mutex
 var collectedErrors []error

 for workerIndex := 0; workerIndex < workerCount; workerIndex++ {
  waitGroup.Add(1)
  go func() {
   defer waitGroup.Done()
   for {
    select {
    case <-ctx.Done():
     return
    case job, ok := <-jobs:
     if !ok {
      return
     }
     if err := processJob(ctx, job); err != nil {
      collectorMutex.Lock()
      collectedErrors = append(collectedErrors, fmt.Errorf("process job %s: %w", job.ID, err))
      collectorMutex.Unlock()
      cancel()
     }
    }
   }
  }()
 }

 waitGroup.Wait()
 return collectedErrors
}
```

This shape encodes a few deliberate tradeoffs:

- Cancellation is best-effort: a job that is already running finishes its current step, since
  `processJob` must check `ctx.Err()` at its own checkpoints to actually stop early.
- The returned slice is in completion order, not submission order.
- Calling `cancel` on the first failure means `collectedErrors` holds the failures that happened
  before the stop took effect, not every job that would eventually have failed. Some queued jobs
  never run at all once cancellation lands, so a short list does not mean only a few jobs were
  bad.

When first-error-wins is acceptable, prefer the simpler `errgroup` pattern above.

## Channels

Pipeline pattern: chained stages communicate over channels, each stage selecting on ctx.Done to unwind on cancellation:

```go
func Generate(ctx context.Context, nums ...int) <-chan int {
 out := make(chan int)
 go func() {
  defer close(out)
  for _, n := range nums {
   select {
   case <-ctx.Done():
    return
   case out <- n:
   }
  }
 }()
 return out
}

func Square(ctx context.Context, in <-chan int) <-chan int {
 out := make(chan int)
 go func() {
  defer close(out)
  for n := range in {
   select {
   case <-ctx.Done():
    return
   case out <- n * n:
   }
  }
 }()
 return out
}

// Usage
nums := Generate(ctx, 1, 2, 3, 4)
squares := Square(ctx, nums)
for s := range squares {
 fmt.Println(s)
}
```

## Sync Primitives

**Use `sync.WaitGroup` for coordinating goroutines**:

```go
// Classic pattern (all Go versions)
var wg sync.WaitGroup
for i := 0; i < 10; i++ {
 wg.Add(1)
 go func(id int) {
  defer wg.Done()
  process(id)
 }(i)
}
wg.Wait()
```

**Go 1.25+ Pattern - Use `WaitGroup.Go` method**:

If `go >= 1.25` in your `go.mod`, use the new simpler pattern:

```go
// Modern pattern (Go 1.25+)
var wg sync.WaitGroup

// No need for Add/Done - Go method handles it
for i := 0; i < 10; i++ {
 wg.Go(func() {
  process(i)  // No need to pass i as parameter
 })
}
wg.Wait()
```

**When to use which**:

- Check your `go.mod` file's Go version directive
- If `go 1.25` or higher, use `WaitGroup.Go`
- If `go 1.24` or lower, use classic `Add`/`Done` pattern

**Use `sync.Once` for one-time initialization**:

```go
var (
 instance *Service
 once     sync.Once
)

func GetService() *Service {
 once.Do(func() {
  instance = &Service{
   // expensive initialization
  }
 })
 return instance
}
```

**Use `sync.Mutex` for protecting shared state**:

```go
type Cache struct {
 mu    sync.RWMutex
 items map[string]Item
}

func (c *Cache) Get(key string) (Item, bool) {
 c.mu.RLock()
 defer c.mu.RUnlock()
 item, ok := c.items[key]
 return item, ok
}

func (c *Cache) Set(key string, item Item) {
 c.mu.Lock()
 defer c.mu.Unlock()
 c.items[key] = item
}
```
