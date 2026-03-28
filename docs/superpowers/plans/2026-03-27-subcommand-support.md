# Subcommand Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add subcommand and nested subcommand dispatch to CairLI so tools like `kafka-cli produce --topic foo` work with per-command flags and shared global flags.

**Architecture:** The app map gains a `"subcommands"` key (List of subcommand Maps). During parsing, the first non-flag argument is matched against registered subcommands. When found, global flags are merged with subcommand-specific flags, the subcommand path is recorded in the parsed context, and parsing continues with the merged flag set. Nested subcommands recurse one level deeper. Help text adapts to show commands at the appropriate level.

**Tech Stack:** Pure AIRL, compiled with g3. All output uses single-arg `(print (str ...))`. No `assert` — use `check` helper in tests. `match` for all Result handling.

**Spec:** `/mnt/b6d8b397-9fc1-42ac-a0da-8664a73d4ee9/airl_kafka_cli/docs/specs/cairli-subcommands.md`

**g3 quirks to remember:**
- `string-to-int` returns `(Ok n)` in g3 — use match to unwrap
- No `assert` with `print` — use custom `check` function
- Always `(print (str ... "\n"))` — never `println` or multi-arg `print`

---

## File Structure

```
src/cairli.airl                     # Modify: add subcommand builders, lookup, help, parser changes
tests/test-subcommands.airl         # Create: subcommand parsing tests
tests/test-nested-subcommands.airl  # Create: nested subcommand tests
tests/test-subcommand-help.airl     # Create: help text output tests for subcommand apps
test.sh                             # Modify: add new test files
```

All new functions go into `src/cairli.airl`. The file is organized top-down (helpers → builders → lookup → help → parser → public API), and new functions slot into the appropriate section. Dependencies must appear before dependents.

---

### Task 1: Subcommand Builder Functions

**Files:**
- Modify: `src/cairli.airl` (insert after `cairli-add-positional`, ~line 87)
- Create: `tests/test-subcommands.airl`

- [ ] **Step 1: Write failing test for `cairli-add-subcommand`**

Create `tests/test-subcommands.airl`:

```lisp
;; CairLI — Subcommand Tests

(defn check
  :sig [(cond : Bool) (msg : String) -> _]
  :requires [(valid msg)]
  :ensures [(valid result)]
  :body (if cond nil (do (print (str "FAIL: " msg "\n")) (exit 1))))

;; Test cairli-add-subcommand
(let (app : _ (cairli-app (map-from ["name" "tool" "version" "1.0"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "serve" "help" "Start server"])))
     (subcmds : List (map-get app "subcommands"))
     (sc : _ (at subcmds 0))
  (do
    (check (= (length subcmds) 1) "one subcommand")
    (check (= (map-get sc "name") "serve") "subcommand name")
    (check (= (map-get sc "help") "Start server") "subcommand help")
    (check (map-has sc "flags") "subcommand has flags list")
    (check (map-has sc "positionals") "subcommand has positionals list")
    (check (empty? (map-get sc "flags")) "flags empty")
    (check (empty? (map-get sc "positionals")) "positionals empty")
    (print "PASS: cairli-add-subcommand\n")))
```

- [ ] **Step 2: Compile and verify it fails**

```bash
AIRL_STDLIB=/mnt/b6d8b397-9fc1-42ac-a0da-8664a73d4ee9/AIRL/stdlib \
/mnt/b6d8b397-9fc1-42ac-a0da-8664a73d4ee9/AIRL/g3 -- \
  src/cairli.airl tests/test-subcommands.airl -o /tmp/cairli-test-sub 2>&1
```

Expected: compile error — `cairli-add-subcommand` undefined.

- [ ] **Step 3: Implement `cairli-add-subcommand`**

Insert after `cairli-add-positional` in `src/cairli.airl`:

```lisp
;; Add a subcommand to the app
(defn cairli-add-subcommand
  :sig [(app : _) (subcmd-config : _) -> _]
  :requires [(map-has app "name") (map-has subcmd-config "name")]
  :ensures [(valid result)]
  :body (let (subcmds : List (map-get-or app "subcommands" []))
              (sc : _ (map-set (map-set (map-set subcmd-config
                        "flags" []) "positionals" []) "subcommands" []))
           (map-set app "subcommands" (append subcmds sc))))
```

- [ ] **Step 4: Compile and verify it passes**

```bash
AIRL_STDLIB=... g3 -- src/cairli.airl tests/test-subcommands.airl -o /tmp/cairli-test-sub && /tmp/cairli-test-sub
```

Expected: `PASS: cairli-add-subcommand`

- [ ] **Step 5: Commit**

```bash
git add src/cairli.airl tests/test-subcommands.airl
git commit -m "feat(cairli): add cairli-add-subcommand builder"
```

---

### Task 2: Subcommand Flag & Positional Builders

**Files:**
- Modify: `src/cairli.airl` (insert after `cairli-add-subcommand`)
- Modify: `tests/test-subcommands.airl`

- [ ] **Step 1: Write failing tests for `cairli-subcommand-flag` and `cairli-subcommand-positional`**

Append to `tests/test-subcommands.airl`:

```lisp
;; Test cairli-subcommand-flag
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "serve" "help" "Serve"])))
     (app : _ (cairli-subcommand-flag app "serve" (map-from ["name" "port" "short" "p" "type" "int" "default" "8080"])))
     (app : _ (cairli-subcommand-flag app "serve" (map-from ["name" "host" "default" "localhost"])))
     (subcmds : List (map-get app "subcommands"))
     (sc : _ (at subcmds 0))
     (flags : List (map-get sc "flags"))
  (do
    (check (= (length flags) 2) "two flags on subcommand")
    (check (= (map-get (at flags 0) "name") "port") "first flag is port")
    (check (= (map-get (at flags 1) "name") "host") "second flag is host")
    (print "PASS: cairli-subcommand-flag\n")))

;; Test cairli-subcommand-positional
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "run" "help" "Run"])))
     (app : _ (cairli-subcommand-positional app "run" (map-from ["name" "script" "help" "Script file"])))
     (subcmds : List (map-get app "subcommands"))
     (sc : _ (at subcmds 0))
     (positionals : List (map-get sc "positionals"))
  (do
    (check (= (length positionals) 1) "one positional on subcommand")
    (check (= (map-get (at positionals 0) "name") "script") "positional is script")
    (print "PASS: cairli-subcommand-positional\n")))

;; Test flag added to non-existent subcommand is a no-op (or returns app unchanged)
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "serve"])))
     (app2 : _ (cairli-subcommand-flag app "nonexistent" (map-from ["name" "port"])))
  (do
    ;; app unchanged — subcommands list is identical
    (check (= (length (map-get app2 "subcommands")) 1) "still one subcommand")
    (check (empty? (map-get (at (map-get app2 "subcommands") 0) "flags")) "no flags added")
    (print "PASS: flag on nonexistent subcommand is no-op\n")))
```

- [ ] **Step 2: Compile and verify it fails**

Expected: `cairli-subcommand-flag` undefined.

- [ ] **Step 3: Implement both functions**

Insert after `cairli-add-subcommand`:

```lisp
;; Internal: update a subcommand by name within the subcommands list
(defn cairli--update-subcommand
  :sig [(subcmds : List) (name : String) (updater : _) -> List]
  :requires [(valid subcmds)]
  :ensures [(valid result)]
  :body (map (fn [sc]
               (if (= (map-get sc "name") name)
                 (updater sc)
                 sc))
             subcmds))

;; Add a flag to a specific subcommand
(defn cairli-subcommand-flag
  :sig [(app : _) (subcmd-name : String) (flag-config : _) -> _]
  :requires [(map-has app "name") (map-has flag-config "name")]
  :ensures [(valid result)]
  :body (let (subcmds : List (map-get-or app "subcommands" []))
              (flag : _ (if (map-has flag-config "type")
                          flag-config
                          (map-set flag-config "type" "string")))
              (updated : List (cairli--update-subcommand subcmds subcmd-name
                                (fn [sc] (map-set sc "flags"
                                           (append (map-get sc "flags") flag)))))
           (map-set app "subcommands" updated)))

;; Add a positional to a specific subcommand
(defn cairli-subcommand-positional
  :sig [(app : _) (subcmd-name : String) (pos-config : _) -> _]
  :requires [(map-has app "name") (map-has pos-config "name")]
  :ensures [(valid result)]
  :body (let (subcmds : List (map-get-or app "subcommands" []))
              (with-type : _ (if (map-has pos-config "type")
                               pos-config
                               (map-set pos-config "type" "string")))
              (pos : _ (if (map-has with-type "required")
                         with-type
                         (map-set with-type "required" true)))
              (updated : List (cairli--update-subcommand subcmds subcmd-name
                                (fn [sc] (map-set sc "positionals"
                                           (append (map-get sc "positionals") pos)))))
           (map-set app "subcommands" updated)))
```

- [ ] **Step 4: Compile and verify passes**

Expected: all three new tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/cairli.airl tests/test-subcommands.airl
git commit -m "feat(cairli): add subcommand flag and positional builders"
```

---

### Task 3: Nested Subcommand Builder

**Files:**
- Modify: `src/cairli.airl` (insert after `cairli-subcommand-positional`)
- Create: `tests/test-nested-subcommands.airl`

- [ ] **Step 1: Write failing test for `cairli-add-nested-subcommand`**

Create `tests/test-nested-subcommands.airl`:

```lisp
;; CairLI — Nested Subcommand Tests

(defn check
  :sig [(cond : Bool) (msg : String) -> _]
  :requires [(valid msg)]
  :ensures [(valid result)]
  :body (if cond nil (do (print (str "FAIL: " msg "\n")) (exit 1))))

;; Test cairli-add-nested-subcommand
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "topic" "help" "Topic ops"])))
     (app : _ (cairli-add-nested-subcommand app "topic" (map-from ["name" "list" "help" "List topics"])))
     (app : _ (cairli-add-nested-subcommand app "topic" (map-from ["name" "create" "help" "Create topic"])))
     (subcmds : List (map-get app "subcommands"))
     (topic : _ (at subcmds 0))
     (nested : List (map-get topic "subcommands"))
  (do
    (check (= (length nested) 2) "two nested subcommands")
    (check (= (map-get (at nested 0) "name") "list") "first nested is list")
    (check (= (map-get (at nested 1) "name") "create") "second nested is create")
    (check (map-has (at nested 0) "flags") "nested has flags")
    (check (map-has (at nested 0) "positionals") "nested has positionals")
    (print "PASS: cairli-add-nested-subcommand\n")))
```

- [ ] **Step 2: Compile and verify it fails**

Expected: `cairli-add-nested-subcommand` undefined.

- [ ] **Step 3: Implement `cairli-add-nested-subcommand`**

Insert after `cairli-subcommand-positional`:

```lisp
;; Add a nested subcommand under a parent subcommand
(defn cairli-add-nested-subcommand
  :sig [(app : _) (parent-name : String) (subcmd-config : _) -> _]
  :requires [(map-has app "name") (map-has subcmd-config "name")]
  :ensures [(valid result)]
  :body (let (subcmds : List (map-get-or app "subcommands" []))
              (sc : _ (map-set (map-set (map-set subcmd-config
                        "flags" []) "positionals" []) "subcommands" []))
              (updated : List (cairli--update-subcommand subcmds parent-name
                                (fn [parent]
                                  (let (children : List (map-get-or parent "subcommands" []))
                                    (map-set parent "subcommands" (append children sc))))))
           (map-set app "subcommands" updated)))
