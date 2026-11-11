# App guides — rule #53 in full

App guides are built with `GuideRegistry` and `guidi_client`. Rule numbers refer to `SKILL.md`.

## Playback

A screen that plays guides carries this pattern, verbatim. `screenFeature` is the screen's id in `GuideRegistry`.

```dart
class _FeatureScreenState extends State<FeatureScreen> {
  bool _guideIsPlaying = false;
  Timer? _guideStartTimer;

  @override
  void initState() {
    super.initState();
    _scheduleGuideStart(const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _guideStartTimer?.cancel();                         // cancel in dispose (#52)
    super.dispose();
  }

  // A tab screen also checks that its tab is the selected one.
  bool get _isScreenCurrent => ModalRoute.of(context)?.isCurrent ?? false;

  void _scheduleGuideStart(Duration delay) {
    _guideStartTimer?.cancel();                         // cancellable: one pending start at most
    _guideStartTimer = Timer(delay, () {
      if (!mounted || _guideIsPlaying) return;
      if (!_isScreenCurrent) {
        _scheduleGuideStart(const Duration(milliseconds: 1500));   // not current: reschedule
        return;
      }
      _startGuides();
    });
  }

  void _startGuides() async {
    if (_guideIsPlaying) return;
    if (Constants.guideService == null) return;
    _guideIsPlaying = true;                             // lock synchronously, before any await
    try {
      final unseen = await Constants.guideService!.unseenForScreen(GuideRegistry.screenFeature);
      if (!mounted || unseen.isEmpty) {
        _guideIsPlaying = false;
        return;
      }
      if (!_isScreenCurrent) {                          // isCurrent guard after every async boundary
        _guideIsPlaying = false;
        _scheduleGuideStart(const Duration(milliseconds: 1500));
        return;
      }
      final guide = unseen.first;
      // A short delay lets the widget tree settle. addPostFrameCallback does not work here:
      // Flutter may not schedule a frame when the tree is static.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) {
          _guideIsPlaying = false;
          return;
        }
        if (!_isScreenCurrent) {
          _guideIsPlaying = false;
          _scheduleGuideStart(const Duration(milliseconds: 1500));
          return;
        }
        final played = GuidePlayer(
          context: context,
          guide: guide,
          groupIndex: 0,
          l10n: AppLocalizations.of(context)!,
          theme: GuideRegistry.guidePlayerTheme(AppLocalizations.of(context)!),
          onGroupFinished: () {                         // the terminal beat
            _guideIsPlaying = false;
            Constants.guideService!.markGuideSeen(guide.id, completedSteps: guide.steps.length, totalSteps: guide.steps.length, skipped: false);
          },
          onSkip: (completedSteps) {
            _guideIsPlaying = false;
            Constants.guideService!.markGuideSeen(guide.id, completedSteps: completedSteps, totalSteps: guide.steps.length, skipped: true);
          },
        ).play();
        if (!played) {
          _guideIsPlaying = false;
        }
      });
    } catch (_) {
      _guideIsPlaying = false;
    }
  }
}
```

The guide itself is an entry of `GuideRegistry.guides`, and each target a `GlobalKey` on the registry:

```dart
// lib/logic/services/guide_registry.dart
static const screenFeature = "feature";
static final featureFilterKey = GlobalKey(debugLabel: "guideFeatureFilter");

Guide(
  id: "feature_v1",
  priority: 0,
  startScreen: screenFeature,
  audience: GuideAudience.all,
  titleResolver: (l10n) => l10n.tourFeatureTourTitle,
  descResolver: (l10n) => l10n.tourFeatureTourDesc,
  icon: Symbols.filter_list,
  steps: [
    GuideStep(screen: screenFeature, targetKey: featureFilterKey, titleResolver: (l10n) => l10n.tourFeatureFilterTitle, descResolver: (l10n) => l10n.tourFeatureFilterDesc),
  ],
),
```

## Every guide reaches `markGuideSeen`

Every guide ends on a beat that calls `markGuideSeen`. The player's `onGroupFinished` does **not** fire when the last shown step is `tapThrough`. A guide that ends on a `tapThrough` step, or whose custom interactive flow continues past one, calls `markGuideSeen` itself in its finish handler. Without that call the guide is never marked seen and **replays on every visit**.

## Targets

- Each step's `targetKey` is attached to a live widget (`key: GuideRegistry.x`). A target that is never mounted is skipped silently: nothing highlights.
- When you remove or rename guided UI, delete the matching key and step, and any bespoke playback plumbing, so no orphan target or dead resume path is left (#90).

## Audience

Gate intros with `GuideAudience` (`newUser`/`returningUser`/`all`). `unseenForScreen` does **not** filter by audience, so the gate is applied at the auth transitions:

- on onboarding, call `markGuideNotApplicable` for every `returningUser` guide, so new users skip the intros made for existing users;
- on a returning user's login, call it for every `newUser` guide.

A feature shipped *after* some members onboarded needs a `returningUser` guide to reach them: they completed the `newUser` welcome tour and will not replay it.
