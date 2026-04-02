# CairLI — Project Instructions

## Overview

CairLI is a CLI argument parsing framework written in pure AIRL. Builder pattern API for defining flags, positional args, help text, and type parsing.

## Pre-Flight (BLOCKING)

Before writing any `.airl` file, you MUST read `../AIRL/AIRL-Header.md`.

## Build & Test

CairLI is pure AIRL. Use **g3 exclusively** — never cargo, never modify the AIRL repo.

```bash
# Set up
export AIRL_DIR=../AIRL
export AIRL_STDLIB=$AIRL_DIR/stdlib
G3=$AIRL_DIR/g3

# Compile library + your app
$G3 -- src/cairli.airl your-app.airl -o your-app
./your-app [args...]

# Run tests
bash test.sh
```

## g3 Quirks

- **No `assert` with `print`:** g3 compiles `assert` to use 2-arg `print` internally. If you also use single-arg `print`, you get a verifier error. Use a custom `check` function instead.
- **`string-to-int` returns `(Ok n)`:** In g3, `string-to-int` returns a Result, not a bare int. Use `match` to unwrap.
- **`print` not `println`:** Use `(print (str ... "\n"))` for output. Avoid variadic `println` — g3 has arity mismatch issues with variadic builtins used at different arities.
- **Single-arg `print` only:** Always wrap in `(str ...)` to produce a single string argument.

## Structure

```
src/cairli.airl                         # The library (all functions)
tests/test-builders.airl               # Builder unit tests
tests/test-parsing.airl                # Parsing integration tests (13 tests)
tests/test-subcommands.airl            # Subcommand builder and parsing tests
tests/test-nested-subcommands.airl     # Nested subcommand tests
tests/test-subcommand-help.airl        # Subcommand help text tests
examples/greeter.airl                  # Example CLI tool
test.sh                                # Test runner (uses g3)
```

## API

### Builders
- `(cairli-app config-map)` — create app (requires "name" key)
- `(cairli-add-flag app flag-map)` — add flag (keys: "name", "short", "type", "default", "help", "required")
- `(cairli-add-positional app pos-map)` — add positional (keys: "name", "help", "required", "type")

### Running
- `(cairli-run app raw-args)` — parse args, returns `(Ok ctx)` or `(Err msg)`. Pass `(get-args)` for raw-args.
- `(cairli-run-or-die app raw-args)` — parse or print error and exit 1

### Accessors
- `(cairli-flag ctx "name")` — get flag value
- `(cairli-positional ctx "name")` — get positional value

### Subcommands
- `(cairli-add-subcommand app config-map)` — register subcommand (keys: "name", "help")
- `(cairli-subcommand-flag app subcmd-name flag-map)` — add flag to subcommand
- `(cairli-subcommand-positional app subcmd-name pos-map)` — add positional to subcommand
- `(cairli-add-nested-subcommand app parent-name config-map)` — register nested subcommand

### Subcommand Accessors
- `(cairli-subcommand ctx)` — get matched subcommand path string (e.g., "topic create")

## Conventions

- Public API: `cairli-` prefix (single dash)
- Internal functions: `cairli--` prefix (double dash)
- All functions have contracts (`:requires`/`:ensures`)
- No loops/mutation — recursion and fold only
- Use multi-binding `let` (preferred AIRL style)
