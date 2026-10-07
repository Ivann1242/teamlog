# The teamlog format

Version 0.5. This page is the whole format. Anything that reads and writes files this way interoperates; `tl` is one implementation of it.

A team space is a directory:

```
log/<id>.md         entries and routing records; append-only
people/<name>.md    one profile per teammate
hub/seen-<name>     ids of the entries <name>'s agent has made a routing decision for
```

Nothing else belongs in a team space. What is private to one machine (who you are there, what you have acknowledged) is kept outside it, so the space can be shared by any means that syncs a folder.

## Where a team space lives

Normally inside the directory the team works in, under the name `.teamlog`, and it is found the way `.git` is: by walking up from wherever you are.

- In a git project, `.teamlog/` is a worktree of a branch named `teamlog` that shares no history with the code. The log then travels through the project's own remote with the project's own permissions, is the same on whichever code branch each person has checked out, and never appears in the code's history. Each clone lists `.teamlog/` in `.git/info/exclude`.
- In a plain folder, `.teamlog/` is an ordinary subfolder, shared however the folder is shared.

A team space may also stand alone, as its own directory or repository, for a team that shares no folder.

## Names

A name matches `[a-z][a-z0-9_]*`. Names beginning with `hub` are reserved for routing.

## Entries

An entry is a file `log/<id>.md` where `<id>` is

```
<YYYYMMDD>-<HHMMSS>-<author>[-<n>]
```

in UTC. `-<n>` (2, 3, ...) separates entries by the same author in the same second.

The content is free text. If its first line is `re: <id>`, the entry is a reply to that entry, and that line is not part of the text.

Entries are never changed or deleted. A correction is a reply.

Inside the text:

| Written | Meaning |
|---|---|
| `@name` | asks `name` to act; this is a *request*, open until `name` replies |
| `cc @name` or `抄送 @name` | informs `name`; not a request |
| `#decision` or `#决定` | the entry records a decision |
| `#closed` (also `#done`, `#关闭`, `#完成`) in a reply by the original's author | closes every request of the original |
| `#flag <why>` in a reply | the original must not be acted on |
| `#unflag` in a reply by whoever flagged it | lifts the flag |

An `@` that is part of an e-mail address is not a mention. Unknown `#tags` are ordinary text.

## Routing records

A routing record is an entry whose author is `hub_<name>` (written by `<name>`'s agent) or `hub` (written with no identity). Its first line is `re: <id>`; each following line is one of

```
@<name> [action] <reason>
@<name> [fyi] <reason>
@<name> [reminder] <text>
```

`action` creates a request for `<name>` on the entry referred to; `fyi` only shows it to them. For a given entry and person, the earliest record wins and later ones are ignored, so two agents routing the same entry cannot disagree destructively.

Deciding that nobody else needs an entry writes no record. In every case the agent adds the entry's id to its own `hub/seen-<name>`, one id per line. An entry *needs routing* while its id is in no `hub/seen*` file and it is not flagged.

A reply to a routing record counts as a reply to the entry that record refers to.

## Requests

A request is a pair (entry, person). It exists when the entry mentions the person without `cc`, or a routing record marks them `action`. It is open until one of:

- the person writes a reply to the entry (any reply);
- the entry's author closes it;
- the entry is flagged.

Only people who have a profile take part. A mention of anyone else creates nothing.

## Profiles

`people/<name>.md` is free Markdown for agents to read. Tools read only lines of the form `key: a, b, c`:

| Key | Meaning |
|---|---|
| `owns` (`负责`) | what `name` is responsible for |
| `cares` (`关心`) | what `name` wants to hear about |
| `ignores` (`不关心`) | what should not be routed to `name` |
| `interrupt` (`打断`) | what is worth interrupting `name` for |
| `git` | e-mail addresses `name` commits with |

Unknown keys are ignored.

## One writer per file

Every shared file has exactly one writer: an entry belongs to its author, a routing record and `hub/seen-<name>` to `<name>`'s agent, a profile to its owner. This is what lets any number of agents work at the same time over plain file sync without conflicts.

## Identity

The format does not authenticate anyone. With git, an implementation can compare the commit author of `log/<id>.md` with the `git` line of the named author's profile and warn on a mismatch. That catches mistakes and casual impersonation, not a determined one; use signed commits when it matters.

## Left open on purpose

- How files are synchronised. Git is assumed; anything that syncs a directory works.
- How an agent decides who should see an entry, and when to tell its human.
- What a human or an agent sees. `tl check` suggests three tiers (NOW, LATER, FYI); they are advice, not part of the format.
- Access control. Everyone who can read the directory can read everything.
