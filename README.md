# teamlog

**One shared log, one hub, one agent per person.** A team-communication convention for small teams where everyone works with an AI agent.

[中文说明](README.zh-CN.md)

## The idea

Team communication is complicated because every message needs a recipient. The sender has to decide who needs to know, when, and in what form. Meetings, channels, CCs and tickets all exist to solve that routing problem.

Teams don't simply write everything down in one place because nobody could read it all. Agents can.

So in teamlog nobody sends anything:

- People talk only to their own agent.
- Agents append short entries to one shared log.
- A **hub** reads every new entry once and decides **who** else should see it.
- Each person's **worker agent** reads what is addressed to them and decides **when** to tell its human.

```
log/
  20261006-090100-alice.md   Login endpoint is done, tests pass. Waiting for review.
  20261006-090200-bob.md     Need the pricing proposal by Wednesday. @carol can you do it?
  20261006-090300-carol.md   re: ...-bob   Ready Monday. Also, we should build enterprise first.
  20261006-090600-hub.md     re: ...-alice @bob [action] owns: review
```

Bob was never mentioned in Alice's entry. The hub routed it to him because he owns review. That is the whole mechanism.

## Try it

Needs Python 3.8+ and git. No dependencies, no API key.

```bash
git clone https://github.com/Ivann1242/teamlog && cd teamlog
./examples/demo.sh
```

The demo plays a four-person team in a temporary directory: entries are written, the hub routes them, a reply closes a request, and an unanswered request comes back 26 hours later.

## Use it with your team

One person creates the team space and pushes it to a git remote the team can reach:

```bash
./tl init ~/myteam          # creates log/, people/, AGENTS.md and a copy of tl
cd ~/myteam
git remote add origin <your-remote> && git add -A && git commit -m "teamlog" && git push -u origin HEAD
```

Everyone clones that repository and says who they are:

```bash
./tl join alice --owns "login, sso" --cares "enterprise"
```

Then open the team space with your coding agent (Claude Code, Codex, or anything that reads `AGENTS.md`). `AGENTS.md` tells it how to act as your worker agent: check the inbox at the start of a session, write entries when you finish or need something, and tell you things in the right tier. You can also drive it by hand:

```bash
./tl write "Login endpoint is done, tests pass. Waiting for review."
./tl inbox
./tl reply <id> "Reviewed, approved."
./tl sync                   # git pull, commit the log, push
```

One machine runs the hub. Exactly one:

```bash
./tl hub --watch 300 --sync     # a pass every 5 minutes, pulling before and pushing after
```

## How it works

```
team/
  log/              append-only entries, the single source of truth
  people/alice.md   one file per person: owns, cares, ignores, interrupt + free notes
  STATUS.md         rebuilt by the hub: waiting / latest / decided
  hub/seen          which entries the hub has already routed
  AGENTS.md         instructions for worker agents
  tl                the tool, one file
```

An entry is a Markdown file named `<UTC time>-<author>.md`. Its optional first line `re: <id>` makes it a reply. That is the whole format.

| | Hub (one per team) | Worker agent (one per person) |
|---|---|---|
| Answers | **Who** should see this entry? | **When** do I tell my human? |
| Reads | every new entry, once | entries that mention its human, or that the hub routed to them |
| Writes | routing entries, reminders, `STATUS.md` | its human's progress, requests, decisions |
| Never | decides, sets priorities, speaks for anyone | promises or decides on its human's behalf |

Conventions inside an entry:

- `@name` asks that person to act. The request stays open until they reply.
- `cc @name` tells them without asking for anything.
- `#decision` puts the entry in the Decided section of `STATUS.md`.
- A reply from the author containing `#closed` closes their own request.

The inbox sorts what is new into three tiers:

| Tier | Meaning | What lands here |
|---|---|---|
| `NOW` | tell your human immediately | reminders about requests they have not answered; anything matching their `interrupt` keywords |
| `LATER` | bring up at the next natural break | open requests; replies to their entries |
| `FYI` | do not report, remember | things worth knowing with nothing to do |

The CLI's tiers are a baseline computed by plain rules. The worker agent is expected to use judgment on top, as `AGENTS.md` describes.

Three rules keep it robust:

1. **`@` does not go through the hub.** Worker agents read mentions directly. The hub only handles what was not mentioned, so the two paths fail independently.
2. **The hub holds no private state.** Everything it knows is in the repository. Delete `hub/seen` and it re-derives the same routes without duplicating them.
3. **Code where code is enough.** Reminders and `STATUS.md` are plain code. Only "who is this relevant to" needs a model.

## Routing with a model

By default the hub routes by matching each person's `owns` and `cares` keywords against the entry. That needs no setup, and it is crude: it only finds literal matches.

Point `TL_LLM` at any command that reads a prompt on stdin and prints an answer, and the hub asks it instead:

```bash
export TL_LLM="claude -p --model haiku"
./tl hub
```

The hub sends the entry and everyone's profile, and expects a JSON array like `[{"to":"bob","kind":"action","why":"owns code review"}]`. If the command fails or the answer does not parse, that entry falls back to keyword routing and the hub says so.

Notes:

- Run the hub from a normal terminal. `claude -p` refuses to start inside another Claude Code session, so a hub launched by your coding agent will fall back to keywords.
- Entries are treated as data. The model's answer is filtered too: only known teammates and the kinds `action` and `fyi` survive.

## Commands

```
tl init [dir]            create a team space
tl join <name>           set who you are on this machine, create your profile
tl write "text"          append an entry (or pipe text on stdin)
tl reply <id> "text"     answer an entry
tl inbox [--peek|--json] new items for you, in three tiers
tl show <id>             an entry and its replies
tl log [-n N] [--hub]    recent entries
tl status                who is waiting on whom, latest per person, decisions
tl hub [--watch S] [--sync] [--llm CMD] [--no-llm] [--remind-hours H] [--remind-max N]
tl sync                  git pull, commit the log, push
```

An `<id>` may be shortened to any unique part of it. Environment: `TL_ME` (identity), `TL_ROOT` (team space), `TL_LLM` (model command), `TL_REMIND_HOURS` (default 24).

## Status and limits

This is v0.1, an experiment. What is and is not verified:

- The tool's behaviour is covered by end-to-end tests (`python3 -m unittest discover -s tests`), including two clones exchanging entries through a git remote.
- Model routing is tested against a stub command. **The quality of routing by a real model has not been evaluated yet.** That is the bet the whole design rests on, and the next thing to measure.
- The worker-agent instructions in `AGENTS.md` have not been tested across different agents yet.

Known limits:

- Built for small teams, roughly ten people or fewer. There is no partitioning of the log.
- The log is open to everyone with access to the repository. There are no private entries and no access control.
- Everyone is trusted. Nothing stops a teammate from writing an entry under another name.
- Exactly one hub may run. Two hubs would write duplicate routes.
- Keyword routing does substring matching, so keep keywords short.

## License

MIT
