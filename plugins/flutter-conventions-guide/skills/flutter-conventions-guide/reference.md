# Flutter Conventions — Reference

Fuller templates for the patterns summarized in `SKILL.md`. Copy these shapes; confirm details against the cited canonical files, which are the source of truth.

## Cubit + state pairing

A cubit and its state are one unit split across two files via `part`/`part of`.

```dart
// lib/logic/cubit/feature/feature_cubit.dart
import "package:bloc/bloc.dart";              // bare Cubit + Bloc.observer (NOT flutter_bloc)
import "package:equatable/equatable.dart";
import "package:club_mobile/logic/cubit/main_cubit.dart";
import "package:club_mobile/logic/models/...";

part "feature_state.dart";                    // after imports, before the class

class FeatureCubit extends Cubit<FeatureState> {
  final MainCubit mainCubit;                  // the ONLY dependency

  FeatureCubit({required this.mainCubit}) : super(const FeatureState());

  Future<void> init() async {
    emit(state.copyWith(loadingId: "fetchingFeature"));
    try {
      final items = await mainCubit.featureRepo.items();
      emit(state.copyWith(loadingId: "", items: items));
    } catch (error, stacktrace) {
      emit(state.copyWith(loadingId: ""));
      // ignore: invalid_use_of_protected_member
      Bloc.observer.onError(this, error, stacktrace);
    }
  }
}
```

```dart
// lib/logic/cubit/feature/feature_state.dart
part of "feature_cubit.dart";                 // first line, no imports

class FeatureState extends Equatable {
  final String loadingId;
  final List<Item> items;
  final Item? selected;                       // nullable: no default

  const FeatureState({
    this.loadingId = "",
    this.items = const [],
    this.selected,
  });

  FeatureState copyWith({
    String? loadingId,
    List<Item>? items,
    Item? selected,
    bool clearSelected = false,               // explicit clear for the nullable field
  }) {
    return FeatureState(
      loadingId: loadingId ?? this.loadingId,
      items: items ?? this.items,
      selected: clearSelected ? null : (selected ?? this.selected),
    );
  }

  @override
  List<Object?> get props => [loadingId, items, selected];   // every field, in order
}
```

The state lives in the `*_state.dart` part; the `clearX` flag is the only addition `copyWith` needs to reset a nullable field to null.

## Error handling (the one pipeline)

```dart
Future<bool> submit(String text) async {
  emit(state.copyWith(loadingId: "submitting"));
  try {
    final created = await mainCubit.wishRepo.createMemberWish(text);
    emit(state.copyWith(loadingId: "", wishes: [created, ...state.wishes]));  // new list
    return true;
  } on ValidationError catch (error) {                 // KNOWN error → state, NOT observer
    emit(state.copyWith(loadingId: "", submitErrorMessage: error.message));
    return false;
  } catch (error, stacktrace) {                        // UNEXPECTED → observer, reset, false
    emit(state.copyWith(loadingId: ""));
    // ignore: invalid_use_of_protected_member
    Bloc.observer.onError(this, error, stacktrace);
    return false;
  }
}
```

- Specific `on XError catch` clauses come BEFORE the generic catch.
- Never show a toast / log-and-return / swallow for the generic catch.
- The global `BlocObserver` routes a forwarded error to `MainCubit.setError` / Crashlytics — that bridge is the only place an unexpected cubit error becomes user-visible or logged.

## Pagination

```dart
Future<void> loadMoreItems() async {
  if (state.itemConnection?.pageInfo?.hasNextPage != true || state.loadingId == "pagination") return;
  emit(state.copyWith(loadingId: "pagination"));
  try {
    final next = await mainCubit.featureRepo.items(endCursor: state.itemConnection?.pageInfo?.endCursor);
    emit(state.copyWith(
      loadingId: "",
      itemConnection: next.copyWith(items: [...state.itemConnection!.items, ...next.items]),  // merged, new list
    ));
  } catch (error, stacktrace) {
    emit(state.copyWith(loadingId: ""));
    // ignore: invalid_use_of_protected_member
    Bloc.observer.onError(this, error, stacktrace);
  }
}
```

The guard (`hasNextPage == true && loadingId != "pagination"`) and the spread-merge of the new page onto the existing items are the whole pattern.

## Repo

