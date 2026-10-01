Part of Moonrelay, a matrix protocol client.
Copyright (C) 2025 Surena Karimpour Ghannadi
AGPLv3

WORK_NEEDED

Open work ledger for Moonrelay. Each item is anchored to a file:line or
file path.

Tests at head: flutter test 850 green (unit + widget). flutter analyze 0
issues.

The categories used below are:
- correctness (things that are broken or unreliable)
- performance (CPU, memory, rebuilds)
- refactor (code shape, dead code, consolidation)
- feature (user-facing capability)
- quality (tests, logging, polish)
- security


1. Open bugs and refactors

1.1 Skeleton loading - login to hub navigation still flashes empty

Login to hub navigation: the redirect chain briefly flashes an empty hub
before the first sync. Splash (lib/src/splash_screen.dart) shows a
spinner but should stay visible until the hub has at least one room
cached.

The accounts-page skeleton (lib/src/screens/hub_screen/accounts_page.dart,
the _buildLoading(theme) placeholder while a Future<Profile> is in
flight) is already in place and does not need further work.

1.2 Future-aware surface comments

(See also 26.3 in WORK_DONE.md: _UndecryptableBanner now reads its count via ValueListenableBuilder instead of a setState callback; the comment at lib/src/chat/timeline_view.dart:135 documents the notifier's lifecycle.)

In-room search jump accuracy: ChatTimeline.jumpToEvent
(lib/src/chat/chat_timeline.dart:1134) now uses Scrollable.ensureVisible
The fallback path (when the key is not in the current viewport, e.g.
during rapid pagination) still estimates from a fraction; the existing
comment noting that users may need to scroll up/down after a fallback
jump is still in place at lib/src/chat/jump_coordinator.dart:211.

Superseded in part by WORK_DONE section 53. The fraction estimate is still
there, but a jump to an event the cache does not hold now fetches a
`/context` window and scrolls to the real widget, so the estimate is only
reached for events that *are* rendered or one frame stale. See
WORK_NEEDED.md section 8 for what is still open, including the item-index
map that makes the estimate necessary in the first place.

1.3 Refactor candidates

- `paginate_until_marker_test.dart` asserted a wall-clock bound (the
  pager's 30s global cap, with 1s of headroom) and had to run inside
  `tester.runAsync` so the real stopwatch advanced. It failed once out of
  five full-suite runs on an idle machine, while running under load, and
  passed on three consecutive reruns. SHIPPED in WORK_DONE section 54:
  `JumpToUnreadPager`'s timeout is now an injectable `budget`, defaulting to
  the shipped 30s, so the test waits 300ms and asserts the exact ceiling.

  Two things that fix did not cover, deliberately:

  - `budgetExceeded()` is redundant with the outer `Timer`, and no test can
    tell them apart. Deleting the loop guard leaves the suite green: with a
    hanging server the guard is never reached, because the loop is blocked
    inside `await requestHistory()`. It matters only when the server
    answers promptly and the marker never surfaces. An assertion about
    request counts in that case is CPU-speed dependent, which is the same
    trap that made the original test flaky, so none was written.
  - The test could always pass by returning early. It now asserts a lower
    bound on elapsed time too, so a pager that bailed on the first
    iteration would fail.

- Accent i18n: accent labels are baked English constants
  (lib/src/settings/accents.dart), matching the existing convention for
  preset enums like LayoutDensity/DisplayType. If full localisation of
  accent names is wanted, move the label behind the l10n helper and add an
  `accentColor_<id>` key per locale.

- Design tokens have no test coverage: MoonrelayDesignTokens.standard and
  MoonrelayComponentTokens.fromDesignTokens
  (lib/src/theme/design_tokens.dart, lib/src/theme/component_tokens.dart)
  are pure functions of constants, so a unit test can pin the radius scale
  and the derived per-component values cheaply. Nothing asserts them today.

- HTML tag allow-list: MarkdownToHtml and HtmlTagParser each implement
  their own tag allow-list. Extract a single SanitizedHtml helper.
  (HtmlTagParser was extracted to html_tag_parser.dart in the cleanup
  pass, but the shared allow-list is still outstanding.)

- Color palette: MoonrelayColorPalette mixes raw swatches with
  StringColor wrappers. Either pull in or delete the unused side.

- Provider wiring: boot.dart injects clientFactory/onClientReady;
  app.dart re-wraps in Provider.value. Consolidate into a single
  MoonrelayScope widget.

- Scattered widgets: 60+ _buildXxx private classes. Move them into
  lib/src/widgets/ for reuse.

- Encryption cache invalidation: SHIPPED. EncryptionService._onSync now
  clears _cachedUnverified alongside the per-user/device verification
  caches (lib/src/encryption/encryption_service.dart), so the unverified
  device count in the encryption overview no longer goes stale after a
  sync. The own-device list refresh is also throttled to once per 30s
  from the sync path (still immediate at init, after bootstrap, and
  after device deletion) so the per-sync HTTP/notify churn no longer
  stacks on the SDK's device-keys bookkeeping.

- The settings stack is six hand-unrolled sites per setting. One logical
  setting currently exists as: a key constant, a granular read getter, an
  update method, a `SettingsSnapshot` field with its default and its
  `loadAll()` line, a `SettingsController` field with its initializer, and
  a getter with a clamping update method. Adding one boolean touches
  roughly eight locations across two files, which is why those files are
  ~2,400 lines and grow linearly. The fix direction is a typed descriptor
  table (`class Setting<T> { key, initial, decode, clamp }`) that drives
  load, persistence and the controller getters generically, or a
  `build_runner` codegen pass over the existing triplet. This was
  deliberately left out of the September 2026 pass: it is a large,
  wide-reaching change and not a prerequisite for any of the correctness
  fixes that round made. The test coverage the refactor would lean on
  already exists in `test/unit/settings_controller_test.dart`.

- Most of that surface is dead. `SettingsService` has 75 granular
  `Future<T> name()` getters with zero callers in `lib/`; eight are called
  from tests only (`test/unit/settings_service_test.dart`,
  `settings_controller_test.dart`, `accents_test.dart`,
  `space_pinning_test.dart`) and 67 are called from nowhere at all. With
  the setters, 786 of the file's 1,396 lines are this boilerplate. Deleting
  the 67 is pure deletion with no behavioural risk, but the eight in use
  would first need their test call sites migrated to
  `SettingsController` or `loadAll()`. Worth doing as its own change
  before, not after, any descriptor-table rework.

- The render cache in the event dispatcher is fragile by construction.
  `_MessageEventHandlerState._computeKey`
  (lib/src/chat/chat_event.dart:110-149) hashes `identityHashCode` of the
  content map plus the body lengths plus a scan of the aggregated-edit
  timestamps, as a workaround for the SDK mutating events in place. It is
  documented and it works, but an edit that keeps `body.length` identical
  on a path where the aggregated-edit lookup misses renders stale content
  with no error. The structural fix is to stop handing widgets a live
  `Event` and hand them an immutable view model instead (partly exists
  via `TimelineItem`'s props), so the cache can be deleted rather than
  kept honest by heuristics.

- `MessageActionRunner.showDetails` still pushes from a post-frame
  callback to dodge a layout assertion
  (lib/src/chat/message_action_runner.dart:103-113). This was one of three
  sites in that family; the other two were the router's page builder and the
  shell widget, both removed in the router rewrite. What is left is worth a
  look, but it no longer has company, so it may simply be a
  `context.push` that would work directly.

  The general lesson is in
  `lib/src/layouts/layout_shell_controller.dart`: writing to shared state
  during build is what forced a post-frame `notifyListeners` deferral, which
  in turn made it look safe to also navigate from the same place. The router
  rewrite removed the notification rather than the deferral, because the
  consumers are all descendants of the one writer and read the value in the
  same pass. Check for that shape before adding a post-frame callback
  anywhere.

- Three service-locator styles coexist, and one of them is shared mutable
  state. Services are exposed through Provider (lib/main.dart:370-397),
  shutdown ordering goes through `ServiceRegistry`
  (lib/src/helpers/service_registry.dart, which has a `register` and a
  `shutdownAll` and no lookup at all, so it is teardown-only by
  construction), and three services are classic singletons:
  `TrayService.instance` (lib/src/services/tray_service.dart:60),
  `DraftService.instanceFor(accountId)`
  (lib/src/services/draft_service.dart:77) and
  `NotificationService._mutedRoomsSnapshot`
  (lib/src/services/notification_service.dart:214-216), a globally
  mutable static the tray reads. That last one is the one to fix: it is
  invisible shared state any file can write and no test can isolate.
  Separately, `_AppState` (lib/main.dart:65-93) field-for-field duplicates
  `BootContext` (lib/src/boot.dart:66-78) only to feed MultiProvider, and
  drops `databaseService` in the process; making `BootContext` itself
  provided would delete the copy.

- The largest screens are better but not done. Every screen over about 900
  lines that is a screen rather than a service now has a directory, but
  three State classes are still doing too much in one place:
  `login_page/login_page.dart` (1,109, one State covering the form, the
  sign-in requests and the post-login handoff),
  `command_palette/command_palette.dart` (1,060, where the five
  near-identical paginated fetch pairs want collapsing into
  one) and `hub_screen/hub_screen.dart` (955).
  The login page's flag bundle is gone: `LoginMode` and `SsoStep` replaced
  the booleans, `SsoTokenCapture` owns the local-server lifecycle, and
  `_prepareLoginRequest` / `_runLoginRequest` hold the sign-in opening that
  the three request types used to copy between them. What remains is
  presentation plus the three login requests, and the next thing worth
  doing is moving the form's own widgets out of the State the way the other
  split screens did, since `_buildPasswordSection`,
  `_buildSsoSection` and the four action buttons are still private methods
  on the page. The SSO path keeps its own copy of the middle steps on
  purpose, so it is not a candidate for that.
  `room_settings_page.dart`
  is 1,026, down from 1,774 but still the biggest screen in the app: its
  build method is 280 lines and the state-event edit verbs are all methods
  on the page's State. `ChatBoxState._send`
  (lib/src/chat/chat_box.dart:274-409, 138 lines) does slash-command
  parsing, markdown conversion, relation and thread payload assembly,
  optimistic draft handling, timeout wrapping and error restoration in one
  body; extracting `_parseSlashCommand(text)` and
  `_buildSendContent(...)` would make the slash-command grammar unit
  testable on its own, which it currently is not. Worth chipping at
  opportunistically as these files are touched rather than in one split.
- Most of the remaining bare `catch (_)` sites are legitimate probes of
  SDK state that throws when it is not loaded, and now say so. 88 of the
  132 were carrying no comment and no log; the ones in the files this pass
  touched are annotated and the fail-open `canEditText` is fixed, but the
  other ~75 across lib/ are unaudited. A sweep is unreviewable in one go;
  it wants doing per screen as each is next edited.

- Two things the pass found that are not defects but are worth a decision.
  `flutter gen-l10n` reports untranslated keys in the `fa` table, which is
  pre-existing drift, not from this work. And `code_review.md` is not in the
  `DOCS` list of `tools/check_typography.sh`, so the guard does not scan it;
  add it there if the file stays in the tree, since it contains em dashes.

- Three new `fa` strings came in with the router rewrite and have no
  translation yet: `noRoomSelected`, `noRoomSelectedHint` and
  `stillWaitingForServer` in `lib/src/localization/app_en.arb`. The
  `profileIdNullError` key was removed in the same change, since the error it
  described no longer exists.

1.4 SDK device-keys churn (open, upstream)

The UI freezes during sync ticks on homeservers that constantly churn
device lists. The matrix SDK runs Client.updateUserDeviceKeys() after
every sync tick; when a user's device key list is marked outdated (the
server's device_lists.changed), the SDK re-queries /keys/query and
re-writes EVERY cached device key of the affected users to the database
in one transaction on the main isolate. Measured with
tool/device_keys_bench.dart: 24,000 device keys cost ~720ms per sync
(~560ms of it in the DB transaction alone, the rest in key parsing and
JSON encoding on the main isolate). On the user's homeserver the log
shows 24k-48k device keys rewritten on almost every sync.

The app cannot stop this from the outside; the fix belongs upstream
(batch the device-key writes, skip the re-store when the key hash is
unchanged, or move updateUserDeviceKeys off the sync path). Local
mitigations shipped: throttled own-device refresh and cache-first
devicesForUser (lib/src/encryption/encryption_service.dart). The
"Already seen Device ID has been added again" / "Invalid device"
warnings are server-data artifacts (device ID reuse / malformed keys),
 not app misuse.


1.5 Hardcoded English strings in UX surfaces (quality/polish, deferred)

Several user-facing strings are still hardcoded English instead of living
in app_en.arb/app_fa.arb and routing through l10n. Not touched in the
status-pill/density round:

- lib/src/helpers/room_delegate.dart:158,165  ("Still waiting for the
  server…", "Retry" in the sync-waiting fallback).
- lib/src/screens/encryption/bootstrap_screen.dart:94-101  (wipe-SSSS
  confirmation dialog).
- lib/src/services/deep_link_service.dart:240  ("Invalid Matrix user id: …"
  is surfaced from a service without a BuildContext, so it cannot trivially
  use AppLocalizations; either resolve the string at the UI layer that
  dispatches the deep link, or pass a context through the method-channel
  callback).
- lib/src/screens/hub_screen/settings/appearance_settings.dart:162,166,
  184,188  ("Font size", "Message font size", "UI scale", "Interface scale"
  section/titles are literals; the rest of the page is localized).
- lib/src/screens/create_room_form.dart:316,321,479-480,741-742  (Room/Space
  segment labels, the type subtitle interpolation, and _typeLabel returning
   raw 'room'/'space').
- lib/src/widgets/navigation_sidebar.dart  (the space context-menu items
  "Move Up"/"Move Down"/"Move Group Up"/"Move Group Down"/"Remove from
  group"/"Ungroup all"/"Sort into groups"/"Reset space layout" and the
  group label "Group" were ported verbatim from the deleted navigation
  rail; they should move into app_en.arb/app_fa.arb).


1.7 Integration tests are currently broken (quality, known-fail)

The E2E suite under integration_test/ does not pass in the current
environment, independent of the dashboard refresh.  Until it is
repaired, changes are not validated against it.  Note that
login_test.dart asserts the in-app header title ("Moonrelay" via
find.text); the E2E boot helper
(integration_test/helpers/test_app_boot.dart) now forces
useOsTitleBar=false so the header chrome the tests drive is rendered
inside the Flutter tree.  Any repair pass should keep that opt-in in
place.

1.8 Unreachable left-sidebar width setting (feature, reopened)

The left sidebar is no longer resizable (the drag handle and the hub
slider were removed in the dashboard refresh), so `leftSidebarWidth`
(SettingsController, SettingsService key `left_sidebar_width`) is now
only ever read at its persisted default.  This entry previously left it
open as "keep it for a future picker, or remove it".

Resolved: it is a goal, not dead weight. Per the standing decision in
1.10, a setting with no consumer is a specification for missing app
behaviour, so the width picker comes back rather than the setting going
away. Concretely that means a resizable left sidebar again
(`lib/src/layouts/dashboard_layout/`), which also needs the clamp
disagreement resolved: `SettingsController.setLeftSidebarWidth` clamps
to 200..600 while the consumer at
`lib/src/layouts/dashboard_layout/dashboard_view.dart:86` clamps to
200..360, so any value in between persists and is then silently
discarded at render. Pick one range and put it in a named constant
next to `LayoutBreakpoints.minSidebarWidth` in
`lib/src/helpers/responsive.dart:87`.


1.6 Silent failure surfaces with no retry affordance (quality, deferred)

Two spots swallow server errors silently and leave the user with no
recovery path (logged here so the empty-state pass doesn't claim them):

- lib/src/widgets/sidebar_members_list.dart:222-224  The server
  member backfill (`_fetchMissingBatch`) catches and swallows errors
  with no UI. The local member set is shown, but there's no "couldn't
  load remote members, tap to retry" row, so a transient server blip
  looks identical to "these are all the members". Add a fetch-error
  flag + inline retry row to the members list footer.
- lib/src/helpers/threads_provider.dart:115-117  `ThreadsProvider`
  swallows thread-roots fetch failures. Expose a `hasError`/`error`
  state and let the consumers (`FullRoomThreadsList` in
  lib/src/screens/room_threads_view.dart and
  lib/src/widgets/thread_list_sidebar.dart`) render a retry row instead
  of silently showing an ever-shrinking list.


1.9 Working-tree line endings drift from .gitattributes (mostly resolved)

.gitattributes declares `* text=auto eol=lf`, but the working tree had
accumulated CRLF endings in 137 tracked files (checked out before the
attribute existed, or last saved by a Windows editor). The August 2026
typography sweep normalized every one of them to LF in the working
tree, and git's index now agrees everywhere.

One residue remains: 17 of those files still have CRLF inside their
committed blobs (.gitignore, analysis_options.yaml,
lib/src/settings/settings_service.dart, test/unit_test.dart,
test/widget_test.dart, and the windows/runner C++/CMake set plus
windows/.gitignore), so they currently show as whole-file diffs. They
will normalize into whatever commit next touches them, or you can run
`git add --renormalize .` first to land the line-ending fix on its own;
doing it alongside unrelated content changes makes diffs noisy.


1.10 Unwired settings are a specification, not dead code (feature, decision)

Standing decision, recorded because an audit proposed the opposite and
the reasoning matters more than the finding. When a setting looks like
it does nothing, the correct reading is that the app is unfinished, not
that the setting is surplus. A setting that persists, round-trips and
renders a confident control while nothing reads it is a promise the
code has not kept yet. So these are to be implemented, not deleted, and
in most cases the fix belongs in the service that was supposed to
consume the value rather than in the settings layer at all.

SHIPPED for 19 of the 23, in WORK_DONE.md 39. Wired, with the surface
each one landed on:

- syncDebounceMs, the `SyncPulse` fan-out window. The debounce was
  already a constructor argument; it is now a settable field pushed
  from `app.dart` on every build, so the change is live.
- searchDebounceMs, the in-room search keystroke debounce.
- draftAutosaveMs, the `DraftService` autosave window. Pushed on every
  composer load because the service is a ref-counted singleton that
  outlives any single composer.
- notificationPersistMs, both notification prefs-debounce sites.
- deepLinkDedupMs, the deep-link duplicate-suppression window, seeded
  from the controller at boot.
- encryptionRefreshDebounceMs, the per-sync refresh coalesce. Passed to
  both `EncryptionService` construction sites, since a new service is
  built per account switch.
- firstSyncTimeoutS, the boot first-sync wait. One line: settings load
  before the wait, so the hard-coded eight seconds was simply wrong.
- searchPageSize, the in-room search page limit. The `app_en.arb` label
  says "In-room search page size", so it deliberately does NOT govern
  the command palette, whose per-call limits are a UX decision.
- notificationDedupeCacheSize, the in-memory dedupe bound. Its minimum
  was 0, which would have emptied the cache on every insert, so the
  controller clamp now starts at 1.
- logMaxFileSizeMb, logMaxFiles, logFlushDelayS and logLevel, through a
  new `LogService.reconfigure`. See the logging note below.
- wipeLogsOnLogout, which was calling `wipeLogs` unconditionally on
  logout regardless of the toggle.
- trayLeftClick, all three values now implemented, including a
  previously-absent `openUnread` that routes through `DeepLinkService`.
- deepLinkAutoJoin, in the one place a deep link meets a room.
- dbBackupKeepCount, over timestamped backups instead of a single
  fixed-name `.bak`.
- draftRetentionDays, as an expiry check on draft load. The timestamp
  was already persisted and parsed, so this needed no new bookkeeping.
- attachmentClickThresholdMb, via a new shared policy helper. See the
  note below.

The logging group needed a real reconfigure path rather than a
one-line swap, and the reason is worth keeping. The logger package
exposes no setters for size, retention, flush delay or level, so the
sink has to be rebuilt. `Provider<Logger>`, `BootContext.log` and the
closure captured by `MoonShutdown.register` all hold the `Logger` built
at boot, so replacing it would leave every one of them writing into a
destroyed sink. `LogService` therefore swaps the output behind the
stable `_RedactingLogOutput` wrapper and never replaces the `Logger`
itself; there is a test asserting the identity holds across a
reconfigure.

That work also surfaced two live bugs, both of which made the
`logVerboseRelease` toggle do nothing:

- `updateVerboseRelease` assigned the static `Logger.level`, but
  `LogService.create` passes a non-null level to the constructor, which
  `Logger` stores on the filter, and `LogFilter.level` reads
  `_level ?? Logger.level`. With `_level` set the static is never
  consulted. It now sets the level on this logger's own filter, which
  also stops it mutating every other `Logger` in the process.
- Because the service is constructed before settings load, the four
  logging settings would only have taken effect from the first change
  made in the settings page. `boot.dart` now re-asserts the whole
  policy right after loading settings, and an unchanged policy is a
  no-op so this does not churn the sink.

`logMaxFiles` also needed a semantic decision: the logger treats a null
retention count as "keep everything", and the setting defaults to 0.
Reading 0 as "unlimited" rather than "delete every archive on rotation"
is what the label implies, so 0 is mapped to null. Pruning inside the
logger only runs on rotation, which with a 32 MB file may be months
away, so a lowered limit sweeps for itself rather than waiting.

`attachmentClickThresholdMb` was the one setting where the name pointed
somewhere it could not go. It is not an upload cap: `kMaxUploadBytes` in
`lib/src/helpers/upload_limits.dart` is a deliberate 512 MB guard against
a phone 4K video exhausting the UI isolate, and the setting's slider
tops out at 200 MB, so wiring it there would have turned a design
decision into a user preference. It belongs on the auto-download path,
where five renderers each carried a private copy of the
always/wifi/never switch and none of them looked at size at all. Those
now share `AttachmentDownloadPolicy`, and the size guard comes with a
`ClickToDownloadTile` affordance, because the previous "did not
auto-download" state rendered a dead icon with no tap handler. Video,
audio and file needed no new affordance because each already has a
download control; stickers are exempt from the threshold, since a
threshold there would only replace a sticker with a download tile.
An unknown `info.size` is not treated as large, or events from clients
that omit the field would never load.

All twenty-three are now resolved, and not in the direction this entry
originally proposed. Two were deleted, one was renamed and wired, and the
presence work uncovered considerably more than a settings gap. Recorded
in WORK_DONE.md 40; the reasoning for each is here.

- dbWipeRequiresPrompt and avatarCacheTtlDays were removed rather than
  wired, on the argument in the shipped notes: both describe features
  the app does not have, and a control that silently does nothing is
  worse than an absent one. The db wipe prompt in particular cannot be
  honoured where the wipe happens, in `DatabaseService.openDatabaseFor`
  during boot, before any route exists. avatarCacheTtlDays wanted a
  disk cache that does not exist, against an in-memory LRU where a TTL
  in days is not expressible.
- autoLockEnabled and autoLockMinutes became
  autoOfflinePresenceEnabled and autoOfflinePresenceMinutes, which is
  what the setting's own l10n description always said it did. The
  minutes default moved off zero, because a user who turned the toggle
  on without touching the slider would otherwise get "go offline on
  every activity gap" with no way back in.
- Everything else shipped in WORK_DONE.md 39, and two of the fixes
  turned out to be the more important half of their commits:
  `logVerboseRelease` never worked, and neither did a manual
  "Appear offline" choice, because neither pinned `Client.syncPresence`
  and the server therefore marked the client online on the next
  long-poll. A presence control that cannot hold its own state is the
  same class of bug as a settings control wired to nothing.

What follows is the original analysis, kept because it records the
thinking behind the decision above. Several claims in it turned out to
be wrong, and the corrections are in the shipped notes above; the
reasoning is what is worth keeping.

The sharpest case is the logging group, which settles the principle by
its own size. `LogService.create`
(lib/src/helpers/log_service.dart:166-170) took
`maxFileSizeKB` and two levels as parameters with defaults of 32 MB and
warning/all, and it is called from lib/src/init_logger.dart:30 before
settings have loaded, so it could never see them. Meanwhile
`advanced_settings.dart:157-193` gave the user four controls over
exactly those values (logMaxFileSizeMb, logMaxFiles, logFlushDelayS,
logLevel) and a fifth over verbosity (logVerboseRelease) which this
analysis wrongly believed was the only one with any effect. It was not:
that toggle never worked either, because the level was assigned to the
static `Logger.level` while the filter holds its own non-null level. The
work was therefore larger than a parameter pass: a reconfigure path, and
a level that lives on the filter.

The same shape recurs across the rest. Roughly 22 settings had no
consumer anywhere in lib/, and they were the clearest statement of what
the app still owed its user:

- autoLockEnabled, autoLockMinutes
  (lib/src/screens/hub_screen/settings/privacy_settings.dart:124-141).
  There is no auto-lock at all. A green toggle for a lock that does not
  exist is the failure mode AGENTS.md warns about with "never derive a
  security fact from an unrelated one", and here it is worse: nothing
  is being derived, there is just nothing there. It needs an idle timer
  that clears the encryption keys and re-locks, per account, surviving
  sleep and resume. Still unwired: see the deferred notes above, which
  add that its own l10n description promises a presence change rather
  than a lock, and that the SDK offers no way to clear keys from a live
  session.
- trayLeftClick, with a `TrayClickAction` enum
  (lib/src/settings/chat_preferences.dart:41-45) and a three-way picker
  at `background_settings.dart:112-135` that selected among three
  behaviors, none of which `TrayService` implemented. Shipped.
- avatarCacheTtlDays, dbBackupKeepCount, dbWipeRequiresPrompt,
  draftRetentionDays, attachmentClickThresholdMb. Each is a real
  storage-policy knob with no policy behind it, and
  `DatabaseService` did the wipe and the backup on a fixed schedule.
  Three shipped; the other two are deferred, with reasons.
- syncDebounceMs, searchDebounceMs, draftAutosaveMs,
  notificationPersistMs, deepLinkDedupMs, encryptionRefreshDebounceMs.
  Six debounce settings, all read by nobody, and all naming a timer
  that already exists in the corresponding service with a hard-coded
  constant: the sync pulse, the in-room search debounce, the draft
  autosave in `DraftService`, the notification flush, the deep-link
  dedup window at `deep_link_service.dart:108`, and the
  `EncryptionService` refresh throttle. All shipped. Two needed a
  live-set rather than a construction-time value, because the service
  outlives the user action that would change them: `DraftService` is a
  ref-counted singleton, and `EncryptionService` is rebuilt per account
  switch so its two construction sites have to stay in agreement.
- firstSyncTimeoutS. This analysis also called the first-sync wait
  "structurally a no-op" (see 1.12). That was wrong: it awaits
  `sdk.onSync.stream.first` and does yield to the event loop. The
  setting was simply hard-coded at eight seconds, and is now wired.
- searchPageSize, which this analysis assumed meant the command palette
  and the in-room search. The `app_en.arb` label says "In-room search
  page size", so it deliberately does not govern the palette, whose
  per-call limits are a UX decision rather than a throughput one.

Two consequences for how the rest of this audit is read. First, the
deletion sweep in 1.11 does not touch any of these, and the descriptor
table in 1.16 does not either: both are shape refactors that must
preserve every existing key. Second, where a control is a lie today
and its implementation is not scheduled, the interim move is to hide or
disable the control rather than to delete its setting, so the spec
stays in the tree.


1.11 Refactor audit September 2026: confirmed dead code (refactor)

Everything in this section was verified by import-graph search over
lib/, test/ and integration_test/, not by name matching, which is why
these counts are trustworthy. Roughly 1,400 lines, and none of it
behaves differently when it goes. This is the cheapest maintainability
win available and it should land before any of the shape refactors,
because every later change is easier to review against a smaller tree.

- lib/src/screens/create_new_room.dart, 525 lines, zero importers and
  no route. It is a complete, plausible-looking second create-room UI,
  which is what makes it costly: a reader has every reason to assume it
  is the live path. It is a fork that predates the current form and has
  drifted: hardcoded geometry where the live form uses tokens, no
  join-rule picker, no parent-space support, hardcoded English, and the
  worst version of the build-phase snackbar bug, which never clears
  `_error` and so re-queues the same message on every rebuild. Delete
  it. Do not merge it; `CreateRoomWidget` in
  lib/src/widgets/create_room_form/ supersedes it, and
  `router.dart` routes `/main/addroom` to a wrapper that embeds it.
- lib/src/widgets/common/, four of six files dead: action_tile.dart,
  info_chip.dart, info_row.dart, section_header.dart, 258 lines, zero
  importers. The two survivors are `status_card.dart` (one importer) and
  `feedback.dart` (three), so the directory cannot be removed, only
  thinned. This is also a naming trap: `widgets/common/feedback.dart`
  and `helpers/feedback.dart` are two independent snackbar and confirm
  toolkits with different APIs, and only the helpers one is what
  AGENTS.md mandates. The dead `info_chip.dart` is worse than dead,
  it is a third `InfoChip` (the live one is
  lib/src/widgets/info_widgets.dart:25, and there is a fourth private
  copy at room_preview_screen.dart:618), and the three render with
  different contrast, so room chips and space chips do not match today.
- lib/src/services/read_marker_service.dart, 99 lines, referenced only
  by its own test. The live implementation is
  lib/src/chat/read_marker_tracker.dart. Delete both.
- lib/src/chat/timeline_item_sender_name_and_timestamp.dart, 52 lines,
  referenced only by its own test. It is a fourth copy of the
  sender-name-plus-timestamp row that `timeline_item.dart` already
  writes out three times, and it carries a comment admitting it is a
  workaround ("So get this. I can't just solve this the peaceful way").
  Delete it and its test.
- `SettingsService`'s granular getter layer, about 500 lines. See 1.16,
  which supersedes the treatment in 1.3 and explains why deleting the
  67 genuinely-unused ones is separate work from the 8 the tests touch.
- The unreferenced token surface: `MoonrelayChatTokens`
  (lib/src/theme/component_tokens.dart:639-699, 61 lines, nine fields,
  zero readers anywhere including the theme builder), the two dead
  `copyWith` blocks (design_tokens.dart:235-323 at 89 lines and
  component_tokens.dart:84-118 at 35, unreachable by construction since
  `MoonrelayDesignTokens` has exactly one instance shape), the unused
  `MotionLevel` enum, `LayoutBreakpoints.shouldUseCompact` and
  `shouldUseMobile` (lib/src/helpers/responsive.dart:133,142, which the
  real logic in `LayoutShellController._targetFor` replaced), and the
  nine design tokens with zero read sites including the entire shadow
  and curve systems. Note that the AGENTS.md claim that only
  `components.avatar` is read outside the theme builder is accurate
  and was re-verified across all fifteen sub-token classes; the dead
  `chat` class is the one it does not mention.


1.12 Refactor audit September 2026: defects (correctness)

These produce wrong behaviour, a crash, or a silent failure. They are
ordered by cost to fix, not by severity, because the cheap ones are
cheap.

- `withRetry` does not throw, and about a dozen call sites discard the
  result and report success anyway. `lib/src/helpers/async_utils.dart:89`
  returns `RetryResult.failed(e)` on the last attempt instead of
  rethrowing, so the surrounding `try`/`catch` never fires and the
  bug is invisible to review. `space_settings_page.dart:534` shows
  "Room added to space" after a failed add; the same shape is at
  my_profile_page.dart:185, delete_space_progress.dart:71,102,
  room_settings_page.dart:262, create_room_form.dart:206,
  edit_message_dialog.dart:114, poll_message_type.dart:114,
  voice_recorder_dialog.dart:180 and login_page.dart:812. Two call
  sites already check the result correctly
  (`rooms_pane.dart:306`, `chat_timeline.dart:269`), so the intended
  usage is not in doubt. Make `withRetry` rethrow on exhaustion and
  repair every caller in one sweep.
- Seven persisted enums are read without a bounds check, and enums are
  stored by ordinal. `settings_service.dart:503` has the correct
  `_readEnum` helper; `:313, 325, 337, 483, 488, 493, 499, 608` do
  `values[index]` directly. Reordering or inserting a value in
  `LayoutMode` or `RightPaneChoice` during alpha therefore throws
  `RangeError` out of `loadAll()`, which `boot.dart:186` awaits with no
  try, and the app cannot boot with no recovery path. Route all eight
  through `_readEnum` now; persisting by `name` instead of `index` is
  the durable fix and can follow.
- `void ... async` handlers whose futures are discarded. The
  `room_settings_page.dart:174` `_leaveRoom` is the clearest: it is
  passed bare as `onTap:` at `:600`, and its inner `try` covers
  `room.leave()` but not the `showDialog` that precedes it, so a throw
  during dialog construction becomes an unhandled zone error with no
  log and no user feedback. Same class at
  `encryption_overview.dart:557, 602, 619`
  (three handlers, none awaiting `enc.onBootstrapFinished()`, so the
  success snackbar can appear before the service has refreshed) and at
  `notification_service.dart:357` (the notification tap handler, where
  the errors come from `processUri`).
- `boot.dart:183` calls `SystemTheme.accentColor.load();` and discards
  the future. `system_theme` catches `MissingPluginException` but
  rethrows anything else, so a `PlatformException` during boot is an
  unhandled async error. Await it, inside the step's own try, so the
  accent is also resolved before first paint.
- `chat_box.dart:196-203` `_fillEditText` assigns `_controller.text`
  after an `await` with no `mounted` guard on either the success or
  the catch branch. Tap Edit then navigate away before `getTimeline()`
  resolves and this writes to a disposed `TextEditingController`. Every
  other async path in that file guards (`:124, 136, 379, 387, 395, 468,
  474, 489`), so the fix is two lines and the inconsistency is the
  tell.
- `encryption_overview.dart:513` builds `FutureBuilder(future:
  enc.countUnverified())` inside `build`. The page watches
  `EncryptionService`, which refreshes on every sync, so each tick
  constructs a new future, `data` is null, and the unverified-count
  card collapses to zero height and re-expands. It is also a redundant
  SDK walk per tick, and the walk at
  `encryption_service.dart:818-855` is synchronous, so it runs on the
  UI isolate. Hold the future in a field invalidated by the same cache
  as the service's other memoizers.
- `timeline_view.dart:171-179`: the item cache key has no room id and
  no timeline identity. `ChatTimeline` and `TimelineView` both hold
  stable `GlobalKey`s, so neither State is destroyed on a room switch,
  and `_timelineVersion` is only ever incremented
  (`chat_timeline.dart:329`), never reset. After switching rooms the
  new timeline produces an identical key, `didUpdateWidget` skips
  invalidation, and the previous room's items render under the new
  room's header until the first sync callback fires. The precedent for
  the fix is one line away, at `chat_event.dart:145`, which already
  keys on `identityHashCode(timeline)`. A widget test belongs beside
  test/widget/timeline_content_update_test.dart.
- SHIPPED in WORK_DONE.md 38: `LogService.wipeLogs` had been calling
  `fileOutput.destroy()`, which closes the sink and cancels the rotation
  timer, and was reachable from logout and the Clear Logs button, both
  of which leave the app running, so every line after either one was
  buffered and never written for the rest of the process. It now
  re-initialises the output after deleting, and a new `dispose()` is
  the process-exit path.
- The cold-start deep link is parsed and discarded. `boot.dart:239`
  initializes `DeepLinkService`, and `deep_link_service.dart:102` calls
  `onMatrixUri`, but `DeepLinkListener` assigns that callback in a
  post-frame callback later, so on a cold start there is no receiver and
  no queue. The comment at `boot.dart:232-234` states the intent, and
  the intent cannot work as written. Buffer until the listener attaches,
  and make `onMatrixUri` a setter so the flush is guaranteed.
- The first-sync wait blocks the boot pipeline with no frame scheduled.
  `boot.dart` awaits `sdk.onSync.stream.first.timeout(...)`, which is a
  real wait, but `runBootPipeline` itself is awaited from
  `main.dart` outside any frame, so nothing calls `setState` while it
  runs and the splash animation freezes for the duration. The
  hard-coded eight seconds is now the user's `firstSyncTimeoutS`, which
  makes the ceiling reach 60, so the freeze is longer than it was. The
  wait should either pump a heartbeat frame or drop out of the pipeline
  entirely: "no rooms yet" is a loading state `RoomsListRoute` already
  has a spinner and a retry for.


1.13 Refactor audit September 2026: service ownership (correctness, refactor)

SHIPPED, partly. The ownership split itself is done and is recorded in
WORK_DONE.md 38: `AccountManager` is now the single owner of the
`Client` and the `EncryptionService` (the stale registry entry that held
a disposed notifier after an account switch is gone, and
`performShutdown` takes the manager so it resolves the live pair at
teardown time instead of the boot client frozen into the closure),
`AutoUpdateService` is registered and its `http.Client` is finally
closed, `LogService` has a `dispose()`, and `DatabaseService` documents
why it correctly owns no handle. `LogService.wipeLogs` also no longer
destroys the log sink, which was the sharper of the two live bugs.

What is left is instance-level correctness inside individual services
rather than ownership questions, so it does not depend on that pass
having landed:

- `EncryptionService.dispose()` does not cancel `_ongoingRefresh`, and
  the `mounted` guard at `encryption_service.dart:325-341` is a
  `ChangeNotifier` member, so it does not actually detect `dispose()`.
  A sync tick, then a device-list HTTP call in flight, then an account
  switch that disposes the instance, then the response arriving, means
  `notifyListeners()` on a disposed notifier. Add an explicit
  `_disposed` flag. `AccountManager.shutdown` now disposes this
  service, so the path is reachable from a normal quit as well as from
  a switch.
- `EncryptionService.init` is not re-entrancy safe. `_isInitialized` is
  set at the end (`encryption_service.dart:290`) while the subscription
  is assigned at `:280`, and both `boot.dart:213` and
  `post_login.dart:44` can call it, so two overlapping inits leak the
  first subscription.
- `NotificationService` is never constructed on a fresh login
  (`boot.dart:246-262` is the only construction site in lib/, and it is
  inside `if (sdk.isLogged())`), but three call sites read it from the
  provider unguarded: room_notification_tile.dart:47,58,
  room_details/room_notification_tile.dart:49,60 and
  notification_settings.dart:101. Construct it unconditionally and let
  init no-op until an account is active. It also binds to the boot
  client in `init` and never rebinds, unlike `TrayService` which does
  this correctly at `tray_service.dart:168-191`, so notifications stop
  silently after an account switch, and its per-account state
  (`_lastNotifiedEventIds`, `_mutedRooms`, `_focusChecked`) leaks
  across accounts. `RoomStateBus.bind` has the same defect: the
  `userID` guard in `app.dart:77-82` is right for `SyncPulse` and wrong
  for `RoomStateBus`, whose `bind` early-returns, so a switched account
  gets no room events at all. The rebind work is a natural companion to
  a notification setting, so 1.10 may be the better moment for it.
- `DatabaseService` compares one global `db_schema_version` prefs key
  against per-account databases (`database_service.dart:42-48, 95-97`).
  Account A bumps to v3 and wipes; account B is still at v2, sees 3, and
  is not wiped, so it runs an old schema on new code. Key the version
  by account.
- `router.dart:133` holds the route table in a `static final` list, and
  the two `ShellRoute`s allocate `GlobalKey<NavigatorState>` in their
  constructors. `app.dart:53-56` correctly moved router construction
  into the State to avoid cross-router key reuse, but the route objects,
  and therefore the keys, are still shared singletons. Two live routers
  reuse them; test/widget/router_test.dart creates seven and passes only
  because each tree is torn down first. Make it a getter or a
  `buildRoutes()` function. Unrelated to service ownership; listed here
  only because the audit found it in the same pass.

Two further items from the same audit are cheap and were left alone
while the ownership question was open:

- `DatabaseService` is now documented as owning no handle, which
  closed the "four untracked services" count to three; the other two
  (`DraftService`, via its ref-counted `instanceFor` and the consumer
  `release` calls, and `TrayService`, which is a singleton torn down
  explicitly in `performShutdown`) were always deliberately handled
  rather than missed.
- `room_notification_sheet.dart:35-38, 96` writes the
  `notification_muted_rooms` key directly while
  `notification_service.dart:830-884` owns the same key and keeps the
  in-memory set the tray badge reads. Muting from the sheet updates
  disk but not the service, so notifications keep arriving and the tray
  badge does not clear until restart. Route it through the service.

- `EncryptionService.dispose()` does not cancel `_ongoingRefresh`, and
  the `mounted` guard at `encryption_service.dart:325-341` is a
  `ChangeNotifier` member, so it does not actually detect `dispose()`.
  A sync tick, then a device-list HTTP call in flight, then an account
  switch that disposes the instance, then the response arriving, means
  `notifyListeners()` on a disposed notifier. Add an explicit
  `_disposed` flag.
- `EncryptionService.init` is not re-entrancy safe. `_isInitialized` is
  set at the end (`encryption_service.dart:290`) while the subscription
  is assigned at `:280`, and both `boot.dart:213` and
  `post_login.dart:44` can call it, so two overlapping inits leak the
  first subscription.
- `NotificationService` is never constructed on a fresh login
  (`boot.dart:246-262` is the only construction site in lib/, and it is
  inside `if (sdk.isLogged())`), but three call sites read it from the
  provider unguarded: room_notification_tile.dart:47,58,
  room_details/room_notification_tile.dart:49,60 and
  notification_settings.dart:101. Construct it unconditionally and let
  init no-op until an account is active. It also binds to the boot
  client in `init` and never rebinds, unlike `TrayService` which does
  this correctly at `tray_service.dart:168-191`, so notifications stop
  silently after an account switch, and its per-account state
  (`_lastNotifiedEventIds`, `_mutedRooms`, `_focusChecked`) leaks
  across accounts. `RoomStateBus.bind` has the same defect: the
  `userID` guard in `app.dart:77-82` is right for `SyncPulse` and wrong
  for `RoomStateBus`, whose `bind` early-returns, so a switched account
  gets no room events at all.
- Two writers for the mute preference, and the wrong one is in the UI.
  `room_notification_sheet.dart:35-38, 96` writes the
  `notification_muted_rooms` key directly while
  `notification_service.dart:830-884` owns the same key and keeps the
  in-memory set the tray badge reads. Muting from the sheet updates
  disk but not the service, so notifications keep arriving and the tray
  badge does not clear until restart. Route it through the service.
- `DatabaseService` compares one global `db_schema_version` prefs key
  against per-account databases (`database_service.dart:42-48, 95-97`).
  Account A bumps to v3 and wipes; account B is still at v2, sees 3, and
  is not wiped, so it runs an old schema on new code. Key the version
  by account.
- `router.dart:133` holds the route table in a `static final` list, and
  the two `ShellRoute`s allocate `GlobalKey<NavigatorState>` in their
  constructors. `app.dart:53-56` correctly moved router construction
  into the State to avoid cross-router key reuse, but the route objects,
  and therefore the keys, are still shared singletons. Two live routers
  reuse them; test/widget/router_test.dart creates seven and passes only
  because each tree is torn down first. Make it a getter or a
  `buildRoutes()` function.


1.14 Refactor audit September 2026: duplication (refactor)

`chat_event.dart` and `timeline_item.dart` are not duplicate renderers.
`TimelineItem` composes `MessageEventHandler`, and the split of
responsibilities is defensible. The duplication is in the machinery both
reimplemented independently, and the two largest items are the ones
that also carry a latent bug:

- Two hand-rolled render caches, one nested inside the other, with
  divergent keys. `_HandlerRenderKey`
  (lib/src/chat/chat_event.dart:763-838, 75 lines) and `_ItemRenderKey`
  (lib/src/chat/timeline_item.dart:756-827, 71 lines) are two
  `@immutable` records over overlapping fields, with two hand-written
  `operator ==` and two `Object.hash` calls over the same lists. An
  edit that invalidates the outer key but not the inner leaves the
  pre-edit body on screen. `TimelineView` already caches the widget
  list and `ChatTimeline` already narrows settings with a `Selector`,
  so the real cost is re-running one `build`, not its descendants.
  Deleting both is likely correct; if a measurement says otherwise,
  extract one shared cache mixin with one invalidation story.
- The nine-line capability probe is copy-pasted verbatim into
  `message_actions.dart:74-83` and
  `message_context_menu.dart:101-110`. Both call `event.canRedact`
  bare inside a `build`, one file away from
  `message_action_runner.dart:429-438`, which guards that exact call
  with a comment explaining that the SDK throws from it before room
  state has loaded. A capability check that answers `true` on error
  puts a button in front of the user that then fails, which is the
  specific thing AGENTS.md forbids. One `MessageCapabilities.of(event,
  room, timeline)` value object, computed once, fixes the drift and the
  unguarded call together.
- `_renderContent` (chat_event.dart:298-441) is a 144-line nested
  switch containing a dead branch: `:399` tests
  `event.type == 'm.poll.start'` inside `case EventTypes.Message:` of
  the outer `switch (event.type)`, so the `PollMessageType` it builds
  is unreachable. It also writes the same "content plus edited marker"
  `Column` six times (`:344-397`, one per media type) and the
  verification dispatch twice (`:319-324` and `:433-438`). A table
  keyed by message type collapses the first; the second is a
  mis-ordering that the comment at `:430-432` explains as legacy
  servers sending these as raw event types.
- Smaller but real: `isEdited` is computed in four places
  (chat_event.dart:326,477, message_actions.dart:82,
  message_context_menu.dart:109), the sender-name-plus-timestamp row in
  three (timeline_item.dart:549, 630, 719) with three different font
  ratios, the avatar slot in two, the message body composition in two
  (`:451` and `:726`, which is why IRC mode silently lacks receipts,
  delivery state and thread indicators), and the context-menu gesture
  block in two (timeline_item.dart:305-340 and
  redacted_event.dart:128-159).
- Three error-handling idioms in one feature area:
  `context.showActionResult` in the runner, hand-rolled
  `ScaffoldMessenger` in chat_box.dart (four sites, none of which log)
  and reactions_bar.dart (two sites), and bare `catch (_)` with no
  comment and no retry in `in_room_search_panel.dart:290` and
  `search_provider.dart:250, 286, 335`. The search one is the same
  defect as 1.6 and is not on that list: a 500 from the homeserver is
  indistinguishable from "no results" and `SearchProvider` has no
  `Logger` to report through, so the swallow is structural.
- One more duplication that is a behavior bug, not just a size one.
  `_isSameSenderAndCloseInTime` exists twice
  (lib/src/chat/timeline_model.dart:68 and
  lib/src/chat/pinned_events_list.dart:115-125) and they disagree: the
  pinned list has no sticker exclusion, and `inMinutes.abs() <= 10` is
  not the same predicate as a raw millisecond comparison. A third copy
  of the same ten-minute rule lives at
  `DateTimeExtension.sameEnvironment` (date_time_extension.dart:33),
  which is the one both should call.


1.15 Refactor audit September 2026: screen decomposition (refactor)

Purely mechanical and safe to defer, but the project's own rule (a
screen has a directory, one file per sub-page) is being violated in a
few places, and these are the offenders by `build` method length:

- lib/src/widgets/create_room_form/create_room_form.dart: `build` is
  497 lines, and the directory holds two files for it. The four
  `TextField`s repeat a 13-line `InputDecoration` and a 6-line label
  style; four `Card`+`SwitchListTile` blocks are identical; the five
  `JoinRuleTile`s differ only in value, icon and title, so they want a
  loop over a const list. Two defects live in the same file:
  `create_room_form.dart:485-486` interpolates the private getter
  `$_typeLabel` into what reads as a localised string, so a Persian UI
  gets English concatenated into the visibility card one line below two
  properly localised titles; and eight `setState` calls at `:330, 500,
  536` are wrapped in `addPostFrameCallback` for no reason, which is
  why the visibility toggle and the join-rule radio can briefly
  disagree, since `:504-509` mutates `_joinRule` inside the deferred
  callback one frame after the switch visually moved. Line 632 of the
  same file already does it correctly with a bare `setState`.
- lib/src/screens/encryption/bootstrap_screen.dart:
  `_buildStateWidget` is 418 lines, a single switch over eleven
  `BootstrapState` values with an inline widget per case, plus 17
  copies of the same `try`/`catch`-then-snackbar shape and two bare
  `catch (_)` with no comment at `:298, 314`. Worse, `:96-110` is an
  entire destructive key-wipe confirmation dialog in hardcoded English,
  which means a user who has told us they cannot read the warning taps
  through an irreversible wipe. It also never disposes
  `_passphraseCtl` (`:46`) and never clears `Bootstrap.onUpdate`
  (`:53`), which retains the State.
- lib/src/screens/room_settings/room_settings_page.dart: 1,026 lines,
  so larger than the directory that contains it, with a 283-line build.
  The seven `_edit*` state-event verbs (`:772-1025`) want to become
  free functions taking `(BuildContext, Room)`, and `_pickOption` /
  `_promptText` (`:688-753`) are generic and context-free, so they
  belong in lib/src/widgets/ rather than inside a room page.
  `space_settings_page.dart` re-implements both inline instead. That
  file is 767 lines with no directory at all, despite already importing
  two siblings from `screens/space_settings/`, and the two pages are
  roughly 80 percent the same file: identical avatar-upload-and-
  snackbar blocks, the same edit-name and edit-topic dialogs inlined,
  and three copies of the Synapse admin delete URL.
- Smaller, but the same shape: `hub_screen/my_profile_page.dart`
  (301-line build, no directory), `hub_screen/accounts_page.dart`
  (242), `hub_screen/about_page.dart` (182),
  room_directory_search.dart (three builders in 633 lines).

One defect in this group is not about size at all.
`room_settings_page.dart:911-917` reads the room's current directory
visibility from `m.room.history_visibility` and its `visibility` key,
which does not exist (the state event has `history_visibility`), so
`current` is always `'private'`. The dialog therefore always shows
private selected and invites the user to change a value that may
already be correct. Per AGENTS.md's "model it as unavailable" rule,
drop the radio and make the tile a toggle that flips the current value,
so there is nothing to misreport.


1.16 Refactor audit September 2026: the settings layer itself (refactor)

This supersedes the treatment of the same material in 1.3, which
measured the file at 786 of 1,396 lines as boilerplate. The shape
problem is confirmed and slightly worse than 1.3 recorded, but the
deletion is now split from the refactor on purpose, and the descriptor
table must preserve every key including the unwired ones from 1.10.

The mechanical facts, all re-verified. `SettingsSnapshot` has 77
fields; `SettingsService` declares 75 key constants; the controller has
74 getters, 76 `Future<void>` mutators and 74 hand-placed
`notifyListeners()` calls. One logical setting is therefore written out
six or seven times, across four hand-synced tables that no compiler
helps keep aligned: the key constants, the constructor defaults, the
`loadAll` read expressions, and the controller's field initializers. A
fifth copy of three of the defaults lives in
`lib/src/settings/media_size_prefs.dart:45-52`, whose own comment says
"Keep in sync with the SettingsController defaults", which is the
smell stated in a comment.

Do these in this order:

- Delete the 71 genuinely-unused granular getters. This is pure
  deletion with no behavioural risk and it is not the descriptor work.
  The 8 that tests call (`settings_service_test.dart`,
  `settings_controller_test.dart`, `accents_test.dart`,
  `space_pinning_test.dart`) need their call sites ported to
  `loadAll()` or to `SharedPreferences` directly first. The dead layer
  is also the *less* safe half: it hand-rolls `values[index]` in seven
  places where `_readEnum` bounds-checks, so deleting it removes a
  latent crash surface as a side effect.
- Give the mutators an error path. Every one of the 76 has the shape
  `if (v == current) return; field = v; notifyListeners(); await
  service.update(v);` with no try, so state is broadcast before the
  write is confirmed, and a failed `SharedPreferences` write is an
  unhandled async error plus silent in-memory/disk divergence. The
  guard is also applied inconsistently, which shows the shape is
  maintained by hand. One private funnel with one clamp policy and one
  logged catch replaces 76 near-identical bodies. The call sites
  discard these futures anyway (`appearance_settings.dart:217` and
  about ten others), so return `void` and persist unawaited, or return a
  result and route every caller through `context.showActionResult`; do
  not keep 76 futures that nobody awaits and nobody handles.
- De-duplicate the subscriptions. `SettingsController` is listened to
  six times: twice in `app.dart` (`:86` watches it, `:106` wraps the
  same notifier in a `ListenableBuilder`, so one preference change
  rebuilds the app shell), plus addListener in `router.dart:442`,
  `app_frame.dart:60`, `notification_service.dart:299` and
  `startscreen_frame.dart:54`. And `router.dart:464` is a blanket
  `setState(() {})` on every preference change, including a font-size
  nudge, purely so the layout shell re-resolves. Guard it on
  `layoutMode` actually changing and 75 of 76 changes stop rebuilding
  the shell.
- Then the descriptor table 1.3 proposes, with the enum codec
  persisting by `name` rather than `index`.

Two smaller things in the same layer. `SpacePreferences`
(lib/src/settings/space_preferences.dart) has four persisted
collections and its mutators hand-pick which to write, so
`toggleGroupCollapsed` writes one key while `createGroup` writes four,
with nothing documenting which is intentional; and its
`updateSpaceOrder` guard at `:104` compares two `List<String>` with
`==`, which is identity, so it never short-circuits and reads as a
check that is not one. Separately, `SettingsController` mixes in
`WindowListener` (`:32`), implements none of its methods, and never
calls `windowManager.addListener(this)`; drop the mixin and the import.

1.17 Search cannot report failure, so "no results" is a lie (correctness)

`SearchProvider` returns `SearchPage.empty()` from all three of its remote
catch blocks (lib/src/widgets/search_provider.dart, in
`searchHomeserverFirstPage`/`NextPage`, `_searchMessages`, and the user
directory path), with no comment naming the expected exception and no log.
An empty page is exactly what "the server answered and there is nothing"
looks like, so a homeserver that is refusing connections, a session that
has expired, or a server without the `m.room_message` search capability
all render identically to a query that genuinely matched nothing. This
breaches the rule in AGENTS.md twice over: the bare `catch (_)` carries
no explanation, and the fallback hides a failure the user would want to act
on.

It is now load-bearing rather than cosmetic. `GlobalSearchPage`
(lib/src/screens/global_search_page.dart, shipped in WORK_DONE.md section
45) is built entirely on this provider, and it deliberately does *not*
claim to surface failures, because it cannot distinguish them. Its class
doc says so. That is a correct response to the wrong interface: the page
is honest about its own blindness, but the blindness is the bug.

The fix is to give the provider a way to report, not to infer from an empty
page. Options, cheapest first:

- Add an optional `void Function(Object error, SearchCategory source)?
  onError` to the constructor. Default null preserves every existing
  caller (the palette, the four dead navigation helpers) and makes the
  failure observable without a breaking change. The page then renders a
  section-level "couldn't search messages" state with a retry, instead of
  omitting the section.
- Or make `SearchPage<T>` carry a nullable `Object? error`, so the failure
  travels with the result rather than beside it. More honest, more churn,
  and it forces every consumer to decide what an error page means.

Either way the log has to happen inside the provider. A caller that
receives an empty page has no way to know whether to log, and the palette
currently does not. Do this before adding any further search surface,
because every surface built on the provider inherits the same blindness.

1.18 Hub redesign: the navigation pane shipped, two things still open

Largely done (WORK_DONE.md sections 47 and 48). The hub is a routed
full-screen page, the modal overlay is gone, the tab strip is gone, and a
wide window now has a navigation pane with the active section expanding
inline. A narrow window gets the profile as the index with the section list
underneath, and every section is a full-screen push.

What is still open, now that the chrome is a list rather than a strip:

- `EncryptionOverviewScreen(embedded: true)` still drops its `AppBar` and
  with it the refresh action, so the hub's Encryption page has no way to
  refresh and the standalone `/main/encryption` route does. Now that the
  hub has a content pane with a title, the flag is more obviously wrong:
  decide whether the hub's version gets the refresh or the page stops
  sharing an implementation with the standalone route.
- `HubSubPageHeader` still uses `Expanded`, which is what forces
  `embedded: true` to exist at all. A content pane does not need it; the
  pages are all scrollable. If the header is replaced with a plain title
  row the flag can go, and then the hub and `/main/encryption` can be the
  same widget.
- The hub is not modal-free. The command palette and the profile overlay
  still use `BarrierDismissableOverlay` and `BlurBackground` from
  `lib/src/widgets/blur_background.dart`. Both are transient lookups rather
  than places, which is the line drawn so far; the reasoning is recorded on
  `showProfileOverlay` in `lib/src/screens/user_profile.dart`. If the
  profile ever needs deep links it becomes a route on the hub's pattern.
- `/main/me` and the hub's index both host `HubMyProfilePage`. The sidebar
  profile pill goes to the hub; the single-pane shell's "You" navigation
  destination goes to `/main/me`. They are the same editor in two places
  and the nav destination is now the odd one out. Either make "You" land on
  the hub index, or make `/main/me` a redirect to it. This is the last piece
  of the duplication that section 48 removed everywhere else.
7.7 Why there is no pop-guard on a layout-mode change

Reported as: switching to the focus layout, opening the "You" tab, then
switching back leaves the "You" page stranded in the dashboard's middle
pane. The suggested fix was to pop non-room pages when the mode changes.
Not adopted; the page was given chrome instead. The reasoning, so it is not
re-proposed without new information.

The visible problem was never really the routing, it was that
`OwnAccountPage` rendered no `AppBar`. Every other page that can appear in
the dashboard's middle pane has one, because that pane has no URL bar and no
title of its own. A chrome-less page there looks like the sidebar's
contents spilled over. WORK_DONE.md section 47 gave it a `Scaffold` and
`AppBar`, which is the same rule `ProfilePage` and `SpaceHomePage` already
follow.

A guard was rejected because it would contradict a deliberate, tested
decision. `_AdaptiveMainLayout` does not navigate on a shell change, and
`test/widget/router_test.dart` pins that: a pushed route must survive a
resize across the breakpoint. The old code called `router.go()` on every
shell flip, which replaced the whole page stack and ejected the user from
any room sub-page they had open. Reintroducing navigation on shell change,
even a narrow version of it, reopens that.

Three further reasons:

- The guard would be shell-change *navigation*, so widening a window could
  yank someone out of a page they deliberately deep-linked to. Deep-linking
  `/main/me` and then resizing would silently redirect them to the room
  list.
- It would need an exception list, and exception lists are where this kind
  of guard rots. `/main/spaces`, `/main/search` and `/main/me` are all
  focus destinations, but they are also perfectly good pages on the
  dashboard. "Pop unless it is a room" is the wrong predicate; the right
  one is "every route is renderable in every shell", and that is a
  per-route property, not a navigator rule.
- There is no evidence it is the actual complaint. `SpaceHomePage` and
  `RoomInformations` already behave the same way, and nobody reported them.

If the middle pane should only ever show a room or the dashboard's own
empty state, that is a legitimate product decision, but it should be made
for all such pages at once and enforced by making the non-room routes
nested under the shell rather than siblings of it. That is a routing
change with its own trade-offs, not a guard.

2. Open features

2.1 Communication surface

Recovery-key save dialog (post-bootstrap). bootstrap_screen.dart shows
a reminder that the SDK encrypts the key but cannot display it. We want
action buttons: "I saved it" and "Later". Strings go in app_en.arb.

The following previously-tracked surface items have shipped:

- Per-room encryption badge in RoomsPane - wired at
  lib/src/widgets/rooms_pane.dart:576 (RoomEncryptionBadge).
- "Rotate megolm session" - wired at
  lib/src/screens/room_details_page.dart:107, backed by
  EncryptionService.rotateMegolmSession
  (lib/src/encryption/encryption_service.dart:148).
- "Export E2EE keys" - wired at
  lib/src/screens/encryption/encryption_overview.dart:375, backed by the
  SSSS export path and confirmed via dialog (encryptionExportKeysConfirm).

2.2 Timeline / chat

- Reply expand / collapse: chat_event.dart renders replies inline; there
  is no affordance for a thread-mode view.
- Sticker sender label: sticker messages are routed through
  StickerMessageType (lib/src/chat/chat_event.dart:222 and 244) and
  rendered with the same sender-name treatment as images. Differentiate
  the label (e.g. "Sent a sticker:") in
  lib/src/chat/timeline_item_sender_name_and_timestamp.dart.
- Push notifications: NotificationService is local-only; OS push bridge
  is not wired.

The following previously-tracked timeline items have shipped:

- Mention vs highlight distinction in room list - _RoomUnreadBadges
  (lib/src/widgets/rooms_pane.dart:457) keys off Room.highlightCount
  first and falls back to Room.notificationCount.
- Off-thread Markdown - MarkdownToHtml.convertAsync
  (lib/src/helpers/markdown_to_html.dart:55) runs the parser on a
  background isolate via compute(); the chat-box send path awaits the
  async variant.

2.3 Right-sidebar expansion

Four views today: roomInfo, members, threads, pinned. Search, member
management, settings, and avatar uploads stay as full-page routes.
Decide whether the sidebar should grow or be replaced with context menus.

2.4 Room management

The following previously-tracked room-management items have shipped:

- Knock-accept confirmation dialog: _approve in
  lib/src/screens/room_settings_page.dart:1666 shows display name plus
  Matrix ID plus a "View profile" link before calling the underlying
  approve API.
- In-room search result highlights: _HighlightedText plus
  _MatchCountChip in lib/src/chat/in_room_search_panel.dart:690
  highlight matching terms in result tiles and surface a match count
  pill next to the sender name.


3. Features shipped (July 2026 review)

3.1 Messaging and chat

- Message edit (m.replace) send plus indicator plus history viewer:
  edit_message_dialog.dart, edit_history_dialog.dart, and the
  _EditedMarker in chat_event.dart.
- Audio in-app player: audio_message_type.dart (scrub slider, save
  button).
- Video inline playback: video_message_type.dart (height-constrained,
  tap-to-play, fullscreen).
- Image/GIF height-constrain: image_message_type.dart (BoxFit.contain
  for panoramics).
- Voice-note recorder: voice_recorder_dialog.dart (mic button in
  composer toolbar).
- Location messages: share_location_dialog.dart,
  location_message_type.dart (open-in-maps).
- Polls (MSC3381): poll_send_dialog.dart, poll_message_type.dart.
- Typing notifications: typing_indicator.dart (animated footer,
  auto-stop after 4s).
- Per-message read receipts: receipt_avatars.dart (up to 5 avatars plus
  "+N").
- Slash commands: /me -> m.emote, /shrug, unknown -> snackbar
  (chat_box.dart:_send).
- Delivery indicator on outgoing messages:
  lib/src/chat/events/delivery_indicator.dart consumed in
  lib/src/chat/timeline_item.dart:251.

3.2 Rooms / users / spaces

- Room version display plus upgrade:
  room_settings_page.dart:_upgradeRoom.
- Knock approve/deny UI with confirmation dialog: _KnockRequestsSection
  in room settings; _approve at
  room_settings_page.dart:1666.
- Room editor tiles: join rule, history visibility, encryption, alias,
  guest access, power levels.
- Own-profile editor: display name, status message, presence (hub
  my_profile_page.dart).
- DM pane dedup: LeftPaneChoice.friends uses
  RoomsPane(roomFilter: isDirectChat).
- Per-room encryption badge in rooms list: encryption_badge.dart
  consumed in rooms_pane.dart:576.
- Highlight-vs-unread badge split: _RoomUnreadBadges in
  rooms_pane.dart:457.
- Rotate megolm session from room details:
  room_details_page.dart:107, encryption_service.dart:148.
- Export E2EE keys from encryption overview:
  encryption_overview.dart:375.

3.3 Platform support

- Permissions wired: record (mic) and geolocator (location) via
  permission_handler.
- Cleanup: friend_chats_pane.dart and own_user_profile.dart deleted.
- Global keyboard shortcuts mounted: Ctrl+K (command palette),
  Ctrl+Shift+K (global search), and ? (cheat-sheet overlay) via
  GlobalShortcutListener (dashboard_layout.dart:260,
  global_shortcut_listener.dart:34).
- Per-room notification preferences sheet (showRoomNotificationSheet)
  reachable from room details (room_details_page.dart:1294) and room
  settings (room_settings_page.dart:29).


4. Future work

Expected timeline: 2027 and beyond (maybe)

- Custom events (events v3): Git events, ~~Map events~~ this exists, realtime
  audio/video chat.
- Application fundamentals v2: background process optimisation, tighter
  system integration.


5. Wishlist

Extremely long-term; listed here to keep the design flexible.

- Server SDK v1 - server-side Matrix SDK.
- Client SDK v1 - alternative chat protocols, like XMPP.


See WORK_DONE.md for the closed-work ledger.


6. Feature catalogue (aka wishlist of what we need)

6.1 VoIP / WebRTC calls
(Need to investigate how matrix-dart sdk and Fluffychat handle any of these)
What we are missing:
- Voice calls (1:1): no m.call invite/hangup/answer anywhere. Entirely missing.
- Video calls (1:1): same gap. No camera track support for calls.
- Group calls: no MSC3401 or native group VoIP.
- Screen sharing: no desktop-capture integration.
- Call history: no m.call event renderer in the timeline.

6.2 Location & maps

- Embedded map display: location_message_type.dart renders lat/lon as
  monospace text + an "Open in Maps" button. There is no map tile
  renderer (OSM / MapLibre / google_maps_flutter). See
  lib/src/chat/events/matrix_events/Message/location/location_message_type.dart.
- Map picker in composer: share_location_dialog.dart reads current GPS
  position only. No interactive map to pick a point or search a POI.
  See lib/src/chat/share_location_dialog.dart.

6.3 Composer & messaging

- Slash commands: only /me and /shrug exist. Missing /join, /leave,
  /nick, /topic, /flip, /tableflip, /html, etc. See
  lib/src/chat/chat_box.dart.
- Emoji auto-complete: no :smile: -> smiley conversion while typing.
- Rich text / WYSIWYG editor: composer inserts Markdown syntax only.
  No live preview or rich-text editing mode.
- Link previews: URL messages render as plain text. No inline preview
  card (Open Graph / oEmbed) for links shared in chat.
- Scheduled / send-later messages: no future-delivery affordance.
- Message effects: no birthday, fireworks, or confetti overlays.
- Message translations: no "Translate" action on messages.
- Message bookmarks: no local bookmark/star collection for messages.
- Voice message playback: received audio from other users shows the
  generic audio player (scrub + play). No dedicated voice-message UI
  with speed control or waveform. See
  lib/src/chat/events/matrix_events/Message/audio/audio_message_type.dart.
- Custom emoji / sticker packs: sticker picker exists but no
  upload/import/management UI for custom sets. See
  lib/src/chat/chat_box_sticker_picker.dart.

6.4 Rooms & spaces

- Invite-to-room dialog: no dedicated invite dialog in the room header.
  Invite is only accessible from the user profile page
  (lib/src/screens/user_profile.dart:830) and room settings
  (lib/src/screens/room_settings_page.dart:1729). Create a standalone
  InviteDialog with user search + multi-select + reason field.
- Space creation wizard: no guided flow for creating spaces with name,
  avatar, purpose, and initial child rooms. See
  lib/src/screens/space_settings_page.dart.
- Space membership management: no UI to browse/manage space members,
  approve/deny space membership requests.
- Space drag-reorder in navigation pane: no drag-to-reorder spaces.
  Persisted locally. See lib/src/widgets/spaces_pane.dart.
- Room tagging / labels: no custom tag system. Rooms are organised by
  space membership only.
- Room directory favourites: no local star/bookmark for public rooms.
- Room upgrade flow: m.room.tombstone creation and guided re-join are
  not wired in the UI. See
  lib/src/screens/room_settings_page.dart.
- Power level matrix editor: per-user power levels are set via
  individual dialogs. No grid view of all users x permission levels.
  See lib/src/screens/room_settings_page.dart.

6.5 Platform & integration

- Matrix widget support: no embedded widget URLs (Etherpad, Jitsi,
  etc.). The SDK can fire widget-open events but there is no renderer.
- Bridge management UI: no UI for viewing or managing Matrix bridges
  (Telegram, WhatsApp, Slack, IRC).
- Drag-and-drop file upload: desktop client has no drag-to-attach on
  the chat area.
- Auto-start on boot: no "Launch at system startup" preference.
- App lock / passcode: no local unlock on app resume.
- Spell check in composer: no OS spell-checker integration.
- Offline / low-connectivity mode: no graceful degradation when the
  network is down. Sends throw errors instead of queueing.
- Export chat history: no export-to-file (JSON / HTML / plain text).
- Accessibility pass: no systematic screen-reader, contrast, or
  keyboard-navigation audit. The two auth forms now have ordered Tab
  traversal and Enter-to-submit (`lib/src/widgets/form_keyboard.dart`), but
  nothing else has been looked at, and there is no test that would notice
  if a form regressed.

6.6 Encryption & security

- Self-verification badge: no per-device trust indicator in the user's
  own device list that explains whether this session is verified.
- Verified identity badge: no verified checkmark next to user display
  names in timeline messages (only available in the sidebar / profile).
- Message-level encryption info: no per-message "encrypted with..."
  info popup showing algorithm, session ID, and sender device.
- Security audit log: no log of verification events, device additions,
  or key backup state changes.

6.7 Internationalization

- Language coverage: only English (app_en.arb) and Persian/Farsi
  (app_fa.arb). No DE, FR, ES, JA, ZH, RU, PT, IT, KO, AR, NL, PL,
  SV, TR, VI, or TH. See lib/src/localization/.

6.8 Testing

- Settings page widget tests: 14 settings UI pages in
  lib/src/screens/hub_screen/settings/ have zero widget test coverage.
  Only unit tests exist for the settings model layer.
- Integration tests for room operations: invite, kick, ban, room
  creation, space creation are not covered by integration_test/.
- Integration test mock gaps: room_flow_test and logout_test still
  404 on unmocked endpoints after login (`/devices`, room
  `/messages` pagination, `/read_markers`), and the second test in a
  file can hit "attempt to write a readonly database" on the shared
  temp DB during teardown of the previous test's client. See
  integration_test/room_flow_test.dart and
  integration_test/helpers/test_app_boot.dart.
- L10n smoke tests: no automated check that every .arb key renders
  without crash in both languages across all screens.
- Performance benchmark suite: no regression benchmarks for timeline
  scroll, startup time, sync processing, or memory pressure.

6.9 Refactor candidates (from audit)

- VoIP wiring surface: pubspec.yaml needs dart_webrtc, flutter_webrtc,
  and a Matrix call transport package before any call feature can ship.
- Location map surface: pubspec.yaml needs a map rendering package
  (map_launcher already exists for "Open in Maps").
- Composer expansion surface: slash-command registry and emoji-complete
  engine would share a common autocomplete widget.

7. Layout rework (opened 2026-09)

The audit behind WORK_DONE.md section 42 found that the single-pane
shell is not a designed alternative to the dashboard, it is the
dashboard with the sidebar deleted. The first batch of defects shipped;
the rest is scoped here. Planning detail, including the answers to the
open design questions, is in the untracked LAYOUT_PLAN.md.

7.1 The focus shell is a 100px band

The one-way door is closed, and more durably than it first was. The hub is
now a routed page reachable from every shell (WORK_DONE.md section 47), so
the single copy of the layout-mode control in Hub > Settings > Layout is
reachable everywhere. It briefly lived in two shell surfaces as well, which
was unnecessary once the hub had a URL, and has been removed.

The 100px band remains. In `auto` it applies only to widths in [500, 600),
because
`windowMinWidth` defaults to 500 (`settings_service.dart:140`, enforced
at `boot.dart:216`) and `mobileMax` is 600
(`lib/src/helpers/responsive.dart:75`); hysteresis means the user has to
fall below 540 to enter it
(`lib/src/layouts/layout_shell_controller.dart:167`). The
window-min-width slider goes down to 320
(`lib/src/screens/hub_screen/settings/appearance_settings.dart:285`),
which widens the band, but the default leaves a phone-shaped experience in
a 100px sliver. Now that the shell is a real product, decide the
breakpoint honestly: the floor for a navigation pane plus a readable chat
is nearer 700 than 600, and neither `LayoutMode.mobile`'s name nor
`windowMinWidth`'s default should keep implying that the focus layout is a
phone thing.

7.2 The compact shell is no longer a second widget system

Done (WORK_DONE.md section 44). `CompactDashboard` and `CompactSidebar`
are deleted, `DashboardView` is one composition parameterised by whether
the detail pane fits, and the narrow band now gets the same navigation
sidebar with space grouping, drag-to-reorder, the space context menu,
auto-grouping and both room-row badges.

The name `LayoutMode.compact` is now a slight misnomer: it means "the
dashboard without its detail pane", which is what it always meant, but
it no longer names a distinct widget. Worth renaming alongside a
`LayoutMode.mobile` rename, and the persisted-index hazard is now handled
by the bounds-checked readers (section 42), so the rename is cheap.

7.3 Focus-mode destinations are real routes

Done (WORK_DONE.md sections 43 and 45). The navigation seam owns every
room open in `lib/`, and `/main/rooms`, `/main/spaces`, `/main/search` and
`/main/me` are routes matched back to a `FocusDestination` by segment, so
the navigation bar reads its selected index off the matched location.

Still open: the dashboard sidebar's `NavigationState` sentinels
(`lib/src/helpers/navigation_state.dart:20-21`, `___home___`, `___all___`)
survive for the sidebar's Home / All / space selection. That is a different
concern from the focus bar and is not wrong, but the two now model "where
am I" in parallel. Decide whether the sidebar should read the same route
state, or whether the split is deliberate and should be documented as such.

7.4 Small-screen correctness, what is left

Done (WORK_DONE.md section 46): the four room detail panes are reachable in
the single-pane shell as a bottom sheet, and the shell publishes a
`LayoutScope`, which is what had been making the in-room search panel's
compact branch unreachable.

The hub is no longer listed here. The "present it full screen below the
focus breakpoint" note that used to live in this section was the symptom
of a larger design problem and is now tracked properly as 1.18.

Still open, all of it inside the chat surface rather than the shell:

- the composer packs seven controls into one row
  (`lib/src/chat/chat_box.dart:639-758`), leaving roughly 180px of input
  at 500px wide. The formatting toolbar above adds eleven more.
- the message context menu is anchored at the long-press point
  (`lib/src/chat/message_context_menu.dart:411`); with about fifteen
  entries that belongs in a bottom sheet, which now has a house pattern in
  `room_pane_sheet.dart`.
- `_kMaxBubbleWidth` (480) and `_kBubbleRightMargin` (64) in
  `lib/src/chat/timeline_item.dart:40,46` are desktop proportions; the
  right gutter costs 13% of a phone screen.
- no `PopScope` anywhere, so no predictive back and no guard on a
  non-empty composer draft.

- The in-room search panel reads `LayoutScope`, which the single-pane
  shell never provides, so its compact branch
  (`in_room_search_panel.dart:320-326`) is dead and it renders at a
  fixed 320px beside a ~180px timeline.
- The message context menu is anchored at the long-press point
  (`message_context_menu.dart:411`); with ~15 entries that belongs in a
  bottom sheet under the single-pane shell.
- The composer packs seven controls into one row
  (`lib/src/chat/chat_box.dart:639-758`), leaving roughly 180px of input
  at 500px wide. The formatting toolbar above adds eleven more.
- No `PopScope` anywhere, so no predictive back and no guard on a
  non-empty composer draft.
- `_kMaxBubbleWidth` (480) and `_kBubbleRightMargin` (64) in
  `lib/src/chat/timeline_item.dart:40,46` are desktop proportions; the
  right gutter costs 13% of a phone screen.
- `GlobalShortcutListener` is absent from the single-pane shell, so a
  desktop user who opts into it loses the command palette.

7.5 Search: a page now exists, but the keyboard path and the filter field
  do not

Partly done (WORK_DONE.md section 45). `GlobalSearchPage` is reachable at
`/main/search` from the single-pane shell's navigation bar and from its top
bar, built on `SearchProvider` and the public result tiles.

Still open:

- `l10n.shortcutOpenSearch` exists in the ARB
  (`app_localizations_en.dart:3067`) and is still referenced by no widget:
  there is no `Ctrl+F` binding. `GlobalShortcutListener` registers only
  `Ctrl+Shift+P` and `Ctrl+Shift+?`. The page now exists, so wiring the
  shortcut is a one-line intent plus a `go` to the destination, and the
  string finally gets a reader. It was written for exactly this.
- `RoomsPane` still has no filter field on any shell, so within a large
  joined-room list the only way to narrow is global search. A local
  substring filter over `client.rooms` is what `SearchProvider`'s own local
  path already does, so this is a field plus a predicate, not a feature.
- `SearchProvider` cannot report failure, so the new page cannot either.
  This is now tracked as its own correctness item, 1.17, and it should be
  fixed before any further search surface is added, because every surface
  built on the provider inherits the same blindness.

7.6 Dead second responsive system, and other cruft

`LayoutSize` and `LayoutBreakpoints.sizeForWidth`
(`lib/src/helpers/responsive.dart:119-124`) return `compact` for both
`width < 600` and `900 <= width < 1100`, and never return `expanded`.
Dead alongside them: `shouldUseMobile` (`:133`), `shouldUseCompact`
(`:142`), `clampSidebarWidth` (`:152`),
`BoxConstraintsLayoutSize.layoutSize` (`:169`),
`LayoutSize.hasTwoSidebars` / `hasOneSidebar`,
`hubCategorySidebarWidth` and `hubNavRailWidth` (`:102`, `:105`) for a
removed rail, and `LayoutModeExtension.label` /
`RightPaneChoiceExtension.label`
(`lib/src/settings/layout_settings.dart:30-39`, `:51-65`).

`LayoutShellController.isExpanded`
(`layout_shell_controller.dart:104`) was on this list while it had no
readers. It has one now, `fitsTwoPanes` (`:117`), which both the
dashboard's detail pane and the hub's navigation pane ask. That is the
point of it: two surfaces that independently decide "is there room for
two panes" will eventually disagree about the same measurement, which is
the mistake the dashboard unification removed.

Also open:

- `OwnProfileBar` (`lib/src/widgets/own_profile_bar.dart`, 243 lines) has
  zero consumers. A second profile surface was built and dropped; decide
  revive or delete rather than writing a third.
- `EmptySpace` (`lib/src/layouts/empty_space.dart`) is referenced only by
  a test.
- Hard-coded English reaching the UI: the five right-pane dropdown labels
  are gone. `right_sidebar_content.dart` was a `DropdownButton` with
  'Room Info', 'Members', 'Threads' and 'Pinned' written into it, while
  `localizedRightPaneChoice` sat unused next to it. It is now a four-tab
  strip reading from that helper, and
  `test/widget/right_sidebar_test.dart` pins it. Two remain: `'Group'` in
  `nav_rows.dart` and in `space_context_menu.dart` ('Move Up', 'Move
  Down', 'Move Group Up', 'Move Group Down', 'Remove from group',
  'Ungroup all', 'Sort into groups', 'Reset space layout'). The hub's
  hard-coded "All categories" button also went away with the rewrite of
  `hub_screen.dart`.
- Stale comments that will mislead during this work: `_MobileTopBar`'s doc
  claimed a search affordance it never rendered; `_AdaptiveMainLayout`'s
  doc says the shell commits in `didChangeDependencies` when it commits
  in `build` (`router.dart:408-413`); `AGENTS.md`'s layout diagram lists
  a `StatusBar` removed in commit `567e9cd`.
- No widget test covers `MobileLayout`, `CompactDashboard` or
  `DashboardView`. `test/unit/layout_shell_controller_test.dart` is the
  only coverage any of the layout system has. `DashboardView` does now
  have composition tests in `navigation_sidebar_test.dart`, so this line
  is narrower than it was: the shell and the dashboard row are covered,
  the single-pane shell is not.

7.7 The shell-mode guard was considered and rejected

When a pushed route is open (`/hub/settings`, a room, a profile) and the
window crosses a shell breakpoint, the router must not redirect. That
was the "pop guard": a `PopScope` around the shell that swallowed the
back gesture or repointed the stack whenever `LayoutShellController`
committed a different shell. It was written, and it is gone.

The reason is that the guard encoded a false premise. It assumed the
pushed route belonged to the shell that happened to be on screen when
it was pushed, so that swapping shells should discard it. It does not:
`/hub/settings` is the same screen at 600px and at 1400px, and the hub
answers the difference with `fitsTwoPanes`. Redirecting on a breakpoint
cross is what used to eject users from pushed sub-routes, and a guard
that only "mostly" does that is worse than none, because the failure is
intermittent and looks like the user losing their place.

What ships instead:

- Pages own their chrome. `OwnAccountPage` (now a redirect to the hub,
  see WORK_DONE.md) took a real `Scaffold`/`AppBar` when it first shipped
  a bare body under a route that had no app bar of its own, and
  `test/widget/router_test.dart` pins that a pushed route survives a
  shell resize.
- `LayoutShellController` is deliberately not a `ChangeNotifier`.
  `_AdaptiveMainLayout` is the only writer and it writes in `build`, so
  consumers cannot be woken by a shell change and cannot miss one.

Open: the mobile shell has no chat surface, so on a phone `/main/rooms`
is a list and nothing is ever pushed on top of it. That is a product
gap, not a guard gap, and it is listed under 7.4.

7.8 The design language is one elevation system short of finished

The shadow tokens now have readers and the account card is lifted, so the
app is no longer uniformly flat. What is left needs a decision rather than
a patch:

- There are two elevation systems. `MoonrelayDesignTokens.shadowLow` and
  friends are layered pairs; Material's `elevation:` on any widget
  generates its own shadows from `ThemeData.shadowColor` and Material's own
  algorithm. They do not agree, so a `Card` beside a hand-built surface
  will not look like it came from the same app. Either route Material's
  elevation through the tokens, or stop using `elevation:` in favour of
  explicit `boxShadow`. The first is theme-wide and touches every screen;
  the second is mechanical but shows up as a diff in a lot of places.
- The shadow tokens are the light theme's numbers. `standard()` is static
  and shared, so dark mode gets black shadows on a near-black surface,
  which is close to doing nothing. Dark wants a lighter rim rather than a
  darker drop, so the tokens have to become brightness-aware, which means
  either two instances or a resolver.
- Nothing else uses elevation yet. That is deliberate, because boldness is
  spent in one place. But the composer and the room header are the next
  candidates and the chat surface currently has no layering behind them at
  all.
- The filter sits above the section it filters. `RoomListFilter` is above
  the Spaces section and controls the Rooms section below it; the section
  header echoing the chosen word is the current mitigation. Moving the
  control directly above the Rooms header would show the causal link
  better and read worse, because it would look like a control owned by
  whatever sits directly under it.

7.9 The sidebar still shows about five rooms

Unchanged, and still the largest remaining layout problem. Two `Expanded`
calls in one `Column` in
`lib/src/widgets/navigation_sidebar/navigation_sidebar.dart` force a 50/50
split regardless of content. Replacing the two Home and All rows with
`RoomListFilter` recovered one row of height; the larger type scale in
WORK_DONE section 50 gave some of it back.

Note the tension with the lesson in LAYOUT_PLAN section 14: an empty band
*inside* the pane is a defect, because the split makes the room list
smaller than the window allows. An empty band *beside* a full-width
conversation is not. Those are different problems and must not be fixed
with the same technique.


8. Timeline reliability (opened 2026-10)

A full audit of the chat timeline. The headline finding is structural, not
a set of independent bugs: the chat surface holds a **single** `Timeline`
object that is anchored to the live tail, and every "jump to a point in
history" feature is implemented by reaching around that one object. It
cannot work, and the individual defects below are all consequences of
trying.

**Shipped in WORK_DONE section 53:** 8.2, 8.3 and the first half of 8.4
are fixed. Read receipts are now position-aware, jumps to uncached events
load a `/context` window, and event permalinks resolve. Sections 8.1 and
8.5 are still open, and 8.1 is the reason.

8.1 The live timeline cannot page forward, and the app depends on it doing so

Verified against `matrix-9.0.0`:

- `Timeline.events` is one flat newest-first list with a single
  `prevBatch`/`nextBatch` pair. A `Timeline` is in one of two modes, and
  the constructor picks between them from `chunk.nextBatch`
  (`timeline.dart:364-370`): empty means live (`allowNewEvent = true`,
  sync inserts accepted), non-empty means fragmented
  (`allowNewEvent = false`, and `timeline.dart:647` then drops every sync
  insert).
- `room.getTimeline()` with no `eventContextId` always builds
  `TimelineChunk(events: events)`, whose `nextBatch` defaults to `''`
  (`room.dart:1787`). So the app's timeline is **always** in live mode.
- `canRequestFuture => !allowNewEvent` (`timeline.dart:109`). On a live
  timeline that is therefore permanently `false`.
- There is no `getEventTimeline`, no `PaginationDirection` and no
  `TimelineSet` in this SDK. `room.getTimeline(eventContextId:)` is the
  only "load around an event" primitive and it *replaces the whole chunk*
  with a `/context` window (`room.dart:1789-1794`), producing a
  different kind of object than the live one.

`JumpToUnreadPager.paginateNewer` (`jump_to_unread_pager.dart:90-107`)
checks `canRequestFuture` and returns `false` on its first iteration,
every time. The "both directions in parallel" race at
`jump_to_unread_pager.dart:121-122` is a one-direction race in practice.
`paginateOlder` is then left walking *backwards* looking for a read
marker that lies *ahead* of the loaded window, which is the common case
(you were away, only the tail is cached). It cannot succeed, it burns the
full 30s budget (`_globalTimeout`, `jump_to_unread_pager.dart:46`), and
`jumpToLastRead` falls through to `scrollToBottom()` plus
`markRoomReadForce()` (`jump_coordinator.dart:174-179`).

Observed behaviour, exactly: tap the pill, spin for thirty seconds, land
at the bottom, mark the room read. The feature is not "buggy", it is
incapable.

8.2 The unread pill is marked read before the user reads anything

Four independent defects, any one of which is enough on its own.

- **Unconditional mark-read on open.** The post-frame callback in
  `_initTimeline` calls `_markRoomRead()` (`chat_timeline.dart:291`).
  `TimelineSnapshot.fromEvents` picks `events.first` when it is synced,
  i.e. the *newest* event (`read_marker_tracker.dart:230-236`), and that
  is what gets posted. Opening a room marks the whole room read.
- **The scroll listener is not position-aware.** `_onScroll`
  (`chat_timeline.dart:302-324`) fires on any offset change, including a
  fling *upward* into history, and posts a marker for the newest cached
  event. The snapshot only ever carries "newest in cache"; it never
  carries "what the user is actually looking at".
- **One jump latches the pill off.** `onJumpToUnread`
  (`chat_timeline.dart:527-534`) marks read and then calls
  `_dismissUnreadPill()`. `_pillDismissed` is cleared only on room switch
  (`chat_timeline.dart:169`) and never when new unread events arrive by
  sync, so a single jump removes the affordance for the rest of the
  session.
- **The marker-at-index-0 case paginates for nothing.** The fast path
  requires `markerIdx > 0` (`jump_coordinator.dart:149`). When the marker
  is at index 0 the room is fully read and the correct action is no
  action, but the code enters the slow path and burns the whole budget
  before scrolling to the bottom.

8.3 Why the pill disappears "abruptly"

This is a direct consequence of 8.2 and is worth stating separately
because it is the symptom users report. `Room.fullyRead` reads
`m.fully_read` account data (`room.dart:164-165`), and
`client.setReadMarker` is a bare network call with no optimistic local
write (`matrix_api_lite/generated/api.dart:4767`). So the pill is driven
by a sync boundary arriving seconds later, not by user intent:

1. Pill is visible.
2. The user scrolls a little, or taps anything. `_onScroll` posts a
   marker for the newest cached event.
3. One to thirty seconds pass. Nothing visibly happens.
4. A sync returns `m.fully_read` = newest event.
5. `countUnreadInWindow` breaks at the marker on its first iteration
   (`chat_unread_utils.dart:63-80`), returns 0, and the pill vanishes
   with no user action and no animation.

The user is never shown the unread boundary. The pill appears, sits, and
then deletes itself.

8.4 The rest of the jump surface

Fixed in WORK_DONE section 53, in the sense that both of these now do the
obvious thing. What is left here is the reasoning worth keeping, plus the
items that are still open.

- `JumpCoordinator.jumpToEvent` returned early when the id was not already
  in `timeline.events` (`jump_coordinator.dart:202-220`, guard at `:208`).
  It could not page at all, so a search-result jump or a reply-preview
  jump into anything older than the cached window was a silent no-op. The
  early return is gone; the three-case path now lives on the widget, and
  the coordinator still only handles the in-cache case because it is the
  only case where a scroll is the right answer.
- Permalinks were generated but not resolvable: `MatrixUriEntity` had only
  `room`, `user` and `roomAlias` cases, so a permalink copied out of this
  client could not be opened back into the message. Resolved now, in both
  the `matrix.to` and `matrix:` URI forms, and routed through
  `?event=` on the room route.
- The item cache key omitted room identity (`timeline_view.dart`), so a new
  room could render the previous room's events. Fixed with
  `identityHashCode(room)` and `identityHashCode(timeline)`.
- The event-id-to-index map is structurally wrong. SHIPPED in WORK_DONE
  section 55. The banner slot is reserved rather than `insert`ed, so the
  recorded indices are exact, and the scan in `_doScrollToEvent` that
  re-derived the truth is deleted. The unit test had been asserting the
  off-by-one value.
- `_paginateUntilMarkerViaCoordinator` (`chat_timeline.dart`) ran the full
  `jumpToLastRead()`, which can scroll the user, purely to answer a test
  boolean. SHIPPED in WORK_DONE section 54: deleted, and
  `JumpCoordinator.paginateUntilMarkerForTest` is the primitive it was
  standing in for.
- `TimelineScrollTarget.scrollToEvent` (`timeline_scroll_target.dart:72-85`)
  had no callers. DELETED in section 54; `scrollToFraction` is still used by
  both fallbacks. `unreadInWindow` at `jump_coordinator.dart:315-318` is
  never called outside tests, and
  `timeline_item_sender_name_and_timestamp.dart` is unreferenced apart from
  its own test. Both still open; see section 55.

8.5 The target design, and the order to get there

The fix is not to patch `HistoryPager`. It is to stop asking one
`Timeline` to be both the live tail and an arbitrary history window.

Two SDK details constrain the design and are the reason the naive
version does not work:

- A `/context` window comes back as a `Timeline`, so it subscribes to
  `onSync` and will run `_removeEventsNotInThisSync`
  (`timeline.dart:348-350`) on the next gappy sync, which deletes every
  event not in that sync. A detached segment must have its subscriptions
  cancelled (`cancelSubscriptions()`) the moment it is created.
- Detached segments must page with `Timeline.getRoomEvents()`
  (`timeline.dart:222-237`), which pages off the segment's *own*
  `chunk.prevBatch`/`chunk.nextBatch`, not with `requestHistory()`.
  `canRequestHistory` consults `room.prev_batch` (`timeline.dart:83`),
  the room's live token; on a fully synced room that is `null`, so a
  valid `/context` window with a real `start` token immediately reports
  itself exhausted. Gate detached segments on their own token instead.
  `getRoomEvents` also returns a count and mutates `chunk` while firing
  `onInsert`, so it fits the existing `HistoryPager` shape.

Staged, cheapest-risk first. Steps 1 to 4 shipped in WORK_DONE section 53.

1. **Position-aware read receipts.** SHIPPED. `TimelineSnapshot` carries the
   oldest event on screen, a dwell threshold replaced the tick debounce,
   the unconditional mark-read on open is gone, and pill dismissal is
   scoped to the newest event rather than latched. Fixed 8.2 and 8.3.
2. **Jump to an uncached event.** SHIPPED, with one deliberate deviation
   from the plan below: rather than splicing a segment into the live
   timeline, `jumpToEvent` loads the `/context` window as a *replacement*
   view with a "back to latest" pill. The substitution was chosen because
   a spliced segment is step 5 in miniature, and doing it twice would have
   meant building the wrong abstraction and then rebuilding it.
3. **Permalink resolution.** SHIPPED. `MatrixUriEntity.event`, both URI
   forms, and an `?event=` route parameter.
4. **Room identity in the `TimelineView` cache key.** SHIPPED, via
   `identityHashCode` rather than `room.id`.
5. **Full `TimelineStore`.** SHIPPED. All five stages are done and recorded in
   WORK_DONE sections 55.5 to 56; the design, the four verified SDK constraints
   and the stage breakdown are in `TIMELINE_STORE_PLAN.md`. The one structural
   item this was gating is closed.

   Two questions in the plan's section 4 are still open and both should be
   settled against a real server: whether `getEventContext` re-anchors
   `prevBatch` correctly for an event older than the live tail, and whether the
   ten-minute contiguity heuristic in `TimelineStore.gapBoundaries` agrees with
   a real timeline's ordering. Both are guarded rather than assumed.

6. **Jump to an arbitrary date.** OPEN, and now deliberately so. Closing a gap
   from the viewer's side means the timeline can grow a window *newer* towards
   the live tail (plan section 8.3), which is what a user who followed a search
   result or a permalink needs in order to walk back. What does not exist is
   picking the *starting point* by date: resolving a timestamp to an event id
   and then handing it to the same `jumpToEvent` path. That is a feature, not a
   gap in the store, and it is the natural next thing to build on this.

Step 5 in detail. Introduce a per-room `TimelineStore` holding an ordered
list of segments (a live segment plus any number of detached history
segments), an `eventId -> (segment, index)` index, and a flattened
newest-first render list with gap separators at non-contiguous boundaries.
`TimelineView` would then render the store's list rather than
`widget.timeline.events`, which is the change that makes it worth doing:
the model already takes the event list as input.

Two SDK details constrain the design and are the reason the naive
version does not work:

- A `/context` window comes back as a `Timeline`, so it subscribes to
  `onSync` and will run `_removeEventsNotInThisSync`
  (`timeline.dart:348-350`) on the next gappy sync, which deletes every
  event not in that sync. A detached segment must have its subscriptions
  cancelled (`cancelSubscriptions()`) the moment it is created. Step 2
  already does this for the window it swaps in; a store has to do it for
  every window it keeps.
- Detached segments must page with `Timeline.getRoomEvents()`
  (`timeline.dart:222-237`), which pages off the segment's *own*
  `chunk.prevBatch`/`chunk.nextBatch`, not with `requestHistory()`.
  `canRequestHistory` consults `room.prev_batch` (`timeline.dart:83`),
  the room's live token; on a fully synced room that is `null`, so a
  valid `/context` window with a real `start` token immediately reports
  itself exhausted. `HistoryPager._canPageOlder` now handles this (ask the
  SDK first, fall back to the window's own token), and the store should
  reuse it rather than re-deriving the rule. `getRoomEvents` also returns a
  count and mutates `chunk` while firing `onInsert`, so it fits the
  existing `HistoryPager` shape.

Do not touch the `_ItemRenderKey` cache or the FAB column while step 5 is
in flight. Neither is the source of the unreliability, and the FAB column
was already touched once for the back-to-live pill.

## Presence: auto-offline and window-listener registration

**Both SHIPPED**, see WORK_DONE section 59. Kept here rather than deleted
because neither fix is obvious from the code, and the test suite had actively
encoded the first bug as expected behaviour.

**The countdown never starts.** `presence_service.dart:286` only arms the timer
in the `idleFor >= window` branch of `_evaluate`. Every caller that leads into
it first sets `_lastActivity = clock()`, so `idleFor` is about zero and the
`idleFor < window` branch runs, which republishes online and arms nothing.
`bind` (`:121`) and `onSettingsChanged` (`:224`) are exactly that shape, and
both cancel the timer first. The result is that enabling
`autoOfflinePresenceEnabled` appears to do nothing, and any later settings
change silently kills a countdown that was running.

`app.dart:112` registers `onSettingsChanged` on the whole
`SettingsController`, which is a `ChangeNotifier` that fires on every setter,
so changing an unrelated preference (theme, density, sidebar width) is enough
to trigger it. The existing tests do not catch this because they reach the
armed-timer assertions through `onResumed` and `noteActivity`, both of which
arm the timer themselves, and `presence_service_test.dart:184` asserts the
negative only for the pre-window case.

The fix belongs in `_evaluate` rather than at the call sites: arm with
`window - idleFor` whenever the feature is on, nothing has been chosen
manually, and the deadline is still ahead. That makes "enabled and not
manually overridden implies an armed deadline" true for every entry point,
including future ones, instead of relying on each caller to remember.

**`bind` leaks window listeners.** `windowManager.addListener` is a plain
`List.add` and `removeListener` a single `List.remove`, so the accumulation in
`presence_service.dart:129` is real: `bind` is documented as replacing any
previous binding but only returns early for an identical client, so each
account switch adds another copy of the same object and `dispose` (`:248`)
removes one. `noteActivity` is not gated on `_disposed`, so focus events keep
creating timers on a disposed service.

`app.dart:111-112` already does remove-then-add for the settings listener two
lines above the call, so the correct pattern is right there to copy.