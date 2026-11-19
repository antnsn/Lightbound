# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->

## Git flow: main is protected

`main` only takes changes through a pull request (GitHub ruleset "main": signed commits, no force
push, no deletion, 0 approvals needed). The maintainer doesn't work on the code: Claude opens, and
merges, its own pull requests. Wherever these instructions say `git push`, it means:

```bash
git switch main && git pull --rebase   # start from an up-to-date main
git switch -c <topic>                  # one branch per piece of work
git commit ...                         # the change and its .beads/issues.jsonl together
git push -u origin <topic>
gh pr create --fill                    # body ends with the Claude Code attribution line
gh pr merge --squash --delete-branch   # after the checks above (Codex review, lint, tests) pass
git switch main && git pull --rebase
```

- Squash merges are signed by GitHub, so they pass the signature rule.
- The docs wiki builds when the merge lands on main.
- Release tags are not covered by the ruleset: tag the merged commit on main, then push the tag.
- There is no Dolt remote: skip `bd dolt push`.


## Build & Test

No build step: WoW loads the .lua files directly. Before committing, from this folder:

```bash
for f in *.lua; do luac5.1 -p "$f" || echo "syntax error: $f"; done   # syntax (Lua 5.1, like the client)
~/.luarocks/bin/luacheck .                                            # lint, config in .luacheckrc
```

A new name in luacheck's "undefined variable" warnings is either a typo or WoW API not yet in
`.luacheckrc`: check it exists on Forever (many legacy globals are gone there) before adding it.
Nothing replaces an in-game test: `/reload` for changed files, a client restart for new files.

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

_Add your project-specific conventions here_
