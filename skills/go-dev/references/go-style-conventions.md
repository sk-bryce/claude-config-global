---
created: 2026-08-05
updated: 2026-09-23
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild, unless a section says it is written in house style. Upstream examples are not house
> style. House declaration and naming style lives in `go-style-preferences.md` and governs
> new code you write.
# Go Style, Structure, and Tooling

**When to read**: Writing new Go code, setting up projects, reviewing code style, configuring linters

---

## Project Structure

### Module Layout

Group by **feature/domain**, not by layer. Layer-based layouts (`service/`, `repo/`, `domain/`) create artificial separation without enforced dependency boundaries.

The module sits at the repository root, in the conventional Go layout:

```
<repository root>/
├── go.mod
├── go.sum
├── cmd/
│   ├── <binary>/
│   │   └── main.go           # Wiring only - no business logic
│   └── <second-binary>/
│       └── main.go           # Each binary gets its own directory
├── internal/                 # Not importable from outside this module
│   ├── server/               # Transport: thin HTTP/gRPC handlers
│   ├── config/               # Configuration loading
│   ├── <domain>/             # One package per subdomain
│   │   ├── doc.go            # Package doc comment only
│   │   ├── interactor.go     # Business logic
│   │   ├── repo.go           # Data access (concrete types)
│   │   ├── adapter.go        # External service adapters
│   │   └── errors.go         # Sentinel errors and error types
│   └── <domain2>/
│       └── ...
└── pkg/                      # Only for packages deliberately published for outside import
```

- `cmd/<binary>/` holds one `main` package per binary, even when there is only one, so adding a
  second never forces a move.
- `internal/` holds everything else. The compiler refuses imports of it from outside the module,
  which is the only package-privacy boundary Go enforces.
- `pkg/` exists only when a package is meant to be imported by other modules. It is not a default
  home for shared code; a package under `internal/` can be promoted later.

### Key Principles

**Feature-grouped, not layer-grouped**

- Package names reflect the domain (`card`, `scan`, `offers`), not a technical role (`service`, `repo`, `handler`). The transport package (`internal/server/` above) is the one exception: it is the boundary domain packages are kept away from, not a layer of domain code.
- Never create generic packages: `util`, `common`, `helper`, `types`, `interfaces`

**`cmd/<binary>/main.go` does all dependency wiring**

- Construct all repos, interactors, and handlers here
- No global mutable state: loggers, config, and clients arrive through struct fields or function
  arguments
- No `init()` functions. They run in an order the reader cannot see from any call site and
  cannot be called from a test; do the work in an explicit constructor that `main` calls.
  `gochecknoinits` enforces this.

```go
func main() {
    cfg := config.Load()
    db := dynamo.NewClient(cfg.DynamoDB)
    cardRepo := card.NewDynamoRepo(db, cfg.CardTable)
    cardInteractor := card.NewInteractor(cardRepo)
    handler := NewHandler(cardInteractor)
}
```

**Transport handlers are thin orchestration**

- Parse gRPC/Connect request, then call subdomain interactor, then serialize response
- No business logic in handlers

**Subdomain packages do not import each other**

- Cross-subdomain dependencies are satisfied via consumer-defined interfaces (see below)
- The transport package or `cmd/<binary>/main.go` is the only place that imports multiple subdomain packages

**Domain packages must not depend on transport**

- `internal/<domain>/interactor.go` must not import `net/http` or gRPC packages
- The transport package adapts domain types to HTTP/gRPC

**Keep package names short and meaningful**

```go
// GOOD — feature names
import "myapp/internal/card"
import "myapp/internal/offers"

// AVOID — layer names and generic names
import "myapp/internal/service"
import "myapp/internal/utils"
import "myapp/internal/helpers"
```

---

## Consumer-Defined Interfaces

This is Go's key idiom for managing cross-package dependencies. Interfaces are defined by the **consumer**, not the producer. This is the inverse of Java/C# conventions and is how subdomain packages collaborate without importing each other.

