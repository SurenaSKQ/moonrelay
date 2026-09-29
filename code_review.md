Part of Moonrelay, a matrix protocol client.
Copyright (C) 2025 Surena Karimpour Ghannadi
AGPLv3

# Code review: quality and complexity management

Date: 2026-08-24
Scope: boot pipeline (`main.dart`, `boot.dart`), settings stack
(`settings_service.dart`, `settings_controller.dart`), router
(`router.dart`), chat surface (`chat_box.dart`, `chat_timeline.dart`,
`chat_event.dart`, `message_action_runner.dart`, `timeline_item.dart`),
services (`encryption_service.dart`, `notification_service.dart`,
`service_registry.dart`), largest screens (`room_settings_page.dart`,
`hub_screen.dart`, `theme_spec.dart`), ledgers and `AGENTS.md`.

Overall verdict: this is a disciplined alpha codebase with a real test
suite, honest work ledgers, and consistent licensing/comment style. It
has one systemic complexity problem (the settings stack) and several
medium ones that are quietly compounding. Items are ordered by severity;
suggested priorities are at the end.

---

## 1. The settings stack is ~3,400 lines of hand-unrolled duplication (critical)

This is the single worst complexity offender in the project. One logical
setting currently exists in six places:

1. `SettingsService` key constant (`lib/src/settings/settings_service.dart:198` onwards)
2. `SettingsService` granular getter (`Future<bool> draftsEnabled()` etc.)
3. `SettingsService` update method
4. `SettingsSnapshot` field + constructor default + `loadAll()` line
   (`lib/src/settings/settings_service.dart:28-194`, `421-544`)
5. `SettingsController` private field + initializer
   (`lib/src/settings/settings_controller.dart:76-135`)
6. `SettingsController` getter + update method with clamp logic
   (`lib/src/settings/settings_controller.dart:189+`, `618+`)

Adding one boolean touches roughly eight locations across two files.
That is why these two files alone are ~2,500 lines and will keep growing
linearly with every feature. There are 90+ settings and counting.

Worse, a large chunk is dead: the granular read getters in
`SettingsService` have no callers outside the service/controller pair
since `loadAll()` landed. Verified against `syncDebounceMs()`,
`searchPageSize()`, `logLevel()`, `notifyWhenFocused()`,
`draftsEnabled()`, `autoLockMinutes()`: zero external callers. Several
hundred lines of maintenance surface that can never rot because they are
never executed, but also never removed.

Fix direction: replace the per-field plumbing with a typed descriptor
table:

```dart
class Setting<T> {
  final String key;
  final T initial;
  final T Function(Object? raw) decode;
  final T Function(T value) clamp;
}
```

One `Map<String, Setting<Object>>` drives load, persistence, and
controller accessors generically; `SettingsController.update(key, value)`
becomes one method plus `context.select`-friendly getters where needed.
This deletes well over 2,000 lines and makes adding a setting a one-line
change. Alternative: keep explicit fields but generate the triplet
(snapshot field / service pair / controller pair) with `build_runner`.
Hand-maintaining six sites per setting is not sustainable either way.

## 2. Dialog-and-action copy-paste at scale (high)

Two hotspots:

- `room_settings_page.dart` (~1,866 lines, largest screen) contains nine
  structurally identical edit flows:
  `_editJoinRules` (:785), `_editHistoryVisibility` (:819),
  `_editCanonicalAlias` (:861), `_editGuestAccess` (:906),
  `_editPowerLevels` (:941), `_editDirectoryVisibility` (:1122),
  plus `_editRoomName` (:104) and `_editRoomTopic` (:160).
  Each is: build dialog -> await -> null/mounted guard -> set state
  event -> snackbar. A generic
  `editViaDialog<T>(title, current, options|textField, apply)` collapses
  each method to a few lines and cuts the file roughly in half.
