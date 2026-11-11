---
name: flutter-conventions-guide
description: Team conventions for our Flutter apps. Use when writing or editing any `.dart` or `.arb` file.
file_patterns:
  - "**/*.dart"
  - "**/*.arb"
---

# Flutter/Dart Conventions

Code that breaks these rules still compiles and passes `flutter analyze`, so only this list catches it. Hold every line you write or edit to the rules below. Where existing code and a rule disagree, the rule wins; where the rules are silent, match the surrounding code.

- `<app>` stands for the app's package name, the `name` in `pubspec.yaml`.
- Rules are cited by number (`#30`), and the numbers are stable.
- Broken most often, so check them first: #1, #5, #6, #9, #10, #19, #30, #42, #47, #51.
- The cubits form three tiers: a **core cubit** takes repos directly, **`MainCubit`** holds every repo and every core cubit, and a **screen cubit** takes `MainCubit` only (#1, #88).

## Read first, when it applies

Both files sit next to this one.

| Before you | Read |
|---|---|
| create a cubit and its state, a repo, a model or enum, a screen, a route, ARB keys, a cubit test or a provider | the matching section of `reference.md`: one template per layer |
| add, change or remove an app guide, or the UI a guide points at | `guides.md` |

## Before you say done

1. Every piece of code you touched is re-read, and what the edit made pointless is deleted (#90).
2. Every character of the diff is English (Rule 0).
3. After an ARB edit, `flutter gen-l10n` has run and its generated files are in the change (#75).
4. `flutter analyze`, the formatter (160-character width) and `flutter test` pass on a run started after your last edit.

## Rule 0 — everything is in English

**Every character we author is English**: class, method and variable names, file and directory names, doc comments and comments, `group`/`test` names, `AppRoutes` values, `Palette` entries, log messages, exception names and messages, ARB **keys** and their en `@`-descriptions, `TODO`s, commit messages and PR descriptions. This holds whoever wrote the surrounding code and however short the snippet. No linter checks it, so read every diff for it.

The one exception is translated *copy*, which is data: the message **values** in `app_fr.arb`. `app_en.arb` is the source of truth, its keys are English (#71), its `@`-metadata is English (#72), and `app_fr.arb` holds French message values and nothing else. French text anywhere but an ARB value is either a hardcoded user string, which moves to both ARB files (#47), or a Rule 0 violation.

Code you touch that is in another language is renamed and its comments rewritten in English, in the same change.

## The rules

### A. Cubit architecture & state
1. Screen cubits declare exactly `final MainCubit mainCubit;` via `({required this.mainCubit})` and reach repos and core cubits through `mainCubit.x`; a repo or a core cubit is never injected directly. `CreateActivityCubit`, `UpdateOrSubmitActivityCubit` and `ActivityCheckoutCubit` broke this historically and are not templates.
2. Pair every cubit with a sibling `*_state.dart`: the cubit declares `part "x_state.dart";`, the state file starts `part of "x_cubit.dart";`. Do not import the state file.
3. State extends `Equatable`; all fields `final`; a `const` constructor with defaults (`""` for loadingId, `const []` for lists, `false` for bools, nullable left without default); `copyWith` mirrors the constructor with `x ?? this.x`; `props` lists EVERY field in declaration order.
4. Cubit constructor calls `super(const XState())`.
5. Loading is one `final String loadingId` (default `""`). Set a descriptive lowerCamelCase id before an async call and reset it to `""` on completion and on error; per-item spinners are `"<key>-$id"`. The UI keys off `loadingId == "..."`. A state has no `bool isLoading` and no status enum.
6. Wrap repo calls in `try/catch`. The generic `catch (error, stacktrace)` resets `loadingId` to `""` (and returns `false` in a `Future<bool>` method), then forwards the error with exactly these lines and does nothing else: no toast, no log-and-return.

    ```dart
    } catch (error, stacktrace) {
      emit(state.copyWith(loadingId: ""));
      // ignore: invalid_use_of_protected_member
      Bloc.observer.onError(this, error, stacktrace);
      return false;
    }
    ```
7. Handle KNOWN typed errors (`ValidationError`, `NoAvailableSeatsError`, …) with `on XError catch` clauses BEFORE the generic catch: map them to state (`showToast`/feedback, or `submitErrorMessage` for `ValidationError`) and do not forward them to the observer.
8. Surface user feedback as state (`bool showToast` + a `ToastType?`), reset via `updateShowToast(bool)`; a cubit never calls UI feedback APIs and never takes a `BuildContext` or AppLocalizations. `ToastType` is an abstract feedback intent that wraps a `SnackBarType`; the screen maps it to a localized message and style.
9. Build a NEW list before emitting any list change: `emit(state.copyWith(wishes: [newWish, ...state.wishes]))`. A list mutated in place equals itself for `Equatable`, so the UI does not rebuild. New items are prepended to newest-first lists.
10. Clear a nullable field with an explicit `clearX` flag in `copyWith`, `relatedActivity: clearRelatedActivity ? null : (relatedActivity ?? this.relatedActivity)`, or with a `withNullX()` method that builds a fresh state. `copyWith(field: null)` is a silent no-op, because of `field ?? this.field`.
11. Guard `loadMore` with `state.xConnection?.pageInfo?.hasNextPage == true && state.loadingId != "pagination"`; set loadingId `"pagination"`; append the new page by spread.
12. Name methods: `init()`/`init(id)` for primary load, `refresh()` for pull-to-refresh (no spinner), `loadMoreX()` for pagination, intent verbs for mutations; UI-branching mutations return `Future<bool>` (true = success).
13. If holding a `Timer`/`StreamSubscription`, override `Future<void> close()`, cancel it, then `return super.close();`.
14. Import `package:bloc/bloc.dart` (not flutter_bloc) and Equatable in the cubit; use full `package:<app>/...` paths.

### B. Repos & GraphQL
15. Repo is a plain class with one `final GraphqlService graphqlService;` and a positional constructor `XxxRepo(this.graphqlService);`, with no base class.
16. Reads go through `graphqlService.performQuery(...)`, writes through `graphqlService.performMutation(...)`; never touch the `GraphQLClient` directly.
17. GraphQL as raw triple-quoted strings; reusable fragments as `static const String xxxFragment` composed with `+`; single-use operation strings may live inline in the method.
18. Parse with model `fromMap`; lists via `[for (var node in result.data!["field"]) Model.fromMap(node)]`; paginated via `Connection.fromMap`. Never hand-build models.
19. Wrap each operation in `try { ... } catch (error) { rethrow; }` and ONLY `rethrow`. The bare rethrow is intentional: error-code to typed-exception mapping happens once, in `GraphqlService`, so a repo never maps, logs or toasts.
20. Mirror schema nullability in the return type (`Future<Entity>` / `Future<List<Entity>>` / `Future<EntityConnection>`); success-only mutations request `{ entity { id } }` and return `id != null` as `Future<bool>`.
21. **Read methods are named after the bare GraphQL field** (`user()`, `activity()`, `threads()`, `members()`), with no `get` prefix. Mutations use intent verbs.
22. Mutations take a single `$input: XxxInput!` built as `variables: {"input": {...}}`; trim user email with `email.trim()`.
23. Default page size `"first": 20`; accept optional `String? endCursor`, add `"after"` only when non-null. Build the variables map with collection-`if` (`{if (x != null) "x": x}`) in new code.
24. Required identifiers positional; optional filters/cursors/toggles named optional; multi-field create/auth methods use named `required`.

### C. Models & enums
25. Every data model is immutable: `extends Equatable`, all fields `final`, one `const` constructor; no setters.
26. Override `List<Object?> get props` listing EVERY field in declaration order.
27. Deserialize with `static Model fromMap(Map<String, dynamic> map)`, never `factory`, never `fromJson`.
28. Guard nullable nested objects: `map["x"] == null ? null : Child.fromMap(map["x"])`.
29. Parse object lists with a null-guarded comprehension: `map["xs"] == null ? [] : [for (var x in map["xs"]) Child.fromMap(x)]`; `.map().toList()` only for primitive lists.
30. Non-null GraphQL lists are `final List<T> xs;` with `this.xs = const []`, never `List<T>?`: `final List<Activity> activities;` and `const ActivityConnection({this.activities = const []});`.
31. Mirror the schema's nullability: non-null scalar → `final T x;` + `required this.x`; nullable → `final T? x;` + `this.x` (no default). Only nullable schema fields become nullable Dart, and the same nullability flows from the model's `fromMap` to the repo's return type to the cubit state.
32. `copyWith` with every field nullable named, `field ?? this.field`; add `withNullX()` companions when a field must be clearable.
33. Parse timestamps as `DateTime.parse(map["x"]).toLocal()` (guarded for nullable); always chain `.toLocal()`.
34. When adding a field, update ALL of: constructor, `fromMap`, `copyWith`, AND `props`.
35. Wire enums: positional `const Enum(this.label)` with SCREAMING_SNAKE label, an `undefined` member last, and `static Enum fromString(String label)` using `firstWhere(..., orElse: () => Enum.undefined)`.
36. Rich enums (icon/color) use a named-param const constructor and resolve display text via `String getName(BuildContext)` + AppLocalizations, never a hardcoded label. Pure UI enums (no wire value) are bare enums.
37. One model/enum per snake_case file matching the type; wire enums under `enums/`; member order: fields, const ctor, getters, `fromMap`, `copyWith`, `props`.
38. GraphQL input types use a `toJson()` that conditionally includes only non-null keys (`if (x != null) "x": x`).

### D. Screens & widgets
39. Top-level screens are `StatefulWidget`s; load data in `initState` via `context.read<XCubit>().init(...)` (after `super.initState()`). `StatelessWidget` only for extracted sub-widgets.
40. Never create a `BlocProvider` in a screen; obtain globally-provided cubits via `context.read<X>()` for actions and `BlocBuilder`/`context.watch` for reactive reads; reach repos via `cubit.mainCubit.repo`.
41. Root build with a Bloc widget typed `<FeatureCubit, FeatureState>`; name the builder/listener param after the feature (`forumState`), not `state`.
42. Put navigation and toasts ONLY in a `BlocConsumer`/`BlocListener` `listener`, never in a `builder`; gate with `listenWhen` for many-field states.
43. Drive loading UI off `state.loadingId == "tag"`; spinner is a fixed-size `SizedBox` `CircularProgressIndicator` with `AlwaysStoppedAnimation` (`Palette.textOn` on filled buttons, `Palette.primary` otherwise, strokeWidth 2.0).
44. Empty states: centered localized `Text` via `Theme.of(context).textTheme` (often `copyWith(color: Palette.textSubdued)`), after the loading check.
45. Show feedback only via `Helper.topSnackBar(context:, type: SnackBarType.x, message: <localized>)`; never raw `SnackBar`/`ScaffoldMessenger`. Two layers, both canonical: `SnackBarType` (`success`/`info`/`error`) is the low-level style `topSnackBar` needs; a cubit-driven toast carries an abstract `ToastType` in state, and the screen maps `state.toastType` → a localized message + `state.toastType!.snackBarType`. Use `SnackBarType` directly for feedback raised in the screen itself; use a `ToastType` when a cubit must signal feedback (it cannot localize).
46. Navigate via go_router with `AppRoutes.<route>.name` (`goNamed` for flow replacement, `pushNamed` for detail); objects via `extra: {"key": value}`, ids via `pathParameters`. Pop a page route with `context.pop()`; dismiss a modal sheet/dialog with `Navigator.pop(context)`.
47. All user text goes through `AppLocalizations.of(context)!.<key>`, with the key added to BOTH `app_en.arb` and `app_fr.arb` (#73); the only literal `Text` allowed is a decorative separator.
48. Use `Palette.*` for every color and `Theme.of(context).textTheme.*` for typography; never `Colors.*` (except shadows/overlays) or hex. Set font weight by swapping `fontFamily` (`"SatoshiBold"`), never `fontWeight`.
49. Use `ShadowButton` wrapped in `SizedBox(width: double.infinity)`; wrap forms in `Form` + `AutofillGroup` + `KeyboardDismisser`; validate before submit.
50. Constrain content to `maxWidth` 480 via `Align(topCenter)` + `ConstrainedBox` (incl. the AppBar via `PreferredSize`); AppBar leading `IconButton(Icons.arrow_back, size: 28)` → `context.pop()`, `centerTitle: true`, `elevation: 0`.
51. After any `await`, guard `if (!mounted) return;` before using `context`.
52. Dispose every controller/Timer/AnimationController in `dispose()`; use `WidgetsBindingObserver` for lifecycle-aware screens.
53. **App guides** (`GuideRegistry` + `guidi_client`) follow the rules in `guides.md`: read it before adding, changing or removing a guide, or the UI a guide points at.
54. Files snake_case `_screen.dart` (`_tab.dart` for tabs); private build helpers `_buildX`, action methods `_x`; open sheets via `Helper.showBottomSheet` with a `RouteSettings` name.

### E. Components
55. `StatelessWidget` by default; `StatefulWidget` only when owning a controller/animation (always disposed).
56. Every public constructor is `const` with `super.key`, never the legacy `Key? key` + `: super(key: key)`.
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
68. Colors are `static const Color` on `Palette`, grouped by section, named role+variant camelCase; never raw hue names or `Color(0x..)` in widgets/theme: add a `Palette` entry.
69. Configure theme in the single `themeData` (theme_data.dart) from `Palette` + named font families; standard 12px radius, 2px borders.
70. App-wide singletons/runtime config are static fields on `Constants` (`const` for fixed, nullable for runtime-set).

### G. Localization
71. Keys lowerCamelCase `{featurePrefix}{ThingDescription}`; reuse the existing feature prefix.
72. Every en key gets a sibling `@key` block with at least a description (plus a `placeholders` block for substitutions); `app_fr.arb` contains ONLY message keys, never `@`-metadata.
73. Add every key to BOTH arb files with matching names; use ICU plural with `=1`/`other`, count placeholder `int` + `"format": "compact"`, mirrored in fr.
74. Access via `AppLocalizations.of(context)!.key` with import `package:<app>/l10n/app_localizations.dart`.
75. Run `flutter gen-l10n` after editing ARB and commit the generated files; never hand-edit them. It fails on a getter that is referenced and missing. Deleting a string removes the key (and en `@`metadata) from BOTH files. `@`-descriptions default to a screen/context tag; prose only when the tag is insufficient.

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
85. Resolve flavor into `Constants.apiEnvironment` via `ApiEnvironment.fromParameter(flavor)` first; branch on `Constants.apiEnvironment?.staging == true`; never re-parse the flavor or hardcode URLs/keys.
86. Fixed init order: apiEnvironment, HttpOverrides, `WidgetsFlutterBinding.ensureInitialized`, SystemChrome, then `await Firebase.initializeApp` before any Firebase service. Guard optional service init with `isNotEmpty`; wrap fail-tolerant SDK init in `try/catch(_)`.
87. Instantiate every repo as `final XRepo xRepo = XRepo(graphqlService)` reusing the single shared `GraphqlService`.
88. Register providers in strict tier order: core cubits (direct repos) → `MainCubit` (all repos + all core cubits) → screen cubits (`mainCubit:` ONLY). When adding a repo/core cubit, thread it through both its own provider AND the `MainCubit` constructor.
89. Install `Bloc.observer` in `MyApp.initState` via `addPostFrameCallback`. Treat `firebase_options.dart` as generated: never hand-edit it.

### J. Change hygiene
90. **After editing, above all after removing logic, re-read the code you touched and, in the same change, delete whatever the edit made pointless.** A wrapper widget that now only returns its child is inlined at its lone call site and removed. An unreachable branch, an unused private method, a state field nobody reads any more (with its `copyWith` and `props` entries, #3), an orphaned ARB key (from BOTH files, with its en `@`metadata, #75) and a dead import are deleted. `flutter analyze` flags only the unused import and private method; the rest is found by reading. Comments and doc comments stay useful and current: drop any that no longer matches the code, and keep none that says what the code *used to be* or *used to do*, since that history is in git.

### K. Application boundaries
91. **The app knows everything inside its own boundary and nothing outside it.** It owns its screens, cubits, state and navigation; its knowledge of everything else stops at the published contract, the GraphQL schema.
    - **What the schema exposes is what exists.** The app encodes no backend internals: no table or column names, no id format taken apart client-side, no assumption about how a value is stored or computed server-side.
    - **One side owns each rule.** When a screen needs a computed value, a permission or a status the API does not return yet, ask for the field; a rule recomputed locally "for now" drifts from the original.
    - **Shared code ships as a versioned package.** The app reaches into no other app's code: not a sibling Flutter app, not the admin web app, not the backend repo. A file copied across apps and kept in sync by hand is already out of sync. The boundary we do have is kept too: no hardcoded URL or key (#85), no raw HTTP call around `GraphqlService` (#16).
    - **Comments describe what *this* code does with a value**, never what another app does ("the backend nulls this out when the order ships"). Nothing in this repo can verify such a sentence, and nobody updates it when that app changes.

### L. Style
92. String literals use double quotes in new code. Existing single-quoted code stays as it is: the codebase is mixed, and there is deliberately no `prefer_double_quotes` lint and no mass reformat.
