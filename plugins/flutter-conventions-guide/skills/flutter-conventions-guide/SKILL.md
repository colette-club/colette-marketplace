---
name: flutter-conventions-guide
description: Use when writing or editing Dart/Flutter code in any of our Flutter apps — any .dart or .arb file, including cubits and their state classes, repos, services, models and enums, screens, reusable components, routing/theme/config, localization, and widget/unit tests.
file_patterns:
  - "**/*.dart"
  - "**/*.arb"
---

# Flutter/Dart Conventions

## Overview

Our Flutter apps share strong, near-universal conventions. Code that ignores them still compiles and passes `flutter analyze`, but it fails review and erodes the architecture. **Before writing or editing any `.dart` file, check the rules below and match the surrounding code.** Consistency is the single most important property of these codebases. (Canonical examples below cite `club-mobile` as the reference implementation; the same pattern lives in each app.)

Three core principles cover most mistakes:

- **Mirror the GraphQL schema's contract exactly, end to end.** Non-null scalars are required and non-nullable; non-null lists are `final List<T>` with a `const []` default (never `List<T>?`); only nullable schema fields become nullable Dart. The same nullability flows model `fromMap` → repo return type → cubit state. Defaulting to nullable hides the contract and produces dead null-checks and ambiguous empty-vs-absent states.
- **Errors flow through ONE pipeline, never ad-hoc UI.** Repos/services only `try/catch` + `rethrow` (error-code → typed-exception mapping happens once, in `GraphqlService`). Cubits map KNOWN typed errors to state and forward UNEXPECTED errors to `Bloc.observer.onError` via the exact idiom. Never swallow, log-and-return, or pop a generic toast for an unexpected error.
- **Honor the three-tier cubit architecture and immutable-state discipline.** Screen cubits depend ONLY on `MainCubit` and reach repos/core cubits via `mainCubit.x`. All state extends `Equatable` with `final` fields, a `const` constructor, `copyWith`, and `props` listing every field; loading is a single `String loadingId` (default `""`), never a bool. Always emit a NEW list reference; clear nullable fields via a `clearX` flag or `withNullX()` (copyWith's `?? this.x` cannot null a field).

## Highest-risk rules

These are violated most often, even when everything else is correct. Fix these first.

### 1. Forward unexpected errors to `Bloc.observer` with the exact idiom

In the generic `catch (error, stacktrace)` of a cubit async method: reset `loadingId` to `""` (and `return false` for `Future<bool>` methods), then forward. Never swallow, log-and-return, or show a generic toast for an unexpected error.

```dart
// ❌ BAD
} catch (e) {
  Helper.topSnackBar(context: context, message: "Something went wrong");
}

// ✅ GOOD
} catch (error, stacktrace) {
  emit(state.copyWith(loadingId: ""));
  // ignore: invalid_use_of_protected_member
  Bloc.observer.onError(this, error, stacktrace);
  return false;
}
```

KNOWN typed errors (`ValidationError`, `NoAvailableSeatsError`, …) are handled by `on XError catch` clauses BEFORE the generic catch and mapped to state — they are NOT forwarded to the observer.

### 2. Emit a NEW list reference on every list change

Build a fresh list before emitting; never mutate state's list in place, or `Equatable` sees an equal state and the UI fails to rebuild.

```dart
// ❌ BAD
state.wishes.add(newWish);
emit(state.copyWith(wishes: state.wishes));

// ✅ GOOD — prepend onto a newest-first list
emit(state.copyWith(wishes: [newWish, ...state.wishes]));
```

### 3. Clear a nullable field with a flag or `withNullX()` — not `copyWith(field: null)`

`copyWith`'s `field ?? this.field` makes passing `null` a silent no-op.

```dart
// ❌ BAD — no-op, stale value persists
emit(state.copyWith(relatedActivity: null));

// ✅ GOOD — explicit clear flag in copyWith
emit(state.copyWith(clearRelatedActivity: true));
// copyWith: relatedActivity: clearRelatedActivity ? null : (relatedActivity ?? this.relatedActivity)
```

Or a dedicated `withNullX()` method that constructs a fresh state.

### 4. Screen cubits depend on `MainCubit` ONLY

```dart
// ❌ BAD
class NewCubit extends Cubit<NewState> {
  final ActivityRepo activityRepo;
  final ViewerCubit viewerCubit;
  NewCubit({required this.activityRepo, required this.viewerCubit});
}

// ✅ GOOD
class NewCubit extends Cubit<NewState> {
  final MainCubit mainCubit;
  NewCubit({required this.mainCubit}) : super(const NewState());
  // use mainCubit.activityRepo, mainCubit.viewerCubit
}
```

(`CreateActivityCubit`, `UpdateOrSubmitActivityCubit`, `ActivityCheckoutCubit` historically violated this — they are NOT templates.)

### 5. Track loading with a `String loadingId`, not a bool

A single `final String loadingId` (default `""`) drives all loading. Set a descriptive lowerCamelCase id before an async call, reset to `""` on completion/error; encode per-item spinners as `"<key>-$id"`. The UI keys off `loadingId == "..."`. Never add `bool isLoading` or a status enum.

### 6. Non-null GraphQL lists are `final List<T>` with `const []` default

```dart
// ❌ BAD
final List<Activity>? activities;

// ✅ GOOD
final List<Activity> activities;
const ActivityConnection({this.activities = const []});
// fromMap: map["edges"] == null ? [] : [for (var e in map["edges"]) Activity.fromMap(e["node"])]
```

### 7. Repos only `try/catch` + `rethrow` — never map or toast

Error-code-to-exception mapping lives once in `GraphqlService`. The bare `try { ... } catch (error) { rethrow; }` is intentional — do not "clean it up" into a swallow/log/remap.

### 8. Never hardcode user-facing strings; guard `context` after `await`

All user text via `AppLocalizations.of(context)!.<key>` (added to BOTH `app_en.arb` and `app_fr.arb`). After any `await`, guard `if (!mounted) return;` before using `context`. Put navigation/toasts only in `BlocConsumer`/`BlocListener` `listener`, never `builder`.

## Quick reference — full checklist

### A. Cubit architecture & state
1. Screen cubits declare exactly `final MainCubit mainCubit;` via `({required this.mainCubit})`; reach repos/core cubits via `mainCubit.x` — never inject a repo or core cubit directly (highest-risk #4).
2. Pair every cubit with a sibling `*_state.dart`: cubit declares `part "x_state.dart";`, state file starts `part of "x_cubit.dart";`. Do not import the state file.
3. State extends `Equatable`; all fields `final`; a `const` constructor with defaults (`""` for loadingId, `const []` for lists, `false` for bools, nullable left without default); `copyWith` mirrors the constructor with `x ?? this.x`; `props` lists EVERY field in declaration order.
4. Cubit constructor calls `super(const XState())`.
5. Track loading with a single `String loadingId` (default `""`); encode per-item spinners as `"<key>-$id"` (highest-risk #5).
6. Wrap repo calls in `try/catch`; the generic `catch (error, stacktrace)` resets loadingId (returns false for `Future<bool>`) then forwards via the two-line `Bloc.observer.onError` idiom (highest-risk #1).
7. Handle KNOWN typed errors with `on XError catch` BEFORE the generic catch — map to state (`showToast`/feedback, or `submitErrorMessage` for `ValidationError`); do NOT forward these to the observer.
8. Surface user feedback as state (`bool showToast` + a `ToastType?`), reset via `updateShowToast(bool)`; never call UI feedback APIs (no `BuildContext`/AppLocalizations) from a cubit. `ToastType` is an abstract feedback intent (it wraps a `SnackBarType`); the screen maps it to a localized message + style.
9. Build a NEW list before emitting any list change; prepend new items to newest-first lists (highest-risk #2).
10. Clear a nullable field via an explicit `clearX` flag or a `withNullX()` method — never `copyWith(field: null)` (highest-risk #3).
11. Guard `loadMore` with `state.xConnection?.pageInfo?.hasNextPage == true && state.loadingId != "pagination"`; set loadingId `"pagination"`; append the new page by spread.
12. Name methods: `init()`/`init(id)` for primary load, `refresh()` for pull-to-refresh (no spinner), `loadMoreX()` for pagination, intent verbs for mutations; UI-branching mutations return `Future<bool>` (true = success).
13. If holding a `Timer`/`StreamSubscription`, override `Future<void> close()`, cancel it, then `return super.close();`.
14. Import `package:bloc/bloc.dart` (not flutter_bloc) and Equatable in the cubit; use full `package:club_mobile/...` paths.

### B. Repos & GraphQL
15. Repo is a plain class with one `final GraphqlService graphqlService;` and a positional constructor `XxxRepo(this.graphqlService);` — no base class.
16. Reads go through `graphqlService.performQuery(...)`, writes through `graphqlService.performMutation(...)`; never touch the `GraphQLClient` directly.
17. GraphQL as raw triple-quoted strings; reusable fragments as `static const String xxxFragment` composed with `+`; single-use operation strings may live inline in the method.
18. Parse with model `fromMap`; lists via `[for (var node in result.data!["field"]) Model.fromMap(node)]`; paginated via `Connection.fromMap`. Never hand-build models.
19. Wrap each operation in `try/catch` and ONLY `rethrow` (highest-risk #7).
20. Mirror schema nullability in the return type (`Future<Entity>` / `Future<List<Entity>>` / `Future<EntityConnection>`); success-only mutations request `{ entity { id } }` and return `id != null` as `Future<bool>`.
21. **Read methods are named after the bare GraphQL field** (`user()`, `activity()`, `threads()`, `members()`) — do NOT use a `get` prefix. Mutations use intent verbs.
22. Mutations take a single `$input: XxxInput!` built as `variables: {"input": {...}}`; trim user email with `email.trim()`.
23. Default page size `"first": 20`; accept optional `String? endCursor`, add `"after"` only when non-null. Build the variables map with collection-`if` (`{if (x != null) "x": x}`) in new code.
24. Required identifiers positional; optional filters/cursors/toggles named optional; multi-field create/auth methods use named `required`.

### C. Models & enums
25. Every data model is immutable: `extends Equatable`, all fields `final`, one `const` constructor; no setters.
26. Override `List<Object?> get props` listing EVERY field in declaration order.
27. Deserialize with `static Model fromMap(Map<String, dynamic> map)` — never `factory`, never `fromJson`.
28. Guard nullable nested objects: `map["x"] == null ? null : Child.fromMap(map["x"])`.
29. Parse object lists with a null-guarded comprehension: `map["xs"] == null ? [] : [for (var x in map["xs"]) Child.fromMap(x)]`; `.map().toList()` only for primitive lists.
30. Non-null lists are `final List<T> xs;` with `this.xs = const []` (highest-risk #6).
31. Mirror nullability: non-null scalar → `final T x;` + `required this.x`; nullable → `final T? x;` + `this.x` (no default).
32. `copyWith` with every field nullable named, `field ?? this.field`; add `withNullX()` companions when a field must be clearable.
33. Parse timestamps as `DateTime.parse(map["x"]).toLocal()` (guarded for nullable) — always chain `.toLocal()`.
34. When adding a field, update ALL of: constructor, `fromMap`, `copyWith`, AND `props`.
35. Wire enums: positional `const Enum(this.label)` with SCREAMING_SNAKE label, an `undefined` member last, and `static Enum fromString(String label)` using `firstWhere(..., orElse: () => Enum.undefined)`.
36. Rich enums (icon/color) use a named-param const constructor and resolve display text via `String getName(BuildContext)` + AppLocalizations — never hardcode labels. Pure UI enums (no wire value) are bare enums.
37. One model/enum per snake_case file matching the type; wire enums under `enums/`; member order: fields, const ctor, getters, `fromMap`, `copyWith`, `props`.
38. GraphQL input types use a `toJson()` that conditionally includes only non-null keys (`if (x != null) "x": x`).

### D. Screens & widgets
39. Top-level screens are `StatefulWidget`s; load data in `initState` via `context.read<XCubit>().init(...)` (after `super.initState()`). `StatelessWidget` only for extracted sub-widgets.
40. Never create a `BlocProvider` in a screen; obtain globally-provided cubits via `context.read<X>()` for actions and `BlocBuilder`/`context.watch` for reactive reads; reach repos via `cubit.mainCubit.repo`.
41. Root build with a Bloc widget typed `<FeatureCubit, FeatureState>`; name the builder/listener param after the feature (`forumState`), not `state`.
42. Put navigation and toasts ONLY in `BlocConsumer`/`BlocListener` `listener`, never `builder`; gate with `listenWhen` for many-field states (highest-risk #8).
43. Drive loading UI off `state.loadingId == "tag"`; spinner is a fixed-size `SizedBox` `CircularProgressIndicator` with `AlwaysStoppedAnimation` (`Palette.textOn` on filled buttons, `Palette.primary` otherwise, strokeWidth 2.0).
44. Empty states: centered localized `Text` via `Theme.of(context).textTheme` (often `copyWith(color: Palette.textSubdued)`), after the loading check.
45. Show feedback only via `Helper.topSnackBar(context:, type: SnackBarType.x, message: <localized>)`; never raw `SnackBar`/`ScaffoldMessenger`. Two layers, both canonical: `SnackBarType` (`success`/`info`/`error`) is the low-level style `topSnackBar` needs; a cubit-driven toast carries an abstract `ToastType` in state, and the screen maps `state.toastType` → a localized message + `state.toastType!.snackBarType`. Use `SnackBarType` directly for feedback raised in the screen itself; use a `ToastType` when a cubit must signal feedback (it cannot localize).
46. Navigate via go_router with `AppRoutes.<route>.name` (`goNamed` for flow replacement, `pushNamed` for detail); objects via `extra: {"key": value}`, ids via `pathParameters`. Pop a page route with `context.pop()`; dismiss a modal sheet/dialog with `Navigator.pop(context)`.
47. All user text via `AppLocalizations.of(context)!.<key>`; the only literal `Text` allowed is decorative separators (highest-risk #8).
48. Use `Palette.*` for every color and `Theme.of(context).textTheme.*` for typography; never `Colors.*` (except shadows/overlays) or hex. Set font weight by swapping `fontFamily` (`"SatoshiBold"`), never `fontWeight`.
49. Use `ShadowButton` wrapped in `SizedBox(width: double.infinity)`; wrap forms in `Form` + `AutofillGroup` + `KeyboardDismisser`; validate before submit.
50. Constrain content to `maxWidth` 480 via `Align(topCenter)` + `ConstrainedBox` (incl. the AppBar via `PreferredSize`); AppBar leading `IconButton(Icons.arrow_back, size: 28)` → `context.pop()`, `centerTitle: true`, `elevation: 0`.
51. After any `await`, guard `if (!mounted) return;` before using `context`.
52. Dispose every controller/Timer/AnimationController in `dispose()`; use `WidgetsBindingObserver` for lifecycle-aware screens.
53. Follow the GuideService timer pattern verbatim (cancellable Timer, `_guideIsPlaying` lock, `isCurrent` guard at every async boundary, reschedule on not-current, cancel in dispose).
54. Files snake_case `_screen.dart` (`_tab.dart` for tabs); private build helpers `_buildX`, action methods `_x`; open sheets via `Helper.showBottomSheet` with a `RouteSettings` name.

### E. Components
55. `StatelessWidget` by default; `StatefulWidget` only when owning a controller/animation (always disposed).
56. Every public constructor is `const` with `super.key` — never the legacy `Key? key` + `: super(key: key)`.
57. Components with 2+ params: fields first, then an all-named const constructor. Thin single-domain-object wrappers may use a leading positional arg (`const X(this.model, {super.key})`).
58. Model variants as an enum field + named const constructors setting the enum and `Palette` colors in the initializer list; branch on the enum in `build()`.
59. Pull semantic colors from `Palette`; `Colors.black`/`white` only for shadows/overlays via `.withValues(alpha:)`. Derive every `TextStyle` from `Theme.of(context).textTheme.<role>?.copyWith(...)`.
60. Localize all user text via `AppLocalizations.of(context)!`; pre-bind `final l10n = ...` when using several keys.
61. Callbacks typed `Function(T)`/`Function()` named `onX`; `VoidCallback` only on button-like wrappers. Boolean flags are named params with explicit `= false` defaults.
62. One snake_case file per component; prefix Flutter-name collisions with `App` (`AppBadge`); define `<Component>Type` enums in the same file; extract repeated internal pieces into private `_PascalCase` widgets in the SAME file.
63. Render nothing with `const SizedBox.shrink()`; remote images via `CachedNetworkImage`; backend assets via `BackendImage`.

### F. Routing / config / theme
64. Routes use a `GoRoute` with `name: AppRoutes.x.name` and a `pageBuilder: (context, goRouterState)` (param named `goRouterState`, not `state`) returning a `MaterialPage` with `key: goRouterState.pageKey` and `name: AppRoutes.x.name`.
65. Top-level paths `"/${AppRoutes.x.name}"`; nested children use the bare enum name; path params as `/:id`. Set `parentNavigatorKey: _shellNavigatorKey` on any full-screen route above the bottom-nav tabs.
66. Read extra via `goRouterState.extra as Map<String, dynamic>?` into `extra`, then `extra?["key"] as Type?`; guard required extras with a redirect fallback. Use `pathParameters` for ids, `uri.queryParameters` for optional scalars.
67. Add routes as enhanced-enum values in `AppRoutes` (`name` matching the identifier, regex list for deep-linkable routes); never hardcode path strings. Navigate by name everywhere.
68. Colors are `static const Color` on `Palette`, grouped by section, named role+variant camelCase; never raw hue names or `Color(0x..)` in widgets/theme — add a `Palette` entry.
69. Configure theme in the single `themeData` (theme_data.dart) from `Palette` + named font families; standard 12px radius, 2px borders.
70. App-wide singletons/runtime config are static fields on `Constants` (`const` for fixed, nullable for runtime-set).

### G. Localization
71. Keys lowerCamelCase `{featurePrefix}{ThingDescription}`; reuse the existing feature prefix.
72. Every en key gets a sibling `@key` block with at least a description (plus a `placeholders` block for substitutions); `app_fr.arb` contains ONLY message keys — never `@`-metadata.
73. Add every key to BOTH arb files with matching names; use ICU plural with `=1`/`other`, count placeholder `int` + `"format": "compact"`, mirrored in fr.
74. Access via `AppLocalizations.of(context)!.key` with import `package:club_mobile/l10n/app_localizations.dart`.
75. Run `flutter gen-l10n` after editing ARB and commit the generated files; never hand-edit them. Deleting a string removes the key (and en `@`metadata) from BOTH files. `@`-descriptions default to a screen/context tag; prose only when the tag is insufficient.

### H. Testing
76. Tests at `test/<same path as lib/>` with a `_test.dart` suffix, one file per source unit.
77. `flutter_test` + `mocktail` only; NEVER `bloc_test` (no `blocTest`/`whenListen`); assert on the real `cubit.state`.
78. Mocks: `class MockX extends Mock implements X {}`; mock repos and `MainCubit`, never the cubit under test. Test a screen cubit with the REAL cubit + a `MockMainCubit`, stubbing `when(() => mainCubit.repoName).thenReturn(mockRepo)`.
79. Fresh mocks/cubit in `setUp`; `cubit.close()` in `tearDown`; restore a swapped `Bloc.observer` via `addTearDown`. Register non-primitive `any()` args with `registerFallbackValue` in `setUpAll`.
80. Assert behaviour on real emitted state; `verify().called(n)`/`verifyNever` only to confirm repo calls. For unexpected errors, use a `RecordingBlocObserver` and assert it received the error.
81. Use `test/helpers/screen_test_harness.dart` (`pumpLocalizedScreen`, `setUpFakeImages`/`withFakeImages`, `RecordingNavigatorObserver`). Wrap navigating screens in a `GoRouter` with a `/home` base + stub destination routes.
82. Build fixtures with file-local private factories (`_wish(...)`, `_activity(...)`); for `fromMap`, build fully-populated maps matching the non-null schema.
83. `group("<methodOrFeature>")`; tests named as present-tense behavioural sentences. Drive Timers with `fakeAsync`; use explicit `tester.pump(Duration)` instead of `pumpAndSettle` when a perpetual spinner is in flight.

### I. Entry / DI
84. Flavor entry files (`main_prod`/`main_stg`) only call `mainCommon(flavor: "...")`; all bootstrapping lives in `mainCommon`.
85. Resolve flavor into `Constants.apiEnvironment` via `ApiEnvironment.fromParameter(flavor)` first; branch on `Constants.apiEnvironment?.staging == true` — never re-parse the flavor or hardcode URLs/keys.
86. Fixed init order: apiEnvironment, HttpOverrides, `WidgetsFlutterBinding.ensureInitialized`, SystemChrome, then `await Firebase.initializeApp` before any Firebase service. Guard optional service init with `isNotEmpty`; wrap fail-tolerant SDK init in `try/catch(_)`.
87. Instantiate every repo as `final XRepo xRepo = XRepo(graphqlService)` reusing the single shared `GraphqlService`.
88. Register providers in strict tier order: core cubits (direct repos) → `MainCubit` (all repos + all core cubits) → screen cubits (`mainCubit:` ONLY). When adding a repo/core cubit, thread it through both its own provider AND the `MainCubit` constructor.
89. Install `Bloc.observer` in `MyApp.initState` via `addPostFrameCallback`. Treat `firebase_options.dart` as generated — never hand-edit.

## Where to copy patterns from

This skill is self-contained — learn the patterns from the code it carries, not from paths into any one repo:

- Each **highest-risk rule** above carries a bad/good snippet.
- **`reference.md`** has full, copyable templates for every layer: cubit + state pairing, the error pipeline, pagination, repo, model + enum, screen, routing, localization, test, and dependency injection.

If you want to see a pattern live, `club-mobile` is the reference app — but you should not need to open it; the snippets here are the source of truth.

## Red flags — stop and reconsider

- `bool isLoading` or a status enum in a state class → use a `String loadingId`.
- `emit(state.copyWith(list: state.list))` after mutating the list in place → build a new list.
- `copyWith(nullableField: null)` to clear a value → no-op; add a `clearX` flag or `withNullX()`.
- Injecting a Repo or core Cubit into a screen cubit → take `MainCubit` only.
- A `SnackBar`/`ScaffoldMessenger`/`Fluttertoast`, or log-and-return, in a catch for an unexpected error → forward to `Bloc.observer.onError`.
- A repo `try/catch` doing anything but `rethrow` → mapping belongs only in `GraphqlService`.
- A model list field as `List<T>?` → non-null schema lists are `final List<T>` + `const []`.
- `factory Model.fromJson` → use `static Model fromMap(Map<String, dynamic> map)`.
- A new model field without updating constructor, `fromMap`, `copyWith`, AND `props`.
- `DateTime.parse(...)` without `.toLocal()`.
- `context.goNamed`/`Helper.topSnackBar` in a `builder` instead of a `listener`.
- `context` used after an `await` without `if (!mounted) return;`.
- A hardcoded user-facing string, or a key in only one arb file, or a missing en `@`metadata.
- `fontWeight: FontWeight.bold` instead of swapping `fontFamily` to a Satoshi variant.
- `Colors.grey`/`Color(0x..)` for a foreground/surface/border → add a `Palette` entry.
- A `BlocProvider` inside a screen, or a top-level screen as `StatelessWidget`.
- A route without an `AppRoutes` value, a missing `parentNavigatorKey` on an above-tabs route, or a `pageBuilder` param named `state`.
- A repo read method with a `get` prefix → name it after the bare GraphQL field.
- `blocTest`/`whenListen`, mocking the cubit under test, or `pumpAndSettle` on a perpetual-spinner screen.
- A new screen cubit registered with a repo/core cubit instead of `mainCubit:` only (`CreateActivityCubit`/`ActivityCheckoutCubit` are legacy violations, not templates).
- A new repo/core cubit not threaded through the `MainCubit` constructor in `main_common.dart`.

## Also enforced mechanically

`flutter analyze` (standard lints incl. `use_build_context_synchronously`, `prefer_const_constructors`) and the formatter (160-char width) must pass; `flutter gen-l10n` regenerates AppLocalizations and fails on a missing referenced getter; `flutter test` runs the full suite (`flutter_test` + `mocktail`, no `bloc_test`).

NOT mechanically enforced — must be caught in review: **double quotes for string literals** (preferred for new code; the codebase is currently mixed and there is intentionally no `prefer_double_quotes` lint or mass reformat), in-place list mutation, `copyWith(field: null)` no-ops, loadingId-vs-bool, schema-nullability mirroring, the `Bloc.observer.onError` idiom, `fromMap`-vs-`fromJson`, `.toLocal()` on dates, `props` staying in sync with fields, `Palette`-only colors, `fontFamily`-based weights, the maxWidth-480 constraint, and the three-tier dependency rule.