- `MessageActionRunner` is the right idea (canonical actions shared by
  hoverbar/context menu), but `kick` (:272), `ban` (:314), `report`
  (:360), `retrySend` (:415), `cancelFailedSend` (:446), and both
  branches of `confirmDelete` (:191-269) repeat the same confirm -> try
  -> success/error snackbar skeleton. Note `confirmDelete` duplicates its
  own confirmation dialog twice inside one method (:201-220 vs :240-259).
  One `runModerationAction(context, confirmTitle, confirmBody, action)`
  helper removes ~150 lines and guarantees consistent UX.

The snackbar-with-mounted-guard pattern appears dozens of times across
the app; a small feedback helper/extension would remove hundreds of
repetitions.

## 3. God files and long methods (high)

Beyond room_settings_page: `user_profile.dart` (1,498),
`theme_spec.dart` (1,342), `room_details_page.dart` (1,317),
`command_palette.dart` (1,300), `login_page.dart` (1,275),
`video_message_type.dart` (1,222 for a single event renderer),
`chat_box.dart` (1,127). Project conventions say functions under 20
lines; many state classes here have methods three to seven times that.

Concrete example: `ChatBoxState._send`
(`lib/src/chat/chat_box.dart:273-409`) does slash-command parsing,
markdown conversion, relation/thread payload assembly, optimistic draft
handling, timeout wrapping, and error restoration in one ~135-line
method. Extracting `_parseSlashCommand(text)` and
`_buildSendContent(...)` would make each piece unit-testable in
isolation; the slash-command grammar especially deserves its own tests.

## 4. Fragile manual memoization in the event dispatcher (medium-high)

`MessageEventHandler._computeKey`
(`lib/src/chat/chat_event.dart:110-149`) builds a render-cache key from
`identityHashCode(content)`, body lengths, timeline identity, and an
edit-timestamp scan. This works around the SDK mutating events in place,
and it is documented, but it is exactly the kind of cleverness that
fails silently: an edit that keeps `body.length` identical, on a path
where the aggregated-edit lookup misses, renders stale content with no
error. Caching rendered subtrees keyed on hash heuristics is complexity
paid for during every future bug hunt. Consider making item identity
explicit instead: hand children an immutable view-model (partially
exists via `TimelineItem` props) so widgets can be plain const-friendly
and the cache can be deleted.

## 5. Three competing DI/service-location styles (medium)

The app simultaneously uses:

- Provider for most services (`lib/main.dart:370-397`)
- `ServiceRegistry` for shutdown ordering (good idea, but only wired
  for teardown, `lib/src/helpers/service_registry.dart`)
- Classic singletons with static mutable state:
  `TrayService.instance` (`lib/src/services/tray_service.dart:60`),
  `DraftService.instanceFor(accountId)` static registry
  (`lib/src/services/draft_service.dart:77`), and
  `NotificationService._mutedRoomsSnapshot`, a globally mutable static
  read by the tray (`lib/src/services/notification_service.dart:214-216`)

Plus `_AppState` (`lib/main.dart:65-93`) field-for-field duplicates
`BootContext` from `boot.dart` just to feed MultiProvider. Pick one
composition story: services constructed in boot, exposed exclusively
through Provider (or one registry object that is itself provided), no
statics. The muted-rooms static is the riskiest: invisible shared
mutable state any file can touch and no test can isolate.

## 6. Build-phase side effects and deferred-navigation folklore (medium)

`MoonRouter._roomsListPageBuilder` mutates `LayoutShellController`
during a route build (`lib/src/router.dart:492`), and
`_AdaptiveMainLayout.build` calls `shell.update()` mid-build then
schedules a post-frame `GoRouter.go` when the shell flipped
(`lib/src/router.dart:603-614`). `MessageActionRunner.showDetails`
pushes routes from a post-frame callback to dodge a layout assertion
(`lib/src/chat/message_action_runner.dart:114-123`). Each site is
individually explained by a comment, which is honest, but collectively
they show the architecture fighting Flutter's lifecycle instead of
reacting to it. A single window-width widget that commits shell
transitions from a MediaQuery listener (outside build) would eliminate
the whole class of "update during build, navigate after frame" patches,
and their comments.

