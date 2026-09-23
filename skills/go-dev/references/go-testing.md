---
created: 2026-08-05
updated: 2026-09-23
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild. They are not house style. House declaration and naming style lives in
> `go-style-preferences.md` and governs new code you write.
# Go Testing Patterns

**When to read**: Writing tests, table-driven tests, mocks, test organization

---

## Test Organization

**File naming**: `<package>_test.go`

```go
// user_service_test.go
package service_test // Use package_test for black-box tests

import (
 "testing"
 "myapp/internal/service"
)

func TestUserService_CreateUser(t *testing.T) {
 // test implementation
}
```

---

## Table-Driven Tests

**Modern pattern for testing multiple scenarios**:

```go
func TestValidateEmail(t *testing.T) {
 tests := []struct {
  name    string
  email   string
  want    bool
  wantErr error
 }{
  {
   name:    "valid email",
   email:   "user@example.com",
   want:    true,
   wantErr: nil,
  },
  {
   name:    "missing @",
   email:   "userexample.com",
   want:    false,
   wantErr: ErrInvalidEmail,
  },
  {
   name:    "empty string",
   email:   "",
   want:    false,
   wantErr: ErrInvalidEmail,
  },
  {
   name:    "just @",
   email:   "@",
   want:    false,
   wantErr: ErrInvalidEmail,
  },
 }

 for _, tt := range tests {
  t.Run(tt.name, func(t *testing.T) {
   t.Parallel() // Run tests in parallel

   got, err := ValidateEmail(tt.email)

   if !errors.Is(err, tt.wantErr) {
    t.Errorf("ValidateEmail(%q) error = %v, wantErr %v", tt.email, err, tt.wantErr)
   }

   if got != tt.want {
    t.Errorf("ValidateEmail(%q) = %v, want %v", tt.email, got, tt.want)
   }
  })
 }
}
```

Under Go 1.22 and later, each iteration of a `range` loop gets its own copy of the loop
variable, so the old capture-the-range-variable line before `t.Run` is no longer needed. It is
only needed for a module whose `go.mod` still declares `go 1.21` or earlier.

### The same test in house style

The example above is upstream idiom, kept so it matches the sources it came from. The version
below is the same test written in this codebase's house style; this is the shape to follow
when writing new test code.

```go
type validateEmailCase struct {
 name    string
 email   string
 want    bool
 wantErr error
}

func TestValidateEmail(t *testing.T) {
 var testCases = []validateEmailCase{
  {
   name:    "valid email",
   email:   "user@example.com",
   want:    true,
   wantErr: nil,
  },
  {
   name:    "missing @",
   email:   "userexample.com",
   want:    false,
   wantErr: ErrInvalidEmail,
  },
  {
   name:    "empty string",
   email:   "",
   want:    false,
   wantErr: ErrInvalidEmail,
  },
  {
   name:    "just @",
   email:   "@",
   want:    false,
   wantErr: ErrInvalidEmail,
  },
 }

 for _, testCase := range testCases {
  t.Run(testCase.name, func(t *testing.T) {
   t.Parallel()

   var got, err = ValidateEmail(testCase.email)

   if !errors.Is(err, testCase.wantErr) {
    t.Errorf("ValidateEmail(%q) error = %v, wantErr %v", testCase.email, err, testCase.wantErr)
   }

   if got != testCase.want {
    t.Errorf("ValidateEmail(%q) = %v, want %v", testCase.email, got, testCase.want)
   }
  })
 }
}
```

The house declaration and naming rules above govern new code you write in this codebase. The
reference examples elsewhere in this file stay in upstream form on purpose, so they match their
sources; when the two disagree, follow `go-style-preferences.md` for your own code.

---

## Test Naming Conventions

Scenario naming: `Test<FunctionName>_<Scenario>`.

```go
func TestUserService_CreateUser(t *testing.T)
func TestUserService_CreateUser_DuplicateEmail(t *testing.T)
func TestUserService_GetUser_NotFound(t *testing.T)
```
