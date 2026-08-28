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

`reference.md` carries these rules worked all the way through — the same shape, never a fragment.

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

## Highest-risk rules

These are violated most often, even when everything else is correct. Fix these first. Rule 0 — everything is in English — is the sixth highest-risk rule; it already has its own section above and isn't repeated here.

### 1. Never swallow a failure

A caught error that becomes a hardcoded success, a default value, or a `null` return is worse than an uncaught one: it looks like everything is fine, and the next person to touch this code has no reason to doubt it. Every branch of a fallible function returns the same shape, so the caller can't reach for the value without confronting the failure.

```typescript
// ❌ BAD — the catch path returns a "successful-looking" shape; callers can't
// tell "not found", "network timeout", and "success" apart — they all render as null
async function fetchInvoice(invoiceId: string): Promise<Invoice | null> {
  try {
    const res = await http.get(`/invoices/${invoiceId}`);
    return res.data;
  } catch (err) {
    logger.warn("could not load invoice, returning null", err);
    return null;
  }
}

const invoice = await fetchInvoice(id);
if (!invoice) return renderEmptyState(); // silently hides a 500 as an empty invoice

// ✅ GOOD — every branch returns the same Result shape; the caller decides
// what to do with the failure instead of having it decided for them
async function fetchInvoice(invoiceId: string): Promise<Result<Invoice, InvoiceError>> {
  try {
    const res = await http.get(`/invoices/${invoiceId}`);
    return { ok: true, value: res.data };
  } catch (err) {
    return { ok: false, error: toInvoiceError(err) };
  }
}

const result = await fetchInvoice(id);
if (!result.ok) return renderError(result.error);
renderInvoice(result.value);
```

### 2. Change hygiene

An edit isn't finished until what it made pointless is gone: the helper nothing calls anymore, the comment describing behavior that no longer exists, the branch that used to matter. Leaving them behind hands the next reader a choice between two stories about what the code does.

```ruby
# ❌ BAD — the discount moved from percentage-based to flat cents, but the old
# helper and the comment describing the old behavior were left behind
class Order
  # Applies the loyalty discount as a percentage of the subtotal
  def apply_discount
    self.total_cents = subtotal_cents - flat_discount_cents
  end

  private

  def percentage_discount_cents
    (subtotal_cents * loyalty_percentage).round
  end
end

# ✅ GOOD — the comment matches the code that ships; the dead helper is gone
class Order
  # Applies the loyalty discount as a flat amount in cents
  def apply_discount
    self.total_cents = subtotal_cents - flat_discount_cents
  end
end
```

### 3. Self-contained tests

The data under assertion is built inside the test body, not handed down by a shared fixture — a reader who opens only this test should be able to tell what's being tested and why the expected value is what it is, without a trip to `conftest.py`. Fixtures stay reserved for harness wiring: a db connection, an http client, a tmp dir.

```python
# ❌ BAD — the fixture builds the exact data under assertion; the test reads
# "assert == 4_500" with no visible reason why 4_500 is the right number
@pytest.fixture
def rushed_shipment():
    shipment = Shipment(weight_kg=3, distance_km=150)
    shipment.apply_rush_surcharge()
    return shipment


def test_apply_rush_surcharge(rushed_shipment):
    assert rushed_shipment.cost_cents == 4_500


# ✅ GOOD — the data under assertion is built in the test body; readable
# standalone, detached from conftest.py
def test_apply_rush_surcharge():
    shipment = Shipment(weight_kg=3, distance_km=150)

    shipment.apply_rush_surcharge()

    # 3kg × 150km × 10 cents/kg·km
    assert shipment.cost_cents == 4_500
```

### 4. Application boundaries

A service that queries another service's tables directly has no boundary — a column rename on either side breaks the other silently, and nothing in this repo can tell you it happened. Read another app's data through its API or an event it publishes; never through its database.

```sql
-- ❌ BAD — the orders service reaches directly into the auth service's schema;
-- a column rename in auth.users breaks this query with no warning
SELECT o.id, o.total_cents, u.email, u.full_name
FROM orders.orders o
JOIN auth.users u ON u.id = o.user_id;

-- ✅ GOOD — orders keeps only the id it owns; email and name come from
-- auth's published API instead of being read out of its tables:
--   auth_client.get_user(o.user_id) -> { email, full_name }
SELECT o.id, o.total_cents, o.user_id
FROM orders.orders o;
```

