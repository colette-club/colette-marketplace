# Engineering principles — worked examples

One bad/good pair per group, first in neutral pseudocode, then in Elixir, then in Dart. The principle stays the same; only the idiom changes. When a language skill is loaded, its own examples take precedence.

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

## D. Design (EP-D1–D12)

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

Law of Demeter (EP-D7): ask your direct collaborator, don't reach through it.

```dart
// ✗
Text(mainCubit.viewerCubit.state.viewer.address.city.name)
// ✓
Text(viewerState.cityName)   // a getter on the state owns the path
```

## E. Boundaries (EP-E1–E4)

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

## F. Comments and docs (EP-F1–F4)

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

## H. Concurrency, transactions and side effects (EP-H1–H10)

```
✗  transaction { insert(referral); email.send(invite) }
✓  transaction { insert(referral); enqueue(SendInvite) }            // EP-H5, EP-H8
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

## I. Change hygiene (EP-I1–I2)

```
✗  fetch(id) { return get(id) }     // left behind after the refactor made it a pass-through
✓  (deleted; callers use get(id))
```

## J. Code smells (EP-J1–J18)

Feature envy (EP-J5 → EP-D2): the logic moves to the data it uses.

```
✗  invoice_total(invoice) { return invoice.lines.sum(l -> l.price * l.qty) - invoice.customer.discount }   // in a controller
✓  invoice.total()                                                                                          // on the invoice
```

## K. Data access and performance (EP-K1–K10)

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