**Rule: accept interfaces, return structs** (Dave Cheney).

```go
// BAD: producer defines the interface (Java-style)
// package members
// type Store interface { GetMember(...) }  ← don't do this

// GOOD: consumer defines a narrow interface for what it needs
// package offers (the consumer)
type memberGetter interface {
    GetMember(ctx context.Context, id string) (*members.Member, error)
}

type Interactor struct {
    getMember memberGetter
    // ...
}
```

`cmd/<binary>/main.go` wires the concrete implementation at construction time:

```go
memberInteractor := members.NewInteractor(memberRepo)
offerInteractor := offers.NewInteractor(memberInteractor, offerRepo)
// Go's implicit interface satisfaction: *members.Interactor satisfies offers.memberGetter
// with no shared declaration needed
```

**Never create a shared `interfaces/` or `types/` package.** This recreates Java-style interface coupling: a central package that all subdomains depend on, which grows without bound and prevents independent testability.

**When two packages seem to need each other** (circular dependency risk):

1. Consumer-defined interface: depending package defines the narrow interface it needs
2. Function variable injection: pass a method pointer at construction time instead of importing the package
3. Extract a shared leaf type: only if a type truly must be shared; extract it into a package neither imports from the other

---

## Naming Conventions

**Idiomatic Go naming**:

- **unexported**: `camelCase` - `myVariable`, `privateFunc()`
- **Exported**: `PascalCase` - `MyType`, `PublicFunc()`
- **Acronyms**: Keep consistent - `HTTP`, `ID`, `URL` (all caps when exported)

**Examples**:

```go
// Correct
type UserID string
type HTTPClient struct{}
func NewHTTPClient() *HTTPClient

// Incorrect
type UserId string
type HttpClient struct{}
```

**Package names**:

- Short, lowercase, single-word
- No underscores or mixedCaps

```go
// GOOD
package user
package http
package auth

// AVOID
package user_service
package httpUtils
package authHelper
```

**Variable names**:

Naming: descriptiveness scales with the scope's nesting depth and complexity. Avoid one-
and two-letter names. The standing exceptions are `ok` (map access, channel receive, type
assertion), `err` (local error values), `t *testing.T`, `b *testing.B`, and `f *testing.F`
in tests, and a short integer loop index such as `i` or `j`, declared by a `for` clause or by
`for i := range`. Range values are not exempt: write `for _, user := range users`, never
`for _, u := range users`. Method receivers are not exempt either: write
`func (cache *Cache) Get`, not `func (c *Cache) Get`, and neither are handler parameters:
`writer http.ResponseWriter, request *http.Request`, not `w` and `r`. Use three- to five-letter
names sparingly. The more nested or complex the scope, the more descriptive the name must be.

In a larger scope that means a name like `userRepository` or `configLoader`.

`go-style-preferences.md` is the authority on declaration style and naming; see it for the full rule.

---

## Documentation

- **Every exported symbol has a doc comment,** written as full sentences that begin with the
  symbol's name and end with a period. Describe purpose and behavior; a comment that only
  restates the name is not documentation.
- **Every package under `internal/` and `pkg/` has a `doc.go`** holding the package clause and
  its doc comment and nothing else, so the package description has one fixed home instead of
  riding on whichever file was written first.

```go
// Package ratelimit enforces per-client request budgets over a sliding window.
package ratelimit
```

`revive`, enabled in the house config below, runs its `exported` and `package-comments` rules by
default, which flag a missing or malformed doc comment on an exported symbol or package. Neither
checks that the package comment lives in `doc.go`; that part is on review.

---

## Type Safety

### Type-Safe Enums (Always Use Over Strings)

**NEVER use raw strings for status, state, or enum values**. Use type-safe enums:

```go
// GOOD: Type-safe enum
type Status int

const (
 StatusPending Status = iota
 StatusProcessing
 StatusComplete
 StatusFailed
)

func (s Status) String() string {
 switch s {
 case StatusPending:
  return "pending"
 case StatusProcessing:
  return "processing"
 case StatusComplete:
  return "complete"
 case StatusFailed:
  return "failed"
 default:
  return "unknown"
 }
}

type Order struct {
 ID     string
 Status Status // Compiler-enforced valid values
}
```

```go
// AVOID: Raw strings (no compiler safety)
type Order struct {
 ID     string
 Status string // Any string allowed - error-prone!
}

// Easy to make typos:
order.Status = "procesing" // Typo - no compiler error!
order.Status = "PENDING"   // Case mismatch - no compiler error!
```

**Benefits**:

- Compile-time validation
- Autocomplete in IDEs
- Clear valid values
- Type-safe comparisons

### Encapsulation and Private Fields

Private fields plus a validating constructor and public accessor/mutator methods enforce invariants a constructor-free struct cannot:

```go
// GOOD: Private fields with controlled access
type Payment struct {
 id     string
 amount int
 status Status
}

// NewPayment ensures valid initialization
func NewPayment(id string, amount int) (*Payment, error) {
 if amount <= 0 {
  return nil, errors.New("amount must be positive")
 }
 return &Payment{
  id:     id,
  amount: amount,
  status: StatusPending,
 }, nil
}

// Public getters
func (p *Payment) ID() string { return p.id }
func (p *Payment) Amount() int { return p.amount }
func (p *Payment) Status() Status { return p.status }

// Public method with business logic
func (p *Payment) MarkComplete() error {
 if p.status != StatusProcessing {
  return errors.New("can only complete payments in processing state")
 }
 p.status = StatusComplete
 return nil
}
```

### Rich vs Anemic Domain Models

Anemic model (data container, logic lives in separate "service" functions) vs rich domain model (logic lives on the type) - prefer rich for complex domains with invariants to enforce:

```go
// Anemic - AVOID for complex domains
type Order struct {
 ID     string
 Items  []Item
 Total  int
 Status string
}

func CalculateTotal(order *Order) int { /* ... */ }
func ValidateOrder(order *Order) error { /* ... */ }
```

```go
// Rich - PREFER when appropriate
type Order struct {
 id     string
 items  []Item
 status Status
}

// Business logic lives with the data
func (o *Order) AddItem(item Item) error {
 if o.status != StatusDraft {
  return errors.New("cannot modify submitted order")
 }
 o.items = append(o.items, item)
 return nil
}

func (o *Order) Total() int {
 total := 0
 for _, item := range o.items {
  total += item.Price
 }
 return total
}
```

Use rich models for complex domains with invariants or transition rules (orders, payments, workflows); plain structs are fine for simple CRUD, DTOs, and configuration.

---

## Tools and Linting

### Essential Tools

The `shadow` analyzer catches variable shadowing mechanically, regardless of declaration style. It is the mechanical complement to the house declaration rule, which makes shadowing conspicuous to a reader but does not prevent it.

Project `.golangci.yml` (linter set and settings are the settled house config; this targets golangci-lint v2 - v1 used a top-level `linters-settings` key instead of `linters.settings`, and had no `version` key at all):

