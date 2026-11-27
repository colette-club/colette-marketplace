# colette-marketplace

Rules for any agent working in this repo.

## Skills

| Skill | When | Install |
| --- | --- | --- |
| `superpowers:writing-skills` | writing or editing a skill | `claude plugin install superpowers@claude-plugins-official` |
| `mattpocock-skills:writing-for-agents` | skills, agents, AGENTS.md, CLAUDE.md or any other agent instructions | `claude plugin install mattpocock-skills@claude-plugins-official` |
| `engineering-review:engineering-principles` | writing or reviewing any code: scripts, hooks, tests | `claude plugin install engineering-review@cadre` |
| `security-audit:security-audit` | hooks, scripts that run commands, secrets or anything security-sensitive | `claude plugin install security-audit@cadre` |
| `mattpocock-skills:tdd` | writing a test before the code | `claude plugin install mattpocock-skills@claude-plugins-official` |

Load each skill whose When fits the work before starting it, and name them in every subagent brief.

A plugin skill's plugin is enabled in `.claude/settings.json`, with its marketplace when that isn't `claude-plugins-official`. `.claude/settings.json` enables `engineering-review` and `security-audit` from the cadre marketplace, not from this checkout's `plugins/`.

To commit a third-party skill for work in this repo (not a skill one of its plugins ships): add it with `npx skills add <owner/repo> -s <name> -a claude-code -y`, move the folder it writes in `.claude/skills/` to `.agents/skills/`, link it back with `ln -s ../../.agents/skills/<name> .claude/skills/<name>`, and add its row here.
