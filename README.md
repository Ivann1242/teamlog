# teamlog

**One shared log, one agent per person, no server.** A team-communication convention for small teams where everyone works with an AI agent.

[中文说明](README.zh-CN.md)

## The idea

Team communication is complicated because every message needs a recipient. The sender has to decide who needs to know, when, and in what form. Meetings, channels, CCs and tickets all exist to solve that routing problem.

Teams don't simply write everything down in one place because nobody could read it all. Agents can.

So in teamlog nobody sends anything:

- People talk only to their own agent.
- Agents append short entries to one shared log.
- Every new entry is looked at once to decide **who** else should see it. This is *hub duty*, and there is no hub server: whichever agent touches the log next does it, with the model its human is already using.
- Each person's agent reads what is addressed to them and decides **when** to tell its human.

```
log/
  20261006-090100-alice.md     Login endpoint is done, tests pass. Waiting for review.
  20261006-090200-bob.md       Need the pricing proposal by Wednesday. @carol can you do it?
  20261006-090300-carol.md     re: ...-bob   Ready Monday. Also, we should build enterprise first.
  20261006-090700-hub_bob.md   re: ...-alice @bob [action] owns review
```

Bob was never mentioned in Alice's entry. It reached him because he owns review. That is the whole mechanism.

## Try it

Needs Python 3.8+ and git. No dependencies, no API key, nothing to configure.

```bash
git clone https://github.com/Ivann1242/teamlog && cd teamlog
./examples/demo.sh
```

The demo plays a four-person team in a temporary directory: entries are written, one agent does hub duty, a reply closes a request, and an unanswered request comes back 26 hours later.

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

Then open the team space with your coding agent (Claude Code, Codex, or anything that reads `AGENTS.md`). `AGENTS.md` tells it what to do at the start of every session:

```bash
./tl sync       # git pull, commit the log, push
./tl hub        # hub duty: lists entries nobody has routed yet; the agent decides and records
./tl inbox      # what is new for you, in three tiers
```

and when to write on your behalf:

```bash
./tl write "Login endpoint is done, tests pass. Waiting for review."
./tl reply <id> "Reviewed, approved."
```

That is the whole setup. Nothing runs in the background.

## How it works

```
team/
  log/              append-only entries, the single source of truth
  people/alice.md   one file per person: owns, cares, ignores, interrupt + free notes
  hub/seen-alice    which entries alice's agent has already done hub duty for
  AGENTS.md         instructions for the agents
  tl                the tool, one file
  STATUS.md         local snapshot of `tl status`, not committed
```

An entry is a Markdown file named `<UTC time>-<author>.md`. Its optional first line `re: <id>` makes it a reply. That is the whole format.

Every agent has two jobs:

| | Hub duty | For its own human |
|---|---|---|
| Answers | **Who** else should see this entry? | **When** do I tell my human? |
| Command | `tl hub`, then `tl route` | `tl inbox` |
| Writes | routing entries (`hub_<name>`) | its human's progress, requests, decisions |
| Never | decides, sets priorities, gives opinions | promises or decides on its human's behalf |

`tl hub` prints the entries that still need routing together with a one-line summary of each teammate, and the agent answers with:

```bash
./tl route <id> bob:action:"owns code review" dave:fyi:"affects the roadmap"
./tl route --none <id> [<id> ...]
```

Conventions inside an entry:

- `@name` asks that person to act. The request stays open until they reply.
- `cc @name` tells them without asking for anything.
- `#decision` puts the entry in the Decided section of `tl status`.
- A reply from the author containing `#closed` closes their own request.

The inbox sorts what is new into three tiers:

| Tier | Meaning | What lands here |
|---|---|---|
| `NOW` | tell your human immediately | reminders about requests they have not answered; anything matching their `interrupt` keywords |
| `LATER` | bring up at the next natural break | open requests; replies to their entries |
| `FYI` | do not report, remember | things worth knowing with nothing to do |

