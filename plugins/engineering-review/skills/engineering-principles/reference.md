# Engineering principles — worked examples

A bad/good pair for each group of rules in `SKILL.md`, in neutral pseudocode. [reference-elixir.md](reference-elixir.md) and [reference-dart.md](reference-dart.md) hold the same pairs in Elixir and in Dart: read the file for the language you are writing. When a language skill is loaded, its own examples take precedence.

## Contents

- [A. Names (EP-A1–A5)](#a-names-ep-a1a5): examples for EP-A1, EP-A2
- [B. Functions (EP-B1–B7)](#b-functions-ep-b1b7): examples for EP-B5, EP-B6
- [C. Control flow and errors (EP-C1–C4)](#c-control-flow-and-errors-ep-c1c4): examples for EP-C1, EP-C2, EP-H3
- [D. Design (EP-D1–D13)](#d-design-ep-d1d13): examples for EP-D6, EP-D8, EP-D10, EP-D12, EP-D13
- [E. Boundaries (EP-E1–E6)](#e-boundaries-ep-e1e6): examples for EP-E2, EP-E6
- [F. Comments and docs (EP-F1–F5)](#f-comments-and-docs-ep-f1f5): examples for EP-F1, EP-F4
- [G. Tests (EP-G1–G6)](#g-tests-ep-g1g6): examples for EP-G4, EP-G5
- [H. Concurrency, transactions and side effects (EP-H1–H14)](#h-concurrency-transactions-and-side-effects-ep-h1h14): examples for EP-H5, EP-H6, EP-H8, EP-H10, EP-H11, EP-H12, EP-H14
- [I. Change hygiene (EP-I1–I7)](#i-change-hygiene-ep-i1i7): examples for EP-I1, EP-I3, EP-I4, EP-I6, EP-I7
- [J. Code smells (EP-J1–J18)](#j-code-smells-ep-j1j18): examples for EP-J5
- [K. Data access and performance (EP-K1–K11)](#k-data-access-and-performance-ep-k1k11): examples for EP-K6, EP-K11

## A. Names (EP-A1–A5)

```
✗  d = calc(u)
✓  monthly_rent = rent_for(student)
```

EP-A2: the concept keeps the word the codebase already gives it.

```
✗  mint_participant_token(participant)    // the codebase issues tokens: issue_session_token, issue_password_reset_token
✓  issue_participant_token(participant)
```

## B. Functions (EP-B1–B7)

A name that promises a question must not change anything (EP-B5, EP-B6).

```
✗  valid(booking) { booking.checked = true; save(booking); return booking.start < booking.end }
✓  valid(booking) { return booking.start < booking.end }
```

## C. Control flow and errors (EP-C1–C4)

```
✗  result = charge(order); if result.failed then log(result.error); return OK
✓  return charge(order)                      // or map known errors, forward the rest
```

EP-H3, EP-C1, EP-C2 and EP-A2: every constraint comes back as an error, and a getter keeps its family's contract.

```
✗  insert(participation)                          // the user was deleted: the foreign key raises; "200 for every event" answers 500
✓  insert(participation) maps the foreign key → error(user_gone); the webhook logs it and answers 200, as promised
✗  on unique violation → ok(get(session, user))   // get returns null once the other row is gone: ok(null)
✓  on unique violation → get(session, user)       // ok(participation), or error(not_found), like every getter
```

## D. Design (EP-D1–D13)

Minimal solution first (EP-D12): build for the requirement that exists.

```
✗  ProviderRegistry.register("stripe", StripeProvider); factory.for(config.provider).charge(order)
✓  Stripe.charge(order)          // introduce the abstraction when a second provider is real
```

EP-D6: an external service is reached through an adapter that speaks the app's types.

```
✗  plug: LiveKitWebhook.verify(token, body); service: match event["participant"]["identity"]   // the domain speaks the provider
✓  plug: MediaServer.verify_webhook(token, body) → ok(Connection(activity_id, user_id, role))    // the adapter translates
```

EP-D8: every piece a change adds is read by production code in that change.

```
✗  migration adds host_last_seen_at; mark_host_seen() writes it; a test asserts it   // read by nothing in production
✗  declare event SessionCreated; publish it when a run opens                          // no handler consumes it
✗  if session.status == "ended" then ignore(connection)                              // nothing sets "ended"
✓  each piece arrives with the change whose code reads it: the presence check, the handler, the code that ends a run
```

EP-D10: a rule that varies by actor takes the actor as data, on one path.

```
✗  on ViewerJoined → confirm(viewer);  on HostSeen → confirm(host)    // one rule, a path per actor
✓  record participation(user, role); on ParticipationRecorded → confirm(event.user)
```

EP-D13: the same job, done the codebase's way.

```
✗  minutes = env_of_app(:live).opens_before_minutes      // every other module reads settings through the app's config wrapper
✓  minutes = Config.fetch(:live).opens_before_minutes     // the wrapper async tests override per process
```

## E. Boundaries (EP-E1–E6)

```
✗  if caller == "mobile" then hide(field)
✓  each endpoint's schema exposes what its audience needs; the domain never knows who calls
```

EP-E6: a setting is checked at boot, wherever the code that reads it is on.

```
✗  secret = env("LIVEKIT_WEBHOOK_SECRET")                            // production only, nil in dev: the first webhook crashes
✓  if adapter == LiveKit: secret = required_env("LIVEKIT_WEBHOOK_SECRET")   // the boot stops and names it
```

## F. Comments and docs (EP-F1–F5)

```
✗  // increment the counter
   counter = counter + 1
✓  // The provider redelivers webhooks for 3 days; the unique key makes a replay a no-op.
   insert(event, on_conflict: nothing)
```

A stale doc is a bug (EP-F4): when `list_wishes` stops returning archived wishes, the sentence "lists every wish, including archived ones" changes in the same commit.

## G. Tests (EP-G1–G6)

```
✗  assert archive(wish) is ok
✓  assert archive(wish) == ok(wish with archived_at set); assert reload(wish).archived_at is set
✓  assert archive(already_archived) == error(already_archived)      // each branch has its test
```

EP-G4, per branch: each branch of the changed code names the test that fails when it changes, and behaviour that depends on the environment is tested under a non-default one.

```
✗  tests cover a run that is "live" and one that is "ended"   // narrowing ["waiting", "live"] to ["live"] passes them all
✓  a test per branch: waiting after the activity's end, live, ended, no run yet
✗  compare in_utc(activity.starts_at) with run.activity_starts_at; the test database runs in UTC   // removing in_utc breaks no test
✓  a test sets the database session to America/New_York and still finds the same run
```

EP-G4: an endpoint's promise for every input is tested on its failure paths.

```
✗  tests: a recorded connection → 200; an ignored event → 200          // no test makes recording fail
✓  test: a connection from a user deleted since their token was issued → 200, logged, nothing recorded
```

## H. Concurrency, transactions and side effects (EP-H1–H14)

```
✗  transaction { insert(referral); email.send(invite) }
✓  transaction { insert(referral); enqueue(SendInvite) }            // EP-H5, EP-H8
```

```
✗  transaction { for id in cart: lock(product[id]) }                // two carts, opposite orders, deadlock
✓  transaction { lock(products where id in cart, order by id) }     // EP-H6: sorted, all up front
```

```
✗  transaction { insert(order_line(order_id)); update(order[order_id], total) }   // where the foreign-key lock blocks the update: the line locks its order first
✓  transaction { lock(order[order_id]); insert(order_line(order_id)); update(order[order_id], total) }   // EP-H11
```

```
✗  transaction { lock(product[id]); worker.run(refresh_price, id).wait() }   // the worker needs product[id] on its own connection
✓  transaction { lock(product[id]); update(product[id]) }; enqueue(RefreshPrice, id)   // EP-H12: nothing waits while the lock is held
```

EP-H14 and EP-H10: the event carries what happened, and only what matters once publishes one.

```
✗  stamp_host_seen(session) publishes HostSeen(activity_id)              // on every connection and every 5-minute check
   on HostSeen → confirm(host_of(load(activity_id)))                     // the organizer when the job runs, not who connected
✓  stamp_host_seen(session) writes the stamp, nothing else
   record participation(user, role) publishes ParticipationRecorded(activity_id, user_id, role)   // once per run
   on ParticipationRecorded → confirm(event.user_id)                     // who connected, as it happened
```

## I. Change hygiene (EP-I1–I7)

```
✗  fetch(id) { return get(id) }     // left behind after the refactor made it a pass-through
✓  (deleted; callers use get(id))
```

EP-I3 — the check stays on; the code changes:

```yaml
# ✗ — the security scan no longer blocks a merge
- run: npm audit --audit-level=high
  continue-on-error: true

# ✓ — it still blocks; a known advisory is ignored by id, with the reason in the PR
- run: npm audit --audit-level=high
```

EP-I4 — one feature per change, each one deployable and usable:

```
✗  one change, 31 code files: rename Wish to MemberWish, archive a wish, remind members of open wishes
✓  1. rename Wish to MemberWish          14 code files, no behaviour change
   2. archive a wish                      5 code files
   3. remind members of open wishes       9 code files
```

EP-I6: a migration that may have run is final; the schema moves forward.

```
✗  edit 20261001_create_live_sessions: add role to live_participations   // production ran it last week and never gets the column
✓  new 20261028_add_role_to_live_participations: add role               // every database runs the same sequence
```

EP-I7: a change to what rows mean names every reader.

```
✗  record participation(host, role: "host")            // count_participants, "members who took part", now counts the host
✓  the change lists count_participants, the run summary and the stacked PR that reads them, and counts role "viewer" there
```

## J. Code smells (EP-J1–J18)

Feature envy (EP-J5 → EP-D2): the logic moves to the data it uses.

```
✗  invoice_total(invoice) { return invoice.lines.sum(l -> l.price * l.qty) - invoice.customer.discount }   // in a controller
✓  invoice.total()                                                                                          // on the invoice
```

## K. Data access and performance (EP-K1–K11)

```
✗  for listing in listings: listing.host = load_host(listing.host_id)      // 1 + N queries
✓  hosts = load_hosts(ids(listings)); attach(listings, hosts)              // 2 queries
```

EP-K11: the query builder's constructs; raw SQL only for what it cannot express.

```
✗  where("NOT EXISTS (SELECT 1 FROM live_sessions AS later WHERE later.activity_id = ? AND …)")   // a table name in a string
✓  where(not exists(Session as later where later.activity_id == outer.activity_id and row(later) > row(outer)))   // only the row comparison stays raw
```
