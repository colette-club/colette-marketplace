# Testing — rules #52 to #54 in practice

Rule numbers (`#50`) refer to `SKILL.md`. The worked tests cover the referrals feature of `reference.md`. A Service's tests are in `concurrency.md`; GraphQL tests are in `graphql.md`.

## Self-contained tests (#54)

A test is understandable on its own: a reader never scrolls up to a `setup` block, a module attribute or a shared fixture to learn what is under test or why the assertion holds.

- **Build the domain data each test needs inside that test** (`insert(:user)`, explicit attrs), passing the fields the assertion depends on explicitly and inline. Entities created in `setup` and injected through the context (`test "...", %{referrer: referrer}`) hide what matters and make every test in the block carry data it may not need. Where sibling tests cover different outcomes, the **fixture that varies** is the only thing that differs between them (`invites_remaining: 1` against `0`), so the cause of each outcome is visible in the diff between the two tests.
- **`setup` is for harness wiring that is never the subject of an assertion**: Mox mode (`set_mox_from_context`, `verify_on_exit!`), a `conn`, sandbox or config, a feature flag. Even a justified `setup` rots: fixtures accrete as tests are added and their consumers scatter across the module, so nothing ever looks unused, and no single edit reveals it to #56.
- **Literal values are inlined**, in place of module attributes for shared test data or "magic" attrs (`@valid_attrs`, `@user_id`), so the relation between input and assertion reads top to bottom in one place.
- **Duplication over indirection.** The question is "how much context does someone need to understand this test?", not "how do I remove every repeated line?". A few repeated `insert(:user)` lines are fine. When repetition hurts, extract a **named helper the test calls**, visible in the body: a factory (#50), or a small `defp unavailable_product/0` that names a domain intent. A helper runs because the test calls it; a `setup` runs because the test happens to live in that module.
- **Set the environment the behaviour depends on (EP-G4).** The test database's session runs in UTC and Gettext in the default locale, so a `fragment("? AT TIME ZONE 'UTC'", …)` or a locale-dependent format passes every test with or without its conversion. Give each one a test that sets another value inside the test body, `Repo.query!("SET LOCAL TIME ZONE 'America/New_York'")` (the sandbox's transaction scopes it to the test) or `Gettext.put_locale("fr")`, or pass the clock in as an argument.

The check: paste the `test` block alone into a PR comment. A reviewer who cannot tell why it passes is reading a test that is not self-contained. Tests are mostly read that way now: quoted in a review, pasted into an agent's context, dropped into a CI failure report.

```elixir
# ❌ BAD — data and expectations hoisted out of the test; the reader must scroll away to understand it
describe "create_referral/2" do
  @attrs %{email: "friend@example.com"}

  setup do
    %{referrer: insert(:user)}
  end

  test "creates a referral", %{referrer: referrer} do
    assert {:ok, referral} = Accounts.create_referral(Map.put(@attrs, :referrer_id, referrer.id))
    assert referral.email == @attrs.email
  end
end

# ✅ GOOD — each test carries its own arrange and its own expected values;
# the siblings differ only in the fixture that drives the outcome
describe "create_referral/2" do
  test "when the referrer has invites left" do
    referrer = insert(:user, invites_remaining: 1)

    assert {:ok, referral} =
             Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})

    assert referral.email == "friend@example.com"
  end

  test "when the referrer is out of invites" do
    referrer = insert(:user, invites_remaining: 0)

    assert {:error, %Errors.NoInvitesRemainingError{}} =
             Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})
  end
end
```

## A context function's tests (#53)

One `describe` per function, named `"fun/arity"`: `get_referral/2` and `list_referrals/3` each get their own.

```elixir
# test/my_app/accounts/referrals_test.exs
use MyApp.DataCase, async: true
use ExEventBus.Testing, ex_event_bus: MyApp.EventBus

describe "create_referral/2" do
  test "when the attrs are valid" do
    referrer = insert(:user)

    assert {:ok, referral} =
             Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})

    assert_event_received(Events.ReferralCreated, args: %{aggregate: %{id: referral.id}})
  end

  test "when the same email was already referred" do
    referrer = insert(:user)
    attrs = %{referrer_id: referrer.id, email: "friend@example.com"}
    assert {:ok, _} = Accounts.create_referral(attrs)

    assert {:error, %Errors.ReferralAlreadyExistsError{}} = Accounts.create_referral(attrs)
  end
end
```

## An event handler's test (#52)

`assert_event_received` proves only that the event was *enqueued*. To prove the handler *runs*, drain the queue with `execute_events/0,1` and assert on the result:

```elixir
# test/my_app/notifications/event_handler/referral_created_test.exs
describe "handle_event/1" do
  test "when a referral is created" do
    referrer = insert(:user)
    {:ok, _} = Accounts.create_referral(%{referrer_id: referrer.id, email: "friend@example.com"})

    assert %{success: 1, failure: 0} =
             execute_events(event_handler: Notifications.EventHandler.ReferralCreated)
  end
end
```
