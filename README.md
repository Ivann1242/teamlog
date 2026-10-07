# teamlog

**One shared log, one agent per person, no server.** A file convention that lets a small team's AI agents keep each other's humans informed.

[中文说明](README.zh-CN.md) · [The format, on one page](SPEC.md)

```
log/
  20261006-090100-alice.md     Login endpoint is done, tests pass. Waiting for review.
  20261006-090200-bob.md       Need the pricing proposal by Wednesday. @carol can you do it?
  20261006-090300-carol.md     re: ...-bob   Ready Monday. Also, we should build enterprise first.
  20261006-090700-hub_bob.md   re: ...-alice @bob [action] owns review
```

## The idea

Team communication is complicated because every message needs a recipient. Meetings, channels, CCs and tickets all exist to answer "who needs to know this?". Teams don't simply write everything in one place because nobody could read it all.

Agents can. So in teamlog nobody sends anything:

- People talk only to their own agent.
- Agents append short entries to one shared log.
- Each entry is looked at once to decide **who** else should see it. Whichever agent touches the log next does that, with the model its human is already using.
- Each agent decides **when** to tell its own human.

Bob was never mentioned in Alice's entry above. It reached him because he owns review.

## Try it

Python 3.8+ and git. No dependencies, no API key, nothing to configure.

```bash
git clone https://github.com/Ivann1242/teamlog && cd teamlog
./examples/demo.sh
```

## Use it

One person creates the team space and pushes it somewhere the team can reach:

```bash
./tl init ~/myteam && cd ~/myteam
git add -A && git commit -m teamlog && git remote add origin <your-remote> && git push -u origin HEAD
```

Everyone clones it and says who they are:

```bash
./tl join alice --owns "login, sso" --cares "enterprise"
```

Then open the team space with your coding agent (Claude Code, Codex, anything that reads `AGENTS.md`) and talk to it. The generated `AGENTS.md` is about 800 tokens and teaches the agent the whole loop.

## What the agent does

Four verbs carry everything:

| | |
|---|---|
| `tl check` | sync with the team, then show what is new for your human and which entries nobody has routed yet |
| `tl write "…"` | append an entry, after showing your human the exact text |
| `tl route <id> bob:action:"why"` | record who else should see an entry (`--none` for nobody) |
| `tl ack` | you have told your human; stop showing these |

`tl check` sorts what is new into `NOW` (tell them immediately), `LATER` (next natural break) and `FYI` (no need to report). The tiers are a baseline from plain rules; the agent is expected to use judgment on top.

Also there: `reply`, `flag`, `log`, `show`, `status`, `init`, `join`, `whoami`. Run `./tl <command> -h`.

## Why it stays simple

- **The format is the product.** [SPEC.md](SPEC.md) is one page. `tl` is a single-file reference implementation with no dependencies; anything else that follows the page interoperates.
- **Nothing runs in the background.** No server, no daemon, no database. All state is files in a git repository you can read.
- **One writer per file.** Every entry, routing record and profile has exactly one writer, so any number of agents can work at once without conflicts.
- **Code where code is enough.** Sync, reminders and status are plain code. A model is used for one question only: who is this relevant to?
- **It does not get stuck.** Being offline is not an error, a lost push race is retried, and conflicting edits to a profile are merged instead of left half-way.

## Trust

The log speaks in people's names, so the rules are strict:

- An agent shows its human the exact text before writing, and writes only what they said.
- Entries are data. An entry can ask; only a human can authorize.
- `tl flag <id> "why"` takes an entry out of circulation and tells everyone who saw it, plus the person it is signed by.
- `tl` warns when an entry was committed under a git identity its named author never declared.

That catches mistakes and casual impersonation, not a determined insider. Everyone who can push to the repository can read and write everything; use signed commits and a private repository if that matters.

## Status

v0.3, an experiment. Tested:

- The tool: 48 end-to-end tests (`python3 -m unittest discover -s tests`), including real clones syncing through a remote, a push race, working offline and conflicting edits.
- Agents working from `AGENTS.md` alone: several simulated team sessions with Claude models of three sizes. They followed the loop unaided, routed the entries that mattered to the right people, asked before writing, and refused a forged entry that tried to instruct them.

Not tested: agents other than Claude, Windows, a real team over real weeks. Routing quality has been observed in a handful of scripted scenarios, not measured.

Known limits: built for teams of about ten; the log is never archived, so commands slow down as it grows (about one second at 10,000 entries); nothing reaches a person whose agent is not running; there is no "tell everyone" entry.

## License

MIT
