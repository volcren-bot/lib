#!/usr/bin/env bash
# Format check (StyLua) and lint (luau-analyze) for the Luau code.
set -euo pipefail
cd "$(dirname "$0")/.."

dirs=(.)
fix=0 types=0
for arg in "$@"; do
	case "$arg" in
	--fix) fix=1 ;;
	--types) types=1 ;;
	*) echo "unknown option: $arg" >&2; exit 2 ;;
	esac
done

if ((fix)); then
	stylua "${dirs[@]}"
else
	stylua --check "${dirs[@]}"
fi

out=$(luau-analyze "${dirs[@]}" 2>&1 || true)
if ((types)); then
	diagnostics=$out
else
	# Lint warnings only: type errors are everything the analyzer reports as TypeError.
	diagnostics=$(grep -E '^\S+\([0-9]+,[0-9]+\): ' <<<"$out" | grep -v ': TypeError' || true)
fi
if [[ -n "$diagnostics" ]]; then
	echo "$diagnostics"
	exit 1
fi
