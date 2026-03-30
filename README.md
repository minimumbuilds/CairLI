# CairLI

CLI argument parsing framework for AIRL. Builder-pattern API for flags, positional arguments, subcommands, and automatic help text generation.

## Quick Start

Requires the [AIRL](../AIRL) g3 compiler.

```bash
G3=../AIRL/g3

# Compile your CLI app
$G3 -- src/cairli.airl your-app.airl -o your-app
./your-app --help
```

### Example

```scheme
;; greeter.airl
(let (app : _ (cairli-app (map-from ["name" "greeter" "version" "1.0" "description" "A greeting tool"])))
  (let (app : _ (cairli-add-flag app (map-from ["name" "loud" "short" "l" "type" "bool" "default" "false" "help" "Shout the greeting"])))
    (let (app : _ (cairli-add-positional app (map-from ["name" "name" "help" "Who to greet" "required" "true"])))
      (let (ctx : _ (cairli-run-or-die app (get-args)))
        (let (name : String (cairli-positional ctx "name"))
          (print (str "Hello, " name "!\n")))))))
```

## API

### Builders
- `(cairli-app config-map)` -- create app (requires `"name"` key)
- `(cairli-add-flag app flag-map)` -- add flag (`"name"`, `"short"`, `"type"`, `"default"`, `"help"`, `"required"`)
- `(cairli-add-positional app pos-map)` -- add positional (`"name"`, `"help"`, `"required"`, `"type"`)
- `(cairli-add-subcommand app config-map)` -- register subcommand
- `(cairli-subcommand-flag app subcmd flag-map)` -- add flag to subcommand
- `(cairli-add-nested-subcommand app parent config-map)` -- nested subcommand

### Running
- `(cairli-run app (get-args))` -- parse args, returns `(Ok ctx)` or `(Err msg)`
- `(cairli-run-or-die app (get-args))` -- parse or print error and exit

### Accessors
- `(cairli-flag ctx "name")` -- get flag value
- `(cairli-positional ctx "name")` -- get positional value
- `(cairli-subcommand ctx)` -- get matched subcommand path (e.g. `"topic create"`)

## Running Tests

```bash
bash test.sh
```

Runs 7 test suites covering builders, parsing, subcommands, nested subcommands, and help text generation.

## File Structure

```
src/cairli.airl                        The library (707 lines)
tests/test-builders.airl               Builder unit tests
tests/test-parsing.airl                Parsing integration tests
tests/test-comprehensive.airl          Edge cases (40+ tests)
tests/test-subcommands.airl            Subcommand tests
tests/test-subcommands-comprehensive.airl  Complex subcommand scenarios
tests/test-nested-subcommands.airl     Nested subcommand tests
tests/test-subcommand-help.airl        Help text formatting
examples/greeter.airl                  Example CLI tool
```

## Part of the AIRL Ecosystem

CairLI is written entirely in AIRL and compiled to native binaries via g3.
