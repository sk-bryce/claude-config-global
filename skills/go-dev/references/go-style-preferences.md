---
created: 2026-09-19
updated: 2026-09-23
---

# Go Style Preferences (Override)

This file carries one person's deliberate divergences from mainstream Go style guides
(Uber's, Google's). It is not derived from any public style guide; it is a personal
projection, and where this file and any other file under `references/` disagree, this
file wins.

## Declaration style

```
Declaration style: prefer explicit `var` declarations. Use `:=` ONLY as part of an
initializer expression in `if`, `for`, `switch`, or a `select` case, where the declared
variable's scope is visibly limited to that statement. Everywhere else, use `var`. Do not
use grouped `var (...)` blocks; write one `var` per line.
```

The rationale, condensed: a line that starts with `var` is grep-able by that leading
token, whereas `:=` gives grep nothing to anchor on and can vary line to line. A
line-leading `var` is also recognizable as a declaration at a glance, without reading the
rest of the line. And `var` is the only option that works everywhere, including package
scope, where `:=` is illegal - preferring it wherever possible buys consistency across the
whole codebase rather than only inside function bodies.

### The shadowing claim, stated precisely

Using `var` does not prevent shadowing. It makes shadowing easier to notice, because the
declaration is conspicuous, not because `var` declarations are somehow immune to
redeclaring a name in an inner scope. Do not overclaim this: an overclaim in a house-style
document undermines the rules that are actually correct.

The two examples below are the strongest argument for the rule and are carried over in
full, including their Playground links, because they show the failure mode concretely
rather than asserting it.

#### Go Playground - Example 1

<https://go.dev/play/p/b0Hs1_ATSJK>

```go
package main

import (
	"fmt"
	"log"
)

type Closable struct {
	//
}

func NewClosable() (*Closable, error) {
	return &Closable{}, fmt.Errorf("THIS IS NOT THE ERROR YOU SHOULD SEE")
}

func (c *Closable) Close() error {
	return fmt.Errorf("THIS IS THE INTENDED ERROR")
}

func exampleFunc() error {
	var thing, err = NewClosable()

	defer func() {
		err := thing.Close()
		if err != nil {
			err = fmt.Errorf("close error: %w", err)
		}
	}()

	// ... do other stuff here

	return err
}

func main() {
	if err := exampleFunc(); err != nil {
		log.Printf("ERROR: %v", err)
	}
}
```

The intent is for the deferred closure to update the error the outer function returns with
the wrapped result of `Close()`. It does not: `err := thing.Close()` inside the closure
declares a new, closure-scoped `err` that shadows the outer one, so the closure's
assignment never reaches the `err` that `exampleFunc` returns. Running it prints:

```
2009/11/10 23:00:00 ERROR: THIS IS NOT THE ERROR YOU SHOULD SEE
```

Note what actually fixes this: not swapping `var thing, err = NewClosable()` for something
else, but changing the closure's `err := thing.Close()` to a plain assignment,
`err = thing.Close()`, so it reuses the outer `err` instead of declaring a new one. `var`
would not have prevented the bug here either, had it been spelled `var err = thing.Close()`
inside the closure - that still declares a new closure-scoped variable. What `var` buys is
that the declaration is conspicuous: `var err = ...` inside a closure reads visibly as "new
variable," where `err := ...` blends in as if it were the expected update.

#### Go Playground - Example 2

<https://go.dev/play/p/T-ddB5rZCsk>

```go
package main

import (
	"fmt"
	"log"
	"strconv"
)

func exampleFunc(numstring string) error {
	var err error

	defer func() {
		number, err := strconv.Atoi(numstring)
		if err != nil {
			err = fmt.Errorf("cannot convert number: %w", err)
		} else {
			log.Printf("converted number: %d", number)
		}
	}()

	// ... some other operation that might need to return an error
	if err = fmt.Errorf("this error should be wrapped by the deferred function"); err != nil {
		return err
	}

	return err
}

func main() {
	if err := exampleFunc("this is not a number"); err != nil {
		log.Printf("ERROR: %v", err)
	}
}
```

```
2009/11/10 23:00:00 ERROR: this error should be wrapped by the deferred function
```

Here too, `number, err := strconv.Atoi(numstring)` inside the closure declares a new `err`
because `number` is new on that line, and `:=` only needs one new name on the left to be
legal. The wrapped error never reaches the outer `err`. Even on careful inspection this is
easy to miss; with `var` in the outer scope, the `:=` inside the closure stands out as
declaring something new rather than updating what is already there. Closures and defers are
common, and this is exactly where this class of bug hides.

### The honest cost

