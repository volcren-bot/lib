#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
base=${1:-origin/main}

if [[ $base =~ ^0+$ ]] || ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
	echo "No base commit to compare with ($base); skipping the HOST_API check."
	exit 0
fi

globals() { grep -oP '^\t\w+ = g\.\K\w+' | sort -u; }

added=$(comm -13 <(git show "$base:host.luau" | globals) <(globals <host.luau))
old=$(git show "$base:HOST_API" | tr -d '[:space:]')
new=$(tr -d '[:space:]' <HOST_API)

if ((new < old)); then
	echo "HOST_API went down from $old to $new." >&2
	exit 1
fi
if [[ -n $added ]] && ((new == old)); then
	echo "host.luau uses new sandbox globals but HOST_API is still $old; bump it here and in client/src/injector/src/lib.rs:" >&2
	sed 's/^/  /' <<<"$added" >&2
	exit 1
fi
