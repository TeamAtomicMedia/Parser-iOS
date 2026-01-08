# Swift Parser

A lightweight, composable parser combinator library for Swift.
- Zero-copy style input handling using inout Substring
- Clear error reporting via ParseError with contextual wrapping
- Functional combinators (map, <|>, >>=, *> , <*) for expressive composition
- Useful modifiers (atomic, optional, sequence, complete, context, ...)
- Fully Sendable-friendly API for concurrency
- Swift Testing-based test suite

## Installation
Use Swift Package Manager.
1) In Xcode: File > Add Package Dependencies… and enter the repository URL.
2) Or in Package.swift:
- .package(url: "https://github.com/TeamAtomicMedia/Parser-iOS.git", from: "1.0.0")
- .product(name: "Parser", package: "Parser")

## API Overview

### Core Parsers
#### `.result(_:)`  
Always succeeds with a given value without consuming input.

```swift
let p = Parser.result(42)
var input: Substring = "abc"
let value = try p.run(&input) // 42
// input remains "abc"
```

---

#### `.error(.expectedNumber)`
Always fails with a given error without consuming input.

```swift
var input: Substring = "abc"
let parser: Parser<String> = .error(.expectedNumber)
try parser.run(&input) // Throws .expectedNumber
```

---

### Tokens & Characters

#### `.token(_:)`
Consume a `Character` or `String` if they exist at the start of input.
Throws `.expectedToken(.one(_:))` if parse fails.

```swift
var input: Substring = "abcd"
let parser1: Parser = .token("a")
let parser2: Parser = .token("bc")
try parser1.run(&input) // "a"
try parser2.run(&input) // "bc"
// Final input is "d"
```

---

#### `character(_:)` *(deprecated)*
Deprecated in favor of `token(_:)`.

```swift
Parser.character("a") // use Parser.token("a")
```

---

#### `character(where:)`
Consumes a single character matching a predicate.

```swift
let digit = Parser.character { $0.isNumber }
```

Throws `expectedCharactersSatisfyingPredicate` on failure.

---

### Repetition & Predicates

#### `predicate(allowEmpty:where:)`
Consumes characters while a predicate holds.

```swift
let letters = Parser.predicate { $0.isLetter }
```

- Throws if empty and `allowEmpty == false`
- Returns a `String`

---

#### `until(terminator:allowEmpty:allowEOF:consumeTerminator:)`
Consumes input until a terminating parser succeeds.

```swift
let body = Parser.until(terminator: .token(";"))
```

Options:
- `allowEmpty`: allow zero-length result
- `allowEOF`: succeed if EOF is reached before terminator
- `consumeTerminator`: consume or preserve terminator

---

### Whitespace & Layout

#### `whitespace()`
Consumes one or more whitespace characters.

```swift
Parser.whitespace()
```

Throws `.expectedWhitespace` if empty and `allowEmpty == false`

---

#### `space()`
Consumes non-newline whitespace only.

```swift
Parser.space()
```

Throws `.expectedCharactersSatisfyingPredicate` on failure.

---

#### `newline()`
Consumes optional leading spaces followed by a newline.

```swift
Parser.newline()
```

Returns consumed spaces + newline as `String`.

---

### Numbers

#### `number()`
Parses a signed integer.

```swift
var input: Substring = "-42abc"
let value = try Parser.number().run(&input) // -42
// input == "abc"
```

Throws `expectedNumber` on failure.

---

### Enums & Raw Values

#### `rawRepr(_:)`
Parses a specific `RawRepresentable` case by its `rawValue`.

```swift
enum Keyword: String {
    case if, else
}

Parser.rawRepr(Keyword.if)
```

---

#### `enumeration()`
Parses any `CaseIterable & RawRepresentable<String>` enum case.

```swift
enum Op: String, CaseIterable {
    case add = "+"
    case sub = "-"
}

let p = Parser<Op>.enumeration()
```

- Tries all cases
- Preserves first error via `firstError()`

---

### Utility

#### `empty()`
Succeeds without consuming input and returns an empty string.

```swift
Parser.empty() // Parser<String>
```

---

### Design Notes
- Parsers throw `ParseError`
- Non-atomic parsers may partially consume input
- All parsers operate on `inout Substring`
- Composition is expected via combinators (`map`, `>>=`, `<|>`, etc.) and modifiers (`.atomic`, `.optional`, `.sequence`, etc.)

---

## Parser Combinators – Functional Operators

### Functor 

#### `map(_:)`

Transforms the output value of a parser without affecting how input is consumed.

- Runs the parser
- Applies transform to the successful result
- Does not affect input consumption semantics
- Errors thrown by transform propagate