The `x, err := f()` chain is the case this rule does not resolve cleanly. Go's `:=` legally
redeclares `err` as long as at least one variable on the left of `:=` is new, so a run of
calls like

```go
a, err := f()
b, err := g()
c, err := h()
```

has no direct `var` equivalent on a line-by-line basis. Applying the rule here means
hoisting the declarations to the top of the function and reusing `err` by plain assignment
afterward, which is more restructuring than a mechanical find-and-replace. Treat this as
the intended resolution, not a workaround:

```go
var err error
var dataFile *os.File
var row []string

if dataFile, err = os.Open(filePath); err != nil {
	return err
}

var csvReader = csv.NewReader(dataFile)
for {
	// `err` is reused here because it is easy to see the error has already been
	// checked for opening the file, with no danger of losing a value in the
	// enclosing scope.
	if row, err = csvReader.Read(); err != nil {
		return err
	}

	for _, column := range row {
		// do stuff with data...
	}
}
```

Apply the declaration-style rule with judgment: it is a readability and grep-ability
preference, not a rule that has a clean answer for every multi-value error chain.

### Reassigning a parameter from a multi-value call

The same redeclaration rule has a sharper edge when the name being reused is a function
parameter. Parameters share the function body's block, so upstream code can write
`g, ctx := errgroup.WithContext(ctx)`: `g` is new, which licenses the `:=`, and `ctx` is the
parameter, reassigned rather than shadowed. Plain `var` has no redeclaration rule, so the
direct translation does not compile:

```go
func FetchAll(ctx context.Context) error {
	var group, ctx = errgroup.WithContext(ctx) // compile error: ctx redeclared in this block
	group.Go(func() error { return fetchUsers(ctx) })
	return group.Wait()
}
```

Declare only the genuinely new name with `var`, then assign both with `=`:

```go
func FetchAll(ctx context.Context) error {
	var group *errgroup.Group
	group, ctx = errgroup.WithContext(ctx)
	group.Go(func() error { return fetchUsers(ctx) })
	return group.Wait()
}
```

The plain assignment reuses the parameter exactly as the upstream `:=` does, so every closure
below it sees the derived, cancelable context. A new name such as `groupCtx` also compiles, but
it leaves the original `ctx` in scope beside it, and a closure that picks up the wrong one runs
on the parent context and never sees the group's cancellation. Reassigning `ctx` removes that
choice. The same shape applies to any constructor that returns a derived value of a
parameter's own type, such as `context.WithTimeout` or `context.WithCancel`.

### Mechanical enforcement is complementary, and stronger

`var` only makes shadowing conspicuous to a human reader; it does not stop it. `go vet`'s
`shadow` analyzer catches this class of bug regardless of declaration style, and it is not
enabled by the `.golangci.yml` shown in the sibling file `go-style-conventions.md`. Enable
it.

`shadow` is a `go vet` sub-analyzer, configured through `govet`'s settings in
`golangci-lint`, not a linter name in its own right. It does not belong in
`linters.enable`. It is configured like this:

```yaml
linters-settings:
  govet:
    enable:
      - shadow
```

## No grouped declarations

One `var` per line. The rationale is the same grep-ability argument as the declaration-
style rule: a `var (...)` block wraps the declaring keyword around the whole group instead
of prefixing each line, so a search for `var <name>` cannot match a name that only appears
inside the parens. It is also arguably less readable at a glance, since the block's
context-giving `var (` token is separated from each variable it declares.

## Naming

```
Naming: descriptiveness scales with the scope's nesting depth and complexity. Avoid one-
and two-letter names. `ok` (map access, channel receive, type assertion) and `err` (local
error values) are the standing exceptions. Use three- to five-letter names sparingly. The
more nested or complex the scope, the more descriptive the name must be.
```

Non-descriptive names add cognitive overhead when reading or maintaining code, and they
make unintentional shadowing more likely, which is especially costly to debug across
multiple contributors, nested loops, closures, and long functions.

**Avoid:**

```go
func fn(c context.Context, d string, w chan string) error {
	for {
		select {
		case <-c.Done():
			return nil
		case f, ok := <-w:
			if !ok {
				// Channel is closed.
				return nil
			}
			p := filepath.Join(d, f)
			fp, err := os.Open(p)
			if err != nil {
				return err
			}
			r := csv.NewReader(fp)
			for {
				r, err := r.Read()
				if err != nil {
					return err
				}
				for _, l := range r {
					// do stuff with data...
				}
			}
		}
	}
}
```

**Prefer:**