```

- [ ] **Step 4: Compile and verify passes**

Expected: `PASS: cairli-add-nested-subcommand`

- [ ] **Step 5: Commit**

```bash
git add src/cairli.airl tests/test-nested-subcommands.airl
git commit -m "feat(cairli): add nested subcommand builder"
```

---

### Task 4: Subcommand Lookup Helper

**Files:**
- Modify: `src/cairli.airl` (insert in Flag Lookup section, after `cairli--find-flag-by-short`)
- Modify: `tests/test-subcommands.airl`

- [ ] **Step 1: Write failing test for `cairli--find-subcommand`**

Append to `tests/test-subcommands.airl`:

```lisp
;; Test cairli--find-subcommand
(let (subcmds : List [(map-from ["name" "produce" "flags" [] "positionals" [] "subcommands" []])
                      (map-from ["name" "consume" "flags" [] "positionals" [] "subcommands" []])])
     (found : _ (cairli--find-subcommand subcmds "produce"))
     (missing : _ (cairli--find-subcommand subcmds "delete"))
  (do
    (check (not (= found nil)) "found produce")
    (check (= (map-get found "name") "produce") "correct subcommand")
    (check (= missing nil) "delete not found")
    (print "PASS: cairli--find-subcommand\n")))
```

- [ ] **Step 2: Compile and verify it fails**

- [ ] **Step 3: Implement `cairli--find-subcommand`**

Insert after `cairli--find-flag-by-short` in the Flag Lookup section:

```lisp
;; Find a subcommand by name within a subcommands list
(defn cairli--find-subcommand
  :sig [(subcmds : List) (name : String) -> _]
  :requires [(valid subcmds)]
  :ensures [(valid result)]
  :body (find (fn [sc] (= (map-get sc "name") name)) subcmds))
```

- [ ] **Step 4: Compile and verify passes**

- [ ] **Step 5: Commit**

```bash
git add src/cairli.airl tests/test-subcommands.airl
git commit -m "feat(cairli): add subcommand lookup helper"
```

---

### Task 5: Subcommand-Aware Help Text

**Files:**
- Modify: `src/cairli.airl` (modify `cairli--print-help`, add `cairli--print-subcommand-help`)
- Create: `tests/test-subcommand-help.airl`

- [ ] **Step 1: Write help output tests**

Create `tests/test-subcommand-help.airl`. Since help calls `(exit 0)`, these tests verify the app structure and formatting helpers rather than calling `cairli--print-help` directly. Test the label/formatting helpers:

```lisp
;; CairLI — Subcommand Help Tests
;; These test the building blocks. Full help output is verified manually
;; since --help calls (exit 0).

(defn check
  :sig [(cond : Bool) (msg : String) -> _]
  :requires [(valid msg)]
  :ensures [(valid result)]
  :body (if cond nil (do (print (str "FAIL: " msg "\n")) (exit 1))))

;; Test that app with subcommands has correct structure for help rendering
(let (app : _ (cairli-app (map-from ["name" "kafka-cli" "version" "0.1.0"])))
     (app : _ (cairli-add-flag app (map-from ["name" "broker" "short" "b" "default" "localhost:9092"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "produce" "help" "Produce messages"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "consume" "help" "Consume messages"])))
     (subcmds : List (map-get app "subcommands"))
  (do
    (check (= (length subcmds) 2) "two subcommands")
    (check (= (map-get (at subcmds 0) "name") "produce") "produce registered")
    (check (= (map-get (at subcmds 0) "help") "Produce messages") "produce help text")
    (print "PASS: subcommand app structure for help\n")))