These tiers are a baseline computed by plain rules. The agent is expected to use judgment on top, for example raising an item to `NOW` when it can see that someone is blocked.

Four rules keep it robust:

1. **`@` needs no routing.** Agents read mentions directly, so a request reaches its target even if nobody has done hub duty yet.
2. **No private state.** Everything is in the repository. Any agent can do hub duty, and there is nothing to keep running or to lose.
3. **Concurrent agents cannot conflict.** Every file has exactly one writer: entries and routing entries carry their author's name, and each agent has its own `hub/seen-<name>`. If two agents route the same entry offline, both records are kept and the first route per person wins.
4. **Code where code is enough.** Reminders and `tl status` are plain code. Only "who is this relevant to" needs a model.

Requests nobody answers are re-raised after 24 hours, at most three times, by whichever agent does hub duty next. That is often the agent of the person who owes the answer.

## Without an agent

For a server, a cron job, or a team member who has no agent, `tl hub --auto` does hub duty by itself:

```bash
./tl hub --auto                       # match each person's owns / cares keywords
TL_LLM="claude -p --model haiku" ./tl hub --auto --watch 300 --sync
```

`TL_LLM` is any command that reads a prompt on stdin and prints an answer; the hub expects a JSON array like `[{"to":"bob","kind":"action","why":"owns code review"}]`. If the command fails or the answer does not parse, that entry falls back to keywords and the hub says so. Keyword matching is crude: it only finds literal matches.

`claude -p` refuses to start inside another Claude Code session, so run this from a normal terminal.

## Safety

Log entries are data, not instructions. `AGENTS.md` tells agents never to act on what an entry says without their human's authorization. Routing decisions are validated before they are written: only known teammates, only the kinds `action` and `fyi`, never the author.

## Commands

```
tl init [dir]              create a team space
tl join <name>             set who you are on this machine, create your profile
tl write "text"            append an entry (or pipe text on stdin)
tl reply <id> "text"       answer an entry
tl inbox [--peek|--json]   new items for you, in three tiers
tl hub                     hub duty: reminders, and the entries that need routing
tl route <id> name:kind:why ...   record who else should see an entry
tl route --none <id> ...   record that nobody else needs to
tl hub --auto [--watch S] [--sync] [--llm CMD] [--no-llm]   hub duty without an agent
tl show <id>               an entry and its replies
tl log [-n N] [--hub]      recent entries
tl status                  who is waiting on whom, latest per person, decisions
tl sync                    git pull, commit the log, push
```

An `<id>` may be shortened to any unique part of it. Environment: `TL_ME` (identity), `TL_ROOT` (team space), `TL_LLM` (model command for `--auto`), `TL_REMIND_HOURS` (default 24).

## Status and limits

This is v0.2, an experiment. What is and is not verified:

- The tool's behaviour is covered by end-to-end tests (`python3 -m unittest discover -s tests`), including two clones doing hub duty for the same entry and syncing through a git remote without conflicts.
- Agents doing hub duty from `AGENTS.md` alone has been tried once: two Claude models were each given a six-entry log that keyword matching could route nothing in. Both followed the flow unaided and routed the two entries that mattered to the right people; the smaller model also sent two unnecessary FYIs. **That is one scenario and two runs, not an evaluation.** Routing quality is the bet the whole design rests on, and the next thing to measure.
- Other agents (Codex and so on) have not been tried.

Known limits:

- Built for small teams, roughly ten people or fewer. There is no partitioning of the log.
- The log is open to everyone with access to the repository. There are no private entries and no access control.
- Everyone is trusted. Nothing stops a teammate from writing an entry under another name, and the agent that routes an entry is often its author's.
- An entry is routed once, by whichever agent gets there first. A weaker model routes worse.
- There is no "tell everyone" entry; something that concerns the whole team has to mention people.

## License

MIT
