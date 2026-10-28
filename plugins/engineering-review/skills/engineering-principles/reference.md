# Engineering principles — worked examples

One bad/good pair per group, first in neutral pseudocode, then in Elixir, then in Dart. The principle stays the same; only the idiom changes. When a language skill is loaded, its own examples take precedence.

## Contents

- [A. Names (EP-A1–A5)](#a-names-ep-a1a5)
- [B. Functions (EP-B1–B7)](#b-functions-ep-b1b7)
- [C. Control flow and errors (EP-C1–C4)](#c-control-flow-and-errors-ep-c1c4)
- [D. Design (EP-D1–D13)](#d-design-ep-d1d13)
- [E. Boundaries (EP-E1–E6)](#e-boundaries-ep-e1e6)
- [F. Comments and docs (EP-F1–F5)](#f-comments-and-docs-ep-f1f5)
- [G. Tests (EP-G1–G6)](#g-tests-ep-g1g6)
- [H. Concurrency, transactions and side effects (EP-H1–H14)](#h-concurrency-transactions-and-side-effects-ep-h1h14)
- [I. Change hygiene (EP-I1–I7)](#i-change-hygiene-ep-i1i7)
- [J. Code smells (EP-J1–J18)](#j-code-smells-ep-j1j18)
- [K. Data access and performance (EP-K1–K11)](#k-data-access-and-performance-ep-k1k11)

## A. Names (EP-A1–A5)

```
✗  d = calc(u)
✓  monthly_rent = rent_for(student)
```

```elixir
# ✗
def calc(u), do: u.r * 12
# ✓
def yearly_rent(%Student{monthly_rent: monthly_rent}), do: monthly_rent * 12
```

```dart
// ✗
final d = calc(u);
// ✓
final yearlyRent = student.monthlyRent * 12;
```

EP-A2: the concept keeps the word the codebase already gives it.

```
✗  mint_participant_token(participant)    // the codebase issues tokens: issue_session_token, issue_password_reset_token
✓  issue_participant_token(participant)
```

```elixir
# ✗
@callback mint_participant_token(participant()) :: String.t()
# ✓
@callback issue_participant_token(participant()) :: String.t()
```

```dart
// ✗ — the repository says fetch everywhere else
Future<Wish> retrieveWish(String id);
// ✓
Future<Wish> fetchWish(String id);
```

## B. Functions (EP-B1–B7)

A name that promises a question must not change anything (EP-B5, EP-B6).

```
✗  valid(booking) { booking.checked = true; save(booking); return booking.start < booking.end }
✓  valid(booking) { return booking.start < booking.end }
```

```elixir
# ✗ — a predicate that writes
def valid?(%Booking{} = booking) do
  Repo.update!(Booking.check_changeset(booking))
  Date.compare(booking.starts_on, booking.ends_on) == :lt
end

# ✓
def valid?(%Booking{starts_on: starts_on, ends_on: ends_on}),
  do: Date.compare(starts_on, ends_on) == :lt
```

```dart
// ✗
bool isValid() {
  repo.save(this);
  return startsOn.isBefore(endsOn);
}
// ✓
bool get isValid => startsOn.isBefore(endsOn);
```

## C. Control flow and errors (EP-C1–C4)

```
✗  result = charge(order); if result.failed then log(result.error); return OK
✓  return charge(order)                      // or map known errors, forward the rest
```

```elixir
# ✗ — the update can fail; the caller always sees :ok
def archive_wish(%Wish{} = wish) do
  wish |> Wish.archive_changeset() |> Repo.update()
  :ok
end

# ✓ — every shape handled, the failure travels back
def archive_wish(%Wish{} = wish) do
  wish
  |> Wish.archive_changeset()
  |> Repo.update()
  |> case do
    {:ok, wish} -> {:ok, wish}
    {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
  end
end
```

```dart
// ✗ — unexpected error swallowed
} catch (e) {
  print(e);
}
// ✓ — known errors mapped to state, unexpected ones forwarded to one place
} on ValidationError catch (error) {
  emit(state.copyWith(loadingId: "", submitErrorMessage: error.message));
} catch (error, stacktrace) {
  emit(state.copyWith(loadingId: ""));
  Bloc.observer.onError(this, error, stacktrace);
}
```

EP-H3, EP-C1, EP-C2 and EP-A2: every constraint comes back as an error, and a getter keeps its family's contract.

```
✗  insert(participation)                          // the user was deleted: the foreign key raises; "200 for every event" answers 500
✓  insert(participation) maps the foreign key → error(user_gone); the webhook logs it and answers 200, as promised
✗  on unique violation → ok(get(session, user))   // get returns null once the other row is gone: ok(null)
✓  on unique violation → get(session, user)       // ok(participation), or error(not_found), like every getter
```

```elixir
# ✗ — an undeclared foreign key raises; a private get_* returns nil; the race recovery can return {:ok, nil}
|> unique_constraint([:session_id, :user_id])

defp get_participation(session_id, user_id),
  do: Participation |> Query.with_session_id(session_id) |> Query.with_user_id(user_id) |> Repo.one()

{:error, %Ecto.Changeset{errors: [{:session_id, {_, [constraint: :unique, constraint_name: _]}} | _]}} ->
  {:ok, get_participation(session_id, user_id)}

# ✓ — every constraint declared (elixir #7); the getter keeps the family's contract (elixir #15)
|> foreign_key_constraint(:user_id)
|> unique_constraint([:session_id, :user_id])

defp get_participation(session_id, user_id) do
  case Participation |> Query.with_session_id(session_id) |> Query.with_user_id(user_id) |> Repo.one() do
    %Participation{} = participation -> {:ok, participation}
    nil -> {:error, Errors.NotFoundError.new(resource_type: "LiveParticipation")}
  end
end

{:error, %Ecto.Changeset{errors: [{:session_id, {_, [constraint: :unique, constraint_name: _]}} | _]}} ->
  get_participation(session_id, user_id)
```

```dart
// ✗ — its neighbours return a Result; this one returns null, and the caller wraps it as a success
Future<Participation?> getParticipation(String id) => _db.findParticipation(id);
return Result.ok(await getParticipation(id));
// ✓ — the family's contract
Future<Result<Participation>> getParticipation(String id) async {
  final participation = await _db.findParticipation(id);
  return participation == null ? Result.error(NotFound('Participation', id)) : Result.ok(participation);
}
```

## D. Design (EP-D1–D13)

Minimal solution first (EP-D12): build for the requirement that exists.

```
✗  ProviderRegistry.register("stripe", StripeProvider); factory.for(config.provider).charge(order)
✓  Stripe.charge(order)          // introduce the abstraction when a second provider is real
```

```elixir
# ✗ — a behaviour, a registry and a config switch for one provider
@callback charge(Order.t()) :: {:ok, Charge.t()} | {:error, term()}
def provider, do: Application.fetch_env!(:app, :payment_provider)
def charge(order), do: provider().charge(order)

# ✓ — one module; the behaviour arrives with the second provider (or with a test double at the boundary, EP-D6)
def charge(%Order{} = order), do: StripeClient.create_charge(order)
```

EP-D6: an external service is reached through an adapter that speaks the app's types.

```
✗  plug: LiveKitWebhook.verify(token, body); service: match event["participant"]["identity"]   // the domain speaks the provider
✓  plug: MediaServer.verify_webhook(token, body) → ok(Connection(activity_id, user_id, role))    // the adapter translates
```

```elixir
# ✗ — the plug calls the provider's module; the service matches the provider's payload
case App.Live.LiveKitWebhook.verify(token, body) do ... end
def run(%{"event" => "participant_joined", "participant" => %{"identity" => identity}}), do: ...

# ✓ — the configured adapter verifies and translates (elixir #5); past it, only the app's struct
@callback verify_webhook(token :: String.t() | nil, body :: binary()) ::
            {:ok, Connection.t() | :ignored} | {:error, :invalid_signature}
def run(%Connection{activity_id: activity_id, user_id: user_id, role: role}), do: ...
```

```dart
// ✗ — the cubit calls the SDK and keeps its types
final room = await LiveKitClient.connect(url, token);
emit(state.copyWith(participants: room.remoteParticipants.values.toList()));
// ✓ — an interface the app owns; LiveKit's implementation is injected, a fake in tests
final room = await _mediaServer.join(token);
emit(state.copyWith(participants: room.participants));
```

EP-D8: every piece a change adds is read by production code in that change.

```
✗  migration adds host_last_seen_at; mark_host_seen() writes it; a test asserts it   // read by nothing in production
✗  declare event SessionCreated; publish it when a run opens                          // no handler consumes it
✗  if session.status == "ended" then ignore(connection)                              // nothing sets "ended"
✓  each piece arrives with the change whose code reads it: the presence check, the handler, the code that ends a run
```

```elixir
# ✗ — written on every host connection, read by nothing but its own test
def mark_host_seen(%Session{} = session),
  do: session |> Session.host_seen_changeset() |> Repo.update()

# ✓ — left out of this change; the change that closes a live the host left adds the columns, this function and its reader
```

```dart
// ✗ — saved on every heartbeat; no cubit or widget reads it
await _prefs.setString('lastSeenAt', DateTime.now().toIso8601String());
// ✓ — left out until the screen that shows it exists
```

EP-D10: a rule that varies by actor takes the actor as data, on one path.

```
✗  on ViewerJoined → confirm(viewer);  on HostSeen → confirm(host)    // one rule, a path per actor
✓  record participation(user, role); on ParticipationRecorded → confirm(event.user)
```

```elixir
# ✗ — a second event and handler that differ from the viewer's only by the actor
defevents([LiveParticipationRecorded, LiveHostSeen])
# ConfirmViewerAttendance handles LiveParticipationRecorded; ConfirmHostAttendance handles LiveHostSeen

# ✓ — the role is a column of the participation; one event, one handler
|> cast(attrs, [:session_id, :user_id, :role, :first_joined_at])
|> validate_inclusion(:role, ~w(host viewer))
```

```dart
// ✗ — two methods that differ by who acts
Future<void> hostJoined(String userId) async => _confirm(userId);
Future<void> viewerJoined(String userId) async => _confirm(userId);
// ✓ — one method; the role travels as data
Future<void> joined(String userId, ParticipantRole role) async => _confirm(userId, role);
```

EP-D13: the same job, done the codebase's way.

```
✗  minutes = env_of_app(:live).opens_before_minutes      // every other module reads settings through the app's config wrapper
✓  minutes = Config.fetch(:live).opens_before_minutes     // the wrapper async tests override per process
```

```elixir
# ✗ — a second way to read a setting and to default one, beside the codebase's
:app |> Application.fetch_env!(:live) |> Keyword.fetch!(:opens_before_minutes)
String.to_integer(System.get_env("LIVE_OPENS_BEFORE_MINUTES", "15"))

# ✓ — the app's config module and the default idiom config/runtime.exs already uses (elixir #64)
:app |> App.Config.fetch_env!(:live) |> Keyword.fetch!(:opens_before_minutes)
String.to_integer(System.get_env("LIVE_OPENS_BEFORE_MINUTES") || "15")
```

```dart
// ✗ — reads the environment directly, beside the app's Env class
final apiUrl = Platform.environment['API_URL'] ?? '';
// ✓ — the app's Env, which tests override
final apiUrl = Env.apiUrl;
```

Law of Demeter (EP-D7): ask your direct collaborator, don't reach through it.

```dart
// ✗
Text(mainCubit.viewerCubit.state.viewer.address.city.name)
// ✓
Text(viewerState.cityName)   // a getter on the state owns the path
```

## E. Boundaries (EP-E1–E6)

```
✗  if caller == "mobile" then hide(field)
✓  each endpoint's schema exposes what its audience needs; the domain never knows who calls
```

```elixir
# ✗ — the context knows its consumers
def list_activities(client), do: if(client == "mobile", do: public(), else: all())
# ✓ — one domain function; the /api and /admin schemas shape the output
def list_activities(filters), do: Activity |> Query.filtered_by(filters) |> Repo.all()
```

```dart
// ✗ — re-implementing a server rule "for now"
final canBook = activity.seats > activity.bookings.length && !activity.isPast;
// ✓ — ask the API for the decision
final canBook = activity.isBookable;
```

EP-E5 — the old field keeps working until no installed app asks for it:

```elixir
# ✗ — every installed app that still asks for `title` gets an error
field :name, non_null(:string)

# ✓ — add `name`, keep `title` deprecated, remove it once no deployed client uses it
field :name, non_null(:string)
field :title, non_null(:string), deprecate: "Use name.", resolve: fn wish, _, _ -> {:ok, wish.name} end
```

EP-E6: a setting is checked at boot, wherever the code that reads it is on.

```
✗  secret = env("LIVEKIT_WEBHOOK_SECRET")                            // production only, nil in dev: the first webhook crashes
✓  if adapter == LiveKit: secret = required_env("LIVEKIT_WEBHOOK_SECRET")   // the boot stops and names it
```

```elixir
# ✗ — config/runtime.exs: nil allowed, production only, under the domain's key
if config_env() == :prod do
  config :app, :live, livekit_webhook_secret: System.get_env("LIVEKIT_WEBHOOK_SECRET")
end

# ✓ — under the adapter's key, required wherever it is the configured adapter (elixir #5)
if live_adapter == App.Live.Adapters.LiveKit do
  config :app, App.Live.Adapters.LiveKit, webhook_secret: fetch_env!.("LIVEKIT_WEBHOOK_SECRET")
end
```

```dart
// ✗ — read where it is used; an empty value surfaces on the first request
final apiUrl = const String.fromEnvironment('API_URL');
// ✓ — checked once in main(), before the app starts
const apiUrl = String.fromEnvironment('API_URL');
void main() {
  if (apiUrl.isEmpty) throw StateError('API_URL is missing: build with --dart-define=API_URL=…');
  runApp(App(apiUrl: apiUrl));
}
```

## F. Comments and docs (EP-F1–F5)

```
✗  // increment the counter
   counter = counter + 1
✓  // The provider redelivers webhooks for 3 days; the unique key makes a replay a no-op.
   insert(event, on_conflict: nothing)
```

A stale doc is a bug (EP-F4): when `list_wishes` stops returning archived wishes, the sentence "lists every wish, including archived ones" changes in the same commit.

```elixir
# ✗ — the comment repeats the code; the doc still describes the old behaviour
# insert the event
Repo.insert(event, on_conflict: :nothing, conflict_target: :provider_event_id)

@doc "Lists every wish of the member, including archived ones."
def list_wishes(member), do: member |> Wish.Query.for_member() |> Wish.Query.not_archived() |> Repo.all()

# ✓ — the comment says why; the doc changed with the behaviour
# The provider redelivers webhooks for 3 days; the unique index turns a replay into a no-op.
Repo.insert(event, on_conflict: :nothing, conflict_target: :provider_event_id)

@doc "Lists the member's wishes that are not archived, newest first."
def list_wishes(member), do: member |> Wish.Query.for_member() |> Wish.Query.not_archived() |> Repo.all()
```

```dart
// ✗ — the comment restates the code; the doc comment is stale
// wait one second
_search.debounce(const Duration(seconds: 1));
/// Returns every wish, including archived ones.
Future<List<Wish>> wishes() => _api.activeWishes();

// ✓
// The search endpoint accepts one call a second; the debounce keeps typing under that limit.
_search.debounce(const Duration(seconds: 1));
/// Returns the member's wishes that are not archived.
Future<List<Wish>> wishes() => _api.activeWishes();
```

## G. Tests (EP-G1–G6)

```
✗  assert archive(wish) is ok
✓  assert archive(wish) == ok(wish with archived_at set); assert reload(wish).archived_at is set
✓  assert archive(already_archived) == error(already_archived)      // each branch has its test
```

```elixir
# ✗ — passes whatever archive_wish returns inside :ok
test "archives the wish" do
  wish = insert(:wish)
  assert {:ok, _} = Wishes.archive_wish(wish)
end

# ✓
test "when the wish is active" do
  wish = insert(:wish, archived_at: nil)
  assert {:ok, %Wish{archived_at: %DateTime{}}} = Wishes.archive_wish(wish)
end

test "when the wish is already archived" do
  wish = insert(:wish, archived_at: ~U[2026-01-01 00:00:00Z])
  assert {:error, %Errors.WishAlreadyArchivedError{}} = Wishes.archive_wish(wish)
end
```

```dart
// ✗ — asserts the mock returns its own stub; no production code runs
when(() => repo.user()).thenAnswer((_) async => user);
expect(await repo.user(), user);
// ✓ — run the real cubit, assert its state
when(() => mainCubit.userRepo).thenReturn(repo);
when(() => repo.user()).thenAnswer((_) async => user);
await cubit.init();
expect(cubit.state.user, user);
```

EP-G4, per branch: each branch of the changed code names the test that fails when it changes, and behaviour that depends on the environment is tested under a non-default one.

```
✗  tests cover a run that is "live" and one that is "ended"   // narrowing ["waiting", "live"] to ["live"] passes them all
✓  a test per branch: waiting after the activity's end, live, ended, no run yet
✗  compare in_utc(activity.starts_at) with run.activity_starts_at; the test database runs in UTC   // removing in_utc breaks no test
✓  a test sets the database session to America/New_York and still finds the same run
```

```elixir
# ✓ — the session's time zone is not the default, so the conversion is what the test checks (elixir #54)
test "when the database reads times in another time zone" do
  activity = insert(:activity, starts_at: ~U[2026-10-28 18:00:00Z])
  ended = insert(:live_session, activity: activity, status: "ended", activity_starts_at: ~N[2026-10-28 18:00:00])
  Repo.query!("SET LOCAL TIME ZONE 'America/New_York'")

  assert {:ok, %Session{id: id}} = Live.get_session(activity.id)
  assert id == ended.id
end
```

```dart
// ✓ — the locale is not the default, so the formatting rule is what the test checks
test('formats a price for a French locale', () {
  Intl.defaultLocale = 'fr_FR';
  addTearDown(() => Intl.defaultLocale = null);
  expect(formatPrice(1234.5), contains('234,50'));
});
```

EP-G4: an endpoint's promise for every input is tested on its failure paths.

```
✗  tests: a recorded connection → 200; an ignored event → 200          // no test makes recording fail
✓  test: a connection from a user deleted since their token was issued → 200, logged, nothing recorded
```

```elixir
# ✓ — drives the failure path the controller's moduledoc promises to answer 200
test "when the connection cannot be recorded", %{conn: conn} do
  user = insert(:user)
  {:ok, _deleted} = Accounts.delete_user(user)
  expect(App.Live.AdapterMock, :verify_webhook, fn _token, _body -> {:ok, connection_of(user)} end)

  conn = post(conn, "/webhooks/media-server", "{}")

  assert json_response(conn, 200) == %{"status" => "ok"}
  assert Repo.aggregate(Participation, :count) == 0
end
```

```dart
// ✓ — the handler promises `ok` for every event, failures included
test('answers ok when the participation cannot be saved', () async {
  when(() => repo.save(any())).thenAnswer((_) async => Result.error(const UserGone()));
  expect(await handler.handle(joinedEvent), HandlerResult.ok);
});
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

```elixir
# ✗ — email inside the transaction, read-then-write on the counter
Repo.transaction(fn ->
  user = Repo.get!(User, user_id)
  Repo.update!(User.changeset(user, %{invites_remaining: user.invites_remaining - 1}))
  Mailer.deliver_invite(email)
end)

# ✓ — one atomic conditional update, the email as a job that commits with the write
Ecto.Multi.new()
|> Ecto.Multi.update_all(:spend_invite, Query.with_invites_left(user_id), inc: [invites_remaining: -1])
|> Ecto.Multi.run(:check, fn _repo, %{spend_invite: {count, _}} -> ensure_spent(count) end)
|> Oban.insert(:send_invite, SendInviteWorker.new(%{email: email}))
|> Repo.transaction()
```

```dart
// ✗ — context used after await; the screen may be gone
await cubit.save();
context.pop();
// ✓
await cubit.save();
if (!mounted) return;
context.pop();
```

EP-H14 and EP-H10: the event carries what happened, and only what matters once publishes one.

```
✗  stamp_host_seen(session) publishes HostSeen(activity_id)              // on every connection and every 5-minute check
   on HostSeen → confirm(host_of(load(activity_id)))                     // the organizer when the job runs, not who connected
✓  stamp_host_seen(session) writes the stamp, nothing else
   record participation(user, role) publishes ParticipationRecorded(activity_id, user_id, role)   // once per run
   on ParticipationRecorded → confirm(event.user_id)                     // who connected, as it happened
```

```elixir
# ✗ — a stamp that publishes on every check; a handler that re-derives the host when it runs
def mark_host_seen(session, opts),
  do: session |> Session.host_seen_changeset() |> Repo.update(success_event: Events.LiveHostSeen, event_opts: opts)

def handle_event(%{aggregate: %{"activity_id" => activity_id}}) do
  with {:ok, activity} <- Communities.get_activity(activity_id),
       do: Communities.confirm_attendance(activity_id, Live.host_id(activity))
end

# ✓ — the stamp stays silent; the participation's event carries who connected (elixir #45)
def mark_host_seen(session), do: session |> Session.host_seen_changeset() |> Repo.update()

def handle_event(%{aggregate: %{"activity_id" => activity_id, "user_id" => user_id}}),
  do: Communities.confirm_attendance(activity_id, user_id)
```

```dart
// ✗ — the analytics event looks the plan up when it is sent, after the member may have switched
analytics.log('checkout_completed', {'plan': (await planRepo.currentPlan()).id});
// ✓ — the event carries the plan the member paid for
analytics.log('checkout_completed', {'plan': order.planId});
```

## I. Change hygiene (EP-I1–I7)

```
✗  fetch(id) { return get(id) }     // left behind after the refactor made it a pass-through
✓  (deleted; callers use get(id))
```

```elixir
# ✗ — left behind when the query moved to Wish.Query; it only delegates
def fetch_wish(id), do: get_wish(id)

# ✓ — deleted in the same change; its callers now call get_wish/1
```

```dart
// ✗ — the flag has been false since the new onboarding shipped; the branch cannot run
if (useLegacyOnboarding) return const LegacyOnboardingPage();
return const OnboardingPage();

// ✓ — the flag and its branch are gone
return const OnboardingPage();
```

EP-I3 — the check stays on; the code changes:

```elixir
# ✗ — silences the check that caught the nesting, and says nothing about why
# credo:disable-for-next-line Credo.Check.Refactor.Nesting
def partial_refund(%{amount: total} = payment, amount) do
  if amount > 0 do
    if amount <= total, do: Payments.refund(payment.id, amount), else: {:error, :exceeds_payment}
  else
    {:error, :invalid_amount}
  end
end

# ✓ — the guards say what the nesting said; nothing is disabled
def partial_refund(%{amount: total} = payment, amount) when amount > 0 and amount <= total,
  do: Payments.refund(payment.id, amount)

def partial_refund(%{amount: total}, amount) when amount > total, do: {:error, :exceeds_payment}
def partial_refund(_payment, _amount), do: {:error, :invalid_amount}
```

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

EP-I5 — the previous version keeps working while the new one rolls out:

```elixir
# ✗ — the previous version still reads and writes `title` for the minutes the rollout lasts
rename table(:wishes), :title, to: :name

# ✓ — deploy 1 adds `name`, writes both and backfills; deploy 2 reads `name`;
#     deploy 3 drops `title` once nothing uses it
alter table(:wishes), do: add(:name, :string)
```

EP-I6: a migration that may have run is final; the schema moves forward.

```
✗  edit 20261001_create_live_sessions: add role to live_participations   // production ran it last week and never gets the column
✓  new 20261028_add_role_to_live_participations: add role               // every database runs the same sequence
```

```elixir
# ✗ — priv/repo/migrations/20261001000000_create_live_sessions.exs, already on main, edited in place
add :role, :string, null: false, default: "viewer"

# ✓ — a new migration (elixir #63)
defmodule App.Repo.Migrations.AddRoleToLiveParticipations do
  use Ecto.Migration

  def change do
    alter table(:live_participations) do
      add :role, :string, null: false, default: "viewer"
    end
  end
end
```

```dart
// ✗ — Drift: the released step for version 2 edited
if (from < 2) {
  await m.addColumn(sessions, sessions.status);
  await m.addColumn(sessions, sessions.role);
}
// ✓ — schemaVersion becomes 3, with a step of its own
if (from < 3) await m.addColumn(sessions, sessions.role);
```

EP-I7: a change to what rows mean names every reader.

```
✗  record participation(host, role: "host")            // count_participants, "members who took part", now counts the host
✓  the change lists count_participants, the run summary and the stacked PR that reads them, and counts role "viewer" there
```

```elixir
# ✗ — host rows land in a table that a reader counts as members
Live.record_participation(session, host_id, "host", opts)
def count_participants(session_id), do: Participation |> Query.with_session_id(session_id) |> Query.count()

# ✓ — the same change updates every reader it found, and the PR description names them
def count_participants(session_id),
  do: Participation |> Query.with_session_id(session_id) |> Query.with_role("viewer") |> Query.count()
```

```dart
// ✗ — drafts are now saved in the messages table; the unread badge counts them
final unread = messages.where((m) => !m.read).length;
// ✓ — the change that saves drafts there updates the badge
final unread = messages.where((m) => !m.read && !m.isDraft).length;
```

## J. Code smells (EP-J1–J18)

Feature envy (EP-J5 → EP-D2): the logic moves to the data it uses.

```
✗  invoice_total(invoice) { return invoice.lines.sum(l -> l.price * l.qty) - invoice.customer.discount }   // in a controller
✓  invoice.total()                                                                                          // on the invoice
```

```elixir
# ✗ — the controller computes a billing rule from the invoice's own data
def show(conn, %{"id" => id}) do
  invoice = Billing.get_invoice!(id)
  total = Enum.reduce(invoice.lines, 0, &(&1.price * &1.quantity + &2)) - invoice.customer.discount
  render(conn, :show, invoice: invoice, total: total)
end

# ✓ — the rule lives in the context, next to the data it uses
def show(conn, %{"id" => id}) do
  invoice = Billing.get_invoice!(id)
  render(conn, :show, invoice: invoice, total: Billing.invoice_total(invoice))
end
```

Message chains (EP-J10 → EP-D7): the screen should not know the shape of four objects.

```dart
// ✗
Text(context.read<MainCubit>().state.user!.profile.address.city)
// ✓ — the cubit exposes what the screen needs
Text(context.select((MainCubit cubit) => cubit.state.userCity))
```

## K. Data access and performance (EP-K1–K11)

```
✗  for listing in listings: listing.host = load_host(listing.host_id)      // 1 + N queries
✓  hosts = load_hosts(ids(listings)); attach(listings, hosts)              // 2 queries
```

```elixir
# ✗ — N+1, unbounded, and an index built with a write lock
listings |> Enum.map(&Repo.preload(&1, :host))
create index(:listings, [:host_id])

# ✓ — one preload query, a page, and a non-blocking index build
Listing |> Query.filtered_by(filters) |> Query.paginate(page) |> Repo.all() |> Repo.preload(:host)

@disable_ddl_transaction true
@disable_migration_lock true
def change, do: create index(:listings, [:host_id], concurrently: true)
```

```dart
// ✗ — one local query per item (Drift/SQLite)
for (final wish in wishes) { wish.tags = await db.tagsFor(wish.id); }
// ✓ — one query with a join
final wishesWithTags = await db.wishesWithTags();
```

EP-K11: the query builder's constructs; raw SQL only for what it cannot express.

```
✗  where("NOT EXISTS (SELECT 1 FROM live_sessions AS later WHERE later.activity_id = ? AND …)")   // a table name in a string
✓  where(not exists(Session as later where later.activity_id == outer.activity_id and row(later) > row(outer)))   // only the row comparison stays raw
```

```elixir
# ✗ — the subquery and its table written by hand (elixir #12)
where(queryable, [s], fragment(
  "NOT EXISTS (SELECT 1 FROM live_sessions AS later WHERE later.activity_id = ? AND (later.inserted_at, later.id) > (?, ?))",
  s.activity_id, s.inserted_at, s.id))

# ✓ — exists and parent_as over the schema; the row comparison is the only fragment
queryable |> from(as: :session) |> where([s], not exists(later_session()))

defp later_session do
  from(later in Session,
    where: later.activity_id == parent_as(:session).activity_id,
    where: fragment("(?, ?) > (?, ?)", later.inserted_at, later.id, parent_as(:session).inserted_at, parent_as(:session).id),
    select: 1
  )
end
```

```dart
// ✗ — Drift: table names in a SQL string
db.customSelect('SELECT * FROM sessions s WHERE NOT EXISTS (SELECT 1 FROM sessions l WHERE l.activity_id = s.activity_id AND l.created_at > s.created_at)');
// ✓ — Drift's builder over the table classes
final later = db.alias(db.sessions, 'later');
final query = db.select(db.sessions)
  ..where((s) => notExistsQuery(db.select(later)
    ..where((l) => l.activityId.equalsExp(s.activityId) & l.createdAt.isBiggerThan(s.createdAt))));
```
