# Flutter Conventions — templates

One template per layer, for the rules in `SKILL.md`; rule numbers (`#30`) refer to it. All templates build one feature: a paginated list of items. `<app>` is the app's package name, the `name` in `pubspec.yaml`.

## Contents

- [Cubit + state pairing](#cubit--state-pairing)
- [Error handling](#error-handling)
- [Pagination](#pagination)
- [Repo](#repo)
- [Model, connection and enum](#model-connection-and-enum)
- [Screen](#screen)
- [Spinner component](#spinner-component)
- [Routing](#routing)
- [Localization](#localization)
- [Test](#test)
- [Dependency injection](#dependency-injection)

## Cubit + state pairing

Rules #1 to #6, #10 and #14. A cubit and its state are one unit split across two files via `part`/`part of`.

```dart
// lib/logic/cubit/feature/feature_cubit.dart
import "package:bloc/bloc.dart";              // bare Cubit + Bloc.observer (NOT flutter_bloc)
import "package:equatable/equatable.dart";
import "package:<app>/logic/cubit/main_cubit.dart";
import "package:<app>/logic/models/...";

part "feature_state.dart";                    // after imports, before the class

class FeatureCubit extends Cubit<FeatureState> {
  final MainCubit mainCubit;                  // the ONLY dependency

  FeatureCubit({required this.mainCubit}) : super(const FeatureState());

  Future<void> init() async {
    emit(state.copyWith(loadingId: "fetchingFeature"));
    try {
      final itemConnection = await mainCubit.featureRepo.items();
      emit(state.copyWith(loadingId: "", itemConnection: itemConnection));
    } catch (error, stacktrace) {
      emit(state.copyWith(loadingId: ""));
      // ignore: invalid_use_of_protected_member
      Bloc.observer.onError(this, error, stacktrace);
    }
  }

  void updateShowToast(bool showToast) {
    emit(state.copyWith(showToast: showToast));
  }
}
```

```dart
// lib/logic/cubit/feature/feature_state.dart
part of "feature_cubit.dart";                 // first line, no imports

class FeatureState extends Equatable {
  final String loadingId;
  final ItemConnection? itemConnection;       // nullable: no default
  final Item? selected;
  final bool showToast;
  final ToastType? toastType;

  const FeatureState({
    this.loadingId = "",
    this.itemConnection,
    this.selected,
    this.showToast = false,
    this.toastType,
  });

  FeatureState copyWith({
    String? loadingId,
    ItemConnection? itemConnection,
    Item? selected,
    bool clearSelected = false,               // explicit clear for the nullable field
    bool? showToast,
    ToastType? toastType,
  }) {
    return FeatureState(
      loadingId: loadingId ?? this.loadingId,
      itemConnection: itemConnection ?? this.itemConnection,
      selected: clearSelected ? null : (selected ?? this.selected),
      showToast: showToast ?? this.showToast,
      toastType: toastType ?? this.toastType,
    );
  }

  @override
  List<Object?> get props => [loadingId, itemConnection, selected, showToast, toastType];   // every field, in order
}
```

## Error handling

Rules #6 to #9: one pipeline for every error.

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

The global `BlocObserver` routes a forwarded error to `MainCubit.setError` and Crashlytics. That bridge is the only place an unexpected cubit error becomes visible to the user or logged.

## Pagination

Rule #11.

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

## Repo

Rules #15 to #24.

```dart
// lib/logic/repos/feature_repo.dart
class FeatureRepo {
  final GraphqlService graphqlService;
  FeatureRepo(this.graphqlService);                    // positional, no base class

  static const String itemFragment = """
    fragment ItemFields on Item { id name }
  """;

  // Read method named after the bare GraphQL field — NO get prefix.
  // A paginated read returns the connection, parsed by Connection.fromMap.
  Future<ItemConnection> items({String? endCursor}) async {
    const String query = """
      query Items(\$first: Int!, \$after: String) {
        items(first: \$first, after: \$after) {
          pageInfo { hasNextPage endCursor }
          edges { node { ...ItemFields } }
        }
      }
    """ + itemFragment;
    try {
      final result = await graphqlService.performQuery(
        query,
        variables: {"first": 20, if (endCursor != null) "after": endCursor},  // collection-if
      );
      return ItemConnection.fromMap(result.data!["items"]);
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

## Model, connection and enum

Rules #25 to #37.

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
// lib/logic/models/item_connection.dart — a paginated list: the edges' nodes, flattened, plus the page info
class ItemConnection extends Equatable {
  final PageInfo? pageInfo;
  final List<Item> items;

  const ItemConnection({this.pageInfo, this.items = const []});

  static ItemConnection fromMap(Map<String, dynamic> map) {
    return ItemConnection(
      pageInfo: map["pageInfo"] == null ? null : PageInfo.fromMap(map["pageInfo"]),
      items: map["edges"] == null ? [] : [for (var edge in map["edges"]) Item.fromMap(edge["node"])],
    );
  }

  ItemConnection copyWith({PageInfo? pageInfo, List<Item>? items}) {
    return ItemConnection(
      pageInfo: pageInfo ?? this.pageInfo,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [pageInfo, items];
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

## Screen

Rules #39 to #51.

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
      listenWhen: (previous, current) => previous.showToast != current.showToast,
      listener: (context, featureState) {               // nav + toasts ONLY here
        if (featureState.showToast && featureState.toastType != null) {
          if (featureState.toastType == ToastType.notFoundError) {   // the screen maps the intent to a message
            Helper.topSnackBar(
              context: context,
              type: featureState.toastType!.snackBarType,
              message: AppLocalizations.of(context)!.featureNotFound,
            );
          }

          context.read<FeatureCubit>().updateShowToast(false);       // reset, so it shows once
        }
      },
      builder: (context, featureState) {
        if (featureState.loadingId == "fetchingFeature") {
          return const Center(child: Spinner.page());
        }

        final items = featureState.itemConnection?.items ?? const [];

        if (items.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.featureEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Palette.textSubdued),
            ),
          );
        }

        return Align(                                   // content constrained to 480
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(...),
          ),
        );
      },
    );
  }
}
```

After every `await` in a screen method, `if (!mounted) return;` comes before any use of `context` (#51).

## Spinner component

Rule #43, and the component rules #55 to #59. One component owns the three sizes, so no call site picks one.

```dart
// lib/presentation/components/spinner.dart
class Spinner extends StatelessWidget {
  final double size;
  final Color color;

  const Spinner.page({super.key})                     // a page or section is loading; the caller centres it
      : size = 24,
        color = Palette.primary;
  const Spinner.button({super.key, this.color = Palette.textOn}) : size = 29;   // in place of a button label
  const Spinner.inline({super.key, this.color = Palette.primary}) : size = 20;  // beside or inside other content

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(color),
        strokeWidth: 2.0,
      ),
    );
  }
}
```

```dart
// in a button, keyed off loadingId; an outlined button passes its own color
child: featureState.loadingId == "submitting" ? const Spinner.button() : Text(l10n.featureSubmit),
```

## Routing

Rules #64 to #67.

```dart
// lib/config/app_routes.dart — enhanced enum, navigate by name everywhere
enum AppRoutes {
  feature(
    name: "feature",
    regex: [r'.*/features$'],                           // only for a deep-linkable route
  ),
  featureDetail(
    name: "featureDetail",                              // the name matches the identifier
  );
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

Rules #71 to #75.

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

## Test

Rules #76 to #83: the real cubit with a mocked `MainCubit`, assertions on `cubit.state`.

```dart
// test/logic/cubit/feature/feature_cubit_test.dart
class MockFeatureRepo extends Mock implements FeatureRepo {}
class MockMainCubit extends Mock implements MainCubit {}

// Records what the app's Bloc.observer would receive, so a test can assert that
// an unexpected error was forwarded and not swallowed.
class RecordingBlocObserver extends BlocObserver {
  final List<Object> errors = [];

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

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
    test("loads the items and clears loadingId", () async {
      when(() => featureRepo.items()).thenAnswer((_) async => ItemConnection(items: [_item()]));

      await cubit.init();

      expect(cubit.state.itemConnection?.items, [_item()]);   // assert real state
      expect(cubit.state.loadingId, "");
    });

    test("resets loadingId and forwards an unexpected error to the observer", () async {
      final observer = RecordingBlocObserver();
      final previousObserver = Bloc.observer;
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = previousObserver);   // restore the swapped observer

      final error = Exception("boom");
      when(() => featureRepo.items()).thenThrow(error);

      await cubit.init();

      expect(cubit.state.loadingId, "");
      expect(observer.errors, contains(error));
    });
  });
}

Item _item() => const Item(id: "i-1", name: "x");        // file-local fixture factory
```

Widget tests use `test/helpers/screen_test_harness.dart`, and wrap a navigating screen in a `GoRouter` with stub destination routes and a `RecordingNavigatorObserver` (#81).

## Dependency injection

Rules #87 and #88, in `main_common.dart`. Strict tier order: a provider appears after everything it resolves.

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