```dart
// lib/logic/repos/feature_repo.dart
class FeatureRepo {
  final GraphqlService graphqlService;
  FeatureRepo(this.graphqlService);                    // positional, no base class

  static const String itemFragment = """
    fragment ItemFields on Item { id name }
  """;

  // Read method named after the bare GraphQL field — NO get prefix.
  Future<List<Item>> items({String? endCursor}) async {
    const String query = """
      query Items(\$first: Int!, \$after: String) {
        items(first: \$first, after: \$after) { edges { node { ...ItemFields } } }
      }
    """ + itemFragment;
    try {
      final result = await graphqlService.performQuery(
        query,
        variables: {"first": 20, if (endCursor != null) "after": endCursor},  // collection-if
      );
      return [for (var edge in result.data!["items"]["edges"]) Item.fromMap(edge["node"])];
    } catch (error) {
      rethrow;                                          // ONLY rethrow
    }
  }

  // Success-only mutation → request { entity { id } }, return id != null.
  Future<bool> createItem(ItemInput input) async {
    const String mutation = """
      mutation CreateItem(\$input: CreateItemInput!) {
        createItem(input: \$input) { item { id } }
      }
    """;
    try {
      final result = await graphqlService.performMutation(mutation, variables: {"input": input.toJson()});
      return result.data?["createItem"]?["item"]?["id"] != null;
    } catch (error) {
      rethrow;
    }
  }
}
```

Error-code → typed-exception mapping (e.g. `ValidationError`, `NotFoundError`) happens exactly once, inside the `GraphqlService` wrapper — never in a repo. Repos only `rethrow`.

## Model + enum

```dart
// lib/logic/models/item.dart
class Item extends Equatable {
  final String id;                  // non-null scalar → required
  final String name;
  final List<Tag> tags;             // non-null list → const [] default
  final DateTime? archivedAt;       // nullable scalar

  const Item({required this.id, required this.name, this.tags = const [], this.archivedAt});

  static Item fromMap(Map<String, dynamic> map) {       // static, not factory/fromJson
    return Item(
      id: map["id"],
      name: map["name"],
      tags: map["tags"] == null ? [] : [for (var t in map["tags"]) Tag.fromMap(t)],
      archivedAt: map["archivedAt"] == null ? null : DateTime.parse(map["archivedAt"]).toLocal(),
    );
  }

  Item copyWith({String? id, String? name, List<Tag>? tags, DateTime? archivedAt}) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      tags: tags ?? this.tags,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, tags, archivedAt];
}
```

```dart
// lib/logic/models/enums/item_status.dart — wire enum mirroring a GraphQL enum
enum ItemStatus {
  active("ACTIVE"),
  archived("ARCHIVED"),
  undefined("UNDEFINED");           // fallback member, last

  final String label;
  const ItemStatus(this.label);

  static ItemStatus fromString(String label) =>
      ItemStatus.values.firstWhere((s) => s.label == label, orElse: () => ItemStatus.undefined);
}
```

Adding a field means touching all four of: constructor, `fromMap`, `copyWith`, `props`. Rich enums that need an icon/color use a named-param const constructor and resolve display text via `getName(BuildContext)` + AppLocalizations (never a hardcoded label).

## Screen

```dart
class FeatureScreen extends StatefulWidget {            // top-level screens are stateful
  const FeatureScreen({super.key});
  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FeatureCubit>().init();                // no BlocProvider here
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeatureCubit, FeatureState>(
      listenWhen: (p, c) => p.showToast != c.showToast,
      listener: (context, featureState) {               // nav + toasts ONLY here
        if (featureState.showToast) {
          Helper.topSnackBar(
            context: context,
            type: SnackBarType.error,
            message: AppLocalizations.of(context)!.featureSomethingFailed,
          );
        }
      },
      builder: (context, featureState) {
        if (featureState.loadingId == "fetchingFeature") {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.0));
        }
        if (featureState.items.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.featureEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Palette.textSubdued),
            ),
          );
        }
        return ListView(...);
      },
    );
  }
}
```

- Content constrained to `maxWidth: 480` via `Align(topCenter)` + `ConstrainedBox`.
- Back navigation: `context.pop()` for page routes; `Navigator.pop(context)` to dismiss a modal sheet/dialog.
- Guard `context` after every `await` with `if (!mounted) return;`.

