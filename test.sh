#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AIRL_DIR="${AIRL_DIR:-/mnt/b6d8b397-9fc1-42ac-a0da-8664a73d4ee9/AIRL}"
G3="${G3:-$AIRL_DIR/g3}"
export AIRL_STDLIB="${AIRL_STDLIB:-$AIRL_DIR/stdlib}"

# g3 requires CWD to be the AIRL directory to find libairl_rt.a
# g3 may emit non-fatal runtime errors during compilation but still produce a working binary.
compile() {
  local output="$1"
  shift
  rm -f "$output"
  (cd "$AIRL_DIR" && $G3 -- "$@" -o "$output") 2>&1 || true
  if [ ! -f "$output" ]; then
    echo "COMPILE FAILED: $output not produced"
    exit 1
  fi
}

echo "═══ CairLI Test Suite ═══"
echo ""

echo "── Builder tests ──"
compile /tmp/cairli-test-builders "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-builders.airl"
/tmp/cairli-test-builders
rm -f /tmp/cairli-test-builders
echo ""

echo "── Parsing tests ──"
compile /tmp/cairli-test-parsing "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-parsing.airl"
/tmp/cairli-test-parsing
rm -f /tmp/cairli-test-parsing
echo ""

echo "── Comprehensive tests ──"
compile /tmp/cairli-test-comprehensive "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-comprehensive.airl"
/tmp/cairli-test-comprehensive
rm -f /tmp/cairli-test-comprehensive
echo ""

echo "── Subcommand tests ──"
compile /tmp/cairli-test-sub "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-subcommands.airl"
/tmp/cairli-test-sub
rm -f /tmp/cairli-test-sub
echo ""

echo "── Nested subcommand tests ──"
compile /tmp/cairli-test-nested "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-nested-subcommands.airl"
/tmp/cairli-test-nested
rm -f /tmp/cairli-test-nested
echo ""

echo "── Comprehensive subcommand tests ──"
compile /tmp/cairli-test-sub-comp "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-subcommands-comprehensive.airl"
/tmp/cairli-test-sub-comp
rm -f /tmp/cairli-test-sub-comp
echo ""

echo "── Subcommand help tests ──"
compile /tmp/cairli-test-subhelp "$SCRIPT_DIR/src/cairli.airl" "$SCRIPT_DIR/tests/test-subcommand-help.airl"
/tmp/cairli-test-subhelp
rm -f /tmp/cairli-test-subhelp
echo ""

echo "═══ All tests passed! ═══"