### 5. Single level of abstraction

Each function does one thing at one altitude. When a function mixes "what to do" with "how to do it" — orchestration next to raw loops and nested conditionals — extract the "how" into named helpers so the top-level function reads like a table of contents.

```go
// ❌ BAD — validation, pricing math, and notification are all inline, with
// conditionals nested three deep
func ProcessOrder(o *Order) error {
	if len(o.Items) == 0 {
		return errors.New("order has no items")
	}
	total := 0
	for _, item := range o.Items {
		if item.Quantity > 0 {
			if item.UnitPriceCents > 0 {
				total += item.Quantity * item.UnitPriceCents
			} else {
				return errors.New("invalid unit price")
			}
		}
	}
	o.TotalCents = total
	if o.CustomerEmail != "" {
		msg := fmt.Sprintf("Your order total is $%.2f", float64(total)/100)
		if err := mailer.Send(o.CustomerEmail, "Order confirmed", msg); err != nil {
			return err
		}
	}
	return nil
}

// ✅ GOOD — one thing at one altitude; each step is a named helper, and the
// same rules (zero-quantity items are skipped, not validated or summed) carry
// through unchanged
func ProcessOrder(o *Order) error {
	if err := validateItems(o.Items); err != nil {
		return err
	}
	o.TotalCents = totalCents(o.Items)
	return notifyCustomer(o)
}

func validateItems(items []Item) error {
	if len(items) == 0 {
		return errors.New("order has no items")
	}
	for _, item := range items {
		if item.Quantity > 0 && item.UnitPriceCents <= 0 {
			return errors.New("invalid unit price")
		}
	}
	return nil
}

func totalCents(items []Item) int {
	total := 0
	for _, item := range items {
		if item.Quantity > 0 {
			total += item.Quantity * item.UnitPriceCents
		}
	}
	return total
}

func notifyCustomer(o *Order) error {
	if o.CustomerEmail == "" {
		return nil
	}
	msg := fmt.Sprintf("Your order total is $%.2f", float64(o.TotalCents)/100)
	return mailer.Send(o.CustomerEmail, "Order confirmed", msg)
}
```

## Quick reference — full checklist

### A. Foundations
1. **Match the surrounding code** — consistency outranks individual preference.
2. **Single level of abstraction** — one thing at one altitude; extract named helpers; no nested conditionals.
3. **Intention-revealing names, no abbreviations.**
4. **YAGNI** — no speculative abstraction, no parameter, flag, or config entry added for a caller that does not exist yet. (core-only)

### B. Data & control flow
5. **Name the value before you use it** — bind a computed value to a well-named variable before placing it in a literal or passing it on.
6. **Accept the narrowest input you need** — a function that reads only an id takes the id, not the whole entity.
7. **Be exhaustive in branching** — enumerate the real shapes; no blanket catch-all that swallows the case you did not foresee.

### C. Errors
8. **Never swallow a failure** — propagate a fallible result rather than replacing it with a hardcoded success, and give every branch of a function the same return shape.
9. **Typed errors, never raw strings** — define the error type before you return it.
10. **One error pipeline per app** — map once at the boundary; every layer in between only propagates.

### D. Contracts & boundaries
11. **Mirror the contract exactly** — optionality, cardinality, and required-ness flow through every layer unchanged; widening a contract hides it and breeds dead checks and ambiguous empty-versus-absent states.
12. **Application boundaries** — never reach into another app's data, never branch on who is calling, never re-implement a rule that lives on the other side, never document another app's behaviour here.