## 7. Silent error swallowing (medium)

132 bare `catch (_)` blocks across lib/. Some are defensible (probing
SDK state that throws when absent), but many swallow without logging,
e.g. `canEditText` returning true on failure
(`lib/src/chat/message_action_runner.dart:512-516`) inverts fail-safe
into fail-open. Adopt a rule: every catch either logs or carries a
comment naming the expected exception type. Relatedly,
`EncryptionService._refreshBackupState` sets
`_keyBackupCached = enc.crossSigning.enabled` as an admitted guess
(`lib/src/encryption/encryption_service.dart:570-580`); surfacing a
guess as "recovery key cached" in security UI is worse than showing
"unknown".

## 8. Documentation drift in AGENTS.md (medium, cheap to fix)

AGENTS.md materially misdescribes the code it governs:

- Says `matrix: ^7.2.3` and `flutter_vodozemac ^0.5.0`; pubspec has
  `matrix ^9.0.0` and `flutter_vodozemac ^0.6.0`.
- Says `kDbSchemaVersion = 1`; it is 3 (`lib/main.dart:59`).
- Gotcha #11 claims "Reply sending not wired";
  `lib/src/chat/chat_box.dart:342-346` explicitly sends `m.in_reply_to`.
  An agent following the guide would reintroduce a fixed bug.
- The "General flutter rules" appendix recommends lint rules
  (`prefer_single_quotes` etc.) that `analysis_options.yaml` does not
  enable, while the repo mixes relative and package imports freely
  (see `lib/main.dart` imports).

Since AGENTS.md is instructions for agents and contributors, stale facts
here actively cause regressions. Worth enabling stricter lints than
stock `flutter_lints` given the project's stated standards.

## 9. Smaller items worth a pass

- Empty `initState`/`dispose` overrides
  (`lib/src/screens/hub_screen/hub_screen.dart:148-151`, `171-174`);
  categories built once in `didChangeDependencies` guarded by isEmpty,
  so a locale switch never rebuilds labels.
- `ChatBox._attachFile` reads whole files into memory via
  `file.readAsBytes()` (`lib/src/chat/chat_box.dart:496`); fine for
  photos, a multi-hundred-MB video spikes RSS before upload. Stream or
  add a size gate.
- `EncryptionService.init` polls `encryption == null` up to 5 seconds at
  boot (`lib/src/encryption/encryption_service.dart:245-249`); the loop
  should be a named constant with a comment about worst-case latency.
- Windows notification action strings baked in English inside a
  non-widget class ("Mark as read", `notification_service.dart:111-122`);
  need l10n routing.
- `room_settings_page._creationDate` (:83) hand-rolls date formatting
  with `padLeft` instead of `intl`.

## What is genuinely good (so we don't fix what works)

- The collaborator decomposition in `lib/src/chat/chat_timeline.dart`
  (`HistoryPager`, `JumpCoordinator`, `ReadMarkerTracker`) with a
  deliberately thin state class is exactly the right model; extend it,
  do not regress it.
- `lib/src/helpers/async_utils.dart` timeout/retry wrappers used
  consistently across services and UI.
- Test discipline is real: ~50 widget suites, ~39 unit suites, E2E with
  a mock HTTP transport. The settings refactor above is very testable
  because of this.
- The work ledgers are honest and specific, rare in alpha projects.

## Suggested priority

1. Delete or generate the dead/granular `SettingsService` layer, then
   collapse the setting triplet into descriptors (issue 1). Biggest LOC
   win, lowest risk, tests already cover the controller.
2. Extract dialog/action helpers in `room_settings_page.dart` and
   `MessageActionRunner` (issue 2).
3. Correct AGENTS.md drift (issue 8): half an hour of work, prevents
   agent-induced regressions.
4. Standardize DI and remove static mutable state (issue 5).
5. Chip away at god files opportunistically as they are touched, rather
   than a big-bang split.
