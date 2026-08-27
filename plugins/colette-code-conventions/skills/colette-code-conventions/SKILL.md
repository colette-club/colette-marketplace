---
name: colette-code-conventions
description: Use when reading, writing, or editing ANY file in any Colette repository — source in any language, tests, comments, documentation, configuration, and commit or PR text. Carries the language-agnostic engineering rules that the Elixir and Flutter convention skills build on.
file_patterns:
  - "**/*"
---

# Colette Code Conventions

## Overview

These conventions hold in every Colette repository, in every language and every file type: source, tests, comments, documentation, configuration, and commit or PR text. Language-specific skills — Elixir/Phoenix, Flutter/Dart, and any that follow — add to these rules; they never override them. When a rule here is cited elsewhere in the marketplace, it's written `core #N` — this rule is `core #0`.

**Before writing or editing anything, in any repository, check the rules below.**

Three core principles cover most mistakes:

- **Everything we write is in English.** No exceptions — see the next section.
- **A failure is never silently swallowed.** An error is handled, propagated, or logged with enough context to act on it — never caught and discarded, never papered over with a generic fallback that hides what actually went wrong.
- **An edit is not finished until what it made pointless is gone.** Rename the old name everywhere it still appears, delete the code path your change replaced, remove the comment describing behavior that's no longer true. A change that leaves its own obsolescence lying around for someone else to trip over isn't done.

## Rule 0 — everything is in English. No exceptions.

**Every character we author is English**: identifiers, file and directory names, comments and doc comments, test names, log and telemetry messages, error messages and error types, migration and index names, `TODO`s, commit messages, and PR descriptions. This holds no matter who wrote the surrounding code, how short the snippet is, what language or framework the file is in, or how natural a local-language word feels while you're typing it.

A codebase mixing languages costs every reader a translation step, splits naming for a single concept (`prix_ttc` sitting next to `total_price`), silently breaks search (`utilisateur` never matches a grep for `user`), and shuts out every future teammate — and every tool — that reads only English. Consistency here is worth more than any individual word being "clearer" in the author's first language.

The **only** non-English text allowed is translated *values* in a message catalogue — Gettext `.po` files, Flutter's `app_fr.arb`, or equivalent — whose source/default locale is English. Their keys, and every comment or metadata around them, stay English.

Non-English code you did not write is not grandfathered: when you touch a function, file, or test, rename its identifiers and rewrite its comments in English as part of the same change.

```python
# ❌ BAD — French identifiers and comment
# on vérifie que le parrain a encore des invitations
def creer_parrainage(utilisateur_id, invites_restants):
    return invites_restants > 0

# ✅ GOOD
# Referrals are capped by the referrer's remaining invites.
def create_referral(user_id, remaining_invites):
    return remaining_invites > 0
```