```swift
let int = Parser.number()
let stringified = int.map { String($0) }
```

This corresponds to fmap in functional programming.

---

### Alternative 

#### `<|>` (choice)

Attempts the left-hand parser. If it fails, attempts the right-hand parser instead.

Semantics:
- If lhs succeeds, its result is returned
- If lhs fails, rhs is attempted
- If both fail, a combined ParseError.eitherError is thrown
- The operator is atomic: input is restored if the entire alternative fails

```swift
let yes = Parser.token("yes")
let no  = Parser.token("no")
let yesOrNo = yes <|> no
```

---

### Monad 

#### `>>=` (bind) or `bind(to:)`

Sequences parsers where the second parser depends on the value produced by the first.

Semantics:
- Run lhs
- Feed its result into rhs to build the next parser
- Run the resulting parser on the remaining input
- Atomic across the full sequence

```swift
let lengthPrefixedString = Parser.number() >>= { length in
    Parser.character(where: { _ in true })
        .repeat(count: length)
        .map { String($0) }
}
```

This corresponds to flatMap / monadic bind.

---

### Sequencing Operators 

#### `*>` (bind left, discard left)

Runs two parsers sequentially and returns the result of the right-hand parser.

Semantics:
- lhs must succeed
- rhs must succeed
- Result of rhs is returned
- Atomic across both parsers

```swift
let quotedString = Parser.token("\"") *> Parser.until(terminator: .token("\""))
```

---

#### `<*` (bind right, discard right)

Runs two parsers sequentially and returns the result of the left-hand parser.

Semantics:
- lhs must succeed
- rhs must succeed
- Result of lhs is returned
- Atomic across both parsers

Example:

```swift
let identifier = Parser.predicate { $0.isLetter }
    <* Parser.optionalWhitespace()
```

---

### Design Notes
- All operators preserve Parser composability
- atomic() is used to ensure predictable backtracking
- Operators mirror well-known abstractions from Haskell and Swift Result / Optional
- Explicit operators keep grammars declarative and compact

# Parser Combinators – Modifiers

## Atomicity

### `atomic()`

Makes a parser *all-or-nothing*.
Used to prevent partial consumption in compound parsers.

Semantics:
- Saves the original input state
- If parsing succeeds, input remains consumed
- If parsing fails, input is fully restored

```swift
let keyword = (Parser.token("if") *> Parser.whitespace()).atomic()
```

---

## Optionality

### `optional()`

Transforms a parser into an optional parser.

Semantics:
- On success: returns `T`
- On failure: restores input and returns `nil`
- Never throws

```swift
let sign = Parser.token("-").optional()
```

---

### `optional(defaultValue:)`

Provides a default value when parsing fails.

Semantics:
- On success: returns parsed value
- On failure: restores input and returns `defaultValue`

```swift
let signed = Parser.token("-").optional(defaultValue: "+")
```

---

## Discarding Output

### `discard()`

Consumes input but discards the parser’s output.
Useful for structural tokens.

```swift
let openBrace = Parser.token("{").discard()
```

---

## Repetition

### `sequence(separator:allowEmpty:allowTrailingSeparator:)`

Parses a list of elements separated by a configurable separator.

Semantics:
- Greedily parses elements
- Separator must succeed between elements
- Parsing stops when separator or element fails

Options:
- `allowEmpty`: allow zero elements
- `allowTrailingSeparator`: allow a final separator with no element

```swift
let numbers = Parser.number().sequence()
```

---

### `many(allowEmpty:)`

Parses zero or more occurrences of a parser **without a separator**.

Semantics:
- Repeatedly runs the parser until failure
- Failure terminates the loop
- Throws only if no elements were parsed and `allowEmpty == false`

```swift
let digits = Parser.character { $0.isNumber }.many()
```

---

## Error Handling

### `context(_:)`

Adds contextual information to errors.

Semantics:
- Wraps thrown `ParseError` in `.contextualError`
- Non-`ParseError` errors are rethrown unchanged

```swift
let header = Parser.token("HEAD").context("HTTP header")
```

---

### `firstError()`

Extracts the *first* error from an `.eitherError`.

Used to control error reporting when using `<|>`.

---

### `secondError()`

Extracts the *second* error from an `.eitherError`.

Used to control error reporting when using `<|>`.

---

## Completion

### `complete()`

Requires the parser to consume **all input**.

Semantics:
- Runs the parser
- If trailing input remains, throws `.incompleteParse`

```swift
let document = grammar.complete()
```

---

## Design Notes

- Modifiers return new parsers; original parsers are unchanged
- Most modifiers preserve input correctness via restoration
- Error-shaping modifiers enable precise, user-facing diagnostics
- Designed to keep grammars declarative and readable