```yaml
version: "2"

run:
  timeout: 5m
  modules-download-mode: readonly

formatters:
  enable:
    # goimports covers everything gofmt does (spacing, brace style) and also
    # groups and prunes imports, so gofmt does not need separate enabling.
    - goimports
  settings:
    goimports:
      local-prefixes:
        - example.com/project

linters:
  # Explicit opt-in — nothing runs unless listed here.
  default: none
  enable:
    # Core correctness
    - govet
    - staticcheck
    - errcheck
    - ineffassign
    - unused

    # Error-handling correctness
    - errorlint
    - nilerr
    - nilnesserr
    - nilnil
    - errname
    - errchkjson
    - wrapcheck

    # Bug detection
    - bodyclose
    - durationcheck
    - forcetypeassert
    - makezero
    - asasalint
    - noctx
    - canonicalheader
    - reassign
    - contextcheck
    - fatcontext
    - containedctx

    # Code style and quality
    - revive
    - gocritic
    - gocyclo
    - nestif
    - dupword
    - misspell
    - whitespace
    - unconvert
    - predeclared
    - goconst
    - nakedret
    - goprintffuncname
    - nolintlint
    - tagliatelle
    - recvcheck
    - inamedparam

    # Marshaling
    - musttag

    # Testing
    - thelper
    - usetesting

    # Performance and modern Go
    - modernize
    - intrange
    - copyloopvar
    - prealloc
    - perfsprint
    - mirror
    - exptostd

    # Logging and output discipline
    - forbidigo

    # Security
    - gosec
    - bidichk
    - depguard

    # Additional quality checks
    - usestdlibvars
    - unparam
    - nosprintfhostport
    - gocheckcompilerdirectives
    - exhaustive
    - interfacebloat
    - nonamedreturns
    - ireturn
    - gochecknoinits

  settings:
    nonamedreturns:
      # The default exempts a named error assigned in a deferred function,
      # which is the one case the house returns rule exists to remove.
      report-error-in-defer: true
    govet:
      enable:
        - shadow

    gocyclo:
      min-complexity: 15

    errcheck:
      check-type-assertions: false
      check-blank: true
      disable-default-exclusions: false

    depguard:
      rules:
        # Everything except the one scoped exception below.
        main:
          files:
            - "!**/internal/logging/**"
          list-mode: strict
          allow:
            - example.com/project
            - go.uber.org/zap
            - $gostd
          deny:
            - pkg: "math/rand$"
              desc: Use math/rand/v2
            - pkg: "log$"
              desc: Use go.uber.org/zap. Where a third-party API demands a *log.Logger, adapt with zap.NewStdLog.
            - pkg: "log/slog$"
              desc: Application code logs via zap. log/slog belongs only in internal/logging, which bridges library slog records into zap.
            - pkg: "github.com/sirupsen/logrus"
              desc: Use go.uber.org/zap instead of a second logging library.
            - pkg: "github.com/pkg/errors"
              desc: Should be replaced by standard lib errors package

        # The slog-to-zap bridge. Scoped to one package so log/slog appears in
        # exactly one place, keeping the rest of the codebase on zap.
        logging-bridge:
          files:
            - "**/internal/logging/**"
          list-mode: strict
          allow:
            - example.com/project
            - go.uber.org/zap
            - $gostd
          deny:
            - pkg: "math/rand$"
              desc: Use math/rand/v2
            - pkg: "github.com/sirupsen/logrus"
              desc: Use go.uber.org/zap instead of a second logging library.
            - pkg: "github.com/pkg/errors"
              desc: Should be replaced by standard lib errors package
```

The two `depguard` rules together demonstrate one thing: how a project-wide policy gets enforced with a scoped exception. The `main` rule denies `log$`, `log/slog$`, and `github.com/sirupsen/logrus` in application packages - the mechanical enforcement of the logging position stated in `go-style-preferences.md`. The `logging-bridge` rule scopes an exception for the one package that bridges `slog` into zap. Look at what its deny list actually is: a full copy of the `main` list minus the two logging entries being exempted, because `depguard` has no rule inheritance - a scoped rule cannot say "everything `main` denies, except X." The consequence is real maintenance work: a new deny added to `main` must be copied into every scoped rule too, or that package silently gains an exemption nobody intended.

The bridge is not the only package that must import `log/slog`. A package holding a secret-bearing type that implements `slog.LogValuer` (the redaction rule in `go-style-preferences.md`) imports it too, and `main` as written would reject that import. Give such a package its own scoped rule of the same shape, and add its path to the `files` exclusions on `main`, so each exemption stays as narrow as the bridge's.