Loading off `state.loadingId == "tag"`, feedback in the `listener`, content constrained to `maxWidth: 480`, and `if (!mounted) return;` after every await are the load-bearing parts.

## Routing

```dart
// lib/config/app_routes.dart — enhanced enum, navigate by name everywhere
enum AppRoutes {
  feature(name: "feature"),
  featureDetail(name: "feature-detail");
  // ...
}

// lib/config/router.dart
GoRoute(
  path: "/${AppRoutes.feature.name}",
  name: AppRoutes.feature.name,
  parentNavigatorKey: _shellNavigatorKey,             // full-screen routes above the tabs
  pageBuilder: (context, goRouterState) => MaterialPage(    // param is goRouterState, NOT state
    key: goRouterState.pageKey,
    name: AppRoutes.feature.name,
    child: const FeatureScreen(),
  ),
),

// navigate
context.pushNamed(AppRoutes.featureDetail.name, extra: {"item": item});
```

## Localization

```json
// lib/l10n/app_en.arb
"featureEmpty": "No items yet",
"@featureEmpty": { "description": "FeatureScreen" },
"featureItemCount": "{count, plural, =1{1 item} other{{count} items}}",
"@featureItemCount": {
  "description": "FeatureScreen",
  "placeholders": { "count": { "type": "int", "format": "compact" } }
}
```

```json
// lib/l10n/app_fr.arb — message keys only, no @-metadata
"featureEmpty": "Aucun élément",
"featureItemCount": "{count, plural, =1{1 élément} other{{count} éléments}}"
```

Run `flutter gen-l10n` and commit the generated files. Access via `AppLocalizations.of(context)!.featureEmpty`.

## Test

```dart
// test/logic/cubit/feature/feature_cubit_test.dart
class MockFeatureRepo extends Mock implements FeatureRepo {}
class MockMainCubit extends Mock implements MainCubit {}

void main() {
  late MockFeatureRepo featureRepo;
  late MockMainCubit mainCubit;
  late FeatureCubit cubit;

  setUp(() {
    featureRepo = MockFeatureRepo();
    mainCubit = MockMainCubit();
    when(() => mainCubit.featureRepo).thenReturn(featureRepo);
    cubit = FeatureCubit(mainCubit: mainCubit);          // REAL cubit, mocked MainCubit
  });

  tearDown(() => cubit.close());

  group("init", () {
    test("loads items and clears loadingId", () async {
      when(() => featureRepo.items()).thenAnswer((_) async => [_item()]);
      await cubit.init();
      expect(cubit.state.items, [_item()]);              // assert real state
      expect(cubit.state.loadingId, "");
    });

    test("resets loadingId and forwards to the observer on error", () async {
      when(() => featureRepo.items()).thenThrow(Exception("boom"));
      await cubit.init();
      expect(cubit.state.loadingId, "");
    });
  });
}

Item _item() => const Item(id: "i-1", name: "x");        // file-local fixture factory
```

- `flutter_test` + `mocktail` only — never `bloc_test`.
- Widget tests use `test/helpers/screen_test_harness.dart`; wrap navigating screens in a `GoRouter` with stub destination routes + a `RecordingNavigatorObserver`.

The pattern: real cubit + `MockMainCubit` with stubbed repo getters, assert on `cubit.state`, `verify` only for repo calls. Widget tests wrap navigating screens in a test `GoRouter` with stub destination routes.

## Dependency injection (main_common.dart)

Strict tier order — a provider appears after everything it resolves:

```dart
// 1. repos (reuse the one shared GraphqlService)
final featureRepo = FeatureRepo(graphqlService);

// 2. core cubits (direct repos)
BlocProvider<ViewerCubit>(create: (ctx) => ViewerCubit(viewerRepo: viewerRepo, ...)),

// 3. MainCubit (all repos + all core cubits)
BlocProvider<MainCubit>(create: (ctx) => MainCubit(featureRepo: featureRepo, viewerCubit: BlocProvider.of<ViewerCubit>(ctx), ...)),

// 4. screen cubits (mainCubit ONLY)
BlocProvider<FeatureCubit>(create: (ctx) => FeatureCubit(mainCubit: BlocProvider.of<MainCubit>(ctx))),
```

Adding a repo/core cubit means threading it through both its own provider AND the `MainCubit` constructor. This wiring lives in `main_common.dart`.