;; Test that subcommand --help builds merged flag list correctly
;; (global + subcommand-specific flags merged at parse time)
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-flag app (map-from ["name" "verbose" "type" "bool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "run" "help" "Run"])))
     (app : _ (cairli-subcommand-flag app "run" (map-from ["name" "port" "type" "int"])))
     (subcmd : _ (cairli--find-subcommand (map-get app "subcommands") "run"))
     (global-flags : List (map-get app "flags"))
     (sub-flags : List (map-get subcmd "flags"))
     (merged : List (concat sub-flags global-flags))
  (do
    (check (= (length merged) 2) "merged has 2 flags")
    (check (= (map-get (at merged 0) "name") "port") "subcommand flag first")
    (check (= (map-get (at merged 1) "name") "verbose") "global flag second")
    (print "PASS: merged flags for subcommand help\n")))

;; Test cairli--format-subcommand-label
(let (label : String (cairli--format-subcommand-label (map-from ["name" "produce" "help" "Produce messages"])))
  (do
    (check (contains label "produce") "label has name")
    (print "PASS: format-subcommand-label\n")))

(print "\nAll subcommand help tests passed!\n")
```

- [ ] **Step 2: Implement `cairli--format-subcommand-label`**

Insert in the Help Text Generation section (before `cairli--print-help`):

```lisp
;; Format a subcommand's display label for help: "    name"
(defn cairli--format-subcommand-label
  :sig [(subcmd : _) -> String]
  :requires [(map-has subcmd "name")]
  :ensures [(valid result)]
  :body (str "    " (map-get subcmd "name")))
```

- [ ] **Step 3: Implement `cairli--max-subcommand-width`**

Insert after `cairli--format-subcommand-label`:

```lisp
;; Compute max subcommand label width for alignment
(defn cairli--max-subcommand-width
  :sig [(subcmds : List) -> i64]
  :requires [(valid subcmds)]
  :ensures [(>= result 0)]
  :body (fold (fn [mx sc] (max mx (char-count (cairli--format-subcommand-label sc))))
              0 subcmds))
```

- [ ] **Step 4: Modify `cairli--print-help` to show subcommands**

Replace the existing `cairli--print-help` function body. The key change: if the app has a `"subcommands"` key with a non-empty list, show a "COMMANDS:" section in help and change the USAGE line to `<command>` syntax. The full replacement:

```lisp
(defn cairli--print-help
  :sig [(app : _) -> _]
  :requires [(map-has app "name")]
  :ensures [(valid result)]
  :body (let (name : String (map-get app "name"))
              (version : String (map-get-or app "version" ""))
              (description : String (map-get-or app "description" ""))
              (flags : List (map-get app "flags"))
              (positionals : List (map-get app "positionals"))
              (subcmds : List (map-get-or app "subcommands" []))
              (has-subcmds : Bool (not (empty? subcmds)))
              (col-width : i64 (+ (cairli--max-flag-width flags) 4))
           (do
             ;; Header
             (if (= version "")
               (print (str name "\n"))
               (print (str name " " version "\n")))
             (if (= description "")
               nil
               (print (str description "\n")))
             (print "\n")

             ;; Usage line
             (if has-subcmds
               ;; Subcommand-aware usage
               (let (opts-part : String (if (empty? flags) "" " [FLAGS]"))
                 (print (str "USAGE:\n    " name opts-part " <COMMAND>\n")))
               ;; Original flat usage
               (let (pos-usage : String (fold (fn [acc p]
                                                (let (pname : String (map-get p "name"))
                                                     (required : _ (map-get-or p "required" true))
                                                  (if required
                                                    (str acc " <" pname ">")
                                                    (str acc " [" pname "]"))))
                                              "" positionals))
                    (has-flags : Bool (not (empty? flags)))
                    (opts-part : String (if has-flags " [OPTIONS]" ""))
                 (print (str "USAGE:\n    " name opts-part pos-usage "\n"))))

             (print "\n")

             ;; Commands section (only if subcommands exist)
             (if has-subcmds
               (let (sc-col : i64 (+ (cairli--max-subcommand-width subcmds) 4))
                 (do
                   (print "COMMANDS:\n")
                   (fold (fn [_ sc]
                           (let (label : String (cairli--format-subcommand-label sc))
                                (help : String (map-get-or sc "help" ""))
                             (print (str (pad-right label sc-col " ") help "\n"))))
                         nil subcmds)
                   (print "\n")))
               nil)

             ;; Positional args (only if no subcommands)
             (if has-subcmds
               nil
               (if (empty? positionals)
                 nil
                 (do
                   (print "ARGS:\n")
                   (fold (fn [_ p]
                           (let (pname : String (map-get p "name"))
                                (help : String (map-get-or p "help" ""))
                             (print (str "    <" pname ">    " help "\n"))))
                         nil positionals)
                   (print "\n"))))

             ;; Options section header
             (if has-subcmds
               (print "GLOBAL OPTIONS:\n")
               (print "OPTIONS:\n"))

             ;; Built-in help and version
             (let (help-label : String "  -h, --help")
                  (ver-label : String "  -V, --version")
               (do
                 (print (str (pad-right help-label col-width " ") "Print help information\n"))
                 (if (= version "")
                   nil
                   (print (str (pad-right ver-label col-width " ") "Print version information\n")))))

             ;; User flags
             (fold (fn [_ flag]
                     (let (label : String (cairli--format-flag-label flag))
                          (help : String (map-get-or flag "help" ""))
                          (has-default : Bool (map-has flag "default"))
                          (default-suffix : String (if has-default
                                                     (str " [default: " (map-get flag "default") "]")
                                                     ""))
                       (print (str (pad-right label col-width " ") help default-suffix "\n"))))
                   nil flags)

             (exit 0))))
```

- [ ] **Step 5: Add `cairli--print-subcommand-help` for subcommand-level help**

Insert after `cairli--print-help`:

```lisp
;; Print help for a specific subcommand, then exit 0
;; Shows: "appname subcmd — description", merged flags (subcommand + global), subcommand positionals
;; If the subcommand has nested subcommands, show those too
(defn cairli--print-subcommand-help
  :sig [(app : _) (subcmd : _) (subcmd-path : String) -> _]
  :requires [(map-has app "name") (map-has subcmd "name")]
  :ensures [(valid result)]
  :body (let (app-name : String (map-get app "name"))
              (sc-name : String (map-get subcmd "name"))
              (help-text : String (map-get-or subcmd "help" ""))
              (global-flags : List (map-get app "flags"))
              (sc-flags : List (map-get subcmd "flags"))
              (merged-flags : List (concat sc-flags global-flags))
              (positionals : List (map-get subcmd "positionals"))
              (nested : List (map-get-or subcmd "subcommands" []))
              (has-nested : Bool (not (empty? nested)))
              (col-width : i64 (+ (cairli--max-flag-width merged-flags) 4))
           (do
             ;; Header
             (if (= help-text "")
               (print (str app-name " " subcmd-path "\n"))
               (print (str app-name " " subcmd-path " — " help-text "\n")))
             (print "\n")

             ;; Usage
             (if has-nested
               (print (str "USAGE:\n    " app-name " " subcmd-path " <COMMAND>\n"))
               (let (pos-usage : String (fold (fn [acc p]
                                                (let (pname : String (map-get p "name"))
                                                     (required : _ (map-get-or p "required" true))
                                                  (if required
                                                    (str acc " <" pname ">")
                                                    (str acc " [" pname "]"))))
                                              "" positionals))
                    (opts-part : String (if (empty? merged-flags) "" " [OPTIONS]"))
                 (print (str "USAGE:\n    " app-name " " subcmd-path opts-part pos-usage "\n"))))

             (print "\n")

             ;; Nested subcommands
             (if has-nested
               (let (sc-col : i64 (+ (cairli--max-subcommand-width nested) 4))
                 (do
                   (print "COMMANDS:\n")
                   (fold (fn [_ nsc]
                           (let (label : String (cairli--format-subcommand-label nsc))
                                (nhelp : String (map-get-or nsc "help" ""))
                             (print (str (pad-right label sc-col " ") nhelp "\n"))))
                         nil nested)
                   (print "\n")))
               nil)

             ;; Positional args
             (if (empty? positionals)
               nil
               (do
                 (print "ARGS:\n")
                 (fold (fn [_ p]
                         (let (pname : String (map-get p "name"))
                              (phelp : String (map-get-or p "help" ""))
                           (print (str "    <" pname ">    " phelp "\n"))))
                       nil positionals)
                 (print "\n")))

             ;; Options (merged)
             (print "OPTIONS:\n")
             (let (help-label : String "  -h, --help")
               (print (str (pad-right help-label col-width " ") "Print help information\n")))
             (fold (fn [_ flag]
                     (let (label : String (cairli--format-flag-label flag))
                          (fhelp : String (map-get-or flag "help" ""))
                          (has-default : Bool (map-has flag "default"))
                          (default-suffix : String (if has-default
                                                     (str " [default: " (map-get flag "default") "]")
                                                     ""))
                       (print (str (pad-right label col-width " ") fhelp default-suffix "\n"))))
                   nil merged-flags)

             (exit 0))))
```

- [ ] **Step 6: Compile and verify help tests pass**

```bash
AIRL_STDLIB=... g3 -- src/cairli.airl tests/test-subcommand-help.airl -o /tmp/cairli-test-help && /tmp/cairli-test-help
```

Expected: all three tests pass.

- [ ] **Step 7: Commit**

```bash
git add src/cairli.airl tests/test-subcommand-help.airl
git commit -m "feat(cairli): subcommand-aware help text generation"
```

---

### Task 6: Subcommand-Aware Parser

**Files:**
- Modify: `src/cairli.airl` (add `cairli--parse-with-subcommands`, modify `cairli-run`)
- Modify: `tests/test-subcommands.airl`

This is the core change. The strategy:
1. `cairli-run` checks if app has subcommands
2. If yes, delegates to `cairli--parse-with-subcommands`
3. That function scans for the first non-flag arg, matches it as a subcommand
4. Merges global + subcommand flags, then delegates to existing `cairli--parse-args-loop`
5. For nested subcommands, checks the next non-flag arg after the parent subcommand

- [ ] **Step 1: Write failing tests for basic subcommand parsing**

Append to `tests/test-subcommands.airl`:

```lisp
;; Test basic subcommand parsing
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-flag app (map-from ["name" "verbose" "short" "v" "type" "bool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "serve" "help" "Serve"])))
     (app : _ (cairli-subcommand-flag app "serve" (map-from ["name" "port" "type" "int" "default" "8080"])))
     (result : _ (cairli-run app ["tool" "serve" "--port" "3000" "--verbose"]))
  (match result
    (Ok ctx) (do
      (check (= (cairli-subcommand ctx) "serve") "subcommand is serve")
      (check (= (cairli-flag ctx "port") 3000) "port=3000")
      (check (= (cairli-flag ctx "verbose") true) "verbose=true global")
      (print "PASS: basic subcommand parsing\n"))
    (Err e) (do (print (str "FAIL: basic subcommand: " e "\n")) (exit 1))))

;; Test global flag before subcommand
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-flag app (map-from ["name" "verbose" "type" "bool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "run" "help" "Run"])))
     (result : _ (cairli-run app ["tool" "--verbose" "run"]))
  (match result
    (Ok ctx) (do
      (check (= (cairli-subcommand ctx) "run") "subcommand is run")
      (check (= (cairli-flag ctx "verbose") true) "verbose before subcmd")
      (print "PASS: global flag before subcommand\n"))
    (Err e) (do (print (str "FAIL: global before subcmd: " e "\n")) (exit 1))))

;; Test unknown subcommand errors
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "serve"])))
     (result : _ (cairli-run app ["tool" "bogus"]))
  (match result
    (Ok _) (do (print "FAIL: bogus should error\n") (exit 1))
    (Err e) (do
      (check (contains e "unknown command") "error says unknown command")
      (check (contains e "bogus") "error includes bogus")
      (print "PASS: unknown subcommand error\n"))))

