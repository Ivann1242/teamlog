#!/usr/bin/env bash
# A four-person team in a throwaway directory, start to finish.
# No API key, no network: the hub routes with keywords unless you set TL_LLM.
#
#   ./examples/demo.sh
#   TL_LLM="claude -p --model haiku" ./examples/demo.sh    # route with a model instead
set -euo pipefail

TL="$(cd "$(dirname "$0")/.." && pwd)/tl"
TEAM="$(mktemp -d)/team"
"$TL" init "$TEAM" >/dev/null
cd "$TEAM"

# The demo runs on a fake clock so it is instant and repeatable.
minute=0
tick() { minute=$((minute + 1)); export TL_NOW="2026-10-06T09:$(printf %02d "$minute"):00"; }
as() { TL_ME="$1" ./tl "${@:2}"; }   # call tick first; $(...) runs in a subshell
say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

say "Four people join. Each says what they own and care about."
./tl join alice --owns "login, sso" >/dev/null
./tl join bob --owns "review, ci" >/dev/null
./tl join carol --owns "pricing" >/dev/null
./tl join dave --owns "roadmap" --cares "enterprise" --interrupt "outage" >/dev/null
rm .tl/me   # in the demo one machine plays everyone, so identity comes from TL_ME
cat people/dave.md | head -6

say "Their agents write to the log. Nobody is choosing recipients except where they need an answer."
tick; A=$(as alice write "Login endpoint is done, tests pass (commit 3f2a91c). Waiting for review.")
tick; B=$(as bob write "Need the pricing proposal by next Wednesday. @carol can you do it?")
tick; as carol reply "$B" "Pricing proposal will be ready Monday. Also, I think we should build the enterprise tier first." >/dev/null
tick; as alice write "@dave should the enterprise tier support SSO at launch? Need your call before I start." >/dev/null
tick; ./tl log

say "The hub reads each new entry once and decides who else should see it."
tick; ./tl hub
tick; ./tl log --hub | grep -- "-hub" || true

say "Bob's agent checks his inbox: Alice never mentioned him, the hub routed it."
tick; as bob inbox

say "Bob reviews. His reply closes the request and goes back to Alice."
tick; as bob reply "$A" "Reviewed, approved." >/dev/null
tick; as alice inbox

say "STATUS.md: who is waiting on whom."
tick; ./tl hub >/dev/null; cat STATUS.md

say "26 hours later Dave still has not answered Alice. The hub brings it back."
export TL_NOW="2026-10-07T11:30:00"
./tl hub
TL_ME=dave ./tl inbox

say "Done. The team space is in $TEAM"