### E. Change hygiene & docs
13. **Change hygiene** — after editing, above all after removing, delete whatever the edit made pointless; comments stay current, and none of them narrates what the code used to be.
14. **Document the public API and keep it true** — a doc that cannot be verified from this repository alone is a boundary leak (#12).

### F. Testing
15. **Self-contained tests** — one group per unit under test; arrange the data under assertion inside the test body; reserve setup for harness wiring; no magic shared fixtures; prefer duplication over indirection; a test must be readable detached from its file.

### G. Workflow
16. **Test first** — write the failing test that defines the behaviour before the implementation, and run it to watch it fail. A test that has never failed has proved nothing. (core-only)
17. **Small steps, always releasable** — identify the smallest next step, make it green, commit, repeat. The codebase is at every moment in a state you could ship. (core-only)
18. **Green build before commit** — format, lint, and the relevant tests pass. Each language skill names its own commands; there is no version of this rule where a red build is committed.
19. **Atomic commits** — one logical change plus its tests, with a semantic prefix (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`) and an English message (#0). (core-only)
20. **PR hygiene** — say what changed and why, in English. When a change alters a convention, cite the rule number so the diff is findable later. (core-only)
21. **Isolate work** — a branch or worktree per unit of work, so an unfinished change never blocks a shippable one. (core-only)

## Red flags — stop and reconsider

- **A non-English identifier, comment, doc line, test name, log message, or error string — anywhere** → rewrite it in English before doing anything else; the only non-English text we allow is a translated value inside a message catalogue (#0).
- Code that reads differently from the file around it — a new naming scheme, a different error-handling shape, a reordered import style — with no functional reason for the difference → match what's already there; raise the inconsistency as its own change instead of fixing it inline (#1).
- A function mixing orchestration with raw loops, nested conditionals, or low-level detail at the same altitude as its high-level steps → extract the "how" into named helpers so the function reads like a table of contents (#2).
- A single-letter variable, an abbreviated name (`usr`, `cfg`, `tmp`), or a name that only makes sense with the surrounding code open → name it for what it holds or does, in full words (#3).
- A new parameter, flag, config entry, or extension point with no caller that uses it yet → delete it; add it when the real caller arrives (#4).
- A computed expression inlined directly into a literal, a call argument, or a condition → bind it to a well-named variable first, then reference the variable (#5).
- A function that reads only one field off a parameter but takes the whole entity → accept that field directly; add a second function or variant for callers that already hold the whole entity (#6).
- A catch-all branch standing in for cases you did not enumerate → list the real shapes and let an unforeseen one fail loudly (#7).
- A function whose final action is fallible, followed by a hardcoded success → return the fallible call's result; give every branch the same shape (#8).
- A function returning a raw string, a generic exception, or an untyped error value → define the error type first, then return an instance of it (#9).
- A second place in the same app translating a low-level error (an HTTP status, a DB error, an SDK exception) into a domain error → map once at the boundary; every other layer only propagates what it received (#10).
- A field made optional, flattened into a list, or defaulted to a placeholder because it wasn't clear whether the source required it → check the actual contract and mirror its optionality, cardinality, and required-ness exactly (#11).
- A comment or doc describing what another application does internally, or a query/import reaching straight into another app's data → describe what this code guarantees instead, and cross the boundary through its published contract (#12, #14).
- A business rule re-derived here because the other side already enforces it too (or left for the other side because it's easier there) → one side owns the rule and exposes the result as a field, an API response, or a typed error; the other side only reads it (#12).
- A just-edited change that left a now-trivial wrapper, an unreachable branch, an unused constant, or a comment describing what the code used to do → remove it in the same change (#13).
- A test whose data or expected values live outside the test body → arrange inside the test; keep setup for harness wiring only (#15).

The workflow rules (#16–#21) don't get red flags here: they describe how a change comes together over time, not a shape a single diff can show — there's no line to point at that says "this wasn't test-first."

## Also enforced mechanically

Formatters and linters catch some of the shape rules above — the ones with a mechanical fingerprint in a single language: an unused import, an inconsistent format, a missing case in a language that can check exhaustiveness. **Nothing mechanically checks Rule 0 (#0), change hygiene (#13), application boundaries (#12), or self-contained tests (#15), in any language.** No tool can tell that a comment describes behavior that no longer exists, that a query reaches into another app's schema, or that an identifier slipped into a language other than English. Those are caught only in review — which is why this checklist is something to run over every diff you read, not a step you delegate to CI.

Each language skill in this marketplace names its own exact command set — the formatter, linter, and test runner that must pass green before a commit (core #18). Consult that skill for the commands to run; this section states only what a tool can and cannot see.
