# App guides — rule #53 in full

App guides are built with `GuideRegistry` and `guidi_client`. Rule numbers refer to `SKILL.md`.

## Playback

Follow the timer pattern of a screen that already plays a guide, verbatim; find one by searching the app for `_guideIsPlaying`. Its parts:

- a cancellable `Timer` that schedules the start;
- a `_guideIsPlaying` lock, set synchronously before any `await`;
- an `isCurrent` guard at every async boundary, which reschedules the start when the screen is not the current route;
- the timer cancelled in `dispose()` (#52).

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
