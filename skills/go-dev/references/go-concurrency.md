---
created: 2026-08-05
updated: 2026-09-23
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild, unless a section says it is written in house style. Upstream examples are not house
> style. House declaration and naming style lives in `go-style-preferences.md` and governs
> new code you write.
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

## Choosing the Primitive

Pick in this order:

1. **`golang.org/x/sync/errgroup` whenever the goroutines can fail.** `Wait` hands the first
   error back to the caller, and a group built with `errgroup.WithContext` cancels the rest the
   moment one fails, so a doomed fan-out stops paying for work whose result will be discarded.
2. **`sync.WaitGroup.Go` (Go 1.25+) for fan-out that cannot fail,** and for long-lived goroutines
   whose shutdown is driven by a context or a closed channel rather than by an error.
3. **Manual `wg.Add`/`wg.Done` only where the count is genuinely not one per goroutine,** or where
   `go.mod` declares a version before 1.25. One `Go` call cannot drift out of balance the way a
   separate `Add` and `defer Done` pair can.

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
   return fmt.Errorf("getting user: %w", err)
  }
  user = u
  return nil
 })

 // Fetch posts concurrently
 g.Go(func() error {
  p, err := s.postRepo.ListByUser(ctx, userID)
  if err != nil {
   return fmt.Errorf("listing posts: %w", err)
  }
  posts = p
  return nil
 })

 // Fetch stats concurrently
 g.Go(func() error {
  st, err := s.statsRepo.GetUserStats(ctx, userID)
  if err != nil {
   return fmt.Errorf("getting stats: %w", err)
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

### Rules for `errgroup`

- **Honor the derived context in every goroutine.** Cancellation is cooperative. A bare
  `errgroup.Group`, or one whose goroutines never check `ctx.Err()` or pass `ctx` on, gives up
  the cancellation half of the type and waits for every goroutine regardless, which a
  `WaitGroup` would already have done.
- **Reassign the parent context rather than naming a second one:**
  `group, ctx = errgroup.WithContext(ctx)`, as `go-style-preferences.md` shows. A second name
  such as `groupCtx` leaves the uncancelled parent in scope for a closure to pick up by mistake.
- **Call `SetLimit` before the first `Go`,** never while goroutines are running: changing the
  limit with goroutines active panics.
- **Call `Wait` exactly once, on every path, and never discard its error.**
- **`Wait` returns only the first non-nil error; the rest are dropped.** That is the right trade
  when the errors are variations on one failure. When each failure means something on its own,
  use the collector in "Collecting Every Error" below.

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
      return fmt.Errorf("processing job %s: %w", job.ID, err)
     }
    }
   }
  })
 }

 return g.Wait()
}
```

## Collecting Every Error

Examples in this section are written in house style.

`Wait` keeps only the first error. When the caller needs every failure, give each goroutine its
own slot in a slice sized before the fan-out, and join the slots after `Wait`. Each goroutine
writes only its own index, so the slice needs no mutex, and the result comes back in submission
order rather than completion order.

When every failure is independent and one should not stop the others, record the error and
return nil to the group:

```go
func ProcessAllJobs(ctx context.Context, jobs []Job, workerLimit int) error {
 var group errgroup.Group
 group.SetLimit(workerLimit)

 var jobErrors = make([]error, len(jobs))
 for jobIndex, job := range jobs {
  group.Go(func() error {
   if err := processJob(ctx, job); err != nil {
    jobErrors[jobIndex] = fmt.Errorf("processing job %s: %w", job.ID, err)
   }
   return nil
  })
 }

 // Every goroutine returns nil, so this only guards a later change to that.
 if err := group.Wait(); err != nil {
  return err
 }
 return errors.Join(jobErrors...)
}
```

When the first failure should stop the rest but the caller still wants everything that went
wrong, derive the group's context and return the recorded error as well:

```go
func ProcessJobsUntilFailure(ctx context.Context, jobs []Job, workerLimit int) error {
 var group *errgroup.Group
 group, ctx = errgroup.WithContext(ctx)
 group.SetLimit(workerLimit)

 var jobErrors = make([]error, len(jobs))
 for jobIndex, job := range jobs {
  group.Go(func() error {
   if err := processJob(ctx, job); err != nil {
    jobErrors[jobIndex] = fmt.Errorf("processing job %s: %w", job.ID, err)
    return jobErrors[jobIndex]
   }
   return nil
  })
 }

 if err := group.Wait(); err != nil {
  return errors.Join(jobErrors...)
 }
 return nil
}
```

The second shape encodes a few deliberate tradeoffs:

- Cancellation is cooperative. A job already running stops only at `processJob`'s own checks of
  `ctx`, and a job that never checks it runs to completion.
- `SetLimit` makes `group.Go` block the loop until a worker frees up, so jobs started after the
  failure see a cancelled `ctx`. A `processJob` that honors it returns at once, and its
  `context.Canceled` is recorded too: the joined error names the real failure plus one
  cancellation per job that never got going.
- Any non-nil slot means its goroutine returned that error, so a nil `Wait` means every slot is
  nil and there is nothing to join.

When jobs arrive on a channel, so their count is unknown up front, size the slice to the workers
instead of the jobs: start one `group.Go` per worker, have each drain the channel and append its
failures to its own `workerErrors[workerIndex]`, and return
`errors.Join(slices.Concat(workerErrors...)...)` after `Wait`. Each worker still writes only its
own slot, so the slice still needs no mutex.

## Panics in Goroutines

Examples in this section are written in house style.

`recover` stops a panic only from a deferred call in the goroutine that is panicking. A parent
cannot recover a child's panic, so an unrecovered panic in any goroutine ends the whole process.
Neither fan-out primitive softens that:

- **`sync.WaitGroup.Go` documents that its function must not panic.** If it does, `Go` re-panics
  without calling `Done`, on purpose, so `Wait` cannot unblock and let the process exit before
  the crash lands.
- **`errgroup.Group.Go` does not recover either,** and does not carry the panic to `Wait`: x/sync
  declined to, so the panic's stack reaches crash tooling intact.

So work that can panic on bad input recovers inside its own goroutine and turns the panic into
an error. With no named results, a deferred `recover` cannot rewrite the function's return value,
so run the work in an inner function and join its result with the recovered panic. A function
that panics and recovers returns its zero values, so `workErr` is nil on that path and
`panicErr` carries the failure:

```go
// runRecovered runs work and converts a panic inside it into an error, so one
// bad input fails its own goroutine instead of the process.
func runRecovered(work func() error) error {
 var panicErr error
 var workErr = func() error {
  defer func() {
   if recovered := recover(); recovered != nil {
    panicErr = fmt.Errorf("recovered panic: %v", recovered)
   }
  }()
  return work()
 }()
 return errors.Join(workErr, panicErr)
}

group.Go(func() error {
 return runRecovered(func() error { return processJob(ctx, job) })
})
```

The error alone drops the stack. Where the stack matters, log it at the recovery site with
`zap.Stack` before building the error. HTTP handlers are the one place this is partly done for
you: `net/http` recovers a handler panic per connection (see `go-http.md`), but writes no
response and logs only to the server's `ErrorLog`, so a recovery middleware is still worth
having.

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

**Use `sync.WaitGroup` for fan-out that cannot fail**. Goroutines that can fail belong in an
`errgroup` instead; see "Choosing the Primitive" above.

```go
// Go 1.25+: one call per goroutine, nothing to keep in balance
var wg sync.WaitGroup
for i := 0; i < 10; i++ {
 wg.Go(func() {
  process(i) // No need to pass i as parameter
 })
}
wg.Wait()
```

Manual `Add`/`Done` is the fallback, for a count that is not one per goroutine or a `go.mod`
before Go 1.25:

```go
// Fallback: pre-1.25, or a count that is not one per goroutine
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
