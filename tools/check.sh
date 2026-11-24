#!/usr/bin/env bash
# Headless project checks: import, tests, main-scene boot.
# Fails on a non-zero exit code or any script/parse error in the output.
# Usage: tools/check.sh   (set GODOT=/path/to/godot if it's not on PATH)
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
ERROR_PATTERN="SCRIPT ERROR|Parse Error|Failed to load|ERROR:"

run_step() {
	local title="$1"
	shift
	echo "== $title =="
	local output status
	output="$("$GODOT" --headless --path . "$@" 2>&1)"
	status=$?
	grep -vE '^\[|^$' <<<"$output"
	if [[ $status -ne 0 ]] || grep -qE "$ERROR_PATTERN" <<<"$output"; then
		echo ">> $title FAILED (exit $status)" >&2
		exit 1
	fi
}

run_step "Importing project" --import
run_step "Running tests" --script res://tests/run_tests.gd
run_step "Booting main scene for 30 frames" --quit-after 30

echo "All checks passed."
