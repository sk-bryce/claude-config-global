---
created: 2026-09-19
updated: 2026-09-19
---

> Code examples in this file follow upstream Go idiom, including `:=` for local
> declarations, so they match the sources they came from and the Go you will meet in the
> wild. They are not house style. House declaration and naming style lives in
> `go-style-preferences.md` and governs new code you write.
# Go Gotchas

Traps in Go that have cost real debugging time. These are things to recognize when you hit
them, not rules to follow while writing code, which is why they live apart from the style
guide. Each entry states the symptom first, so you can scan for what you just hit, then the
mechanism that causes it.

## Variable shadowing

**Symptom:** A value set inside an `if` block (or any nested block) does not show up in the
enclosing function, even though the code looks like it should have updated the same variable.

**Mechanism:** `:=` always declares a new variable in the current block's scope. If a variable
of the same name already exists in an outer scope, `:=` inside the inner block does not
assign to it; it creates a second, independent variable that shadows the outer one for the
rest of that block, then disappears when the block ends. The outer variable is left
untouched.

This example is shown with its original `:=` declarations, not converted to `var`, because
the shorthand form is exactly what hides the bug: a `var x int` would have made the second
declaration visually obvious, while `:=` lets a same-named variable slip in unnoticed.

```go
func qux(i int, b bool) int {
	x := 42
	if b {
		x, ok := thing(i)
		if !ok {
			panic("Oops.")
		}
		println("x is", x)
	}
	return x
}
```

If `b` is true, this prints `x is 99` (or whatever `thing(i)` returns), but the function
still returns `42`. Line 4's `x, ok := thing(i)` created a brand-new `x` scoped to the `if b {
...}` block, shadowing the outer `x` declared on line 2. The `return x` on the last line sees
only the outer `x`, which was never reassigned.

## Slice aliasing

**Symptom:** Two slices that appear to be independent copies turn out to share data, so
writing through one changes the other, until an `append` somewhere quietly breaks that link
and the same code stops working.

**Mechanism:** A slice is not the data itself. It is a small header of three fields: a
pointer to a backing array, a length, and a capacity. Assigning one slice to another, or
slicing an existing slice, copies the header, not the array, so both slices point at the same
backing array and mutating an element through one is visible through the other. That holds
only while both slices stay within the original capacity. An `append` that would grow a slice
past its capacity forces the runtime to allocate a new, larger backing array and copy the
elements into it, and the appended-to slice's header now points at that new array. From that
point on the two slices are independent: changes to one no longer affect the other, with no
signal at the call site that the relationship changed.

```go
package main

import "fmt"

func main() {
	var backing = []int{1, 2, 3, 4, 5}
	var x = backing[:3]
	var y = x

	y[0] = 99
	fmt.Println(x[0]) // 99: x and y still share the same backing array

	y = append(y, 100) // len 3 -> 4, still within cap 5, no reallocation
	y[0] = 7
	fmt.Println(x[0]) // 7: still shared, the append above did not sever it

	y = append(y, 200, 300) // len 4 -> 6 exceeds cap 5, forces reallocation
	y[0] = 1000
	fmt.Println(x[0]) // still 7: x and y are now independent
}
```

This is treated as an intentional tradeoff in Go's design, not an oversight: the language
gives up automatic copy semantics for slices in exchange for speed, on the assumption that
developers will learn where the seam is. It is still easy to get bitten by it.

## Footguns

### Performance and logic footguns

- **A slice that grows in a hot loop is slower than expected, with no obvious cause.**
  Appending to a slice without pre-allocating its capacity forces the runtime to reallocate
  and copy the backing array repeatedly as the slice grows past each successive capacity. If
  the final size is known or can be estimated, allocate for it up front with `make([]T, 0,
  capacity)` instead of leaving it to `append`'s default growth.

- **Debug-level log calls cost real CPU and allocations even when nothing is logged.**
  An argument to a logging call is evaluated before the logging function decides whether the
  configured level will actually emit anything. An expensive argument, such as a formatted
  string or a computed summary, pays its full cost on every call regardless of whether the
  message is ever shown. Check the log level before doing the expensive work, or use an API
  that defers evaluation until the level check passes.

- **A `nil` check on an interface passes even though the underlying value is `nil`.**
  Assigning a `nil` pointer of a concrete type to an interface variable gives that interface a
  non-`nil` value, because an interface value carries both a type and a value, and here the
  type is set (`*T`) even though the value inside it is `nil`. Comparing the interface to
  `nil` compares the whole two-part value, which is not equal to a bare `nil` even though the
  pointer inside it is.

- **A computed number is off by a small but consistent amount after using an untyped
  constant.** Go's untyped constants convert implicitly to fit the context they are used in,
  and that conversion can silently lose precision, for example when a constant meant to be a
  float is used somewhere that forces integer division. There is no runtime error to flag it;
  the value is just wrong.

- **A failure happens downstream with no error ever surfacing near its actual cause.** Go
  lets a function's returned error be discarded silently, with no explicit `_ =` required to
  do it. A call whose error return is never checked can fail without any visible signal at
  that call site, and the resulting bad state only surfaces later, far from where it started.
  Linters that flag unchecked errors exist specifically because the language does not enforce
  this itself.

### Security footguns

- **The same struct produces different JSON depending on whether it is encoded by value or
  by pointer.** A `MarshalJSON` method declared on a pointer receiver is not called for a
  non-addressable value of that type, for example a struct value stored in a map or held
  through an interface, so the same type can marshal differently depending on how it is held.
  This is long-standing behavior in `encoding/json`, and no Go release has changed it; a
  change has been proposed but not merged. It remains open as of Go 1.26. Code that has to
  work regardless of how a value is held should not assume marshaling is receiver-agnostic.

- **The same payload is accepted by one parser and rejected, or read differently, by
  another.** Parser behavior is not uniform, even within one package, and mixing entry points
  or parsers over the same bytes creates room for an attacker to craft one payload that gets
  interpreted differently by each component, a data format confusion attack. Verified against
  the Go 1.26.4 toolchain: `json.Unmarshal` rejects trailing data after a valid document (it
  returns `invalid character 'G' after top-level value` for `{"a":1} GARBAGE`), but
  `json.NewDecoder(...).Decode(...)` accepts that same input silently, with a nil error, so
  the two JSON entry points disagree with each other. `json.Unmarshal` accepts duplicate keys
  and keeps the last one (`{"a":1,"a":2}` decodes to 2 with a nil error). `xml.Unmarshal` and
  `xml.Decoder.Decode` both accept trailing data after a valid document, silently. Go has no
  standard-library YAML parser; YAML support always comes from a third-party module, and its
  behavior on duplicate keys and trailing data depends on which module and which strictness
  mode is in use, so it cannot be assumed either way.

- **A request with a small body causes a huge, uncontrolled memory allocation.** Sizing a
  buffer or allocation directly from a user-controlled input value, such as a length field in
  a request, without validating it first lets an attacker request an allocation far larger
  than the system can handle, a straightforward denial-of-service vector. Validate or cap the
  size before allocating, never after.