```go
func processFiles(ctx context.Context, dirPath string, fileNames chan string) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case fileName, ok := <-fileNames:
			if !ok {
				// Channel is closed.
				return nil
			}
			var filePath = filepath.Join(dirPath, fileName)
			var dataFile, err = os.Open(filePath)
			if err != nil {
				return err
			}
			var csvReader = csv.NewReader(dataFile)
			for {
				var row, errRead = csvReader.Read()
				if errRead != nil {
					return errRead
				}
				for _, column := range row {
					// do stuff with data...
				}
			}
		}
	}
}
```

**Situational** - encapsulation as a shadowing-prevention strategy: further encapsulation
is not always the right answer, but doing at least a little often reduces scope complexity.

```go
func processFileNames(ctx context.Context, dirPath string, fileNames chan string) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case fileName, ok := <-fileNames:
			if !ok {
				// Channel is closed.
				return nil
			}
			var filePath = filepath.Join(dirPath, fileName)
			if err := processFile(filePath); err != nil {
				return err
			}
		}
	}
}

func processFile(filePath string) error {
	// Defining key names at the top of a function can also help with refactoring
	// and with understanding code someone hasn't worked with before, by giving
	// type context; for `row`, someone unfamiliar with the `csv` package can see
	// immediately, without consulting documentation, that `.Read()` returns a
	// plain string slice.
	var err error
	var dataFile *os.File
	var row []string

	if dataFile, err = os.Open(filePath); err != nil {
		return err
	}

	var csvReader = csv.NewReader(dataFile)
	for {
		// `err` is reused here because it is easy to see the error has already
		// been checked for opening the file, with no danger of losing a value
		// in the enclosing scope.
		if row, err = csvReader.Read(); err != nil {
			return err
		}

		// `column` could be pre-declared too, but that is overkill here since
		// `row` is visibly just a slice of a primitive (`string`). If the
		// function grows longer, moving the declaration up becomes worth it.
		for _, column := range row {
			// do stuff with data...
		}
	}

	return err
}
```

## Logging: zap as the application logger, slog as the bridge

Application code logs through `go.uber.org/zap`, using its typed field API (`zap.String`,
`zap.Int`, `zap.Error`, and so on), with the logger injected as a dependency rather than
reached for as a package global. Not `logrus`, not the standard `log` package, and not
`log/slog` as the application's logger.

This is a preference with a cost, stated below, not an absolute rule.

`log/slog` keeps exactly two jobs under this preference:

1. **The bridge.** One package, and only one, imports `log/slog` and installs a handler
   backed by the zap core, so a dependency that logs through `slog` lands in the same sink
   as everything else:

   ```go
   // NewSlogHandler returns a slog.Handler that writes records into the
   // core of the supplied zap logger, so dependency logs reach the same sink.
   func NewSlogHandler(logger *zap.Logger) slog.Handler {
   	return zapslog.NewHandler(logger.Core())
   }

   func InstallSlogDefault(logger *zap.Logger) {
   	slog.SetDefault(slog.New(NewSlogHandler(logger)))
   }
   ```

   `zapslog` is `go.uber.org/zap/exp/zapslog`, which lives in the `go.uber.org/zap/exp`
   module - a separate module from `go.uber.org/zap` proper that must be required in its
   own right - and it is marked experimental, so its API can change.

2. **Secret redaction.** A secret-bearing type implements `slog.LogValuer`, so a value
   handed to a dependency that logs through `slog` is redacted before the bridge passes the
   record to zap. This must be `slog.LogValuer` specifically, not `fmt.Stringer`: `slog`
   does not consult `fmt.Stringer` for a string-kinded value, so a `String()` method alone
   does not redact anything flowing through `slog`.

### Mechanical enforcement

Enforce the boundary with `depguard` rather than prose discipline: deny `log$`,
`log/slog$`, and `github.com/sirupsen/logrus` in application packages, with a scoped
exception for the bridge package and for any package that needs `slog.LogValuer` for
redaction.

The trap: `depguard` has no rule inheritance, so a per-package exception list is a full
copy of the main deny list minus the one entry being exempted. A deny added to the main
list later has to be copied into every scoped list too, or the package holding the old copy
silently gains an exemption that was never intended.

### The escape hatch

This is a preference with a cost, not a law of Go. It is a two-dependency, two-module
answer to something `log/slog` alone does in the standard library with zero dependencies.
For a small tool, for a library that should not impose a logging dependency on its
consumers, or for a codebase that has already standardized on `slog`, plain `slog` is the
right default and this whole stance does not apply. Where a project's own `CLAUDE.md`,
`AGENTS.md`, or linter config states a different logging decision, that project's decision
governs, and this file yields to it.
