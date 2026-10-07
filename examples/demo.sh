#!/usr/bin/env bash
# A four-person team in a throwaway directory, start to finish.
# No API key, no network, no server.
#
# In real use each person's agent runs these commands and makes the routing
# decisions with its own model. Here the script plays every agent, so the
# decisions are written out by hand.
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
rm .tl/me   # one machine plays everyone, so identity comes from TL_ME
head -6 people/dave.md

say "Their agents write to the log. Nobody picks recipients, except where an answer is needed."
tick; A=$(as alice write "Login endpoint is done, tests pass (commit 3f2a91c). Waiting for review.")
tick; B=$(as bob write "Need the pricing proposal by next Wednesday. @carol can you do it?")
tick; C=$(as carol reply "$B" "Pricing proposal will be ready Monday. Also, I think we should build the enterprise tier first.")
tick; D=$(as alice write "@dave should the enterprise tier support SSO at launch? Need your call before I start.")
tick; ./tl log

say "Bob's agent touches the log next, so it does hub duty. There is no hub server."
tick; as bob hub

say "It decides with the model it already is, and records each decision."
tick; as bob route "$A" "bob:action:owns review"
tick; as bob route "$C" "dave:fyi:proposes changing what we build first"
tick; as bob route --none "$B" "$D"

say "Bob's inbox: Alice never mentioned him. The routing put her entry there."
tick; as bob inbox

say "Bob reviews. His reply closes the request and goes back to Alice."
tick; R=$(as bob reply "$A" "Reviewed, approved.")
tick; as bob route --none "$R"
tick; as alice inbox

say "Who is waiting on whom."
tick; ./tl status

say "26 hours later Dave opens his laptop. He never answered Alice, so his own agent's hub pass brings it back."
export TL_NOW="2026-10-07T11:30:00"
as dave hub
as dave inbox

say "Done. The team space is in $TEAM"
