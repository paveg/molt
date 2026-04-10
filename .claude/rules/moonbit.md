# MoonBit Conventions

## Syntax

- String interpolation: `"\{variable}"` (not `\(variable)`)
- Boolean negation: `!expr` (`not(x)` is deprecated as of MoonBit 0.9.x)
- Bitwise: `<<`, `>>`, `.land()`, `.lor()` (not `.lsl()`, `.asr()`)
- Char literals: `'\u0000'` (not `'\x00'`)
- String slicing: `s[start:end].to_string()` (not `s.substring()`)
- `for i, c in string` iterates chars with index
- `guard ... else { ... }` for preconditions

## Types

- `pub(all) struct` makes all fields public. Don't add `pub` to individual fields.
- `pub(all) enum` with `derive(Show, Eq)` is standard.
- Use named parameters with `~` in constructors: `fn new(rate~ : Int) -> T`

## Async

- `async fn` / `async test` for async code
- `@async.with_task_group(async fn(group) { ... })` for structured concurrency
- `group.spawn_bg(async fn() { ... })` for background tasks
- `@async.sleep(ms : Int)` — milliseconds only

## Testing

- `inspect(value, content="expected")` is the standard assertion
- `try { Ok(f()) } catch { e => Err(e) }` to test raise functions
- Run: `moon test --target native` for full suite

## Packages

- `moon.pkg` uses DSL syntax: `import { "pkg/path" }` and `options(...)`
- `"supported-targets": "native"` for native-only packages
- Import alias not supported (`as "alias"` doesn't work)