;; Test missing subcommand errors
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "serve"])))
     (result : _ (cairli-run app ["tool"]))
  (match result
    (Ok _) (do (print "FAIL: missing subcmd should error\n") (exit 1))
    (Err e) (do
      (check (contains e "command") "error mentions command")
      (print "PASS: missing subcommand error\n"))))

;; Test subcommand with positional
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "open" "help" "Open"])))
     (app : _ (cairli-subcommand-positional app "open" (map-from ["name" "file" "help" "File"])))
     (result : _ (cairli-run app ["tool" "open" "readme.md"]))
  (match result
    (Ok ctx) (do
      (check (= (cairli-subcommand ctx) "open") "subcommand is open")
      (check (= (cairli-positional ctx "file") "readme.md") "file=readme.md")
      (print "PASS: subcommand with positional\n"))
    (Err e) (do (print (str "FAIL: subcmd positional: " e "\n")) (exit 1))))

;; Test cairli-subcommand accessor
(let (app : _ (cairli-app (map-from ["name" "tool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "build"])))
     (result : _ (cairli-run app ["tool" "build"]))
  (match result
    (Ok ctx) (do
      (check (= (cairli-subcommand ctx) "build") "accessor returns build")
      (print "PASS: cairli-subcommand accessor\n"))
    (Err e) (do (print (str "FAIL: accessor: " e "\n")) (exit 1))))
```

- [ ] **Step 2: Compile and verify tests fail**

Expected: `cairli-subcommand` undefined, or parsing doesn't recognize subcommands.

- [ ] **Step 3: Implement `cairli--parse-with-subcommands`**

Insert before `cairli-run` (after the Core Parser section):

```lisp
;; Parse args for an app with subcommands
;; Strategy: scan for first non-flag token, match as subcommand,
;; merge global+subcommand flags, then parse remaining with cairli--parse-args-loop.
;; Global flags can appear before or after the subcommand token.
(defn cairli--parse-with-subcommands
  :sig [(app : _) (args : List) -> _]
  :requires [(valid app)]
  :ensures [(valid result)]
  :body (let (subcmds : List (map-get-or app "subcommands" []))
              (global-flags : List (map-get app "flags"))
           ;; Scan args: collect global flags parsed before the subcommand, find the subcommand token
           (cairli--scan-for-subcommand app args subcmds global-flags [] 0)))

;; Recursive scanner: walk args looking for the subcommand token.
;; Pre-flags is a list of flag args seen before the subcommand (to replay after merging).
;; We handle global flags before the subcommand by collecting them, then replaying.
;; Actually simpler: just find the subcommand name, remove it from args, merge flags, and parse.
(defn cairli--scan-for-subcommand
  :sig [(app : _) (args : List) (subcmds : List) (global-flags : List) (pre-args : List) (depth : i64) -> _]
  :requires [(valid app)]
  :ensures [(valid result)]
  :body (if (empty? args)
          ;; No subcommand found
          (Err (str "missing command. Available: " (join (map (fn [sc] (map-get sc "name")) subcmds) ", ")))
          (let (arg : String (head args))
               (rest : List (tail args))
            ;; Skip --help / -h (let it fall through to help printing later)
            (if (or (= arg "--help") (= arg "-h"))
              (cairli--print-help app)
              (if (or (= arg "--version") (= arg "-V"))
                (cairli--print-version app)
                ;; Is this a flag? (starts with -)
                (if (starts-with arg "-")
                  ;; It's a flag — collect it (and its value if non-bool) into pre-args
                  (let (flag-def : _ (if (if (starts-with arg "--") (> (char-count arg) 2) false)
                                       (cairli--find-flag-by-long global-flags (substring arg 2 (char-count arg)))
                                       (if (= (char-count arg) 2)
                                         (cairli--find-flag-by-short global-flags (substring arg 1 2))
                                         nil)))
                    (if (= flag-def nil)
                      (Err (str "unknown flag: " arg))
                      (if (= (map-get-or flag-def "type" "string") "bool")
                        ;; Bool flag — just collect the flag token
                        (cairli--scan-for-subcommand app rest subcmds global-flags (append pre-args arg) depth)
                        ;; Value flag — collect flag + its value
                        (if (empty? rest)
                          (Err (str "flag " arg " requires a value"))
                          (cairli--scan-for-subcommand app (tail rest) subcmds global-flags
                            (append (append pre-args arg) (head rest)) depth)))))
                  ;; Not a flag — try to match as subcommand
                  (let (matched : _ (cairli--find-subcommand subcmds arg))
                    (if (= matched nil)
                      (Err (str "unknown command: " arg ". Available: " (join (map (fn [sc] (map-get sc "name")) subcmds) ", ")))
                      ;; Found the subcommand! Check for nested subcommands.
                      (let (nested : List (map-get-or matched "subcommands" []))
                           (has-nested : Bool (not (empty? nested)))
                           (sc-path : String arg)
                        (if has-nested
                          ;; Try to match next non-flag arg as nested subcommand
                          (cairli--resolve-nested-subcommand app matched sc-path global-flags (concat pre-args rest))
                          ;; No nesting — merge flags and parse remaining args
                          (let (merged-flags : List (concat (map-get matched "flags") global-flags))
                               (merged-app : _ (map-from ["name" (map-get app "name")
                                                          "version" (map-get-or app "version" "")
                                                          "flags" merged-flags
                                                          "positionals" (map-get matched "positionals")
                                                          "subcommands" []
                                                          "description" (map-get-or matched "help" "")]))
                               (all-args : List (concat pre-args rest))
                               (initial-flags : _ (cairli--apply-defaults merged-flags))
                               (initial-state : _ (map-from ["flags" initial-flags
                                                             "positionals" (map-new)
                                                             "pos-index" 0]))
                               (parse-result : _ (cairli--parse-args-loop merged-app all-args initial-state))
                            (match parse-result
                              (Err e) (Err e)
                              (Ok ctx) (Ok (map-set ctx "subcommand" sc-path))))))))))))))

;; Resolve nested subcommand: look through remaining args for the nested command name
(defn cairli--resolve-nested-subcommand
  :sig [(app : _) (parent : _) (parent-path : String) (global-flags : List) (args : List) -> _]
  :requires [(valid app)]
  :ensures [(valid result)]
  :body (let (nested : List (map-get-or parent "subcommands" []))
          (if (empty? args)
            (Err (str "missing subcommand for '" parent-path "'. Available: " (join (map (fn [sc] (map-get sc "name")) nested) ", ")))
            (let (arg : String (head args))
                 (rest : List (tail args))
              (if (or (= arg "--help") (= arg "-h"))
                (cairli--print-subcommand-help app parent parent-path)
                (if (starts-with arg "-")
                  ;; Flag before nested subcommand — skip it (it's a global flag, will be parsed later)
                  ;; For simplicity, just look at next non-flag arg
                  ;; Collect flag + possible value, then recurse
                  (let (flag-def : _ (if (if (starts-with arg "--") (> (char-count arg) 2) false)
                                       (cairli--find-flag-by-long global-flags (substring arg 2 (char-count arg)))
                                       (if (= (char-count arg) 2)
                                         (cairli--find-flag-by-short global-flags (substring arg 1 2))
                                         nil)))
                    (if (= flag-def nil)
                      (Err (str "unknown flag: " arg))
                      (if (= (map-get-or flag-def "type" "string") "bool")
                        (cairli--resolve-nested-subcommand app parent parent-path global-flags rest)
                        (if (empty? rest)
                          (Err (str "flag " arg " requires a value"))
                          (cairli--resolve-nested-subcommand app parent parent-path global-flags (tail rest))))))
                  ;; Non-flag: try to match as nested subcommand
                  (let (matched : _ (cairli--find-subcommand nested arg))
                    (if (= matched nil)
                      (Err (str "unknown command: " parent-path " " arg ". Available: " (join (map (fn [sc] (map-get sc "name")) nested) ", ")))
                      ;; Found nested subcommand
                      (let (sc-path : String (str parent-path " " arg))
                           (merged-flags : List (concat (map-get matched "flags") (concat (map-get parent "flags") global-flags)))
                           (merged-app : _ (map-from ["name" (map-get app "name")
                                                      "version" (map-get-or app "version" "")
                                                      "flags" merged-flags
                                                      "positionals" (map-get matched "positionals")
                                                      "subcommands" []
                                                      "description" (map-get-or matched "help" "")]))
                           (initial-flags : _ (cairli--apply-defaults merged-flags))
                           (initial-state : _ (map-from ["flags" initial-flags
                                                         "positionals" (map-new)
                                                         "pos-index" 0]))
                           (parse-result : _ (cairli--parse-args-loop merged-app rest initial-state))
                        (match parse-result
                          (Err e) (Err e)
                          (Ok ctx) (Ok (map-set ctx "subcommand" sc-path))))))))))))))
```

- [ ] **Step 4: Add `cairli-subcommand` accessor**

Insert after `cairli-positional` in the Public API section:

```lisp
;; Get the matched subcommand path from parsed context
(defn cairli-subcommand
  :sig [(ctx : _) -> _]
  :requires [(valid ctx)]
  :ensures [(valid result)]
  :body (map-get-or ctx "subcommand" nil))
```

- [ ] **Step 5: Modify `cairli-run` to dispatch to subcommand parser**

Replace the existing `cairli-run` body:

```lisp
(defn cairli-run
  :sig [(app : _) (raw-args : List) -> _]
  :requires [(map-has app "name") (map-has app "flags") (map-has app "positionals")]
  :ensures [(valid result)]
  :body (let (args : List (if (empty? raw-args) [] (tail raw-args)))
              (has-subcmds : Bool (not (empty? (map-get-or app "subcommands" []))))
           (if has-subcmds
             (cairli--parse-with-subcommands app args)
             ;; Original flat parsing
             (let (initial-flags : _ (cairli--apply-defaults (map-get app "flags")))
                  (initial-state : _ (map-from ["flags" initial-flags
                                                "positionals" (map-new)
                                                "pos-index" 0]))
               (cairli--parse-args-loop app args initial-state)))))
```

- [ ] **Step 6: Compile and verify all subcommand tests pass**

```bash
AIRL_STDLIB=... g3 -- src/cairli.airl tests/test-subcommands.airl -o /tmp/cairli-test-sub && /tmp/cairli-test-sub
```

Expected: all tests pass including the new parsing tests.

- [ ] **Step 7: Verify existing tests still pass (backward compatibility)**

```bash
bash test.sh
```

Expected: all 57 existing tests still pass (subcommand code is only activated when `"subcommands"` key exists).

- [ ] **Step 8: Commit**

```bash
git add src/cairli.airl tests/test-subcommands.airl
git commit -m "feat(cairli): subcommand-aware parser with global flag support"
```

---

### Task 7: Nested Subcommand Parsing Tests

**Files:**
- Modify: `tests/test-nested-subcommands.airl`

- [ ] **Step 1: Add parsing tests for nested subcommands**

Append to `tests/test-nested-subcommands.airl`:

```lisp
;; Test nested subcommand parsing: topic create
(let (app : _ (cairli-app (map-from ["name" "kafka-cli"])))
     (app : _ (cairli-add-flag app (map-from ["name" "broker" "short" "b" "default" "localhost:9092"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "topic" "help" "Topic ops"])))
     (app : _ (cairli-add-nested-subcommand app "topic" (map-from ["name" "create" "help" "Create topic"])))
     (app : _ (cairli-add-nested-subcommand app "topic" (map-from ["name" "list" "help" "List topics"])))
     (result : _ (cairli-run app ["kafka-cli" "topic" "create"]))
  (match result
    (Ok ctx) (do
      (check (= (cairli-subcommand ctx) "topic create") "subcommand is topic create")
      (check (= (cairli-flag ctx "broker") "localhost:9092") "global default broker")
      (print "PASS: nested subcommand parsing\n"))
    (Err e) (do (print (str "FAIL: nested: " e "\n")) (exit 1))))

;; Test nested subcommand with flags
(let (app : _ (cairli-app (map-from ["name" "cli"])))
     (app : _ (cairli-add-flag app (map-from ["name" "verbose" "type" "bool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "db" "help" "Database"])))
     (app : _ (cairli-add-nested-subcommand app "db" (map-from ["name" "migrate" "help" "Run migrations"])))
     (result : _ (cairli-run app ["cli" "--verbose" "db" "migrate"]))
  (match result
    (Ok ctx) (do
      (check (= (cairli-subcommand ctx) "db migrate") "path is db migrate")
      (check (= (cairli-flag ctx "verbose") true) "verbose global flag")
      (print "PASS: nested with global flag before\n"))
    (Err e) (do (print (str "FAIL: nested+global: " e "\n")) (exit 1))))

;; Test missing nested subcommand
(let (app : _ (cairli-app (map-from ["name" "cli"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "db"])))
     (app : _ (cairli-add-nested-subcommand app "db" (map-from ["name" "migrate"])))
     (result : _ (cairli-run app ["cli" "db"]))
  (match result
    (Ok _) (do (print "FAIL: should error for missing nested subcmd\n") (exit 1))
    (Err e) (do
      (check (contains e "missing subcommand") "error mentions missing")
      (check (contains e "db") "error mentions parent")
      (print "PASS: missing nested subcommand error\n"))))

;; Test unknown nested subcommand
(let (app : _ (cairli-app (map-from ["name" "cli"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "db"])))
     (app : _ (cairli-add-nested-subcommand app "db" (map-from ["name" "migrate"])))
     (result : _ (cairli-run app ["cli" "db" "bogus"]))
  (match result
    (Ok _) (do (print "FAIL: should error for unknown nested subcmd\n") (exit 1))
    (Err e) (do
      (check (contains e "unknown command") "error mentions unknown")
      (check (contains e "bogus") "error mentions bogus")
      (print "PASS: unknown nested subcommand error\n"))))

(print "\nAll nested subcommand tests passed!\n")
```

- [ ] **Step 2: Compile and run**

```bash
AIRL_STDLIB=... g3 -- src/cairli.airl tests/test-nested-subcommands.airl -o /tmp/cairli-test-nested && /tmp/cairli-test-nested
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test-nested-subcommands.airl
git commit -m "test(cairli): nested subcommand parsing tests"
```

---

### Task 8: Update test.sh and Full Regression

**Files:**
- Modify: `test.sh`

- [ ] **Step 1: Add new test files to test.sh**

Add these sections before the "All tests passed" line:

```bash
echo "── Subcommand tests ──"
$G3 -- "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-subcommands.airl" -o /tmp/cairli-test-sub
/tmp/cairli-test-sub
rm -f /tmp/cairli-test-sub
echo ""

echo "── Nested subcommand tests ──"
$G3 -- "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-nested-subcommands.airl" -o /tmp/cairli-test-nested
/tmp/cairli-test-nested
rm -f /tmp/cairli-test-nested
echo ""

echo "── Subcommand help tests ──"
$G3 -- "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-subcommand-help.airl" -o /tmp/cairli-test-subhelp
/tmp/cairli-test-subhelp
rm -f /tmp/cairli-test-subhelp
echo ""
```

- [ ] **Step 2: Run full test suite**

```bash
bash test.sh
```

Expected: ALL tests pass — existing 57 + new subcommand tests.

- [ ] **Step 3: Commit**

```bash
git add test.sh
git commit -m "chore(cairli): add subcommand tests to test runner"
```

---

### Task 9: Update CLAUDE.md Documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update CLAUDE.md API section**

Add to the API section:

```markdown
### Subcommands
- `(cairli-add-subcommand app config-map)` — register subcommand (keys: "name", "help")
- `(cairli-subcommand-flag app subcmd-name flag-map)` — add flag to subcommand
- `(cairli-subcommand-positional app subcmd-name pos-map)` — add positional to subcommand
- `(cairli-add-nested-subcommand app parent-name config-map)` — register nested subcommand

### Subcommand Accessors
- `(cairli-subcommand ctx)` — get matched subcommand path string (e.g., "topic create")
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(cairli): document subcommand API"
```

---

## Verification

After all tasks are complete:

```bash
# Full test suite
bash test.sh

# Manual smoke test: build a subcommand app and run it
cat > /tmp/test-subcmd-app.airl << 'EOF'
(let (app : _ (cairli-app (map-from ["name" "myapp" "version" "1.0" "description" "My app"])))
     (app : _ (cairli-add-flag app (map-from ["name" "verbose" "short" "v" "type" "bool"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "serve" "help" "Start server"])))
     (app : _ (cairli-subcommand-flag app "serve" (map-from ["name" "port" "short" "p" "type" "int" "default" "8080"])))
     (app : _ (cairli-add-subcommand app (map-from ["name" "deploy" "help" "Deploy app"])))
     (app : _ (cairli-subcommand-positional app "deploy" (map-from ["name" "env" "help" "Target environment"])))
     (ctx : _ (cairli-run-or-die app (get-args)))
  (let (subcmd : String (cairli-subcommand ctx))
    (do
      (print (str "subcommand: " subcmd "\n"))
      (if (= subcmd "serve")
        (print (str "serving on port " (cairli-flag ctx "port") "\n"))
        (if (= subcmd "deploy")
          (print (str "deploying to " (cairli-positional ctx "env") "\n"))
          nil)))))
EOF
AIRL_STDLIB=... g3 -- src/cairli.airl /tmp/test-subcmd-app.airl -o /tmp/myapp

# Test various invocations:
/tmp/myapp --help
/tmp/myapp serve --port 3000 -v
/tmp/myapp serve --help
/tmp/myapp deploy production
/tmp/myapp bogus          # should error
/tmp/myapp                # should error: missing command
```
