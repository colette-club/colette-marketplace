# Engineering principles — worked examples in Dart

The bad/good pairs of [reference.md](reference.md), in Dart. When the `flutter-conventions-guide` skill is loaded, its own examples take precedence.

## Contents

- [A. Names (EP-A1–A5)](#a-names-ep-a1a5): examples for EP-A1, EP-A2
- [B. Functions (EP-B1–B7)](#b-functions-ep-b1b7): examples for EP-B5, EP-B6
- [C. Control flow and errors (EP-C1–C4)](#c-control-flow-and-errors-ep-c1c4): examples for EP-C2, EP-C3
- [D. Design (EP-D1–D13)](#d-design-ep-d1d13): examples for EP-D6, EP-D7, EP-D8, EP-D10, EP-D13
- [E. Boundaries (EP-E1–E6)](#e-boundaries-ep-e1e6): examples for EP-E3, EP-E6
- [F. Comments and docs (EP-F1–F5)](#f-comments-and-docs-ep-f1f5): examples for EP-F1, EP-F4
- [G. Tests (EP-G1–G6)](#g-tests-ep-g1g6): examples for EP-G4, EP-G5
- [H. Concurrency, transactions and side effects (EP-H1–H14)](#h-concurrency-transactions-and-side-effects-ep-h1h14): examples for EP-H9, EP-H14
- [I. Change hygiene (EP-I1–I7)](#i-change-hygiene-ep-i1i7): examples for EP-I1, EP-I6, EP-I7
- [J. Code smells (EP-J1–J18)](#j-code-smells-ep-j1j18): examples for EP-J10
- [K. Data access and performance (EP-K1–K11)](#k-data-access-and-performance-ep-k1k11): examples for EP-K6, EP-K11

## A. Names (EP-A1–A5)

```dart
// ✗
final d = calc(u);
// ✓
final yearlyRent = student.monthlyRent * 12;
```

EP-A2: the concept keeps the word the codebase already gives it.

```dart
// ✗ — the repository says fetch everywhere else
Future<Wish> retrieveWish(String id);
// ✓
Future<Wish> fetchWish(String id);
```

## B. Functions (EP-B1–B7)

A name that promises a question must not change anything (EP-B5, EP-B6).

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

EP-D6: an external service is reached through an adapter that speaks the app's types.

```dart
// ✗ — the cubit calls the SDK and keeps its types
final room = await LiveKitClient.connect(url, token);
emit(state.copyWith(participants: room.remoteParticipants.values.toList()));
// ✓ — an interface the app owns; LiveKit's implementation is injected, a fake in tests
final room = await _mediaServer.join(token);
emit(state.copyWith(participants: room.participants));
```

EP-D8: every piece a change adds is read by production code in that change.

```dart
// ✗ — saved on every heartbeat; no cubit or widget reads it
await _prefs.setString('lastSeenAt', DateTime.now().toIso8601String());
// ✓ — left out until the screen that shows it exists
```

EP-D10: a rule that varies by actor takes the actor as data, on one path.

```dart
// ✗ — two methods that differ by who acts
Future<void> hostJoined(String userId) async => _confirm(userId);
Future<void> viewerJoined(String userId) async => _confirm(userId);
// ✓ — one method; the role travels as data
Future<void> joined(String userId, ParticipantRole role) async => _confirm(userId, role);
```

EP-D13: the same job, done the codebase's way.

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

```dart
// ✗ — re-implementing a server rule "for now"
final canBook = activity.seats > activity.bookings.length && !activity.isPast;
// ✓ — ask the API for the decision
final canBook = activity.isBookable;
```

EP-E6: a setting is checked at boot, wherever the code that reads it is on.

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

A stale doc is a bug (EP-F4): when `list_wishes` stops returning archived wishes, the sentence "lists every wish, including archived ones" changes in the same commit.

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

```dart
// ✓ — the locale is not the default, so the formatting rule is what the test checks
test('formats a price for a French locale', () {
  Intl.defaultLocale = 'fr_FR';
  addTearDown(() => Intl.defaultLocale = null);
  expect(formatPrice(1234.5), contains('234,50'));
});
```

EP-G4: an endpoint's promise for every input is tested on its failure paths.

```dart
// ✓ — the handler promises `ok` for every event, failures included
test('answers ok when the participation cannot be saved', () async {
  when(() => repo.save(any())).thenAnswer((_) async => Result.error(const UserGone()));
  expect(await handler.handle(joinedEvent), HandlerResult.ok);
});
```

## H. Concurrency, transactions and side effects (EP-H1–H14)

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

```dart
// ✗ — the analytics event looks the plan up when it is sent, after the member may have switched
analytics.log('checkout_completed', {'plan': (await planRepo.currentPlan()).id});
// ✓ — the event carries the plan the member paid for
analytics.log('checkout_completed', {'plan': order.planId});
```

## I. Change hygiene (EP-I1–I7)

```dart
// ✗ — the flag has been false since the new onboarding shipped; the branch cannot run
if (useLegacyOnboarding) return const LegacyOnboardingPage();
return const OnboardingPage();

// ✓ — the flag and its branch are gone
return const OnboardingPage();
```

EP-I6: a migration that may have run is final; the schema moves forward.

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

```dart
// ✗ — drafts are now saved in the messages table; the unread badge counts them
final unread = messages.where((m) => !m.read).length;
// ✓ — the change that saves drafts there updates the badge
final unread = messages.where((m) => !m.read && !m.isDraft).length;
```

## J. Code smells (EP-J1–J18)

Message chains (EP-J10 → EP-D7): the screen should not know the shape of four objects.

```dart
// ✗
Text(context.read<MainCubit>().state.user!.profile.address.city)
// ✓ — the cubit exposes what the screen needs
Text(context.select((MainCubit cubit) => cubit.state.userCity))
```

## K. Data access and performance (EP-K1–K11)

```dart
// ✗ — one local query per item (Drift/SQLite)
for (final wish in wishes) { wish.tags = await db.tagsFor(wish.id); }
// ✓ — one query with a join
final wishesWithTags = await db.wishesWithTags();
```

EP-K11: the query builder's constructs; raw SQL only for what it cannot express.

```dart
// ✗ — Drift: table names in a SQL string
db.customSelect('SELECT * FROM sessions s WHERE NOT EXISTS (SELECT 1 FROM sessions l WHERE l.activity_id = s.activity_id AND l.created_at > s.created_at)');
// ✓ — Drift's builder over the table classes
final later = db.alias(db.sessions, 'later');
final query = db.select(db.sessions)
  ..where((s) => notExistsQuery(db.select(later)
    ..where((l) => l.activityId.equalsExp(s.activityId) & l.createdAt.isBiggerThan(s.createdAt))));
```
