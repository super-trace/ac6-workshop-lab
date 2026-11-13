#!/usr/bin/env bash
# Goal check for the standards audit in Scenario 2: sonic's interface
# descriptions follow the team standard (README, "Team standards"). The lab
# seeds two that don't (scripts/lab-ready.sh): Ethernet0 needs its role and
# peer AS, and Ethernet8, with nothing connected, needs none.
set -euo pipefail

lab="clab-ac6-workshop"
failed=0
fail() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; failed=1; }

printf '\033[1;36m== sonic: interface descriptions ==\033[0m\n'
out="$(docker exec "${lab}-sonic" show interfaces description 2>&1 || true)"
grep -E '^ +(Interface|Ethernet[048]) ' <<<"$out" || true

# desc PORT: PORT's description as `show` prints it, empty when it has none.
desc() {
    awk -v p="$1" '$1 == p { $1 = $2 = $3 = $4 = ""; sub(/^ +/, ""); print }' <<<"$out" |
        sed 's/^N\/A$//'
}

want="BGP: eBGP peer AS65001"
got="$(desc Ethernet0)"
[ "$got" = "$want" ] || fail "Ethernet0 should read \"${want}\", not \"${got}\""
if ! grep -qE '^ +Ethernet8 ' <<<"$out"; then
    fail "sonic didn't list Ethernet8; is the lab up?"
else
    got="$(desc Ethernet8)"
    [ -z "$got" ] || fail "Ethernet8 has nothing connected, so no description, not \"${got}\""
fi

echo
if (( failed )); then ./scripts/banner.sh red "SONIC IS OFF STANDARD"; exit 1; fi
./scripts/banner.sh green "SONIC MEETS THE STANDARD"
