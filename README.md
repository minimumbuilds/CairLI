# CairLI — v0.2.0

CLI argument parsing framework for AIRL. Builder-pattern API for flags, positional arguments, subcommands, and automatic help text generation.

## What It Does

CairLI provides everything needed to build well-behaved CLI tools in AIRL:

- **Flags** — boolean, string, and integer flags with short aliases, defaults, and required enforcement
- **Positionals** — typed positional arguments with required/optional control
- **Subcommands** — nested subcommand trees with per-subcommand flags and positionals
- **Help text** — automatic `--help` output generation from the app definition
- **Parse results** — typed accessors for flags, positionals, and matched subcommand path

## Build

Requires the g3 compiler from `$AIRL_DIR`.

```bash
G3=$AIRL_DIR/g3

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

| Function | Description |
|----------|-------------|
| `(cairli-app config-map)` | Create app; requires `"name"` key |
| `(cairli-add-flag app flag-map)` | Add flag — keys: `"name"`, `"short"`, `"type"`, `"default"`, `"help"`, `"required"` |
| `(cairli-add-positional app pos-map)` | Add positional — keys: `"name"`, `"help"`, `"required"`, `"type"` |
| `(cairli-add-subcommand app config-map)` | Register subcommand |
| `(cairli-subcommand-flag app subcmd flag-map)` | Add flag to a specific subcommand |
| `(cairli-subcommand-positional app subcmd-name pos-config)` | Add positional to a specific subcommand |
| `(cairli-add-nested-subcommand app parent config-map)` | Register a nested subcommand under a parent |

### Running

| Function | Description |
|----------|-------------|
| `(cairli-run app (get-args))` | Parse args; returns `(Ok ctx)` or `(Err msg)` |
| `(cairli-run-or-die app (get-args))` | Parse or print error and exit |

### Accessors

| Function | Description |
|----------|-------------|
| `(cairli-flag ctx "name")` | Get flag value |
| `(cairli-positional ctx "name")` | Get positional value |
| `(cairli-subcommand ctx)` | Get matched subcommand path (e.g. `"topic create"`) |

## Running Tests

```bash
bash test.sh
```

Runs 7 test suites covering builders, parsing, subcommands, nested subcommands, and help text generation.

## File Structure

```
src/cairli.airl                            The library
tests/test-builders.airl                   Builder unit tests
tests/test-parsing.airl                    Parsing integration tests
tests/test-comprehensive.airl              Edge cases (40+ tests)
tests/test-subcommands.airl                Subcommand tests
tests/test-subcommands-comprehensive.airl  Complex subcommand scenarios
tests/test-nested-subcommands.airl         Nested subcommand tests
tests/test-subcommand-help.airl            Help text formatting
examples/greeter.airl                      Example CLI tool
```

## Ecosystem Position

CairLI is used by AIRL CLI tools that need structured argument parsing. It is written entirely in AIRL and compiled to native binaries via g3. Other ecosystem CLIs (e.g., `airl_kafka_cli`, `airshell`) depend on CairLI for their argument layer.
