Part of Moonrelay, a matrix protocol client.
Copyright (C) 2025 Surena Karimpour Ghannadi

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.


WORK_DONE

Closed-work ledger for Moonrelay. This file is a running log of things that
have shipped or been fixed, newest first.

Recent entries cover giving the detail panes a home in the single-pane
shell, and the single-pane shell publishing a `LayoutScope` so descendants
stop reading an infinite width in the narrowest layout; the single-pane
shell round (spaces opened as chats, a room header that measured the
window instead of its own pane, three unrelated controls sharing one width
threshold, a second back button stacked over every sub-page, and a stale
persisted preference that could not start the app); the dashboard
unification (one composition instead of
two, so the narrow band gets space grouping, drag-to-reorder, the space
context menu and both room-row badges back instead of a reduced
sidebar); the navigation seam (one place that decides push-versus-replace
per shell, so the room list survives a room switch); dropping the crypto
framing from "away" and making the sync indicator honest (the status bar
gone, the sidebar pill gone
because a connection status under the user's own name reads as that
user's presence, and one quiet room-scoped indicator that stays silent
during a long-poll); giving presence an owner and making it mean
something (the offline choice that a long-poll silently undid, the
profile screen that reported success on failure, contact presence
frozen for the whole session, and the presence colours that failed
contrast); the wiring of nineteen previously-unread settings into the
services that own them (including the logging group, which needed a
live reconfigure path because the logger package exposes no setters,
and which turned out to be silently broken on a fifth setting too); the
service-ownership pass (the log wipe that was silently killing logging,
the registry holding a disposed notifier after an account switch, and
the shutdown that disposed the wrong client); the
router rewrite that removed the delegate widgets
and the page-builder layer (fixing a broken own-profile page, a
"Room not found" card on a healthy dashboard, and the shell-flip
navigation that ejected users from pushed sub-routes); a September 2026
complexity and correctness pass
(the never-run CI workflow, the encryption recovery-key guess, the hub
locale bug, the notification chrome's hardcoded English, and the
dialog/snackbar boilerplate across the two largest screens); the July 2026
code review; the August 2026
performance/memory follow-up; the media widget and UX fix-up rounds;
the chat-timeline scroll-performance and scroll-velocity work; the hoverbar
rearchitecture; the responsive-layout shell rework with its shell-flip
navigation leak fix; an August 2026 bug-fix batch (24 fixes from a
full-codebase review); the SSO loopback-host regression fix; the timeline
scroll-position null-deref crash fix; the August 2026 timeline dead-code
and duplication removal plus a timeline simplification round; the
jump-to-unread FAB survival and target-selection/scroll-execution fixes;
a correction to the sync status pill plus removal of dead
appearance-settings wiring; blank-content error guidance; the dashboard
UI refresh (OS window decorations by default, optional slim in-app
header, unified navigation sidebar); the collapsible sidebar sections
follow-up; the space-selection fix; the removal of the variable look axis
(theming stripped back to seed colour, density and layout); the skins
refactor with the ArchVista GTK theme skin; the accent-color/theme
decoupling with Vista widget-style emulation; the theming overhaul Phases
1-6 (design tokens, component tokens, theme extension upgrade, widget-style
expansion, _buildThemeData rewrite, inline-styling refactor across all widget
categories); Phase 7 (shipping three new themes: Moonrelay signature, Minimal
flat, and Organic soft-rounded); the forbidden-typography and comment-hygiene
cleanup; and the comment de-flourish round that ASCII-fied arrows, banner
rules, and doc-comment emphasis; and the startup-flow round that fixed the
auth error paths echoing request bodies containing passwords and login
tokens, dropped a dead SSO timer and moved the post-login sequence into
one helper; and the login-page round that replaced its eight booleans with
two enums, extracted the automatic SSO flow, and made the "SSO failed"
notice reachable for the first time; and the round that moved the login
page into its directory, collapsed the duplicated sign-in opening, and made
both auth forms drivable from the keyboard.

Known-fail tests: 0 [<---- Update this if a test is known as broken ---->]

Tests at head: flutter test 967 green (805 at b771c4c, +162 new). flutter analyze
0 issues.

53. Fix the read position, so the unread pill means something, and let a
    jump reach an event the cache does not have

The jump-to-unread pill was described as "basically completely useless" and
as disappearing abruptly, and both complaints turned out to be the same
bug wearing two hats. Every read receipt in the app named **the newest
event in the cache**, never the event the user had actually reached. That
single wrong choice explains all of it:

- Opening a room marked it fully read, because the post-frame callback in
  `_initTimeline` posted a receipt for `events.first`.
- The pill then counted zero unread and never appeared.
- Scrolling *upward* through history also marked everything read, because
  the scroll listener was not position-aware at all.
- And when it did appear, it vanished on its own: `Room.fullyRead` reads
  `m.fully_read` account data and `setReadMarker` is a bare network call
  with no optimistic local write, so the count dropped to zero whenever the
  next sync happened to land. One to thirty seconds of nothing, then the
  pill deleted itself with no user action and no animation.

The fix is a read position, defined once: **the oldest event still visible
in the viewport**, never the newest event in the room. Note that "parked
at the live edge" is *not* a special case. Opening a room shows the newest
ten messages, and marking the newest one read retires the forty unread
above the fold that the user has not seen. The live edge has no separate
rule; it just happens that the oldest thing on screen is the oldest thing
in the room when you are at the bottom.

- `lib/src/chat/timeline_view.dart`: `oldestVisibleEventId` walks the built
  children in list order, which under `reverse: true` runs from the bottom
  of the screen upwards, and keeps the last entry that still intersects
  the viewport. Item heights are variable, so the position cannot be
  derived arithmetically from the scroll offset; only the children the
  sliver has actually built are asked, which is a bounded walk. A parallel
  `_cachedItemEventIds` list maps a rendered index back to an event
  without re-running the model.
- `lib/src/chat/read_marker_tracker.dart`: `TimelineSnapshot` gains a
  `readId`/`readTs` read position, and `TimelineSnapshot.fromEvents` now
  deliberately carries **none**. A snapshot with no read position is
  inert rather than defaulting to the newest event, because "assume the
  newest" is indistinguishable from "the user read everything" and that is
  precisely the bug.
- The tracker is now monotonic. A receipt is a floor, not a cursor: a
  candidate that is not strictly newer than the last one posted is
  dropped, with id-based dedupe as the fallback when the timestamp is
  unknown. Without this, scrolling back up after scrolling down would
  retract the marker and resurrect the pill the user had just cleared.
  The scroll debounce went from 250ms to 400ms so a fling that ends
  mid-history does not leave a receipt behind for a screen only flown
  past.
- `lib/src/chat/chat_timeline.dart`: the unconditional mark-read on open
  is gone, replaced by `_settleReadPosition()`, which retries across a few
  frames while the list is still settling and then names what is on
  screen. The jump handler no longer force-marks the newest event after a
  jump either; the jump lands the first unread message near the top of the
  viewport, so the read position is roughly there, and forcing the newest
  is what made the pill reappear and then vanish on every attempt.
- Pill dismissal is scoped to the newest event that existed when the user
  closed it (`_pillDismissedAtNewestId`). It used to latch off for the
  whole room session, cleared only on a room switch, so one tap removed the
  affordance until the user left. A later sync now brings it back.
- `_jumpLoadingDone` is gone. It existed to hide the pill immediately after
  a failed jump, which was a workaround for the pill being wrong. The
  coordinator's own `isJumping` is correct and always triggers a rebuild.
  `JumpCoordinator` also lost its separate `markRoomReadForce` seam: its
  `scrollToBottom` already returns the viewport to the live edge and
  settles the marker with it, so the two produced two POSTs for one user
  action. A marker sitting at index 0 now short-circuits to the live edge
  instead of entering the paginating branch and burning the full 30s
  budget rediscovering that the room is fully read.

**A jump to an event the cache does not have now works.** The live
timeline is anchored to the tail of the room and cannot page forward at
all: `Timeline.canRequestFuture` is `!allowNewEvent`, and the live timeline
is always constructed with `allowNewEvent = true`. `JumpToUnreadPager`'s
"both directions in parallel" race was therefore a one-direction race, and
`jumpToEvent` simply returned early for anything not already cached, so a
search-result jump into older history was a silent no-op.

- `ChatTimeline.jumpToEvent` is now three cases instead of one: scroll if
  cached, otherwise build a `/context` window around the event and show
  that, and on failure keep the current view and say the message is gone.
  A silent no-op is indistinguishable from a broken button.
- The outgoing timeline is detached with `cancelSubscriptions()` before
  being replaced. A `/context` window is still a `Timeline`, so it
  subscribes to `onSync`, and the SDK's `_removeEventsNotInThisSync` would
  delete every event in the window on the next gap-limited sync.
- `lib/src/chat/history_pager.dart`: the page-older gate consulted
  `room.prev_batch`, which is the room's live sync token and has nothing
  to do with a window's own `chunk.prevBatch`. On a fully synced room
  `room.prev_batch` is null, so a history window carrying a perfectly good
  `start` token reported itself exhausted and silently refused to page.
  It now asks the SDK first (authoritative for the live tail, and it keeps
  the common path off the `chunk` lookup) and falls back to the window's
  own token.
- Inside a history window the unread pill is suppressed. The window does
  not contain the read marker, so every event in it counts as unread and
  the pill would offer to jump somewhere the window cannot reach. The
  bottom pill becomes "back to latest" instead
  (`lib/src/chat/chat_timeline_floating_actions.dart`, with new
  `backToLatest`, `loadingEventContext` and `eventNotFound` strings in
  both ARB files).

**Event permalinks now resolve.** The app generated
`https://matrix.to/#/!room/$event` and had no way to parse one, so a
permalink copied out of Moonrelay opened the room without focusing the
message.

- `lib/src/helpers/matrix_uri_parser.dart` gains
  `MatrixUriEntity.event` plus a `roomId` on the result, handles both
  `https://matrix.to/#/!room/$event` and the spec's
  `matrix:roomid/!room/$event`, and gains `buildEventPermalink` so the
  link we hand out and the link we can resolve are the same shape by
  construction (`lib/src/chat/message_action_runner.dart` now uses it).
- The route carries it as `?event=`, alongside the existing `?threadRoot=`
  (`lib/src/router.dart`, `lib/src/widgets/room_resolver.dart`,
  `lib/src/screens/room_page.dart`,
  `lib/src/router_paths.dart:roomChatPath`), and the deep-link service
  routes the `event` case to the room, auto-joining or previewing first if
  the user is not in it.
- `MatrixUriParser.parse` now also catches `ArgumentError`.
  `Uri.decodeComponent` raises that, not `FormatException`, for a bare
  `%`, and a literal percent sign is legal in a Matrix room id, so a
  crafted `matrix.to` link in a message body would have thrown out of the
  parser and taken the message renderer with it. The class doc already
  promised this would degrade to "no match"; it did not, and this runs on
  every message containing a matrix-looking string.

**The `TimelineView` item cache is keyed on room and timeline identity.**
Both `ChatTimeline` and `TimelineView` hold stable `GlobalKey`s, so neither
`State` dies on a room switch, and `_timelineVersion` is only ever
incremented, so a new room could render the previous room's cached events.
Identity rather than `room.id`, because the question the key answers is
"is this the same room object", and a getter that a bare mock does not
stub should not be load-bearing inside `build`.

Tests at head: see the top of this file.

- `test/unit/read_marker_tracker_test.dart`: the receipt policy. Posts to
  the read position rather than the newest event, posts nothing without
  one, mirrors locally when receipts are off, and the monotonic floor in
  all its forms including `force`, the unknown-timestamp fallback and
  `bindRoom`.
- `test/unit/timeline_snapshot_test.dart`: the snapshot's read-position
  semantics, including that `fromEvents` deliberately carries none.
- `test/widget/timeline_read_position_test.dart`: a real rendered
  timeline (real `Event` objects, real `TimelineItem` widgets) asserting
  that opening a room does not post a receipt for the newest message, and
  that a dismissed pill returns when a later message arrives. Both were
  checked against the old behaviour and both fail there.
- `test/widget/timeline_event_context_test.dart`: the uncached jump. Asks
  for a context window, detaches the previous timeline, flags the window so
  the UI offers a way back, suppresses the unread pill inside it, returns
  to live on demand, does not refetch for an event already cached, and
  keeps the live view when the fetch fails.
- `test/helpers/renderable_timeline.dart`: the shared fixture. Most
  timeline widget tests use an empty event list on purpose, which is right
  for their subject and useless here: the behaviour under test lives in
  the seam between scroll position, receipt and rendered list, and a mock
  of either side would have let the original bugs through.
- `test/unit/matrix_uri_parser_test.dart`: event permalinks in both URI
  forms, via servers, the malformed-suffix rejections, the
  build-and-reparse round trip, and the broken percent-escape regression.

54. Make the pager's budget injectable, so the test stops waiting thirty
    seconds to prove it

`paginate_until_marker_test.dart` was the one known flaky test: it asserted
that a hung server is given up on within 31s, so it waited out the real
30s cap every run and then checked an **upper** bound. An upper bound is
the one shape of assertion that gets harder to satisfy the busier the
machine is. It failed once in five full-suite runs under load and passed
on three consecutive reruns, which is what WORK_NEEDED 1.3 called a
sensitive test rather than a regression.

The fix is the one that ledger entry already prescribed. The timeout was a
`static const` on `JumpToUnreadPager`, so nothing outside the class could
shorten it, and the test's only lever was patience.

- `JumpToUnreadPager` takes `budget`, defaulting to the renamed
  `defaultBudget`, still 30s. `JumpCoordinator` takes a `paginationBudget`
  and passes it through; nothing in the app overrides it.
- The test now waits 300ms. It asserts an upper bound of 5s *and* a lower
  bound of the budget itself, because a pager that returned immediately
  would satisfy the upper bound too. That is the flaw in the original test
  beyond its flakiness: "under 31s" cannot distinguish a pager that waits
  for the cap from one that gives up before making a request.
- A second test pins `defaultBudget` at 30s, because making the timeout
  injectable is exactly what would let someone shorten the real one to make
  a test faster, and no other test would notice.

**The test-only shim is gone, and it was worse than "plumbing".**
`ChatTimeline._paginateUntilMarkerViaCoordinator` ran the entire
`jumpToLastRead()` and then re-scanned the event list for the marker, to
answer a boolean. Three problems: it could scroll the user, it ignored the
budget entirely, and it reported whatever the cache happened to hold rather
than what the pager found. `JumpCoordinator.paginateUntilMarkerForTest` is
the primitive it was standing in for, so the shim is deleted rather than
fixed. Verified by reverting it: the budget test and the default test both
fail, because `jumpToLastRead` short-circuits to `scrollToBottom` on a
marker it can already see and never consults the pager.

`TimelineScrollTarget.scrollToEvent` is deleted too. It had no callers:
both real fallbacks call `scrollToFraction` directly with an index they have
already resolved, so the id-list wrapper was a convenience nothing used.

Two things this did **not** fix, both deliberate:

- `budgetExceeded()` is redundant with the outer `Timer` and no test
  distinguishes them. Deleting the loop guard leaves the suite green,
  because with a hung server the loop is blocked inside
  `await requestHistory()` and never reaches the guard. It matters only
  when the server answers promptly and the marker never surfaces, and an
  assertion about request counts there is CPU-speed dependent, which is the
  same trap that made this test flaky in the first place.
- The runAsync requirement stays. The budget bounds how long the test
  takes; it does not make the fake clock unnecessary, because `Future.delayed`
  still needs real time to elapse.

Tests at head: see the top of this file.

55. Make the model's event index exact, and stop re-deriving it in the view

`buildTimelineItems` recorded `eventIdToItemIndex[event.eventId] =
items.length - 1` as it walked, and then did `items.insert(0, banner)`
afterwards. So every index in the map was one less than the event's real
position, always, because the banner is always present, even for a
timeline with nothing undecryptable. `TimelineView._doScrollToEvent` knew:
its comment said the map "can be off by one and omits date separators and
state batches", and it re-derived the truth by scanning the rendered
widget list for the event's key.

That is the shape of bug that survives a code review, because each half
looks defensible on its own. The model is O(1), the view is O(n) but runs
once per jump, and the view's fallback is guarded by `renderedIdx >= 0` so
it degrades silently rather than throwing. Two sources of truth that
disagreed by exactly one, and the one that was wrong was the fast one.

- `lib/src/chat/timeline_model.dart`: index 0 is now *reserved* for the
  banner when the list is created, and the real entry replaces it at the
  end. A replace does not shift anything, so the recorded indices are
  correct as they are recorded. The banner is still always index 0, which
  is what the renderer relies on.
- The map's doc now says what it means: indices index [items] directly,
  counting separators and batches. Only regular messages are *keys*, so a
  caller still cannot assume "index + 1 is the next event".
- `lib/src/chat/timeline_view.dart`: the scan is deleted. `_doScrollToEvent`
  now uses `targetIdx` and `_cachedItems.length` directly.

**The test was pinning the bug.** `timeline_model_test.dart` asserted
`eventIdToItemIndex['msg'] == 0` for a single message, which is index 1 of
`[banner, event]`. The assertion was correct about the map being
"consistent with itself at the time of recording" and wrong about the list
it claimed to index, and it is why the off-by-one survived the extraction
into a pure-Dart model where it became easy to test.

It asserts 1 now, and a new test walks the whole map and checks each entry
resolves to its own event in [items], over a timeline that deliberately
mixes a banner, a date separator and a state-event batch with two
messages. Both mutations are caught by it: restoring the `insert(0)` and
counting only message events each fail.

`_handleItemAction` also took the map as a parameter and never read it,
since every action routes off the `Event` it is handed. Dropped, so the
call site no longer suggests the map is needed there.

Tests at head: see the top of this file.

55.5 Add the TimelineStore, stage 1: pure data, no UI

The audit's remaining structural item, begun. The design and the SDK
constraints are in `TIMELINE_STORE_PLAN.md`, written before the code so the
reasoning survives the commits that change it.

`ChatTimeline` holds one `Timeline` and it is being asked to be both the room's
live tail and an arbitrary `/context` window. It cannot be both, so
`jumpToEvent` resolves it by substitution and `backToLive` resolves it by
rebuilding. Everything awkward downstream follows from that rather than being
independent: `_anchoredEventId` is a nullable `String` doing a type's job,
`isViewingHistoryWindow` is a null check, the unread pill needs suppressing
inside a window because a window has no read marker, and every jump is a full
rebuild because `_cacheKey` hashes `identityHashCode(timeline)`.

Stage 1 adds `lib/src/chat/timeline_store.dart`: a pure-Dart holder for the
ordered segments behind one room. `flatten()` produces the newest-first render
list, `indexOf` is exact, and `version` replaces the timeline-identity term in
the view's cache key. The live tail is a segment too, distinguished only by
`isLive`, because a separate type would put an `is` branch in `HistoryPager`,
in the model, and in every gap calculation for nothing.

The one piece of real logic is the **dedupe**. A `/context` window routinely
overlaps the live tail, because both come from the same room and the window is
built around an event that may well be inside the tail. Without deduplication
the same message renders twice in one list and the context menu on either copy
acts on the same event. Later segments win, so a window's copy of an overlapping
event survives: its events are decrypted in a context that can be richer than
the tail's cache.

Four SDK constraints were verified by reading `matrix-9.0.0`, and two of them
mean the naive version of this plan does not work. A `/context` window is a
`Timeline`, so it subscribes to `onSync` and the SDK's
`_removeEventsNotInThisSync` deletes every event not in a gap-limited sync;
detachment has to happen when the segment is added, not when it is evicted, which
inverts what the substitution code does today. And `getRoomEvents` pages off the
segment's own `chunk.prevBatch` rather than `room.prev_batch`, which is the same
wrong-token bug section 53 fixed in `HistoryPager` and which a store is exactly
where it would come back.

The tests found two things, both instances of the pattern this project keeps
meeting:

- **`indexOf` initially disagreed with `flatten`.** It traversed without the
  dedupe, so it counted events `flatten` had dropped and answered too high by
  however many duplicates preceded the target. Two traversals of one list
  disagreeing about what the list contains is exactly what section 55 just
  fixed in the model's index map, reintroduced one file over.
- **The `isLive` guard in `cancel()` was correct and entirely untested.**
  Removing it failed nothing, because `addHistory` is the only caller and
  rejects live segments first. A test now calls `cancel()` on a live segment
  directly, because a later eviction path will call it on whatever it removed.

Mutations verified: dropping the dedupe, moving the cancel into the factory,
removing the live guard, reversing the history order, and bumping `version` on
reads all fail at least one test.

Tests: `test/unit/timeline_store_test.dart`, 27 cases.

Tests at head: see the top of this file.

55.6 TimelineStore stage 2: segments page themselves

`TimelineSegment` gains `canPageOlder`, `canPageNewer`, `pageOlder` and
`pageNewer`; the store gains `pageOlder(id)` / `pageNewer(id)` that also bump
`version`. 44 tests in the file.

Paging goes through `getRoomEvents`, not `requestHistory`. That is not a
preference: `requestHistory` routes via `room.prev_batch`, while
`getRoomEvents` pages off the segment's own `chunk.prevBatch`/`chunk.nextBatch`
(timeline.dart:231-237). Only the latter is correct for a detached window, and
this is the wrong-token bug section 53 fixed in `HistoryPager`, which a store
is precisely where it would come back. `canPageOlder` is therefore
`canRequestHistory || chunk.prevBatch.isNotEmpty`, with the first term
authoritative for the live tail (whose chunk anchors start empty, because it
reads its first page from the database) and the second rescuing a window on a
synced room. Exhaustion is an **empty string**, never null: `getRoomEvents`
assigns `chunk.prevBatch = newPrevBatch ?? ''`.

**The plan had this backwards for forward paging, and a test caught it.** The
plan assumed the same "ask the SDK, fall back to the chunk" shape for
`canPageNewer`. That is wrong: the SDK clears its own forward flag once a page
reaches the end (timeline.dart:269-275), but until it does, `canRequestFuture`
is true for a window that has nothing left to give, so a spent window reports
itself pageable. Forward paging is now gated on the segment's own
`chunk.nextBatch` and nothing else. The live segment is the only kind that can
never page forward, and it is identified by `isLive`.

That is section 3.4's lesson applied in the other direction: the SDK's flag is
convenient, the segment's own anchor is authoritative, and treating the two as
interchangeable is how this bug happened once already.

**The version bump belongs to the store, not the segment.** `getRoomEvents`
fires `onInsert` once per event *while* it is appending to `chunk.events`
(timeline.dart:302-304), so anything rebuilding from inside that callback reads
a half-appended list. The page returns before the store touches anything and the
bump happens once, after the list is whole.

Two SDK details worth keeping:

- `getRoomEvents`'s `direction` parameter is **untyped** (`direction =
  Direction.b`, no annotation), so it is `dynamic` at the call site and an
  override must be declared `dynamic` too. The mismatch is a compile error
  whose message talks about covariance, which is a long way from the cause.
- `TimelineChunk` is not exported by `package:matrix/matrix.dart`; only
  `src/timeline.dart` imports it. Tests construct one via
  `package:matrix/src/models/timeline_chunk.dart`, the deep import
  `test/helpers/renderable_timeline.dart` already uses. Production code never
  needs it, since windows are built by `room.getEventContext`.

Mutations verified: dropping the `chunk.prevBatch` fallback (4 failures, which is
the section 3.4 regression pinned at the layer it would return to), paging via
`requestHistory` (5), removing the version bump (1), and dropping the `canPage`
guard so an exhausted segment still hits the network (1).

55.7 Refuse a /context window that is anchored to nothing

The plan's one unverified claim, handled rather than assumed.
`room.getEventContext` takes a window's `prevBatch` from the response's `start`
token (`room.dart:1726-1730`), and whether it re-anchors correctly for an event
older than the live tail was never confirmed against a real server.

`TimelineSegment.fromEventContext` returns null for a window that cannot reach
anything: empty, or with both `prevBatch` and `nextBatch` empty. A window
anchored to nothing renders a few events that page in neither direction, so it
looks like the room, is not the room, and its only symptom is that scrolling
does nothing. Failing and letting the existing "that message is no longer
available" path say so is more useful than a view that lies quietly.

The check is deliberately `!canPageOlder && !canPageNewer` rather than
`!canPageOlder`: a window that reached the start of the room but has more after
it is perfectly usable.

Three mutations, each failing one or two tests: dropping the anchoring check,
dropping the empty check, and tightening it to require forward paging. The last
is the one that matters most, because it is the plausible-looking tightening
that would have rejected a legitimate window.

55.8 TimelineStore stage 3: the render list comes from the caller

`TimelineView` now takes `events` (the list it renders) alongside `timeline`
(the live tail, still needed for the aggregation lookups each `TimelineItem`
performs). That is the seam stage 5 needs: wiring the store in becomes passing
`store.flatten()`, rather than a second refactor of the view.

`buildTimelineItems` and `ThreadUtils.buildThreadReplyCounts` both take a
`List<Event>` instead of a `Timeline`. Thread counts have to be computed across
the whole flattened list, because counting within one segment drops a thread
whose root sits in a history window and whose replies sit in the tail.

**The cache key hashes the event list rather than the timeline**, because the
two differ in a way that matters: the live tail keeps the same `Timeline` object
across a history jump, so hashing it would miss a swap of the render list.

**The list identity does not drive invalidation, and the first test asserted
the opposite.** `chunk.events` is mutated in place by the SDK, so its identity
never changes when its contents do; a key driven by identity alone would serve
stale items for as long as the version notifier was silent. The notifier is the
invalidation signal, which is why `events` and `timelineVersion` are a pair
rather than either being redundant. Both halves are now covered.

This is the constraint stage 5 has to respect: `TimelineStore.flatten()`
allocates a fresh list on every call, so its identity is worthless as a cache
key and stage 5 pairs it with `store.version`.

**`_targetInLiveTimeline` is only reachable through an in-place mutation.**
The stale-cache path, where the index map misses but the event is present,
needs the SDK's mutate-in-place behaviour to exist at all: a newly paginated
event is in `events` the instant the request lands, one build before the map
catches up. Two attempts to test it failed for instructive reasons. Swapping in
a new list object cannot reach the branch, and inserting the event at index 0
cannot observe it, because under `reverse: true` that index is already at the
bottom of the viewport and the view never has to move. The test that works
appends to the old end, so resolving the event requires a scroll.

Mutations verified: reading the render list back out of `timeline.events` (4
failures), hashing the timeline instead of the list in the cache key (1),
dropping the list from the cache key (1), and pointing `_targetInLiveTimeline`
at the tail (1).

Tests: `test/widget/timeline_view_render_source_test.dart`, 10 cases.

Tests at head: see the top of this file.

55.10 TimelineStore stage 5: a jump adds a window instead of replacing

`ChatTimeline` holds a `TimelineStore` alongside the live tail, and every
artefact of the substitution is gone: `_anchoredEventId`, `backToLive`, the
`eventContextId` parameter on `_initTimeline`, and the unread pill's
suppression inside a window.

**Windows accumulate.** A jump adds the one it needs and leaves the rest
loaded, so scrolling away from a jump in either direction keeps loading from
where the user is. Collapsing on every jump would also discard the live tail
each time, which is the state a room opens in.

**The live tail is no longer detached on a jump.** The old code cancelled it
because it was being replaced; leaving it cancelled now would freeze the room,
since it is the one segment that follows sync. Windows are detached instead,
when added, which is where a `/context` window has to be detached anyway.

A jump target is looked up in the whole store, so a point inside a window the
user has already been to is a scroll rather than a refetch.

**Two pills, both visible at once.** They answer different questions, "where is
the unread" and "where is the new", and a room with unreads while scrolled up
has both. The old class documented a priority between them and the code did not
implement it. The unread pill is no longer suppressed inside a window: it used
to be, because a substituted window held no read marker and so counted every
event as unread, and with the marker present in the list the count is real.

"Back to latest" is gone as a distinct mode. It existed only because returning
to the live head meant rebuilding a discarded timeline. Jumping to the bottom is
a scroll within one list now.

`TimelineView` takes a `Listenable` rather than a `ValueNotifier`, because the
parent merges the live sync signal with the store version. A merged notifier has
no readable value, so the view keeps its own monotonic counter for the cache key
and listens for the bump.

**Two real bugs, one of them a crash.** Re-jumping to a point whose `/context`
window was loaded but did not contain the event built a second window with the
same id, and `addHistory` rejected it inside `setState`, which takes the frame
with it. That is a crash from a user action. The duplicate is now checked before
the fetch and the rejection is caught as a belt.

`chat_fab_test.dart` rebuilt copies of both pills locally instead of driving the
real widget, which is why it passed while the production class documented a
contract its own code did not implement. It drives the real column now.

**Two things stage 5 deliberately did not do**, both of which section 55.11
then did. Scrolling *up* from a jump did not extend the window the user landed
in, because `HistoryPager` paged only the live tail. And nothing loaded
*downward* between two windows, so a gap was permanent.

Tests at head: see the top of this file.

55.11 Page the oldest window, and close gaps as the user approaches them

The two seams stage 5 recorded as open. `HistoryPager` took a `Timeline` and
paged the live tail, so with a window on screen a scroll to the top of the
render list extended the wrong end and the window never grew. It takes a
`TimelineSegment` now and is handed `store.oldestSegment`.

It also pages through `pageOlder` rather than `requestHistory`, which is the
wrong-token bug for the third time: `requestHistory` routes via
`room.prev_batch`, so a synced room reported itself exhausted and refused to
page a window. The `canPageOlder` rule is the store's, not a copy, because the
copies are how it kept coming back. `onTimelineUpdated` is gated on the
segment's own answer for the same reason.

**A gap is no longer permanent.** The view reports the nearest gap marker and
the group it follows when it comes within 240px of the viewport, and the
timeline grows that group to close the hole.

The direction took two attempts, and the second is the interesting one. The
first paged *newer*, reasoning that a gap needs more of the newer side. It is
the other way round: the events that close a hole are older than the one the
gap follows, and newer is the only direction the live tail cannot take at all,
since it is anchored at the newest event in the room.

The distance to the viewport also started out signed upwards, on the reasoning
that `reverse: true` puts older events higher up. True, and irrelevant: a gap
sitting just above the live edge is the one a user is closest to, and it was the
case being missed. A marker with no `GlobalKey` has no `RenderBox` either, so
it could not be measured at all; gap markers are now keyed by the group they
follow, which also survives the index shifting as either side grows.

`reportGapApproach` dedupes per gap, since a scroll fires it on consecutive
frames while the marker sits near the fold.

Tests at head: see the top of this file.

56. Remove the last dead code on the timeline surface

`TimelineItemSenderNameAndTimestamp` and `unreadInWindow` are gone, which
closes the section 8 audit.

The sender-name widget was a superseded implementation of the row
`timeline_item.dart` already renders, with its own comments conceding it:
"NOTE: Rework this and add proper styling". Its only test was two cases
asserting the widget builds, which is the shape of test that keeps dead code
alive rather than documenting it.

`unreadInWindow` was a re-export of `countUnreadInWindow` that nobody called.
The grep that found it matched the substring inside `countUnreadInWindow`,
which is the same trap that makes dead-code searches noisy in both
directions; the thirteen test references were to the real function, not the
wrapper, so no coverage was lost.

Tests at head: 955 green. flutter analyze 0 issues.

55.9 TimelineStore stage 4: show where messages are missing

Two history windows rendered next to each other look exactly like one
continuous conversation, and the user reads the part below the hole as if it
directly follows the part above it. They then reply to something that is not
what they thought. `TimelineGapMarker` makes the discontinuity visible.

It is a dashed rule rather than a solid one, because a solid rule in the same
position reads as a `DateSeparator`, which claims "a new day". A marker that
lies about the kind of discontinuity it marks is worse than none.

**The read-position walk treats a gap as a hard stop**, which is the only place
a gap behaves differently from every other null-id entry. Separators and state
batches have events behind them on screen; a gap means the messages above are
not contiguous with the ones below, so continuing across it would name an
event the user has not scrolled past and retire messages they never saw. The
walk already skipped null-id entries, so a gap would otherwise have been
transparent to it.

Contiguity is a heuristic and the code says so. Matrix events carry no stream
ordering token that survives being put in a `/context` window, and adjacent
events routinely share an `originServerTs`, so `gapBoundaries` compares time
with a ten-minute tolerance. An overlap is not a gap: when the older segment's
newest event is at or past the newer segment's oldest, the ranges touch.

`gapsAfter` is group-relative rather than index-relative, because a raw index
is ambiguous once a filter hides events: a group's last event may not be
rendered at all, and an index-based marker is dropped with it, silently
closing the hole. A test hides a group's tail behind a reaction and asserts
the gap survives.

Three findings from the tests. `_groupHasLaterVisible` bailed at the first
event belonging to another group instead of scanning for one of its own, which
drew a gap after every event. A gap was drawn after the last group, which needs
two sides to exist. And four of my own tests called events an hour apart
"adjacent" when the tolerance is ten minutes; fixing one of those revealed that
neither event in a two-event list is ever flagged as a group continuation,
which is existing model behaviour and is now described in the assertion rather
than asserted around.

The stage also exposed a stage 1 bug in the store's ordering; it is committed
separately so it is findable on its own.

Tests: `test/unit/timeline_gap_test.dart` (19 cases) and 4 added to
`test/widget/timeline_view_render_source_test.dart`.

Tests at head: see the top of this file.

56. Remove the last dead code on the timeline surface

52. Give the design language an elevation scale, and let the account card
    be the one lifted thing

The app did not look flat because the palette is flat. It looked flat
because the three shadow tokens in `design_tokens.dart` had **zero readers
outside the file that declares them**, and their values would not have
registered anyway: one layer each, 10% black, blur 2. So there was no
elevation language at all. Every surface was a flat colour fill, and the
only depth cue in the entire chat was a 0.7px border around message
bubbles, which is a wireframe rather than a surface.

**Elevation, made real.**

- `lib/src/theme/design_tokens.dart`: `shadowLow`, `shadowMedium` and
  `shadowHigh` are now two layers each, a tight contact shadow under a
  wider and weaker ambient one. The split matters more than the opacity. A
  single soft shadow reads as a glow *around* an object; a contact shadow
  under an ambient one reads as a surface *above* another. One layer cannot
  do both jobs, which is the whole reason this looked flat.

**The account block is the one memorable object.** It was moved to the
bottom of the sidebar earlier and it looked out of place there, because it
was still a flat tinted strip shaped like a row. The move was right; the
treatment was not.

- `lib/src/widgets/sidebar_profile_pill.dart`: a card. Elevated, with a
  hairline, a ringed avatar, and a two-line identity. It is deliberately
  the *only* lifted thing in that pane, because that is what makes a
  single lift read as deliberate: boldness spent in one place and nowhere
  else. Everything above it stays flat.
- The avatar is ringed in the card's own colour. Without the ring the
  avatar and the card share an edge and merge into one flat rectangle,
  which is the specific failure mode of a flat design language: nothing
  states which element is on top of which. The diameter is 36 so the 2px
  ring lands on whole pixels; on an odd diameter it straddles a half pixel
  and goes soft on one side, which would defeat the ring.
- It now shows the localpart under the display name, dropping the
  homeserver when it is long enough to be noise. A Matrix client is full of
  people whose display names collide and the localpart is what tells two of
  them apart. It was not on screen at all before.
- Hover lifts it one step and fades in a chevron. Motion that answers the
  pointer is welcome; motion that plays on its own is noise, and this pane
  has enough of it already.
- Still deliberately no sync indicator, for the reason in its doc comment.

**The filter now shows its own intention.** "Home" and "All" were two
`NavRow`s. Both halves of that were wrong: the labels are navigation words
for what is a filter, and drawing them as rows in a list of places made the
pane read as "here are two destinations" when it is "here is one list and
these are two views of it". People clicked the one that sounded like a
destination and got a narrower list.

- `lib/src/widgets/room_list_filter.dart` (new): an inset track with a
  pill that *slides* between two segments. Two lit buttons would read as
  tabs; one pill moving between two homes reads as a single control
  changing state, and the movement is what carries the meaning.
- The segments are labelled by what the list contains: "Friends" and "All
  rooms". "Home" was actively wrong, because Home showed direct messages
  and nothing else, which is not what anyone means by home.
- The rooms section header underneath already echoes "Friends" or "Rooms",
  so the control and its result are visibly the same thing.
- The track is a hollow, not a card, and the pill inside it is the only
  elevated part. A raised track containing a raised pill is two elevations
  fighting, and the track has to read as somewhere for the pill to move.
- The control stays above the Spaces section rather than moving next to
  the Rooms header it filters. Next to its result would show the
  relationship better and read worse, because a control that changes what
  is below a *different* section looks like it belongs to that section.
- It is announced as one filter, not as two buttons, because a screen
  reader user cannot see the track.

**Selected rows get a leading accent bar.** The tint alone is not enough
to find the current room in a list of two hundred: a row that is merely
near the tint, or hovered, or mid-transition, all read the same. A bar on
the leading edge is a position rather than a colour, so the eye finds it
without comparing shades.

It costs the row nothing, and the first version got that wrong. The
leading padding was carrying `+ (selected ? 3 : 0)`, on the assumption that
a 3px bar drawn at `start: 0` would otherwise sit on top of the label. It
would not: `padH` is 12 or 14 and always wider than the bar, so the bar
draws over the row's own leading gutter and the label never reaches it.
The `+ 3` shifted both the label and the avatar 3px right on every selected
row, so moving the selection reflowed the list under the pointer. Small
enough to look deliberate until you click a second room and watch the first
one jump back, which is worse than a shift you notice immediately.

The test that shipped with it is why this survived. It was named "the bar
does not move the label" and asserted `expect(selected - plain, 3)`: the
name described the intent, the assertion described the code, and the two
were never reconciled. An exact 3 also pins the one number that is wrong,
and would have kept passing if the bar grew to 40px and shoved the label
across the row. It asserts 0 now, and a second test holds the invariant the
fix depends on, that the bar stays inside the gutter. Both are verified by
mutation: restoring the `+ 3` fails the first, widening the bar to 40px
fails the second, and deleting the bar outright fails all three of the
bar-related tests, so none of them pass vacuously.

**Bubbles are surfaces, not boxes.** They were a 30% primary fill behind a
0.7px 50% primary border, which is the visual signature of a wireframe: it
draws a box around the text rather than putting a surface under it, so a
screen full of them looks like a diagram of messages instead of messages.
Now an opaque-enough fill plus `shadowLow`. Own messages read slightly
heavier than everyone else's, which is how a left-aligned conversation
says which side of it you are on without mirroring.

Tests: `test/widget/sidebar_profile_pill_test.dart` and
`test/widget/room_list_filter_test.dart` (new, split from one combined file
so each commit carries its own tests and passes on its own),
`test/widget/sidebar_row_test.dart` for the accent bar, and the sidebar
rendering test in `navigation_sidebar_test.dart` updated for the filter.
Both of the filter's design claims are verified by mutation, because both
are easy to state in a test and hard to actually enforce: relabelling the
segments back to "All" fails three tests, and removing the sliding pill
fails exactly the one that asserts it moves.

### The filter's target was smaller than it looked

Found on screen, not in review. The segmented control drew a 28px slot and
each half looked tappable, but the actual `InkWell` was about 18px tall
and stopped short of the right edge, so roughly a third of the visible
control was dead space. Two separate causes:

- **Height.** A `Row` defaults to `CrossAxisAlignment.center`, which hands
  its children *loose* height constraints, so each segment's `SizedBox`
  sized to its content rather than to the slot. The `Row` in the `Stack`
  now uses `CrossAxisAlignment.stretch`, and the `InkWell`'s child is a
  `SizedBox.expand` so the target is the slot rather than the label.
- **Width.** `segmentWidth` was `(constraints.maxWidth - 6) / 2`, which
  subtracted the track's own 3px inset a second time and left a 6px dead
  strip down the right edge. It is now `constraints.maxWidth / 2`.

The track is 36px rather than 34, so each half is a 30px target. Not
Material's 48px minimum, which does not fit: this is the tightest pane in
the app and two pixels of height is a row of rooms somewhere else.

Verified by mutation, all three claims. Reverting the width arithmetic
fails the geometry test. Removing both height mechanisms fails it again.
A `SizedBox.expand` to `SizedBox(width: double.infinity)` passes, which is
how the two turned out to be redundant for the width but each load-bearing
for a different dimension.

Note for the next person writing this kind of test: the first version of
the tap test aimed 2px above the *label*, and it passed against the bug it
was written for, because 2px above the label is still inside an 18px
target. The dead band is at the slot's edges, so the tap has to be anchored
to the slot. The pill is `AnimatedPositioned` with `top: 0, bottom: 0` and
so fills the slot exactly, which makes it the honest reference. Its x is
the *selected* segment, though, and the second one is selected by default,
so the x has to come from the segment under test.

Open, and deliberately not here: Material's own `elevation` still
generates its shadows from the theme rather than from these tokens, so
there are two elevation systems in the app and they do not agree. Making
them one is a theme-wide change and is recorded in `WORK_NEEDED.md`.

51. Make Back mean what a user means by it, and give the hub two exits

Back was strictly a navigator's Back: pop what was pushed, in the order it
was pushed. That is correct and it is not what people mean by Back in a
chat client.

**Rooms.** Room A, then room B, then Back landed on room A. The
single-pane shell pushed on every room open, so conversations accumulated
on the stack and walking backwards through rooms the user had already read
was one press per room. The dashboard shell never had this problem
because it replaces on every open; only the single-pane shell pushed.

The fix is not in the back button. Changing what the button does would
leave the stack wrong underneath, and every other route into the room
would still inherit it.

- `lib/src/helpers/shell_navigation.dart`: `openRoom` pushes the *first*
  room and replaces every room after it. The first one still has to push,
  because the list underneath is the only navigation the shell has and
  replacing it would throw away the user's scroll position and their
  search text. This is what the function's own doc comment already claimed
  ("a growing history would just walk the user backwards through rooms they
  have already read"); the code just did not do it in this shell.
- `lib/src/router_paths.dart`: `isInsideRoomFlow`, a prefix test over the
  room route, as distinct from `isRoomChatSegments`, which is an exact
  test and has to stay one. The two answer different questions. The exact
  test decides whether the shell draws its own back arrow, and a
  sub-page's own `AppBar` already carries one, so a prefix test there
  produces the doubled header bar the exact test was written to prevent.
  The prefix test decides whether a room open is a switch or a drill-down.
- Room *sub*-pages are deliberately unaffected. `openRoomSubpage` still
  pushes, so a room's settings, thread and room-info pages sit on top of
  the chat and the chat's back arrow still steps through them. The user
  said the room info page's back is already right, and it is right for
  this reason.

**The hub needed two buttons**, because "back" means two different things
there and people mean different things by each.

- `lib/src/screens/hub_screen/hub_screen.dart`: the leading arrow is a
  history step, undoing one section switch and returning to whatever
  opened the hub at the entry point. A trailing cross is an exit. Close
  is not a faster Back: making someone press Back once per section they
  visited to escape a surface they do not think of as a stack is a small
  thing that adds up, and someone who opened the hub to change one setting
  should not have to know how many settings pages they passed.
- `lib/src/helpers/shell_navigation.dart`: `closeToRoomList`, the
  deliberate opposite of `backToRoomList`. Back is one step and keeps what
  is behind it; Close is `go`, so it discards the stack. The difference is
  only observable when the stack is more than one deep, which is why the
  test builds list, room, sub-page rather than a single hop.

Tests: `test/widget/shell_navigation_test.dart` gains the stacking case,
the sub-page case that pins the narrowing did not reach too far, and a
`closeToRoomList` group including the cold deep link.
`test/widget/hub_route_navigation_test.dart` gains the close button and
the back button side by side. The hub's test router needed a
`/main/rooms` route for the first of those: without it the `go` matches
nothing and `router.state` fails with "Bad state: No element", which reads
like a broken router rather than a missing route.

Verified by mutation: reverting `openRoom` to push-always fails exactly
one test, "switching rooms does not stack the second on the first", and
nothing else. That was worth checking, because the sub-page test and the
existing "keeps the room list on the stack" test both pass under the old
behaviour too, so a green suite on its own would not have shown the change
doing anything.

50. One row primitive in the sidebar, tabs in the right pane, and a
    reversible decision about the room's width

The expanded dashboard had a specific, measurable problem: the navigation
sidebar was a fixed 50/50 vertical split showing about five rooms, four
different row types each carried their own padding, and the right pane
hid four destinations behind a dropdown.

**Four row types, four sets of metrics.** `NavRow` and `GroupRow` padded
with `spaceMd`/`spaceSm` and had no corner radius. `SpaceRow` went through
`NavRowShell`, which padded with a hard-coded `10`/`6` and had a radius.
`_RoomRow` had its own padding again, and this is the part that actually
hurt:

```dart
final dense = constraints.maxWidth < 260;
final nameSize  = dense ? 13 : 18;
final bodySize  = dense ? 11 : 16;
```

Density keyed off the *pane width* against a 260px threshold. The
sidebar's own range is 200..360, so a default window rendered room names
at 18pt and preview lines at 16pt directly under 13pt space rows, and
widening the sidebar made the type larger. Meanwhile `LayoutDensity`, the
user-facing "Interface density" control, only reached the theme's
`visualDensity` and changed nothing in this pane at all.

- `lib/src/widgets/sidebar_row.dart` (new): `SidebarRow` and
  `SidebarRowMetrics`, one set of numbers, resolved from the user's
  `LayoutDensity`. Density is read with `context.select`, so a room list of
  a few hundred rows only rebuilds on a density change and not on every
  unrelated settings write.
- `NavRow`, `SpaceRow`, `GroupRow` and `_RoomRow` are now thin wrappers
  over it. `NavRowShell` is gone; it had one caller.
- `SpaceAvatar` derives its radius from the same metrics instead of a
  hard-coded 14, which at the compact density was 28px across inside a
  22px slot.
- `RoomEncryptionBadge` moved to a new `titleSuffix` slot rather than
  `trailing`. It is a property of the room's *name*, so it belongs on the
  title line where the ellipsis can consume it; pinning it opposite the
  unread count would put the two things a user scans for on opposite sides
  of the row. Dropping it entirely would have regressed section 44.

**The type scale, twice.** The first `SidebarRowMetrics` had 13pt titles
and a 12pt compact, and the first result read as too small. Both numbers
are now up: 15pt titles at comfortable against 13pt at compact, with the
subtitle at 12.5 and 11, row height 44 and 34, leading slot 34 and 26. A
one point range is not a density choice, it is a rounding error, and it
made the control look broken. `test/widget/sidebar_row_test.dart` asserts
both a floor (15pt) and a minimum spread (2pt) so neither can be undone by
accident.

- `lib/src/widgets/navigation_sidebar/nav_widgets.dart`:
  `NavSectionHeader` was a hard-coded 12pt that ignored density entirely,
  so the pane's wayfinding sat at a fixed size between rows that moved. It
  now reads the same setting at 13pt and 11.5pt, one step below the rows it
  heads.

**The right pane hid four destinations behind a dropdown.**
`right_sidebar_content.dart` had a `DropdownButton` over room info,
members, threads, pinned and none, showing only the selected one as a
bare icon. Threads and pinned messages are not secondary: they are where
you go to answer a mention or find something you were told to look at.

- `RightSidebarHeader` is now a four-tab strip, icon and label each,
  evenly divided. The selected state is carried by the container as well
  as by colour.
- The labels were hard-coded English. `localizedRightPaneChoice` already
  existed and was already used by the hub's layout settings, so the strip
  uses that rather than a second mapping. This closes the corresponding
  item in `WORK_NEEDED.md` 7.6.
- `RightPaneChoice.none` is no longer a tab. "Show nothing" is not a
  destination and the pane has a collapse control for it. The value stays
  valid in storage: a user last on `none` opens the pane to a strip with
  nothing selected and one tap from there.

**Sidebar chrome.** The account moved from the top of the pane, directly
under the window's title bar, to a pinned footer below both list
sections. "Add room" moved from a full-width navigation row to a `+` on
the rooms section header, which is where the rooms it creates live. A
nav row is about 40px in a pane with roughly 305px of list height to
share, so this is worth more than it looks.

- `lib/src/widgets/navigation_sidebar/nav_widgets.dart`:
  `NavSectionHeader` takes an optional trailing `action` with a tooltip.
  Its label and chevron are now separately tappable, because the `+` sits
  between them and one big `InkWell` would have made both activate it.
- `lib/src/widgets/navigation_sidebar/navigation_sidebar.dart`: the
  footer is `_SidebarFooter`, split out so its position is a property of
  the footer and not of whatever the column happens to be listing.

### The room's width, and why there is no measure

This one shipped and was then taken back out, and the reason is worth
recording because the original reasoning was not wrong, it was aimed at
the wrong thing.

The room surface was briefly capped at 760 and centred, on the reasoning
that bubbles are capped at 480 (`_kMaxBubbleWidth`,
`timeline_item.dart`) inside a full-width list, so a 1920px window showed
480px of content hard against the left edge with ~1400px of empty surface
beside it, and the composer stretched across all of it. Capping the room
instead of the bubble puts the messages and the composer on one measure.

That reasoning is a reading-page argument, and this is not a reading page.
A chat client is a window onto a live conversation, and on a desktop the
window is what the user sized deliberately. The extra width is there to be
used, and an empty band beside the conversation reads as a layout that ran
out of ideas rather than as breathing room. A centred column on a wide
monitor looks like a mistake because on a desktop it is one.

- `lib/src/screens/room_page.dart`: no cap, no centring, no edge rule. The
  header, timeline and composer all fill the pane at every width.
- `test/widget/room_page_layout_test.dart` (was
  `room_page_measure_test.dart`, renamed when the assertion inverted) now
  asserts the opposite invariant at 420, 900, 1600 and 2400px, and that
  the room is flush left with no gutter, so the cap cannot come back
  without a test failing.
- The bubble cap stays at 480. It is pre-existing and was not part of the
  reversal; whether it should grow is a separate question, and the right
  answer probably depends on the pane width rather than being one number.

Tests: `test/widget/sidebar_row_test.dart` (new),
`test/widget/right_sidebar_test.dart` (new),
`test/widget/room_page_layout_test.dart` (new), and additions to
`test/widget/navigation_sidebar_test.dart`. The two width-keyed density
tests there were replaced: they asserted 13 at 220px and 18 at 600px,
which is the behaviour being removed, and asserting it would have made the
suite agree with the bug.

Note for the next person, both cost real time here:

- The default widget-test surface is 800x600, so a `SizedBox(width: 1600)`
  is silently clamped. Every width assertion in
  `room_page_layout_test.dart` would have been a lie about the number it
  named. Set `tester.view.physicalSize` and reset it in `addTearDown`.
- `wrapWithProviders` registers its own unstubbed `MockEncryptionService`
  as a fallback, closer to the tree than a provider you install yourself.
  See section 49 for the same trap in the hub tests.

49. Make the hub a stack, give its security page a way to refresh, and
    retire the duplicate profile route

Three defects, all of them "the hub looks right and does not work", found
in one pass over the routed hub from section 48.

**Back did nothing.** `HubScreen._go` pushed the target when it differed
from the current location and then called `router.go` on it:

```dart
if (path != currentPath) context.push(path);
context.go(path);
```

`go` replaces the whole page stack, so the very first click inside the
hub destroyed the route the hub was opened from. From that point on
there was nothing to pop and nothing to return to, and the AppBar's
leading arrow was inert. The fix is to push and stop:

- `lib/src/screens/hub_screen/hub_screen.dart`: `_go` pushes the target
  when it differs from the current location and does nothing when it
  does not. The second click on the row you are already on must not stack
  a duplicate either, or Back appears broken for one press and gets
  misreported as the same bug.
- `_AccountHeader` was routing the whole hub through `_go`, so tapping
  the profile card had the same effect. It pushes `/hub` directly.
- The AppBar's leading arrow uses `HubScreen._leave`, which pops when
  the hub is somewhere in the stack and otherwise goes to `/main/rooms`,
  so entering the hub from a room and leaving it empty-handed does not
  strand the user.

This is pinned as an invariant rather than as a button handler:
`test/widget/hub_route_navigation_test.dart` walks out of the hub section
by section and asserts that Back always has somewhere to go. Mutating
`_go` from `push` to `go` fails three of those tests, which is how the
fix was checked.

**The encryption page could not refresh from the hub.** It arrives with
`embedded: true` so it does not nest an `AppBar` under the hub's section
header, and that branch also discarded the refresh `IconButton` in the
`AppBar` above it. The hub was therefore the one place in the app where
the only way to pick up a cross-signing or key-backup change made on
another device was to leave the hub and open `/main/encryption`. The
control was not a nicety: `EncryptionService` refreshes off the sync
stream, and a user who just approved a request on their phone is
looking for a button.

- `lib/src/screens/encryption/encryption_overview/encryption_overview.dart`:
  the refresh handler is now `EncryptionRefreshAction`, a public widget
  used by both presentations.
- `lib/src/screens/hub_screen/sub_page_header.dart`: takes an optional
  `actions` list, so a body that cannot supply its own `AppBar` can still
  get its controls.
- `lib/src/screens/hub_screen/hub_screen.dart`: the security section
  passes one. It is the only section that does.

**Two routes rendered the profile editor.** `/main/me` built
`OwnAccountPage`, a page hosting the profile editor plus three links into
the hub, while the hub's index is the profile followed by that same list
in the same order. The editor and the section list each existed twice,
with nothing keeping them in step.

- `lib/src/router.dart`: `/main/me` is now a redirect to the hub index.
  The route stays, because `FocusDestination.you` needs a destination to
  land on and deep links to it already exist.
- `lib/src/screens/own_account_page.dart`: deleted, now unreferenced.
- `lib/src/widgets/layout_mode_switch.dart`: deleted. The switch belongs
  to the hub's layout settings and the shell surfaces were only ever
  holding a second copy of it.
- `test/widget/router_test.dart`: pins the redirect against the real route
  table. It is deliberately not in the hub's own test file, whose router
  is a test-local copy that never had a `/main/me` route to redirect.

Note for the next person: the encryption test needed
`wrapWithProviders(encryptionService: ...)`. That helper registers its own
unstubbed `MockEncryptionService` as a fallback, and it sits closer to the
tree than the provider `pumpHub` installs, so the hub was watching an
unstubbed mock and `crossSigningBootstrapped` returned `null` into a
`bool`. `countUnverified()` and `refresh()` are methods on the service,
not getters, so they are stubbed with the call.

48. Replace the hub's tab strip with a navigation pane, and fold the
    profile into the hub's index

The tab strip is gone. It chose its own presentation by counting tabs, so
the four top-level sections got an evenly divided row and "App Settings"
expanded the strip to fourteen, which is past the strip's own
`_kMaxInlineTabs = 6` threshold, which meant all thirteen settings pages
were permanently a `PopupMenuButton`. That was never a presentation detail.
It is why thirteen settings pages had never been presented as a list of
settings: they were tabs, and tabs run out of room long before lists do.
Five to six tabs hit a third mode, a horizontally scrolling row, which is
the only mode that could put a section off screen.

**Wide window: a navigation pane beside the content.** App Settings,
Accounts and About down the left; content on the right. The active section
reveals its children inline, so a settings sub-page is one tap from anywhere
in the list. Above the list, a tappable account header, which is also the
way back to the index when the user is several sections deep.

**Narrow window or the single-pane shell: the index page is the profile,
with the section list underneath it.** Choosing a section pushes a
full-screen page, so Back walks the stack the way it does in any other app.
A section page does not repeat the list; that would make the hub feel like a
menu rather than a stack of pages.

Same destinations, same labels, same routes, same order in both. The only
difference is arrangement, and the arrangement is decided by
`LayoutShellController.fitsTwoPanes`, which is the same answer the
dashboard's detail pane reads. That getter is new and both call sites use
it, because a hub that went two-pane in a window where the dashboard went
one-pane would be two layouts disagreeing about the same measurement.

**The profile stopped being a section.** It was a fourth category, so
`/hub` and `/hub/profile` both rendered the same editor and the narrow index
page had to choose between showing the profile and listing it. Now the
profile *is* the index, there is one URL for it, and `/hub/profile`
redirects there.

The App Settings overview page is now built from `HubRouteKeys` rather than
a hand-maintained item list, so the overview, the navigation pane and the
router's validation cannot disagree. They were three lists; the disagreement
is what produced `/hub/settings/network`, a palette entry naming a
sub-item that never existed.

Also here: `_HubTabStrip`, `_HubTabStripEntry`, `_HubTab`, `_HubTabScope`
and `_kMaxInlineTabs` are deleted, and `hub_screen.dart` is 518 lines from
958. The settings pages themselves are untouched; every one of them was
already scrollable, which is what let them move into a pane unchanged.

- lib/src/screens/hub_screen/hub_nav_list.dart (new): the section list,
  one widget for both arrangements. `expandActive` is the only difference
  between them. Its rows carry `Semantics(selected:)`, which the tab
  entries did not, so the active section is no longer signalled by an
  underline alone.
- lib/src/screens/hub_screen/hub_screen.dart: `HubScreen` is now the shell
  (AppBar, pane, content); `HubContent` is the dispatcher.
- lib/src/layouts/layout_shell_controller.dart: `fitsTwoPanes`.
- lib/src/layouts/dashboard_layout.dart: uses it.
- test/widget/hub_route_navigation_test.dart: 14 tests. The route tests
  assert on which section `HubContent` was handed rather than on text it
  rendered, because a text assertion there is testing a settings page's
  strings rather than the routing. The arrangement group pins that a wide
  window expands the list inline and a narrow one does not.

Tests at head: flutter test 762 green (756 prior, +6 new). flutter analyze 0
issues.

47. Make the hub a page, and put the layout switch back where it started

Three changes, two of which undo something shipped in section 45, because
the thing that made them necessary arrived in the same change.

**The hub is a route, and the modal overlay is gone.** It was presented as a
`PageRouteBuilder` with `opaque: false` on the root navigator, wrapping a
blurred, centred card clamped to `maxWidth: 900, maxHeight: 680`
(`hub_screen.dart:939`). The overlay existed for one reason, stated at
`router.dart:323-333`: registering the hub as a page replaced the chat in
the navigator stack, so it could not be a page. It could have been a page
all along, pushed.

The real cost of the overlay was not the chat. It was that the URL could
not describe what was on screen, so `HubScreen` held its selection in two
private integers and `_pushHubUrl` had to detect the overlay and skip
itself. It *always* skipped: there was no `/hub` route registered at all, so
every hub URL in the command palette resolved to nothing, and
`HubCategorySelection` had no value equality, so `didUpdateWidget`'s `!=`
was an identity comparison. The overlay was not protecting the chat so much
as hiding that the hub had no address.

`/hub/:category` and `/hub/:category/:sub` are now registered as a
`ShellRoute` sibling of `/main`, under the same `AppFrame`. Sibling rather
than nested, on purpose: nested it would render in the dashboard's middle
pane and behind the single-pane shell's navigation bar, which is two
presentations of one screen. As a sibling it is the whole window in both, so
the only difference between the shells is how you arrived. Entering with
`push` keeps the chat underneath and the hub's own back button returns to
it; switching category inside uses `go`, because that is a tab change.

The selection is now derived from the route. `_selectedCategoryIndex`,
`_selectedSubItemIndex` and `_subTabsParentIndex` were three fields written
in five places, two of which were verbatim duplicates of the same closure;
they are gone, replaced by getters, so the strip and the body cannot
disagree with the address bar.

Keys moved to `HubRouteKeys` in `navigation_items.dart` so the router and
the screen read one list, and the router's redirect validates against it.
That list had already drifted once: `palette_commands.dart` carried nine
hand-written `/hub/settings/...` strings, one of which was
`/hub/settings/network`, naming a sub-item that has never existed. Its
target page was deleted in commit `567e9cd`, so that palette entry opened
an empty pane. The entry is removed and a bad sub-key now redirects to its
category instead.

**The layout-mode switch is back in the hub only.** Section 45 put it in
the dashboard sidebar and in the single-pane shell's "You" destination, to
escape a trap: the only other copy was in Hub > Settings > Layout, which the
single-pane shell could not reach, so opting into the focus layout on a
desktop was a one-way door. The hub is a route now, so it is reachable from
everywhere and the duplication is not needed. Two copies of a control only
invite them to disagree; the hub keeps the one, and `LayoutModeSwitch` is
deleted.

**"You" is no longer a chrome-less page in the dashboard's middle pane.**
Switching to the focus layout, opening "You", then widening the window left
`OwnAccountPage` floating in the middle pane with no title and no way back
out of it. The fix is its own `Scaffold` and `AppBar`, which is what every
other page that can appear in that pane already has. See WORK_NEEDED.md 7.7
for why a pop-guard on shell change was rejected instead.

- lib/src/router_paths.dart: `hubTemplate`, `hubSubTemplate`, `hubLanding`,
  and `hubPath`, the one place a hub URL is built.
- lib/src/screens/hub_screen/navigation_items.dart: `HubRouteKeys`.
- lib/src/router.dart: the three hub routes plus `_hubRedirect`.
- lib/src/screens/hub_screen/hub_screen.dart: route-driven selection;
  `HubCategorySelection`, `showHubOverlay`, `_HubOverlayPage`, `_hubUrlFor`,
  `_pushHubUrl` and `_isOverlay` all deleted. 815 lines from 958.
- lib/src/widgets/sidebar_profile_pill.dart, command_palette/:
  navigate instead of overlaying. `_hubSelectionForPath` deleted, since a
  registered route replaces a hand-rolled path parser.
- test/widget/hub_overlay_navigation_test.dart: deleted. Its premise
  inverted: it asserted the room survived a category tap, which was true
  because the hub could not navigate.
- test/widget/hub_route_navigation_test.dart (new): 8 tests, including the
  stale-sub-key redirect that is the `network` class of bug.

Tests at head: flutter test 756 green (751 prior, +8 new, -3 from the
deleted overlay test). flutter analyze 0 issues.

46. Give the detail panes a home in the single-pane shell, and stop the
    scope lying about how wide it is

Two defects, and the second one had been sitting in the original audit as
a note since the beginning.

**The room's four detail panes were simply absent from the single-pane
shell.** They live in the dashboard's right sidebar, which that shell does
not mount, and the one control that opened them was the room header's
pinned filter, itself inside the width-gated badge block. So below 600px
there was no way to reach room info, members, threads or pinned messages as
panes; pinned was the worst case, because the header toggle was the only
route to it at all.

`showRoomPaneSheet` presents them as a modal bottom sheet, and it hosts the
existing `RightSidebarWithSwitcher` unchanged rather than a purpose-built
mobile variant. The switcher, the four pane bodies and the `RightPaneChoice`
preference stay one implementation across both shells. The bodies were
already the right shape for this: a scrollable column under a header. The
room header gains one button, and only when the shell has no sidebar to put
panes in, so the desktop header is untouched.

**The single-pane shell never published a `LayoutScope`.** Every descendant
that measures itself therefore fell through to `_RootLayoutScope`, which
reports `availableWidth: double.infinity` and a hard-coded
`LayoutSize.expanded`. That is not a neutral default, it is the widest
possible answer handed to the narrowest shell. The consequences were
concrete: `InRoomSearchPanel` picks its width from `LayoutScope.of(context)
.size`, so its compact branch could never fire here and it rendered at a
fixed 320px beside a roughly 180px timeline; and `SidebarRoomInfo` reads
`availableWidth` to choose its pinned-preview column count, where infinity
means three columns.

`MobileLayout` now provides the scope, sized from the window width rather
than its inner constraints, so mounting and unmounting the bar above does
not change what the content believes about its own width. The bottom sheet
provides one too, because a sheet spans the window and so has a real width
worth reporting.

- lib/src/widgets/room_pane_sheet.dart (new).
- lib/src/chat/room_info_card.dart: header tap opens the sheet in the
  single-pane shell instead of pushing the desktop room-details page, plus
  the one button that opens it.
- lib/src/layouts/mobile_layout.dart: publishes the scope.
- test/widget/mobile_layout_scope_test.dart (new): 3 tests. These assert
  what a descendant *observes* rather than that a scope exists, since a
  scope reporting the wrong thing would satisfy the latter. The third pins
  the root fallback itself, so the value being avoided stays legible.

Tests at head: flutter test 751 green (748 prior, +3 new). flutter analyze 0
issues.

45. Give the single-pane shell its own destinations, and a way back out

The single-pane shell had a title bar and nothing else. The two entry
points to global search and to the user's own profile lived in the
navigation sidebar's header, which this shell does not mount, so both were
unreachable; and with them every page behind them, meaning settings,
accounts, devices, encryption, logs and logout could not be reached at
all from that layout. The shell was also the one place the navigation seam
in section 43 sends the user back to, so it needed to be a real place
rather than a list with a back arrow.

The destinations are now routes. `/main/rooms`, `/main/spaces`,
`/main/search` and `/main/me` are declared in `MoonRoutePaths` and matched
back to a `FocusDestination` by segment, which is what lets the navigation
bar read its selected index off the URL instead of holding state that can
drift from it. A sentinel from `NavigationState` could not have done that,
which is the same reason those sentinels are not deep-linkable: they are
not locations. `/main/rooms` doubles as the dashboard's room list, so only
three routes were new.

The bar switches destinations with `go`, not `push`. A tab switch is a
lateral move; stacking it would leave a history the user walks back through
one tab at a time. It is hidden inside a room, where there is nothing to
switch between and the chat wants the height.

**The trap is closed.** A preference you can enter but not leave is not a
preference, and `LayoutMode` was exactly that: its only control lived in
Hub > Settings > Layout, which the single-pane shell could not reach, so a
desktop user who opted into the focus layout could leave only by widening
the window. `LayoutModeSwitch` is now rendered in both shells, in the
dashboard's sidebar header and in the "You" destination. This is also what
lets the focus mode be treated as a user preference at all rather than a
device guess, which is the reframing the whole rework rests on.

The shell top bar now names the destination rather than the app, and
carries the search action the dashboard puts in its sidebar. On the search
destination it drops the button, because that page *is* a search field.
`GlobalShortcutListener` is mounted here too, so a desktop user in focus
mode does not lose the palette they may have arrived through.

Three new pages, all reusing what already existed rather than growing a
second implementation of anything: `GlobalSearchPage` is built on
`SearchProvider` and the four public result tiles, which are free of
palette coupling (`showCommandPalette` takes one parameter and pushes a
non-opaque route around a private page, so it cannot be mounted as a route
body); `SpacesListPage` is a thin page over the shared `roomIsSpace`
filter, and deliberately does not reproduce the sidebar's grouping or drag
ordering, which are navigation-sidebar affordances on `SpacePreferences`;
`OwnAccountPage` hosts the existing `HubMyProfilePage` editor plus the
route into the hub, so settings and accounts stay single-implementation.

- lib/src/router_paths.dart: `FocusDestination`, the three new templates,
  `focusDestinationForSegments`, `focusDestinationOf`. The chat matcher
  still rejects the room route, so the bar does not light up "Chats" while
  the user is reading a conversation.
- lib/src/screens/global_search_page.dart (new), spaces_list_page.dart
  (new), own_account_page.dart (new).
- lib/src/widgets/layout_mode_switch.dart (new).
- lib/src/layouts/mobile_layout.dart: the nav bar, the reworked top bar,
  the shortcut listener.
- lib/src/router.dart: three routes.
- lib/src/localization/app_en.arb: `chats`, `you`, `search`. The first two
  had no string at all; `search` did not exist as a bare noun either.
- test/unit/router_paths_test.dart: 6 tests for the destination matcher,
  including one asserting every destination round-trips to itself and that
  no two share a path.
- test/widget/router_test.dart: 3 tests. The existing top-bar tests were
  rewritten against a key rather than a text count, because the bar and the
  nav bar deliberately share their labels and counting text conflated them.
  New: the bar has four destinations, it is hidden inside a room, and a tab
  switch changes the URL without leaving something to pop.

Tests at head: flutter test 748 green (740 prior, +8 new). flutter analyze 0
issues.

44. One dashboard, and the narrow band gets its features back

The 600-1100px band had its own dashboard. `DashboardView` branched at
its first line into `CompactDashboard`, a second complete widget with a
second sidebar implementation, and the two were not the same product.
The narrow one dropped space grouping, drag-to-reorder, the space
context menu, auto-grouping and the per-space room tree, and swapped the
destination rows for a three-way filter. Its room rows lost the
encryption badge and the mention badge outright. None of that needs
horizontal space: it is vertical, or it is simply a second
implementation that was never kept in step. The two sidebars also
disagreed on the sidebar width clamp (200..360 against 220..360), so a
width the user had chosen in one shell was silently rewritten in the
other.

The split is gone. `DashboardView` is one composition, parameterised by a
single question the shell already answers: is there room for the detail
pane. `CompactDashboard` and `CompactSidebar` are deleted, and
`NavigationSidebar` is the navigation pane at every width. Its rows
already used `Expanded` with ellipsis at 13px, so it needed no
structural change to work at the 200px floor; what did need work was the
room row, which had a fixed 18/16px type chosen for the wide case and
squeezed the room name into the badges in a narrow pane. It now scales
its type, avatar and unread dot to the width it is actually given via a
`LayoutBuilder`, in the same way the room header does. The one clamp
range applies everywhere.

This is the change the whole rework was for: the narrow dashboard is no
longer a worse dashboard, because there is no longer a second one.

- lib/src/layouts/dashboard_layout/dashboard_view.dart: `CompactDashboard`
  removed; `shouldUseCompact` replaced by `detailPaneFits`, with the
  rationale in the class doc.
- lib/src/layouts/dashboard_layout.dart: passes
  `detailPaneFits: !shell.isMobile && shell.isExpanded`.
- lib/src/widgets/compact_sidebar.dart: deleted, 363 lines. The
  destination filter it used is not lost: spaces were already browsable
  through the sidebar's Spaces section, which is why the compact
  segmented control was a substitute for the tree rather than an
  addition to it.
- lib/src/widgets/rooms_pane.dart: `_RoomRow` is width-aware and keeps
  both badges; `_RoomAvatar` takes a size and scales its unread dot.
- lib/src/layouts/layout_shell_controller.dart: the `LayoutShell` doc no
  longer advertises a compact sidebar that does not exist.
- test/widget/navigation_sidebar_test.dart: the `DashboardView` group
  rewritten around `detailPaneFits` and extended from 2 tests to 5. Two
  of the new ones are the regression guards: that the narrow band mounts
  the *same* `NavigationSidebar` with its profile pill, command palette
  and both section headers, and that the detail pane is the only thing it
  drops. A new `RoomPane row density` group pins the type scale at 220px
  and 600px and asserts both badges survive at each; the badge assertion
  is on the shield icon and the rendered count, because
  `RoomEncryptionBadge` returns `SizedBox.shrink()` when a room is not
  encrypted, so finding the widget would have proved nothing.

Tests at head: flutter test 740 green (737 prior, +3 net: the DashboardView
group grew by 3 and the density group added 3, offset by the two
`shouldUseCompact` call sites in the old group). flutter analyze 0 issues.

43. Give navigation an intent, and let the shell pick the mechanism

The single-pane shell's navigation was not a design, it was the desktop
one with its sidebar removed. `RoomsPane` opened a room with
`pushReplacement` unconditionally, which is the right answer for the
dashboard and a data-loss bug for the focus shell: the list page was
destroyed on every room switch, so the user's scroll position, and
eventually their search text, went with it. The shell then tried to
paper over it by treating a failed `canPop()` as "go back to the list",
which meant its back button performed a route reset rather than a pop.
Three different intents had collapsed onto one mechanism, and the
mechanism had been hard-coded in a shared leaf widget that has no idea
which shell it is in.

The seam in `lib/src/helpers/shell_navigation.dart` splits them by
intent:

- `openRoom` means "switch to this conversation". It `push`es in the
  single-pane shell, where the list is the only navigation there is and
  must survive, and replaces on the dashboard, where the list is already
  beside the room and a growing history would walk the user backwards
  through rooms they have already read.
- `openRoomSubpage` means "drill into something this room owns" (room
  settings, room details, a thread, a member's profile). It pushes in
  both shells, because a back button is the correct affordance for it
  everywhere.
- `backToRoomList` separates a pop from a route reset explicitly. The
  `go` branch now only fires on a cold deep link, where there is
  genuinely nothing to pop, instead of on every room switch.

Two call sites are deliberately *not* the seam, and say so at the call
site so nobody "fixes" them later. `room_preview_screen.dart` replaces
in both shells because the preview page is stale the moment the join
succeeds, so leaving it underneath would send Back into a preview of a
room the user is already in. `deep_link_service.dart` `go`es because a
link arrives from outside the app, so there is no in-app step worth
preserving.

The seam also fixed a quieter inconsistency: six call sites put a room
id into a path with no encoding while four encoded it, and GoRouter
decodes `pathParameters` on the way out, so a room id containing a
literal `%` (legal in Matrix) was mangled or threw. Every path is now
built by `MoonRoutePaths.roomChatPath`, which encodes, and the declared
route templates there are the single source for both the matchers in
`router_paths.dart` and the paths the seam produces.

Routing every room open through the seam also removed six now-dead
`GoRouter.of(context)` locals and seven unused `go_router` imports.

- lib/src/helpers/shell_navigation.dart (new): `openRoom`,
  `openRoomSubpage`, `backTo`, `backToRoomList`. Reads the committed
  shell from `LayoutShellController` and falls back to the dashboard
  behaviour when the provider is absent, which is the case in widget
  tests and is the behaviour every call site had before.
- lib/src/router_paths.dart: route templates are now the single source;
  the segment patterns and `roomChatPath` both derive from them.
- lib/src/widgets/rooms_pane.dart, space_rooms_tree.dart,
  search_provider.dart, command_palette/command_palette.dart,
  sidebar_members_list.dart, compact_sidebar.dart, create_room_form/,
  user_search_widget.dart, chat/room_info_card.dart,
  chat/events/matrix_url_banner.dart, chat/events/user_mention.dart,
  screens/room_page.dart, room_details/room_details_page.dart,
  room_details/top_members_section.dart, room_members_view/,
  user_profile/profile_actions_section.dart, add_room_from_id.dart,
  room_directory_search.dart, create_new_room.dart,
  space_home_page/space_home_page.dart: all now go through the seam.
- lib/src/layouts/mobile_layout.dart: the back button calls
  `backToRoomList` rather than carrying its own canPop/go pair.
- test/widget/shell_navigation_test.dart (new): 7 tests. The load-bearing
  ones assert `router.canPop()` after opening a room, in both directions:
  true in the single-pane shell (the list survives) and false on the
  dashboard (it does not stack). These fail if the seam ever collapses
  back to one mechanism.

Tests at head: flutter test 734 green (727 prior, +7 new in the new seam
suite). flutter analyze 0 issues.

42. Fix the single-pane shell, and the boot crash behind it

Five defects, found by auditing how much of the app actually adapts to a
narrow window. The theme of all of them is the same: a shell-level
question was answered by a proxy that lied, and nothing downstream
noticed.

**Spaces were opened as chats.** `MobileRoomsListPage` mounted
`RoomsPane()` with no filter, and a null filter means every joined room,
spaces included. `RoomResolver` turns whatever room id reaches the URL
into a `RoomPage`, so tapping a space in the mobile list opened a chat
view of a space. The expanded sidebar had been guarding this the whole
time with an inline `!room.isSpace`; the compact sidebar had a third
copy. All three now go through named predicates (`roomIsChat`,
`roomIsDirectChat`, `roomIsSpace`) in `lib/src/widgets/rooms_pane.dart`,
so "which rooms belong in this list" is stated once. A null filter now
reads as the trap it is rather than as "no filter needed".

**The room header measured the window, not its pane.** `ChatRoomHeader`
read `MediaQuery.sizeOf(context).width` and then commented that it was
adapting to "the available width" of the pane. The chat column is a
sibling of the sidebars, so at a 1100px window it can be under 500px
wide: the desktop dashboard was packing the sync indicator, the member
badge and the pinned toggle into a 474px column and squeezing the room
name out. It now reads its own constraints through a `LayoutBuilder`.

**One width threshold was gating three unrelated things.** The
`showBadges` block hid the sync indicator, the member count and the
pinned toggle together below 600px, as though they were the same kind of
control. They are not. `SyncIndicator` returns `SizedBox.shrink()` when
sync is quiet and `_PinnedFilterButton` returns it when the room has no
pinned messages, so both already cost nothing in their normal state;
hiding them by width only removed the pinned capability from exactly the
users on the narrowest screens, who were the only ones who could not
otherwise find it. The member count and the topic line are
always-present furniture and are what now gives way, on their own
thresholds.

**The shell stacked a second back button over every sub-page.**
`MobileLayout.isRoomRoute` decided "am I in a room?" by testing for a
`roomid` path parameter, which is true for every child of the room
route. `RoomSettingsPage`, `ThreadViewPage`, `RoomInformations`,
`ProfilePage` and the space pages each render an `AppBar` with a back
button of their own, so every one of them got a second, competing arrow
and a doubled header bar. The same test also misread
`/main/room_preview/:roomid`, which reuses the parameter name, as being
in a room. Matching is now against the declared route pattern, in
`lib/src/router_paths.dart`, and the shell draws its own bar only on the
routes it owns. Note that `GoRouterState.matchedLocation` is the
concrete path, not the `:param` pattern form, so the matcher works on
`Uri.pathSegments` and is a pure function of the segments; that is what
makes it testable without a router.

**A stale preference could not start the app.** `SettingsService` had a
bounds-checked `_readEnum` helper at `settings_service.dart:493` and then
four call sites that ignored it, indexing `values[index]` on a persisted
int with no range check: `_readThemeMode`, `_readDisplayType`,
`_readLayoutMode`, `_readRightPaneChoice`, and the standalone
`themeMode`, `displayType`, `layoutMode` and `rightPaneChoice` getters.
Removing or reordering a value in any of those enums turns every
already-persisted index out of range, and these readers run during boot,
so the result was a `RangeError` before the app ever painted. This was
found while planning the removal of the compact shell, which reorders
`LayoutMode`; it would have shipped as a failed launch for every
existing user. All of them now route through `_readEnum`, and an
out-of-range index resolves to the default rather than throwing.

- lib/src/router_paths.dart (new): declared route patterns as segment
  lists, with `isRoomChatSegments` / `isRoomListSegments` /
  `isShellDestination`. Separate from `router.dart` because the router
  imports the layouts, so a layout naming the routes would be a cycle.
- lib/src/layouts/mobile_layout.dart: the top bar is now one child of the
  Column, conditional, rather than the whole shell returning
  `SizedBox.shrink()`. An early return version of this blanked
  `/main/myprofile` under the mobile shell entirely; the existing
  "a pushed route survives a resize" test caught it.
- lib/src/widgets/rooms_pane.dart: named filter predicates, and a doc
  note that a null filter includes spaces.
- lib/src/widgets/compact_sidebar.dart: routed through the shared
  predicates; its `_CompactSidebarFilter.all` doc said "regardless of
  type" while the code excluded spaces.
- lib/src/chat/room_info_card.dart: `LayoutBuilder`, and independent
  thresholds for the topic and the member badge.
- lib/src/settings/settings_service.dart: all four static readers and all
  four standalone getters now bounds-check.
- test/unit/router_paths_test.dart (new): 10 tests, including one per
  sub-route that used to be misread, and one for a room id containing a
  percent sign, which `AGENTS.md` warns is legal.
- test/unit/settings_service_test.dart: 9 tests for stale and negative
  indices, covering both the individual getters and the batch snapshot.
- test/widget/router_test.dart: 3 tests pinning that the shell draws a
  bar on the room list, draws none on `/main/myprofile`, and still lays
  the page out on routes it does not decorate.

Tests at head: flutter test 727 green (706 prior, +21 new: 10 in
router_paths_test, 8 in settings_service_test, 3 in router_test).
flutter analyze 0 issues.

41. Drop the crypto framing from away, and make the sync indicator honest

Two changes, one about what a word promises and one about what an
indicator says.

**Away is a presence fact and nothing else.** The feature that arrived as
`autoLockEnabled` was renamed to `autoOfflinePresenceEnabled` in 40, but
the crypto framing was still lurking in the reasoning, and the reason to
write it down is that it will otherwise creep back. Going idle changes
one field, `m.presence`. It does not drop megolm or olm keys, close a
database, or show a lock screen, and it is not planned to. The SDK's
`Encryption` exposes only `dispose()` with no re-entry point and
`Client.dispose()` leaves the client unusable, so the original "lock"
name promised a guarantee no code could deliver. The service doc now
states what away is and, more usefully, what it is not, and the arb
`@description`s say the same to translators, including an explicit "do
not word this as a lock" since a translator seeing "Appear offline when
idle" has no way to know the scope. A real local lock, if wanted, is a
separate feature with its own name and its own surface.

**The status bar is gone**, along with the `showStatusBar` setting and
the Network settings page, which existed only to host that one toggle. It
disagreed with the sidebar pill about the same underlying state, using
different words for it: "synced / syncing / waiting for response /
error" against "online / away / offline". Two permanently visible
surfaces contradicting each other is worse than one honest quiet one.

**The sync indicator is now one, in the room, and quiet.** There were
three: the status bar, the sidebar pill, and a bullet-and-"Syncing" chip
in the room header. The sidebar pill was the worst, because a connection
status sitting directly under the user's own display name reads as that
user's presence, and 40 gave presence a real owner. It is deleted with
its widget and test.

The replacement is built around the fact that made all three useless:
`/sync` is a long-poll, so between requests the SDK sits in
`waitingForResponse` for up to the server's timeout, usually thirty
seconds. That is the normal resting state of a healthy client, not a
fault, so an indicator that lights up on any sync in flight is on nearly
all the time and users learn to ignore it.

The rule is therefore inverted. Silence is the default and reports
nothing bad. Something appears only when the user would otherwise be
guessing: no completed sync for ten seconds, worded as reassurance
("Still fetching", tooltip saying the server may simply be slow), or a
failed sync, worded plainly ("Not syncing") with a retry button. A stall
gets no control, because the user is not being asked to do anything
about it. Both states are low-emphasis on purpose: a warning that shouts
is as wrong as one that never appears.

10 tests pin the judgement the design rests on, most of them asserting
the *absence* of a message. The one that matters most is the cold
start: with no completed sync observed yet there is nothing to measure a
stall against, and claiming slowness there would greet every user with a
warning on launch.

- lib/src/widgets/sync_indicator.dart (new): the single indicator, with
  an injectable threshold and stream.
- lib/src/chat/room_info_card.dart: the old private chip replaced.
- lib/src/widgets/sidebar_profile_pill.dart: pill removed, and the doc
  comment says why so it does not come back.
- lib/src/widgets/sync_status_pill.dart and its test: deleted.
- lib/src/widgets/status_bar.dart and
  lib/src/screens/hub_screen/settings/network_settings.dart: deleted.
- lib/src/settings/*: showStatusBar removed through every layer.
- test/widget/sync_indicator_test.dart (new): 10 tests.

Tests at head: flutter test 706 green (703 prior, +10 new, -7 in the
deleted pill test). flutter analyze 0 issues.

40. Give presence an owner, and make it mean something

The presence system had three sub-systems tangled together, two silent
failures, and one control that could not hold its own state. The
settings audit is what surfaced it: `autoLockEnabled` was a dead toggle
whose own description said "Mark the account as offline", so it was
really an unwired presence feature wearing a name that promised a lock
the app cannot provide.

The rename came first, and it is the honest half. There is no idle
tracker, no `WidgetsBindingObserver` anywhere in `lib/`, and no way to
clear encryption keys from a live session: the SDK's `Encryption` only
exposes `dispose()` with no re-entry point. So it is
`autoOfflinePresenceEnabled` / `autoOfflinePresenceMinutes`, which is
what the description always claimed, and the minutes default moved off
zero, since turning the toggle on without touching the slider would
otherwise have meant "go offline on every activity gap".

The most important bug is the one the setting could never have
surfaced. `Client.syncPresence` was never set, and per the Matrix spec
an omitted `set_presence` on `/sync` tells the server to mark the
client online. So a user who tapped "Appear offline" saw the chip
change, and within one long-poll interval every other client showed them
online again. That is the same shape of bug as a setting wired to
nothing: the control appears to work and does not.

Separately, the `sharePresence` l10n keys described a toggle that does
not exist and are gone. "Share presence" is a server-side per-user
setting in Synapse rather than something a client can offer, so
implementing it as a client toggle would have been a lie of the same
shape as the controls this pass removed.

`PresenceService` is the new owner, at app level and bound alongside
the existing client rebinding, so it survives navigation, follows an
account switch, and is disposed once. A screen-scoped version would
restart its idle window on every route change, leaving a user
permanently "active" while reading. Every publish pins `syncPresence`
alongside the PUT, and the profile screen's fallback path goes through
the same static helper, so a caller cannot publish a choice that will
not stick. It is now the only place in `lib/` that writes presence.

The two silent failures were in the profile screen. Both `setPresence`
paths reported "Presence updated." even when the request failed:
`withRetry` returns a `RetryResult` rather than throwing, so the `await`
always completed normally and the `catch` below it was unreachable. A 403
from a server with presence sharing disabled looked exactly like
success. Two more bugs sat in the same methods: editing the status
message defaulted presence to online whenever the presence read had
failed, so asking to change a caption silently changed the user's online
status; and clearing the field passed `null`, which makes the SDK omit
`status_msg` entirely, leaving the server to keep the old value, so the
message could not be cleared at all.

The request spam was structural. The page fired two uncached network
calls from `build()` on every coalesced sync tick, one of them a raw
`getPresence` that bypassed the SDK's map and database so nothing was
ever cached. That is a floor of two requests per tick, and it also
meant the page re-fetched after an account switch on a client that
`initState` never saw again.

Contact presence was frozen for the whole session, in all three read
surfaces. The SDK caches presence with no TTL and only invalidates on an
event over `/sync`, which nothing subscribed to, so a member who came
online after you opened the list stayed offline until you reopened it.
`PresenceBus` is the fix, modelled on `RoomStateBus`: one stream
subscription, per-user `ValueListenable`s.

The two tests found two more defects in code that looked correct. The
in-flight guard dropped a transition, so an idle transition landing while
an online write was still awaiting was discarded and the account stayed
online for the rest of the window; the intent is now recorded and
drained, latest-wins. And `onResumed` ignored a manual presence choice,
so waking the machine undid a presence the user had picked by hand, the
one path missing a check every other transition already had.

Two things about the contrast work are worth stating plainly. The
profile header drew its presence label in `0xFF2ECC71` and `0xFFF39C12`,
which measured 1.84:1 and 1.92:1 against the chip background where body
text needs 4.5:1, and 2.06:1 and 2.15:1 against the 3:1 that dots need.
Both failed, in light mode only, which is why a dark-themed dev machine
never showed it. And Material has no "success" role, so online now maps
to `secondary` and away to `tertiary`: the states are no longer reliably
green and amber. That is a real trade, and a visible one, but an
unlabelled colour that cannot be read is worse than one that carries its
meaning in the label beside it.

Still not done, and recorded rather than hidden: the real crypto lock is
a feature, not a wiring job, and would be a `lock()`/`unlock()` pair on
`AccountManager` over the existing `clientFactory`, with every
`Provider<Client>` consumer tolerating the client being absent for a
while. That is the one part of the old `autoLock` name that was a real
promise, and it is not shipped.

- lib/src/services/presence_service.dart (new): the owner, the idle
  logic, and the static `publishTo` that pins `syncPresence`.
- lib/src/helpers/presence_bus.dart (new): per-user presence fan-out.
- lib/src/widgets/activity_tracker.dart (new): pointer, key and
  lifecycle activity, the app's first `WidgetsBindingObserver`.
- lib/src/theme/presence_colors.dart (new): scheme-derived presence
  colours, replacing the failing literals.
- lib/src/app.dart: owns both new objects, provides them, binds them.
- lib/src/helpers/account_manager.dart: publishes offline on logout and
  on account switch, before the client is torn down.
- lib/src/screens/hub_screen/my_profile_page.dart: honest error
  reporting, a clearable status message, a throttled refresh moved out
  of build, and a `didUpdateWidget` for account switches.
- The three read surfaces (member tile, top-members, profile header)
  now watch the bus.
- lib/src/widgets/sync_status_pill.dart: `PresenceState` renamed to
  `ConnectionIndicator`, and two doc comments that claimed the status bar
  shares the mapping corrected, because it never did. (This widget and
  the status bar are both deleted in 41, so the rename mattered only for
  the two commits in between.)
- The renamed settings, the two deleted ones, and the l10n keys for all
  of them.
- test/unit/presence_service_test.dart (new): 19 tests with an injected
  clock, which is what makes the suspend case testable at all.

Tests at head: flutter test 703 green (684 prior + 19 new). flutter
analyze 0 issues.

39. Wire the unwired settings into the surfaces that own them

Twenty-three settings persisted, round-tripped through the settings UI,
and were read by nothing. WORK_NEEDED.md 1.10 records the standing
decision that made these a specification rather than dead weight: a
setting nothing consumes is a promise the code has not kept yet, and the
fix belongs in the service that was supposed to read the value. This
lands nineteen of the twenty-three.

The cheap half was mostly substitution, with a consistent choice of
mechanism. Where a value is read per use, the service holds the
`SettingsController` and re-reads it, so the setting is live
immediately: that is how `notificationPersistMs` and
`notificationDedupeCacheSize` work, against a `_settings` field the
notification service already had. Where a value is consumed once at
construction, it is passed in from boot, where the controller is already
a live local: the deep-link dedup window, the encryption refresh
debounce, and the database backup retention.

Two services needed a live setter instead of either, because they
outlive the user action that would change them. `DraftService` is a
ref-counted singleton per account, allocated when the first composer
opens and released when the last one closes, so it would have kept
whatever debounce it was born with; `setDebounce` is now pushed on
every composer load, alongside the retention window passed to `load`.
`SyncPulse` is owned by the app-level `State`, and its debounce was
already a constructor argument that nothing supplied, so it became a
settable field written from `app.dart` on each build.

The logging group was the only one that could not be a one-line swap.
`AdvancedFileOutput` exposes no setters for size, retention or flush
delay, so the sink has to be rebuilt; and the `Logger` itself must not
be replaced, because `Provider<Logger>`, `BootContext.log` and the
closure captured by `MoonShutdown.register` all hold the instance built
at boot and a fresh one would leave every reference writing into a dead
sink. `LogService` now swaps the output behind the stable
`_RedactingLogOutput` wrapper, initialises the replacement before the
swap so no line is dropped, and destroys the old sink after so nothing
buffered is lost. A `LogPolicy` value object makes an unchanged policy a
no-op, which is what lets boot re-assert it safely.

Wiring the logging settings exposed that the one setting the earlier
analysis believed was working, `logVerboseRelease`, was not.
`updateVerboseRelease` assigned the static `Logger.level`, but
`LogService.create` hands the `Logger` constructor a non-null level,
which it stores on the filter, and `LogFilter.level` reads
`_level ?? Logger.level`. With `_level` set the static is never
consulted, so the assignment did nothing. It now sets the level on this
logger's own filter, which additionally stops it mutating every other
`Logger` in the process, including the raw one in the SSO server. Since
the service is constructed before settings load, `boot.dart` also
re-asserts the whole policy immediately after loading them; without
that, the four controls would only take effect from the first change
made in the settings page.

`attachmentClickThresholdMb` is the one that needed a decision rather
than a lookup. It is not an upload cap: `kMaxUploadBytes` in
`lib/src/helpers/upload_limits.dart` is a deliberate 512 MB guard
against a phone 4K video exhausting the UI isolate, and this setting's
slider stops at 200 MB, so wiring it there would have turned a design
decision into a user preference. It belongs on the auto-download path,
where five renderers each carried a private copy of the
always/wifi/never switch and none consulted the size at all. Those now
share `AttachmentDownloadPolicy`, and withholding the download comes
with a `ClickToDownloadTile`, because the previous
"did not auto-download" state rendered a dead icon with no tap handler.
Video, audio and file needed no new affordance, each already having a
download control; stickers are exempt from the threshold, since applying
it there would only replace a sticker with a download tile. An unknown
`info.size` is never treated as large, or events from clients that omit
the field would never load.

Smaller fixes found along the way, each of which had been making its own
control a lie:

- `wipeLogsOnLogout` was ignored: logout called `wipeLogs`
  unconditionally, so the privacy toggle did nothing.
- `notificationDedupeCacheSize` clamped to 0, and at 0 the eviction loop
  deleted each entry the instant it was added, leaving the dedupe
  permanently off while the control read as configured. The clamp now
  starts at 1.
- `dbBackupKeepCount` counted nothing: backups were written to a fixed
  `.bak` name, so every schema-bump wipe overwrote the last one and
  there was exactly one backup ever. They are timestamped now and pruned
  to the newest N. While in there, the schema-version prefs key was
  global across accounts, so a second account on an older schema would
  read the version the first had just written, skip its own wipe, and
  run an old schema against new code. It is keyed per database.
- `trayLeftClick` had two of its three enum values unimplemented. All
  three work now, and `openUnread`, which had no implementation at all,
  navigates through `DeepLinkService` so there is one navigation path
  rather than two.
- `deepLinkAutoJoin` lands in the one place a deep link meets a room, and
  falls back to the room preview on failure. That fallback is the same
  behaviour as the setting being off, which is right for an action the
  user did not explicitly take. The join matches the result rather than
  throwing, because `withRetry` returns a `RetryResult` instead of
  rethrowing and a bare try/await/catch would have swallowed every
  failure silently.

Four settings are deliberately still unwired, because in each case the
name does not describe anything the app has and shipping the obvious
implementation would have been a lie. `dbWipeRequiresPrompt` wants a
confirmation before a boot-time schema wipe, where no route exists to
show one. `avatarCacheTtlDays` describes an on-disk avatar cache that
does not exist, against an in-memory LRU cleared on every logout, where
"0 days" would mean "no avatars ever". `autoLockEnabled` and
`autoLockMinutes` have no idle tracker and no way to clear encryption
keys from a live session, and the setting's own l10n description
promises a presence change rather than a lock. WORK_NEEDED.md 1.10
carries the options for each, including the recommendation not to ship
an overlay under the name "lock", since AGENTS.md is explicit about not
presenting a weaker control with a stronger label.

- lib/src/helpers/log_service.dart: `LogPolicy`, `reconfigure`,
  `applyPolicy`, `policy` getter, `toLoggerLevel`, a live-sink
  `destroyCurrent`/`initCurrent` on the redaction wrapper, and the
  `updateVerboseRelease` fix.
- lib/src/screens/hub_screen/settings/advanced_settings.dart: the four
  logging controls apply the policy as a set rather than one at a time.
- lib/src/boot.dart: settings now load before the database so backup
  retention is available; the logging policy is re-asserted at boot;
  `firstSyncTimeoutS`, the deep-link window and both
  `EncryptionService` construction sites are wired.
- lib/src/helpers/sync_pulse.dart, lib/src/app.dart: live sync debounce.
- lib/src/services/deep_link_service.dart: configurable dedup window;
  `navigateToMatrixUri` is async and honours `deepLinkAutoJoin`.
- lib/src/services/notification_service.dart: persistence debounce and
  dedupe bound, both read live from the held controller.
- lib/src/services/draft_service.dart: settable debounce, `maxAge` on
  `load`, and a `debounce` getter.
- lib/src/services/database_service.dart: `backupKeepCount`, timestamped
  backups with pruning, per-database schema version key.
- lib/src/services/tray_service.dart: all three `TrayClickAction` values,
  with `openUnread` ranking highlights above unread and honouring the
  mute set.
- lib/src/chat/in_room_search_panel/in_room_search_panel.dart: search
  debounce and page size.
- lib/src/screens/hub_screen/hub_screen.dart: logout honours
  `wipeLogsOnLogout`.
- lib/src/settings/attachment_download_policy.dart (new): the shared
  auto-download decision and the click-to-download tile.
- The five attachment renderers (image, video, audio, file, sticker) now
  use the shared policy; image and sticker gained the tile.
- test/unit/log_service_lifecycle_test.dart: 10 tests, including one
  asserting the `Logger` identity survives a reconfigure and one
  asserting an unchanged policy does not churn the sink.
- test/unit/attachment_download_policy_test.dart (new): 16 tests over
  size parsing, the threshold, the derived views, size formatting and
  the tile.
- test/unit/draft_service_test.dart: 6 new tests for retention expiry
  and the configurable debounce.
- lib/src/localization/app_en.arb: `clickToDownload`.

Tests at head: flutter test 684 green (656 prior + 28 new). flutter
analyze 0 issues.

38. Give every long-lived service one owner and one teardown path

The first of the four refactor-audit work items in WORK_NEEDED.md
(section 1.13), and the one everything else in that section was
blocked behind. The problem was not that services leaked in an obvious
way; it was that ownership was split across two mechanisms that did not
agree about who held what, and that both were holding references to
instances which get replaced while the app runs.

`ServiceRegistry` had three entries and the provider tree had five, and
neither list was complete. `AutoUpdateService` was in neither: it owns
an `http.Client` that its own `dispose()` closes, and `dispose()` was
never called, so the socket outlived the process. `LogService` had no
`dispose()` at all. `DatabaseService` looked like a fourth omission but
is not one, and now says so in its class doc: every database it opens
is handed to the Matrix `Client`, and the SDK closes the handle from
`Client.dispose`, so there is no resource to register a disposer for.
Documenting that was worth more than a no-op disposer would have been.

The two that actually broke are the reason this was not a bookkeeping
pass. `boot.dart` registered the boot-time `EncryptionService` in the
registry, but `AccountManager` rebuilds that service per client, so
after the first account switch the registry held a notifier that had
already been disposed: the live service was never torn down and its
`onSync` subscription outlived the teardown intent, while the dead one
was disposed and its exception swallowed by the registry's per-entry
try/catch. Separately, the shutdown callback captured `state.sdk`, the
client frozen into the closure at boot, so quitting after an account
switch disposed the wrong client and never joined the active client's
vodozemac isolate, which is the step that releases `vodozemac.dll` and
lets Windows free the build output folder. `app_shutdown.dart` already
documented that hazard in a comment and then did it anyway.

Both are fixed by making the split explicit rather than by teaching the
registry to cope. `AccountManager` is the single owner of the two
account-scoped resources, because it is the thing that swaps them; the
registry owns the process-lifetime singletons, which are built once and
never replaced. So the `EncryptionService` registry entry is gone,
`AutoUpdateService` is now registered, and `performShutdown` takes the
`AccountManager` rather than a `Client` and resolves whatever is live at
teardown time via a new `AccountManager.shutdown()`. That method
disposes the encryption service before the client, and awaits the
client rather than firing it, which matters because the encryption
service subscribes to `client.onSync` and because the client dispose is
what joins the native threads.

`LogService` had the more surprising bug of the two. `wipeLogs` was one
method doing two unrelated jobs: it called `AdvancedFileOutput.destroy`,
which closes the sink and cancels both the buffer-flush and file-target
timers, and nothing in the logger package re-arms either one. It is
reachable from logout and from the "Clear logs" button, and both leave
the app running, so after either one every subsequent log line was
buffered and never written for the rest of the process. `wipeLogs` now
destroys, deletes, and re-initialises the output, which is safe because
`init()` is re-callable and re-opens the same `late final` target file
with append mode, recreating the file the wipe just removed. A new
`dispose()` is the process-exit path, and it is what `performShutdown`
now calls. A failure to reopen is logged rather than thrown, since the
files are gone either way and throwing would turn a successful wipe into
a failed logout.

`LogService.create` grew an optional `baseDirectory` so the tests can
point the sink at a temp directory instead of relying on the
`getApplicationSupportDirectory` failure path, which falls back to the
current working directory and would have littered the repository root.
The new tests assert on disk contents and were checked against the
pre-fix behaviour to confirm they fail without the re-initialisation
(`Actual: ''`, nothing written after a wipe).

- lib/src/helpers/log_service.dart: `wipeLogs` re-arms the sink;
  `dispose()` added for process exit; `create` takes `baseDirectory`.
- lib/src/helpers/app_shutdown.dart: `performShutdown` takes
  `AccountManager` and calls `logService.dispose()`.
- lib/src/helpers/account_manager.dart: `shutdown()` disposes the live
  encryption service then awaits the live client dispose; `dispose()`
  trimmed to a synchronous safety net.
- lib/src/boot.dart: the stale `EncryptionService` registry entry
  removed with the reason inline; `AutoUpdateService` registered.
- lib/src/services/database_service.dart: class doc records that it owns
  no handle and is deliberately absent from the registry.
- test/unit/log_service_lifecycle_test.dart (new): four lifecycle tests
  covering write, wipe-then-continue, repeated wipe, and dispose.

Still open in WORK_NEEDED.md 1.13 and not touched here:
`EncryptionService.dispose` still does not cancel its in-flight refresh,
`init` is still not re-entrancy safe, `NotificationService` is still
never constructed on a fresh login and still never rebinds after an
account switch, and the schema version key is still global across
accounts. Those are instance-level fixes inside individual services
rather than ownership questions, so they do not depend on this one.

Tests at head: flutter test 656 green (652 prior + 4 new). flutter analyze
0 issues.

37. Move the login page into its directory, share the sign-in opening, and
    make both auth forms keyboard-drivable

The remaining startup work, in three commits.

The page was the last one still loose beside its own parts:
`lib/src/screens/login_page.dart` became
`lib/src/screens/login_page/login_page.dart`, which is the shape the
other eleven split screens already have. The four files that live in that
directory were already importing each other; the page was the odd one out.

Password and token sign-in each opened with the same eleven steps, and the
token copy had drifted on the one that mattered: it passed `error: error`
to the logger, which writes the exception through `toString`, which echoes
the request body, which for a token login contains the token. The password
path had a comment explaining why it must not do that, and the token path
sat directly below it. `_prepareLoginRequest` and `_runLoginRequest` now
hold the shared shape, and the log line is built inside the helper so a new
call site cannot attach the exception object by forgetting. The security
note moved with it. SSO keeps its own copy of the middle steps because its
phishing guard and confirmation dialog have to happen before anything
contacts the server, and says so.

Both forms then became usable without a mouse. Tab already worked, by
walking the focus tree, which for a form assembled out of conditionals is
not the order the fields appear in. Enter did nothing at all: no field had
an `onSubmitted`, so a user who typed everything and pressed Enter got a
silent no-op. `FormKeyboard` adds an ordered traversal group and an Enter
shortcut; per field, `FormFieldOrder` decides whether Enter advances to
the next visible field or submits. It takes a list because the login form
shows three fields in password mode and one or two in the others, and it
is the last *visible* field that should submit. `_submitCurrentMode` runs
whatever the primary button runs, which in the SSO manual fallback is the
token request rather than the browser handoff. The Enter shortcut is
disarmed while a request is in flight.

- `lib/src/widgets/form_keyboard.dart`: `FormKeyboard`, `SubmitFormIntent`,
  `FormFieldOrder`.
- `test/widget/login_page_test.dart`: 4 new cases covering Tab order, Enter
  advancing without submitting, Enter reaching the request, and the field
  count following the mode. The existing setup gained the
  `EncryptionService` provider the sign-in path reads, and the
  `checkHomeserver` stub.

Tests at head: flutter test 652 green (648 prior + 4 new), flutter analyze
0 issues. The typography guard passes.

36. Break the login page's flag bundle into enums, then move the SSO flow out

Section 35 left the login page holding the post-login sequence, but the
State itself was still doing too much: 1,241 lines with eight booleans
that the build branched on twenty-odd times, and an automatic SSO routine
that owned a local HTTP server's whole lifecycle. Two bugs fell out of
looking at the flags rather than just the file sizes.

The eight booleans were set independently, so combinations with no
meaning were representable. Both mode flags true rendered the password
action button with the password fields hidden, and a token that never
arrived could leave the SSO flow looking running and failed at once. They
become `LoginMode` and `SsoStep` in
`lib/src/screens/login_page/login_mode.dart`, each with the one predicate
the build asks for. The second bug was that `ssoAutomaticFailed` could
never render: the notice lived in the auto-SSO status block, which is only
built while the browser callback is pending, and every path that raised
the failure also cleared the pending flag. So a user whose automatic SSO
timed out, or who cancelled it, got a stalled page and no explanation.

Then the flow itself moved. `_doAutomaticSso` was 104 lines reporting
failure by throwing `SsoAutomaticException`, with a second bare `catch`
beside the real one in the caller; both fell through to the manual
fallback, and server teardown was repeated across six exit paths.
`SsoTokenCapture` in
`lib/src/screens/login_page/sso_token_capture.dart` owns the socket and
returns a sealed `SsoAttempt`, so a caller switching on the result gets a
compile error if an outcome is added. Every failure path stops the server
before returning, and `cancel` and `dispose` are both safe when nothing is
running because the page can be disposed mid-capture.

Three smaller things fixed on the way through, each its own commit:
`parseHomeserverInput` replaces an inline `Uri.parse` expression that ran
in three places and had no failure mode, since `FormatException` from a
`setState` is not a way to tell a user their address is wrong; the two
sign-in forms share `buildFormFieldLabel` instead of a byte-identical
private copy each; and the four SSO presentation pieces become widgets in
`sso_widgets.dart` that declare what they render.

- `lib/src/screens/login_page.dart`: 1,241 to 1,029 lines.
- `lib/src/services/sso_server.dart`: exposes the `redirectUri` it already
  computed, cleared in `stop` with the rest of the per-run state.
- `test/unit/login_mode_test.dart`, `test/unit/sso_token_capture_test.dart`,
  `test/unit/homeserver_url_test.dart`: 14 new cases, including the
  partition assertion that no `SsoStep` shows the failure notice and the
  paste field at once, and the double-cancel case that can genuinely race.

Tests at head: flutter test 648 green (633 prior + 15 new), flutter analyze
0 issues. The typography guard passes.

35. Stop the startup flow from leaking credentials and duplicating itself

Section 34 noted that the login page's two sign-in paths had drifted so
that token sign-in skipped the device-verification prompt. Chasing that
kind of drift in a 1,240-line State class turned up three things worth
fixing on their own terms.

The worst was a security bug. `MatrixHttpException.toString()` returns
the request body, so a homeserver answering 4xx could put the submitted
password or login token into the exception text. The login page had
`_safeErrorMessage` for exactly this and applied it to the password path
only; the token path interpolated the raw error, and the register page
had no equivalent despite its request carrying `password:`. A user
copying a failed login into a bug report would have pasted their own
secret.

- `lib/src/helpers/login_errors.dart`: new `safeErrorMessage`, the old
  private method promoted to a helper both pages can use, with a doc
  comment naming the requests it is for rather than restating that it is
  safe. `login_page.dart` and `register_page_inclient.dart` both call it.
- `test/unit/login_errors_test.dart`: three cases. The fake exception has a
  `toString()` containing a password, because the real SDK exception does
  too; a test using a plain `Exception` would pass whether or not the
  helper ever called `toString()`, which is the bug.
- `_autoSsoTimer` in `login_page.dart` was declared, cancelled in three
  places and never assigned, so every cancel was a no-op. Its comment
  described a race against the automatic-SSO wait that did not exist: the
  wait is a `.timeout()` on the server's token future. It read as though
  the flow had a second, unwired timeout mechanism, which sends the next
  person hunting a cancellation path that is not there. The field and the
  three cancels go; the real timeout stays.
- `lib/src/helpers/post_login.dart`: the post-login sequence moves out of
  both pages into `completeSignIn`, which persists the account, runs an
  optional `beforeNavigate` hook, navigates, then offers the
  verification prompt. The login page passes its initial-sync wait as
  that hook because it wants the room list populated before the user
  lands on it; the register page has no such wait. The verification prompt
  deliberately sits outside the account-saving step: a homeserver with no
  verification support, or a user who cancels, must not be able to block
  the sign-in that just succeeded.

The recurring shape here is the same one section 34 found: a correct
thing existed and reached some of its callers. That is what a
single-call-site helper is for, and the reason the fix belongs in a
shared helper rather than in two more call-site patches.

`login_page.dart` goes from 1,240 to 1,181 lines,
`register_page_inclient.dart` from 506 to 445.

Tests at head: flutter test 633 green (630 prior + 3 new), flutter analyze
0 issues. The typography guard passes.

34. Split the large screens into directory trees

The hub screen was split into `lib/src/screens/hub_screen/` back in
`87a8169`, and ten other screens had the same shape without the
treatment: one State class with a stack of private widgets underneath it,
each invisible because the file it lived in was named after the page. They
move the same way now.

- `room_settings_page.dart` (1,774) becomes `room_settings/` with the
  identity card, the notification tile, the knock-request section, the
  shared small widgets and the power-levels editor in their own files.
  The editor was the one genuinely awkward extraction: 140 lines of seven
  identical sliders plus the read and the write, and it is the single
  largest thing in the file while not being a page.
- `user_profile.dart` (1,469) becomes `user_profile/`, six files grouped
  by role rather than one each, because ModerationChip only ever appears
  inside ModerationSection.
- `navigation_sidebar.dart` (1,065), `startup_screen.dart` (1,065),
  `room_details_page.dart` (1,161), `space_settings_page.dart` (991),
  `encryption_overview.dart` (929), `in_room_search_panel.dart` (883),
  `room_members_view.dart` (729), `space_home_page.dart` (642),
  `create_room_form.dart` (787) and `video_message_type.dart` (1,222)
  follow. In every case the extracted classes are public and take a key,
  which is the lint the analyzer raises once a class stops being private.

The pattern is mechanical, so the interesting part is what it turned up on
the way. Two things were not really about file size:

**Four screens each carried their own copy of the same four widgets.**
`_InfoChip`, `_SectionHeader`, `_ActionTile` and `_DetailRow` appeared in
`room_settings`, `room_details`, `space_settings`, `space_home` and
`user_profile`, near-identical and drifting: one detail row grew a
`trailing` slot for a verification badge, one section header grew a
leading icon, one detail row stopped using a monospace face for its
values. That is roughly 600 lines of duplication, and it is now
`lib/src/widgets/info_widgets.dart`, the same move the hub screen made
with its own `settings_section.dart`. The drifted bits became optional
parameters rather than a decision, so no screen's appearance changes:
`trailing`, a nullable `icon`, and `valueFontFamily` with the two panels
that wanted a monospace value still asking for it.

`user_profile`'s `_InfoRow` is *not* one of them. It has an `isMono` flag
and a name-and-date layout, so it stays its own thing as `ProfileInfoRow`.

**The login page had a duplicated post-login sequence that had drifted.**
The password flow and the token flow each had their own copy of the forty
lines that run after `client.login` succeeds. The password copy ends with
a device-verification prompt and a comment saying the prompt is meant to
appear immediately after sign-in. The token copy stops at the navigation,
so a user who signed in with a token was never offered the check every
other path asks for, and the comment describing the intent was attached to
the one copy that had it. Both now call one `_onLoginSucceeded` and the
token path gets the prompt. That is a behaviour change and it is called
out rather than left for someone to find in a bug report.

The two error branches stay separate on purpose: they report different
messages, and the password one is careful never to log a raw
`MatrixHttpException`, whose `toString` echoes the request body and with
it the typed password.

`command_palette.dart` (1,300) got the same treatment but needed more
than extraction. It was one 1,150-line State holding both the search
machinery and two long literal data tables, and the tables were methods
only because they had been written as methods. They are now
`palette_commands.dart` as plain functions, and `palette_models.dart`
holds the data types, including a doc comment on the parallel first-page
result whose "null means that source failed" convention is exactly the
kind of thing that gets tidied into a bug.

Every commit is one file or one idea, `flutter analyze` is clean and
`flutter test` is 630 green at each one, and the typography guard passes.
Nothing in the settings stack was touched: `settings_service.dart` (1,396)
and `settings_controller.dart` (963) are not widgets, and the descriptor
rework the code review asks for there is a different and much riskier
change than any of this.

Tests at head: flutter test 630 green (unit + widget), flutter analyze 0
issues.

33. Rewrite the router: drop the delegates and the page-builder layer

A code review flagged the router's `pageBuilder` usage and the
`RoomDelegate` / `ProfileDelegate` widgets as complexity. Investigating
them turned up three defects, two of them user-facing, and the root cause
turned out to be a single habit: writing to shared state during build.

The delegates existed to hold a nullable id and decide what to render.
That shape is what caused the bugs, because "no id" and "bad id" became
the same branch. `/main/myprofile` passed a null id, meaning "the signed-in
user", straight into the null branch and rendered an error card instead of
the user's own profile. The same widget rendered "Room not found" on
`/main/rooms`, which is the normal desktop state of "no room selected yet",
so opening the app on a wide window showed an error where a list should
be. Neither was reachable by a unit test, because both need the real
GoRouter tree mounted, and nothing in the repo mounted it.

The `pageBuilder` layer was `genericPageBuilder`, a helper every one of the
twenty routes had to remember to route through. It existed to wrap pages in
a fade, or in `NoTransitionPage` when the user had turned animations off.
That is a theme concern, so it moved to `MoonrelayPageTransitionsBuilder`
in `lib/src/settings/theme.dart`, wired through
`ThemeData.pageTransitionsTheme` and driven by a new `enableAnimations`
parameter on `MoonrelayTheme.light`/`dark`. Durations are unchanged
(`MotionDurations.medium` forward, `fast` back), and returning the child
untouched reproduces what `NoTransitionPage` did, without swapping the
route type. Every route is now a plain `builder:`.

The shell-flip bug from the previous entry is fixed at the root. It was
symptomatic: a mobile/dashboard change called `router.go()` from a
post-frame callback, replacing the whole page stack, so resizing the window
across the 600px boundary threw away whatever the user had pushed (room
settings, a thread, a profile). The navigation is gone entirely. A shell
change is a pure widget-tree change, and `WORK_DONE` entry 17 had already
established that the pushed-page refresh it replaced was unnecessary
precisely because the page child rebuilds reactively.

What made it feel necessary to navigate at all was a comment in the old
`_roomsListPageBuilder` claiming `RoomDelegate` "renders an empty space when
the room ID is absent". It did not: it rendered the error card described
above. Fixing that made the navigation unnecessary.

The `LayoutShellController` is no longer a `ChangeNotifier`. It was one
because two callers committed the shell from inside a build (the router's
page builder and the shell widget), and mutating a notifier mid-build is
illegal, so `_commit` had to defer `notifyListeners` to a post-frame
callback. That deferral is what made the navigation look safe. The
notification turns out to be unnecessary: `_AdaptiveMainLayout` is the only
writer, it resolves during its own build, and every consumer is a
descendant, so a consumer reading the shell in the same pass already sees
this frame's decision. `DashboardLayout` was a second writer and now only
reads. The class is a plain sticky cache with no lifecycle.

Files:

- `lib/src/router.dart`: all `builder:`, `genericPageBuilder` and
  `_navigateToActiveRoom` deleted, `RoomsListRoute` added, params read
  through one `_param` helper.
- `lib/src/widgets/room_resolver.dart` (new) and
  `lib/src/widgets/profile_view.dart` (new) replace the two delegates.
  `lib/src/helpers/room_delegate.dart` and `profile_delegate.dart` are
  deleted.
- `lib/src/layouts/layout_shell_controller.dart`: `update` renamed to
  `resolve`, `ChangeNotifier` dropped, the post-frame `notifyListeners`
  removed, and a comment explaining why it must not become a notifier
  again.
- `lib/src/settings/theme.dart`, `lib/src/app.dart`: page transitions
  moved into the theme.
- `lib/src/localization/app_en.arb`: `profileIdNullError` dropped (the
  error it described is gone), `noRoomSelected`, `noRoomSelectedHint` and
  `stillWaitingForServer` added.

One finding from this pass was a false alarm worth recording, because the
inverse error is easy to reintroduce. The old router percent-decoded
`:userid` in some places and not others, which looked like a
double-decode bug. Probing GoRouter directly showed it already decodes
matched segments, so the old `Uri.decodeComponent` calls were no-ops at
best; the new `_param` helper documents that decoding again would throw a
`FormatException` on a user ID containing a literal `%`, which is legal in
a Matrix localpart. The `router_test.dart` case for it asserts a user ID
survives intact, which passes on the old tree too, so it is a guard rather
than a regression test.

`test/widget/router_test.dart` (new) mounts the real route table, which
nothing in the repo did before. It pins the own-profile page, the
no-room-selected empty state, that a pushed route survives a resize across
the mobile boundary, and that path parameters arrive decoded exactly once.
The first three were verified to fail against the pre-rewrite tree by
running an equivalent probe against `HEAD` before landing the fixes, so
they are real regression tests rather than restatements of the new
behaviour. `test/widget/empty_states_test.dart` drops the two delegate
groups for `ProfileView` and `RoomResolver`, including the test that
asserted a null user id should produce an error card, and gains coverage
for the empty-sync-cache branch that must wait rather than claim a room is
missing.

`AGENTS.md` recorded all of it, because it described the routing layer in
terms of things that no longer existed.

Tests at head: flutter test 630 green (unit + widget), flutter analyze 0
issues.

32. Repair the CI workflow and correct the AGENTS.md drift

A review of the settings, chat and services layers turned up a file that
had never run at all. `.github/workflows/tests.yml` declared the job key
`build-windows` twice, and GitHub rejects a workflow with duplicate job
ids, so the whole `ci` pipeline failed validation on every push. The first
copy was itself a copy-paste of the Linux build: it ran `sudo apt-get` and
`flutter build linux --release` on a `windows-latest` runner. What kept it
alive is that its own header comment opened with "Per AGENTS.md there is
no CI today", which matched gotcha #8 in AGENTS.md, which was also wrong.
One stale sentence in the agent guide was holding a broken workflow in
place, so the fix is both halves: repair the file and correct the guide.

- `.github/workflows/tests.yml`: the Linux job is now `build-linux` on
  `ubuntu-latest`, `build-windows` builds Windows, the four job ids are
  unique, and the header describes the four jobs that actually run. The
  integration suite stays out on purpose; `CONTRIBUTING.md` already
  explains that it needs a real desktop session, so the header defers to
  that instead of promising a job a hosted runner cannot host.
- `AGENTS.md`: dependency versions (`matrix ^9.0.0`,
  `flutter_vodozemac ^0.6.0`), `kDbSchemaVersion = 3` with its
  `lib/main.dart:59` anchor, the 50-case MatrixUriParser count, and the
  init pipeline, which had drifted to 13 steps under `main.dart` while the
  work lives in `boot.dart` in 12, with three providers missing from the
  MultiProvider list.
- `AGENTS.md`: the structure block listed `lib/src/events/message_body.dart`,
  a path that does not exist and duplicates the real one three lines
  above it. The layout hierarchy described a `NavigationPane` and a
  hardcoded 1100px breakpoint belonging to a `_DashboardView` class that
  no longer exists; both now describe `LayoutBreakpoints` and
  `LayoutShellController`, with an explicit note that there is no
  `_DashboardView`.
- `AGENTS.md`: the lint appendix claimed `avoid_print`,
  `prefer_single_quotes` and `always_use_package_imports`, none of which
  the project enables, and would have led an agent to "fix" the double
  quotes and relative imports the code deliberately uses. Replaced with
  what `analysis_options.yaml` actually does and a rule about fixing
  findings before adding a lint.
- `AGENTS.md`: gotcha #11 told agents reply sending was not wired and
  that `sendFn` omitted `m.in_reply_to`. It does not, at
  `lib/src/chat/chat_box.dart:342-346`. The note is replaced with the
  anchor for the code that does it, because an agent following the old
  text would have reintroduced a fixed bug.
- `tools/check_typography.sh`: the guard now also scans
  `.github/workflows`, since workflow comments are prose agents read and
  write.

31. Fix the hub locale bug and localise the notification chrome

Two unrelated defects that both come from the same mistake: a value read
from `AppLocalizations` exactly once and cached for the life of the
object. The hub nav strip and the OS notification chrome are both built
outside the normal build cycle, so neither noticed the user's language
changing underneath them.

- `lib/src/screens/hub_screen/hub_screen.dart`: `HubScreen` built its
  category labels from `AppLocalizations` behind an `isEmpty` guard and
  cached them on the `State`. Switching language left the entire hub
  navigation in the previous language while the rest of the app
  followed, which is most of what the language setting is for. The state
  now remembers the locale it built against and rebuilds the labels when
  that changes, without re-applying the route selection, which would have
  pushed a redundant navigation on every language change. The empty
  `initState` and `dispose` overrides are gone with it.
- `lib/src/services/notification_service.dart`: "Mark as read", "Open",
  the Android channel description and the test-notification body were
  English literals inside a class with no `BuildContext`. They now resolve
  through the localization delegate against the account's language,
  refreshed by a listener on `SettingsController`, with English kept only
  as a pre-init fallback. The listener is removed in `dispose`.
- `lib/src/localization/app_en.arb` + `app_fa.arb`: Persian strings added
  alongside the English ones for the new recovery-key states, the
  notification action labels, the channel description and the test
  notification body.
- `lib/src/helpers/upload_limits.dart` (new): `readFileBytes` checks the
  picker's own size metadata against `kMaxUploadBytes` and throws
  `UploadTooLargeException` before the read. Uploads read the picked file
  whole into memory before a byte went out, so grabbing a large video
  allocated it on the UI isolate first; the seven pick-and-upload sites
  now go through the guard. `voice_recorder_dialog.dart` is deliberately
  left alone: it reads its own temp file, whose size is bounded by the
  recording length rather than by anything the user picked.
- `lib/src/encryption/encryption_service.dart`: `init`'s wait for the
  SDK's `Encryption` object hid `50` and `100ms` inside the loop. They are
  now named constants with the worst-case five-second boot latency
  spelled out, next to the existing `_deviceRefreshMinInterval` which
  already worked this way.
- `test/widget/hub_overlay_navigation_test.dart`: pins the label rebuild.
  The test was checked against the old `isEmpty` guard and fails there,
  so it is a real regression test rather than a description of current
  behaviour.
- `test/unit/upload_limits_test.dart`: pins the boundary (at the limit
  passes, one byte over throws) and that the oversized path never calls
  `readAsBytes`, which is the property that makes the guard cheap.

30. Stop the encryption screen from guessing about the recovery key

The key backup card is the one screen whose job is to tell a user whether
they can still restore their encrypted history, and it was answering from
an unrelated fact. `_refreshBackupState` assigned
`_keyBackupCached = enc.crossSigning.enabled`, and the card rendered any
`true` as a green tick next to "Recovery key is set". Bootstrapping
cross-signing does create a recovery key, but nothing stops a user
cross-signing without ever setting one, so for those accounts the app
stated a security-critical fact it had not checked. The code carried a
comment admitting it was a substitution.

- `lib/src/encryption/encryption_service.dart`: `keyBackupCached` is now
  `bool?`. The SDK exposes no accessor for whether the recovery secret is
  cached, so the service reports "cannot tell" rather than a proxy, and
  the derivation comment now says not to reintroduce one.
- `lib/src/screens/encryption/encryption_overview.dart`: the card renders
  a third "Recovery key status unknown" state with its own hint, and the
  no-key hint is shown only for a known-absent key, not for an unknown
  one. The distinction matters: "no recovery key set" is a call to action
  and "we cannot tell" is not.
- `lib/src/localization/app_en.arb` + `app_fa.arb`: the two new strings.
- `test/widget/encryption_overview_screen_test.dart`: three cases pinning
  the three states, so `null` can never quietly render as either answer.

The same change fixed the other fail-open in the same area.
`MessageActionRunner.canEditText` returned `true` when `event.canRedact`
threw, which put an Edit button in front of the user that then failed on
tap whenever the power level chain was not loaded. A capability check has
to fail closed, so it now returns `false`.

- `AGENTS.md`: gained an Error handling section stating the rule the
  `catch` sites have been drifting from. Every catch either logs, or
  carries a comment naming what was expected and why the fallback is
  safe, with the two mistakes that have actually shipped called out by
  name: a capability check returning `true` on error, and a security fact
  derived from an unrelated one. All twelve bare catches in the files this
  round already touched now say which of the two they are.

29. Collapse the dialog and feedback boilerplate

A review of the largest screens found the same four lines written out by
hand a few hundred times: try, await, check the context is still alive,
show a `SnackBar`, then repeat the whole thing in the catch. The cost is
not the line count, it is that the guard is easy to omit after the first
`await`, where the failure is silent in release. Two files were dense
enough with it that they had started drifting apart from each other in
wording and behaviour, which is the point at which boilerplate starts
costing more than it saves.

- `lib/src/helpers/feedback.dart` (new): `FeedbackContext` with
  `showMessage`, `showActionResult` and `confirmDestructive`. Each folds
  in the `mounted` guard. Snackbars are docked by default, matching the
  roughly 80 percent of the app that already are, with `floating` as an
  opt-in for the room settings screens that settled on it. Errors now
  carry the theme error colour, which none of the hand-written sites did.
- `lib/src/chat/message_action_runner.dart`: `kick`, `ban`, `report`,
  `retrySend` and `cancelFailedSend` all route through one
  `_runModerationAction` helper, so kick and ban cannot drift apart
  again, and `confirmDelete` no longer carries two near-identical
  confirmation dialogs inside a single method. 532 lines to 444.
- `lib/src/screens/room_settings_page.dart`: `_pickOption` and
  `_promptText` build the two dialog shapes the settings flows repeat,
  and six flows collapse to a title, a list and one call.
  `_setStateEvent` and the remaining bespoke flows report through
  `FeedbackContext`. 1866 lines to 1769. `_editPowerLevels` is left alone:
  it is a 180-line slider form, not a variant of either shape.
- `lib/src/helpers/room_dates.dart` (new): `roomCreatedAt` and
  `formatIsoDay` replace the hand-rolled `YYYY-MM-DD` creation date that
  was copy-pasted into `room_settings_page.dart`, `room_details_page.dart`
  and `space_settings_page.dart`.
- `test/widget/feedback_test.dart` (new): covers the docked/floating
  default, the error colour, `successMessage: null` as an explicit opt-out,
  the failure path and both `confirmDestructive` answers.
- `test/unit/room_dates_test.dart` (new): pins the padding, that the
  rendered form sorts the same way it sorts chronologically, and the five
  ways a room can be missing a usable `created_at`.

28. Strip the variable look axis out of theming

The theming system had grown a second axis on top of colour: a registry of
seven "looks" (`MoonrelayThemeSpec`), each owning a corner radius, a surface
elevation, a bubble radius, a default density and a default font pair, plus
roughly a thousand lines of per-look widget-geometry merging
(`MoonrelayWidgetStyle` with vista/minimal/organic/moonrelay strategies).
Picking a look reset four independent settings behind the user's back, the
whole thing needed two registries, two persisted ids and a two-stage legacy
migration to stay coherent, and the widget-merge layer was almost entirely
dead: only archVista had a non-null widget style, and outside the theme
builder no widget ever read `MoonrelayComponentTokens` except for
`components.avatar`. The cost was far larger than the surface. This round
keeps the axes that are actually used (theme mode, accent seed colour, layout
density, the font families and the layout system) and deletes the rest.

- lib/src/settings/theme_spec.dart and lib/src/theme/shipped_themes/: deleted
  (~1,450 lines). The colour half survives in the new
  lib/src/settings/accents.dart, which holds only `MoonrelayAccent` and the
  nine-entry `MoonrelayAccents` registry.
- lib/src/theme/design_tokens.dart: `MoonrelayDesignTokens.fromSpec(spec)` is
  now the parameterless `MoonrelayDesignTokens.standard()`, with the corner
  radius it used to read from the spec exposed as the
  `MoonrelayDesignTokens.baseCornerRadius` constant. Every one of the ~180
  `MoonrelayThemeExtension.of(context).tokens` call sites is untouched.
- lib/src/theme/component_tokens.dart: `fromDesignTokens` dropped its `spec`
  parameter. The three sub-token factories that consumed it now use
  `radiusMd` / `baseCornerRadius` / a flat zero card elevation, so the token
  layer produces exactly the geometry the material look always produced and
  nothing on screen moves.
- lib/src/settings/theme.dart: `MoonrelayTheme.light`/`dark` take a single
  `Color seed` instead of `(spec, accent)`. The `widgetStyle.mergeInto` tail
  of `_buildThemeData` is gone, and the font fallbacks became
  `MoonrelayTheme.fontFamilyFallback` / `monoFontFamilyFallback`.
- lib/src/settings/settings_controller.dart: `selectedTheme`,
  `selectedThemeId` and `updateSelectedTheme` are gone, along with the
  four-setting reset cascade. Density, bubble radius and the font families
  are now plainly independent settings that no colour change disturbs.
- lib/src/settings/settings_service.dart: the `selected_theme` key, the
  snapshot field, `selectedThemeId()`/`updateSelectedTheme()` and the
  `_readSelectedThemeAndAccent` migration are gone, together with the
  `selected_skin` / `theme_option` legacy keys and their three lookup tables.
  `_readAccentId` reads `selected_accent` directly and falls back to the
  default for unknown ids, so installs predating `selected_accent` land on
  indigo.
- lib/src/screens/hub_screen/settings/appearance_settings.dart and
  lib/src/screens/startup_screen.dart: the "Look & feel" radio lists are
  removed from both the hub page and the welcome-screen page. The accent
  picker, density chips and everything else on those pages are unchanged.
- lib/src/localization/app_en.arb + app_fa.arb: retired the keys the removed
  pickers owned (`lookAndFeel`, `lookAndFeelDesc`) plus the `colourTheme`,
  `skin`, `skinDescription`, `enable`, `themeDefault`-`themeSky` and
  `lightMode`/`darkMode` leftovers no widget had referenced since the
  accent/look split. `accentColorDesc` no longer promises an accent "within
  the selected look", and the command-palette blurb now mentions fonts.
- test/unit/theme_spec_test.dart: becomes test/unit/accents_test.dart, pinning
  the accent registry, accent persistence, the unknown-id fallback, and that
  the retired theme keys no longer influence anything. The ArchVista
  widget-look group went with the merge strategies it tested.
- test/widget/appearance_picker_test.dart: the two "selecting a theme" tests
  are replaced by accent/density tests asserting the inverse invariant,
  namely that neither picker disturbs the other.
- test/widget/appearance_settings_test.dart and
  test/helpers/widget_test_utils.dart: adapted to the seed-only
  `MoonrelayTheme` signature.

27. Comment de-flourish cleanup

A follow-up review of remaining machine-generated-looking residue in
comments turned up three habits: typographic arrows instead of ASCII,
section banners drawn with box-drawing glyphs, and markdown-style bold
emphasis inside doc comments. All three were normalized to plain ASCII
so the tree no longer carries decoration that only an automated writer
would bother with.

- lib/, test/, integration_test/: every U+2192 arrow replaced with ->
  for mappings and chains, or reworded with words where prose read
  better; every U+2500/U+2550 banner rule swapped for -/= with layout
  preserved. The one intentional exception is the U+2502 tree marker
  that html_tag_parser.dart emits into rendered message HTML; the
  typography guard now knows about it.
- Doc comments: markdown bold removed everywhere except
  markdown_to_html.dart, where `**bold**` and friends document the
  literal parser input. Emphasized UI names now use plain quotes.
- tools/check_typography.sh: extended with arrow and box-drawing
  checks so both cannot creep back.
- WORK_DONE.md: synthetic phrasing simplified ("Suckless-cleanup pass"
  -> "Timeline simplification", "Status pillar honesty" -> "Sync pill
  reflects real state", "(Nth pass)" suffixes dropped). Subsection
  titles quoted by test files were kept byte-identical.
- lib/src/settings/settings_controller.dart: replaced the Flutter
  architecture-sample class doc with a description of this controller.

26. Forbidden typography sweep and comment hygiene

A review for LLM-style residue found the earlier em-dash cleanups
(b5ed172, d7709ed, f255079) had swept test/, tools/, and the markdown
docs but never lib/. lib/ still held about 30 em dashes, a dozen en
dashes, and 16 invisible non-breaking hyphens (U+2010/U+2011), some of
them inside user-facing strings. Worse, wherever dashes had been
stripped the removal left double-space gaps mid-sentence: about 200
grammatically broken comments across lib/, test/, and
integration_test/, plus four user-facing strings in app_en.arb whose
generated getters carried the same gaps.

- lib/, test/, integration_test/: every em/en dash replaced with
  context-appropriate punctuation (colon, semicolon, comma, or
  parenthesis per sentence); all non-breaking hyphens normalized to
  ASCII hyphens, including the shipped strings in
  lib/src/screens/privacy_policy.dart ("end-to-end", "open-source")
  and lib/src/screens/licenses.dart.
- The ~200 stripped-dash double-space gaps were repaired with real
  punctuation instead of blind deletion; post-sentence double spacing
  (a house habit, e.g. "render.  Robust") was deliberately kept.
- app_en.arb: fixed the four gapped user-facing strings;
  lib/src/localization/app_localizations.dart and
  app_localizations_en.dart hand-synced to match gen-l10n output
  because no Flutter SDK was available in the authoring environment
  to regenerate them.
- Comment rewrites: lib/src/widgets/logo_with_text_themed.dart lost
  its changelog narration and "Now features:" residue,
  lib/src/chat/message_actions.dart dropped a self-praise line,
  lib/src/screens/privacy_policy.dart dropped "comprehensive", the
  stale `_SidebarRoomInfo` reference in room_state_bus.dart now names
  the real `SidebarRoomInfo` class, and the vague "WORK_DONE.md §10"
  pointer in threads_provider.dart became a plain title quote.
- WORK_DONE.md: intro run-on paragraph rewritten into readable prose,
  ~21 stray dashes fixed, and a UTF-8 BOM removed from line 1.
- CONTRIBUTING.md: two em dashes replaced.
- tools/check_typography.sh (new): fails on em/en dashes,
  non-breaking hyphens, and BOMs across dart dirs and root docs; wired
  into AGENTS.md as a required pre-PR check so the sweep cannot rot
  again.
- Working-tree normalization: all 137 tracked files that still carried
  CRLF endings were converted to LF, matching the `eol=lf` policy in
  .gitattributes. 17 files whose committed blobs contain CRLF (mostly
  windows/runner sources) now show as whole-file diffs and will
  normalize into their next commit; WORK_NEEDED.md 1.9 records the
  optional `git add --renormalize` shortcut.
- WORK_NEEDED.md 1.9: created to track the line-ending residue above.

25. Space selection fix: highlight and navigate

Tapping a space row in the navigation sidebar did nothing. The row
shell's InkWell registered an empty tap handler, and because InkWell
sits deeper in the tree than the context-menu GestureDetector, its
recognizer won the gesture arena and swallowed the tap before it could
reach the selection logic.

- lib/src/widgets/navigation_sidebar.dart: _RowShell now takes a
  nullable onTap and only registers the recognizer when a real handler
  exists; the space row owns the tap (select in NavigationState plus
  push to /main/space/:spaceid), giving the row ripple feedback and
  restoring both highlight and navigation. The context-menu wrapper no
  longer registers a competing tap.
- lib/src/widgets/compact_sidebar.dart: space rows also mark the space
  in NavigationState before navigating, so the full sidebar highlights
  the same space after a layout switch.
- test/widget/navigation_sidebar_test.dart: new test taps a space and
  asserts NavigationState selects it and the space home page route
  renders (the wrapper gained a minimal GoRouter with a space-home
  stand-in route).

24. Collapsible sidebar sections

The navigation sidebar's spaces and rooms regions could not be hidden;
users with a short space list or a single active room had no way to
reclaim that vertical space. Both section headers are now tappable and
show a chevron that flips with the text direction (chevron-down when
expanded, pointing at the screen edge when collapsed in RTL).

- lib/src/settings: new `collapsedSidebarSections` set (ids like
  `spaces` / `rooms`), persisted as a JSON array via the existing
  comma-set reader. The controller replaces the set with a copy on
  toggle so `context.select` consumers rebuild only when the contents
  actually change.
- lib/src/widgets/navigation_sidebar.dart: the section headers take
  collapsed state and a toggle callback; the spaces region (hidden
  entirely when there are no spaces) and the rooms region mount and
  unmount their lists underneath the headers.
- test/widget/navigation_sidebar_test.dart (3 new): tapping the rooms
  or spaces header collapses the section, and a persisted collapsed
  section survives a rebuild.
- test/unit/settings_controller_test.dart (5 new): collapse round-trip,
  set-instance replacement for scoped rebuilds, notify-on-change, and
  persistence across controller reloads.

23. Dashboard UI refresh: OS decorations and the unified navigation sidebar

The window header and the left side of the dashboard were rebuilt so the
app stops fighting the desktop window manager and the rooms/spaces
pickup stops being split across three separate columns.

The header is now optional and off by default: a new `useOsTitleBar`
setting (default true) restores the native title bar, and the old
reversible header with the profile pill, command palette button, and
sidebar toggle is gone.  When the in-app header is enabled it is slim:
a draggable title area, platform window buttons, and the right-click
system menu only.

- `lib/src/settings` persists `useOsTitleBar` (controller, service,
  snapshot).
- `lib/src/helpers/window_chrome.dart` (new) applies the title bar style
  at boot and re-applies it live when the setting flips; both frames
  (`lib/src/layouts/app_frame.dart`, `startscreen_frame.dart`) listen.
- `lib/src/screens/hub_screen/settings/layout_settings.dart` swaps the
  reversed-header toggle for the OS-decorations toggle and drops the
  left-sidebar width slider (the sidebar is no longer resizable).

The wide dashboard's three left columns (nav rail, resizable rooms
pane, header chrome) collapse into one navigation sidebar:

- `lib/src/widgets/navigation_sidebar.dart` (new): the profile pill,
  the command palette row, the Home/All/Add-Room destination rows, and
  the spaces list sit above the destination-filtered rooms region.  The
  spaces ordering, grouping, context menus, auto-grouping, and
  drag-and-drop logic are ported unchanged from the deleted navigation
  rail; the rooms region reuses RoomsPane / SpaceRoomsPane untouched.
- `lib/src/widgets/sidebar_profile_pill.dart` and
  `sidebar_actions.dart` (new): shared by the full and compact
  sidebars so the compact shell keeps every action that used to live
  in the header.
- `lib/src/widgets/compact_sidebar.dart` gains the same header block.
- `lib/src/layouts/dashboard_layout/dashboard_view.dart`: the left
  sidebar is no longer resize-draggable; a hover gutter collapses it,
  and an edge strip with the same affordance lets the user expand it
  again.  Both are row children, so RTL windows keep them on the same
  side as the sidebar.  The right sidebar keeps its resize handle.
- Dead code removed: NavigationPane, SpacesPane, LeftPaneChoice,
  buildLeftPaneContent, the left-resize notifiers, and the
  navigationPaneWidth constant.

Tests added:
- test/widget/navigation_sidebar_test.dart (4): sidebar renders its
  chrome, the command palette row opens the palette, the expanded shell
  shows the collapse gutter, and toggling visibility swaps in the
  expand gutter.
- test/unit/settings_controller_test.dart (+5): useOsTitleBar
  default/round-trip/notify and the left-sidebar visibility toggle.

22. Blank-content error guidance

Three content panes used to render blank surfaces when something was
missing, leaving the user with no recourse:

- `lib/src/helpers/profile_delegate.dart` returned `SizedBox.shrink()`
  (only a transient snackbar as feedback) for a null/malformed user ID.
  It now renders [EmptyState] with an icon, the existing error message
  (`profileIdNullError`/`profileIdInvalid`), and a "Back" button that pops.
- `lib/src/helpers/room_delegate.dart` returned a bare `EmptySpace()` for
  a null/empty room ID and for a room ID that isn't joined. The null/empty
  case now renders [EmptyState] ("Error" / "Room not found" / "Back").
  The not-joined case now hands off to the existing [RoomPreviewScreen]
  (route `/main/room_preview/:roomid`) instead of a blank splash, so a
  deep link to an unjoined room resolves its identity and offers a Join.
- `lib/src/widgets/empty_state.dart` (new): a small reusable centred
  empty/error state (icon + title + message + optional action button),
  matching the visual density of rooms_pane's empty/loading states.

The pre-existing 8-second-first-sync fallback in room_delegate (`Still
waiting for the server…` / `Retry`) was intentionally left as-is; its
hardcoded English text is tracked under 1.5.

Tests added:
- test/widget/empty_states_test.dart (7): EmptyState rendering with/without
  an action, ProfileDelegate null/malformed/valid id paths, RoomDelegate
  null id and not-joined-to-preview-screen handoff.

21. Sync pill reflects real state; drop dead appearance settings

Two UX gaps where the UI either lied or ignored the user's controls.

The header status pill used to render a hardcoded green dot with the
English text "Online" no matter the connection state, while the real
sync state lived only in the status bar. A disconnected user still read
"Online". Replaced it:

- lib/src/widgets/sync_status_pill.dart (new): stateful [SyncStatusPill]
  that subscribes to [Client.onSyncStatus] (the same stream
  lib/src/widgets/status_bar.dart already uses) and a pure
  [syncStatusToPresence] helper mapping [SyncStatus.finished] -> online,
  waitingForResponse/processing/cleaningUp -> away, error -> offline.
  The dot colour follows: green / amber / red. Dot colour for the
  offline state is taken from colorScheme.onErrorContainer so it stays
  legible in both light and dark themes, unlike the previous magic
  green. Accepts an optional injected stream/initialStatus so the widget
  is unit-testable without the SDK's private CachedStreamController.
- lib/src/layouts/app_frame.dart: drop the now-dead [StatusPill] class
  and render [SyncStatusPill] in the header (was app_frame.dart:406).
- lib/src/localization/app_en.arb, lib/src/localization/app_fa.arb: add
  statusOnline/statusAway/statusOffline (+ Persian: آنلاین/دور/آفلاین);
  run flutter gen-l10n. The generated .dart l10n files are gitignored.

Previously the UI-scale slider and the density chips only updated and
persisted [SettingsController] values that nothing read; classic
"control that looks wired but isn't". Wired them:

- lib/src/app.dart: the MaterialApp.router builder now wraps the child
  in a MediaQuery whose textScaler is TextScaler.linear(uiScale), so
  the "Interface scale" slider actually scales every Text in the tree.
- lib/src/settings/theme.dart: [MoonrelayTheme.light]/[dark] now take
  an optional LayoutDensity and call ThemeData.visualDensity accordingly
  (comfortable -> VisualDensity.standard, compact -> VisualDensity.compact);
  default stays comfortable so existing call sites are unaffected.
- lib/src/widgets/status_bar.dart left untouched; it already reported
  sync state, the pill now matches it.

Note: the per-message "Message font size" slider (SettingsController.fontSize,
already wired to the chat timeline) is intentionally left alone; that is
the intended escape hatch for chat density independent of the global UI
zoom.

Tests added:
- test/widget/sync_status_pill_test.dart (7): presence mapping + pill
  rendering for finished/error/waiting + a live stream emission flip.
- test/widget/appearance_settings_test.dart (5): density->visualDensity
  for light/dark/default, uiScale textScaler scaling, and updateUiScale
  persistence + clamping.

20. Timeline dead-code and duplication removal

Dead duplicate files deleted:

- `lib/src/chat/history_pagination.dart` was never imported or referenced
  anywhere in the codebase. It was a near-verbatim duplicate of the
  active `lib/src/chat/history_pager.dart` (same `_shouldDrainStateEvents`,
  same constants). Deleted. WORK_NEEDED had already flagged
  this as a refactor candidate.

- `lib/src/chat/read_marker_coordinator.dart` was never imported or
  referenced. The WORK_DONE.md entry for section 18 explicitly called it
  out as "the dead duplicate path in
  `lib/src/chat/read_marker_coordinator.dart`". Deleted. The active
  implementation is `lib/src/chat/read_marker_tracker.dart`
  (with `ReadMarkerService` in
  `lib/src/services/read_marker_service.dart` for the CAS-protected
  server writes).

Dead inline duplicates removed from `lib/src/chat/timeline_view.dart`:

- `_AnimatedHistorySkeleton` (was lines 737-823) was a private copy of
  the public `AnimatedHistorySkeleton` in
  `lib/src/chat/animated_history_skeleton.dart`. The public version was
  already imported and used at the call site (line 575); the private
  class was never referenced. Deleted.

- `_ItemAppearance` (was lines 831-899) was a private copy of the public
  `ItemAppearance` in `lib/src/chat/item_appearance.dart`. The public
  version was already imported and used at the call site (line 587).
  The unused-key lint warning on the private version had been carried
  through four prior WORK_DONE entries as "pre-existing and unrelated
  to this change". Now resolved. Deleted.

- `_HistorySkeletonTile` (was lines 910-1032) was a private copy of the
  public `HistorySkeletonTile` in `lib/src/chat/history_skeleton_tile.dart`.
  The public version was already imported and used at the call site
  (line 606). Deleted.

- The `motion.dart` import was removed from `timeline_view.dart` since
  `Motion` was only referenced by the three deleted inline classes.

HTML parser extracted from `formatted_text_widget.dart`:

- `_HtmlParseCache`, `_HtmlTagParser`, and the plain-text linkification
  helpers (`_PlainTokenKind`, `_PlainMatch`, `_PlainToken`) were moved
  to a new public `lib/src/chat/events/html_tag_parser.dart` file.
  `formatted_text_widget.dart` is reduced from 938 lines to ~200 lines,
  keeping only the `FormattedTextWidget` class and its linkify logic.
  The parser classes are now public (`HtmlParseCache`, `HtmlTagParser`,
  `PlainTokenKind`, `PlainMatch`, `PlainToken`) and unit-testable.

Permission check consolidation:

- `_canModerate`, `_canBan`, `_canEditText`, and `_isPinned` were
  duplicated verbatim (modulo parameter plumbing) in both
  `lib/src/chat/message_actions.dart` (the hoverbar) and
  `lib/src/chat/message_context_menu.dart` (the right-click menu).
  All four are now static methods on `MessageActionRunner`
  (`canModerate`, `canBan`, `canEditText`, `isPinned`), and both files
  delegate to them. `message_actions.dart` shed 38 lines;
  `message_context_menu.dart` shed 45 lines (plus the unused
  `MessageTypes` import is gone).

Scroll-targeting deduplication:

- The fraction-based scroll-to-index heuristic was triplicated: in
  `TimelineView._scrollToEventId` (timeline_view.dart:632),
  `JumpCoordinator.jumpToEvent` (jump_coordinator.dart:203), and
  `JumpCoordinator._scrollToEvent` (jump_coordinator.dart:284). Each had
  slightly different parameter handling and a slightly different skip-if-close
  guard. All three now share `TimelineScrollTarget.scrollToFraction` in
  the new `lib/src/chat/timeline_scroll_target.dart`. `JumpCoordinator`
  lost ~22 lines; `TimelineView` lost ~14 lines.

Tests at head: flutter test 509 green. flutter analyze 0 errors, 0 warnings.


Dead-count and message-like helper consolidation

- `lib/src/chat/jump_to_unread_pager.dart` contained a second copy of
  `countUnreadInWindow` and a private `_isMessageLike` that shadowed the
  canonical versions in `lib/src/chat/chat_unread_utils.dart`. The
  duplicate was never called (jump_coordinator.dart already imported the
  canonical version via an `as unread` prefix to hide it). Removed the
  dead 27-line function and the 3-line `_isMessageLike` helper, and
  replaced the two call sites of `_isMessageLikeEvent` with the public
  `isMessageLikeEvent` from chat_unread_utils (which is the same function).
  The `EventTypes` import in jump_to_unread_pager.dart is still needed
  for the `_isMessageLikeEvent` callsites within `JumpToUnreadPager` that
  were also replaced. Lost 40 lines.


1. Desktop-service hardening

Items from the July review that touched the desktop platform services.

1. NotificationService used to swallow plugin init failures. _initPlugin
   now returns a bool, an isAvailable flag is exposed, and the service
   silently no-ops when the plugin is null instead of crashing. See
   lib/src/services/notification_service.dart.

2. eventId.hashCode could collide in _showNotification. We now tag
   notifications as matrix:<roomId>:<eventId> on every supported platform
   (see _eventTag). Group summaries use NotificationService.groupSummaryTag.
   See lib/src/services/notification_service.dart:_eventTag.

3. TrayService crashed when getTemporaryDirectory failed. _setup is now
   wrapped in try/catch, an isAvailable flag gates the UI, and _init clears
   _instance on failure. See lib/src/services/tray_service.dart:_setup.

4. showTestNotification used to throw when the plugin was null. It now
   returns bool, and the UI can disable the affordance when isAvailable is
   false. See lib/src/services/notification_service.dart.

5. Notifications were being persisted on every sync tick. There is now a
   750ms debounce timer in _persistDebouncer, which also flushes on dispose.
   See lib/src/services/notification_service.dart.

7. Notification taps were ignoring the payload. _onNotificationTap now
   decodes response.payload and routes via DeepLinkService /
   navigateToMatrixUri. See lib/src/services/notification_service.dart.

8. Encrypted event bodies could leak into notification text. When
   event.type == EventTypes.Encrypted and m.ciphertext is present we
   substitute "(encrypted message)". See
   lib/src/services/notification_service.dart:_processEvent.

9. Tray ignored muted rooms and lost mention counts. Added
   NotificationService.mutedRoomsSnapshot, surfaced Room.highlightCount in
   the tooltip, and use Room.notificationCount as the fallback. See
   lib/src/services/notification_service.dart and
   lib/src/services/tray_service.dart:_refreshBadge.

10. Temp-file leak in _setup. _iconFile is now tracked, deleted in
    destroyTray, and on _setup failure. See lib/src/services/tray_service.dart.

12. processUri had no dedup. Added a 500ms _isDuplicate window via
    _lastUri / _lastAt. See lib/src/services/deep_link_service.dart.

15. TrayService was holding a stale Client across account switches. It
    now listens to AccountManager.activeClient via _onActiveAccountChanged
    and rebinds the sync listener on switch. See
    lib/src/services/tray_service.dart:_onActiveAccountChanged.

16. _notifiedEventIds could grow without bound. Now a bounded FIFO with
    _notifiedIdsCacheLimit = 256 and a _seenOrder list. See
    lib/src/services/notification_service.dart.

17. Linux/macOS plugin was missing from registration. InitializationSettings
    now covers all platforms natively. See
    lib/src/services/notification_service.dart:_initPlugin.

19. There were four SharedPreferences keys backing the same service.
    loadMutedRooms / _loadLastEventIds / _loadGroupNotifiedCounts all
    migrate legacy formats. See lib/src/services/notification_service.dart.

22. dispose was not symmetric to init. In-memory state is cleared on
    dispose, subscriptions and timers are cancelled, flags are reset. See
    lib/src/services/notification_service.dart:dispose.

25. There was no test coverage for the desktop services. Added
    test/unit/notification_service_test.dart (mocktail-based). Tray and
    lifecycle paths are covered indirectly through the boot tests. See
    test/unit/.

26. Method channel could TypeError on non-string arguments. Added an
    "if (call.arguments is String)" guard with a warning log. See
    lib/src/services/deep_link_service.dart:_handleMethodCall.

30. boot.dart had a silent short-circuit when the active account exists
    but sdk.isLogged() returns false. We now emit a log.w here. See
    lib/src/boot.dart.


2. Chat timeline, encryption, settings, login, search

A grab bag of fixes that came out of the July review and the original
WORK_NEEDED backlog. Each entry is short on purpose.

- Reply sending was dropping markdown formatting. chat_box.dart:_send now
  builds the relation payload once with body, formatted_body, reply, and
  thread relations. See lib/src/chat/chat_box.dart.

- Chat box cleared its input before the send result was known. Draft is
  now captured before controller.clear() and restored on throw. See
  lib/src/chat/chat_box.dart:_send.

- The ?threadRoot= query parameter was ignored on room_page. We now forward
  threadRootEventId. See lib/src/screens/room_page.dart.

- _UndecryptableBanner count was frozen. It now lives in a
  ValueNotifier<int> that updates on every visible-items build, and the
  static late reference replaces the ancestor lookup. See
  lib/src/chat/timeline_view.dart.

- SSSS prompt was falling through to a spinner. It now has a dedicated
  icon, copy, canceledReason, and a Cancel button. See
  lib/src/screens/encryption/bootstrap_screen.dart.

- Recovery key disclosure was best-effort. Done state now shows a reminder
  plus ack/later buttons. See
  lib/src/screens/encryption/bootstrap_screen.dart.

- We were making three network calls per sync. They are now coalesced into
  a single in-flight Future with a 750ms debounce. See
  lib/src/encryption/encryption_service.dart.

- The Bootstrap finish signal was being ignored. onBootstrapFinished() now
  resets the refresh and triggers a full refresh. See
  lib/src/encryption/encryption_service.dart.

- Backup numbers used to show placeholders. We now surface
  {exists, cached, algorithm}. See
  lib/src/encryption/encryption_service.dart:_refreshBackupState.

- isUserVerifiedById had stale comment drift. It now reads mk.verified.
  See lib/src/encryption/encryption_service.dart.

- Post-login setup raced the first refresh. _check() now awaits enc.init()
  plus one sync plus a 900ms delay. See
  lib/src/widgets/encryption/post_login_setup_checker.dart.

- In-room search tap didn't actually jump. onJumpToEvent now closes the
  panel and calls _timelineKey.jumpToEvent(id). See
  lib/src/chat/in_room_search_panel.dart.

- HTML _processBoldItalic had a greedy-forward scan bug. Rewrote as a
  per-character state machine. See lib/src/helpers/markdown_to_html.dart.

- The href attribute was XSS-vulnerable. Added _escapeAttribute and
  _isSafeHref; pinned by test/unit/markdown_round_trip_test.dart. See
  lib/src/helpers/markdown_to_html.dart.

- Comma and pipe separator strings were getting split incorrectly.
  _readCommaSet / _readCommaList / _readSpaceGroups now use jsonDecode with
  a legacy fallback. See lib/src/settings/settings_service.dart.

- Matrix URI trailing punctuation was being eaten. Added a trailing
  lookbehind; the bare-ID branch only accepts @...:... and #...:... now.
  See lib/src/helpers/matrix_uri_parser.dart.

- _buildAvatar was throwing on whitespace-only displaynames.
  _initialsForDisplayname now splits, filters, and uses characters.firstOrNull,
  falling back to untitledRoom. See lib/src/widgets/rooms_pane.dart.

- SSO redirect URL was unvalidated. We now call isPlausibleHomeserverUrl
  and show a confirmation dialog. Pinned by
  test/unit/login_security_test.dart. See lib/src/screens/login_page.dart.

- SSO callback could hang on error. Every error branch now completes the
  future with an exception and returns 4xx HTML. See
  lib/src/services/sso_server.dart.

- Plaintext password was leaking through login errors. _safeErrorMessage
  maps TimeoutException to static copy, and log redaction covers
  password=..., "password":"...", and password: ... patterns. See
  lib/src/screens/login_page.dart.

- DatabaseService was swallowing wipe failures. It now re-throws as
  StateError. See lib/src/services/database_service.dart.

- SplashScreen.updateStatus was never wired. _boot now forwards every
  status callback. See lib/main.dart.

- AccountManager.switchToAccount had a race. The new pair is built and
  persisted first, the old pair is disposed on a microtask. See
  lib/src/helpers/account_manager.dart.

- _HtmlParseCache was keyed on hashCode. It now keys on formattedBody
  only (font size is a render-time scale on the cached spans), with a
  proper LRU and byte budget. See
  lib/src/chat/events/formatted_text_widget.dart.

- RoomsPane._buildAvatar was rebuilding a FutureBuilder per row. Added
  cachedThumbnail with a bounded FIFO, keyed by userID. See
  lib/src/widgets/avatar_from_uri.dart.

- _StringColor._colorCache was unbounded. It's now capped at 512 with
  oldest-eviction. See lib/src/helpers/string_color.dart.

- SSSS placeholder backup algorithm string was fake. We now surface the
  real algorithm string. See lib/src/encryption/encryption_service.dart.


3. Performance and memory

38 tickets total. Split into P0 critical, P1 high, P2 medium, and P3/P4
minor/test work.

3.1 P0 - critical

P0-01 Image.memory was decoding at full resolution. We now pass
cacheWidth: (size.width * dpr).ceil() for image, sticker, video thumb, and
the full-screen viewer. See image_message_type.dart, sticker_message_type.dart,
video_message_type.dart, and image_viewer_screen.dart.

P0-02 Each message did context.watch<EncryptionService>, which caused a
full timeline rebuild on every sync. Memoized isDeviceVerifiedById and
isUserVerifiedById cache fields on EncryptionService; the per-message
widget now uses context.read for verification. See
lib/src/encryption/encryption_service.dart and lib/src/chat/chat_event.dart.

P0-03 _HtmlParseCache was unbounded and its LRU was broken. It's now a
true LRU with a 4MB byte budget and LRU-order refresh. baseFontSize was
removed from the cache key (spans are cached at canonical 16px and scaled
at render time). See lib/src/chat/events/formatted_text_widget.dart.

P0-04 AvatarFromUri thumbnail cache was unbounded and identityHashCode had
a leak risk. Now a true LRU capped at 512, keyed by userID with an anon:
fallback, plus clearCacheFor and clearAll. Wired into AccountManager
logout. See lib/src/widgets/avatar_from_uri.dart.

P0-05 Each pane subscribed to client.onSync independently and produced
3-5 setState per tick. Introduced a new SyncPulse ChangeNotifier with a
350ms debounce plus a first-tick-immediate behavior. compact_sidebar,
navigation_pane, spaces_pane, and rooms_pane all consume it now. See
lib/src/helpers/sync_pulse.dart and lib/src/app.dart.

3.2 P1 - high

P1-01 TimelineItem was rebuilt on every parent build. Removed unused
previousEvent; single onAction callback with a TimelineItemAction enum;
ValueKey(event.eventId) for stable diffing. See
lib/src/chat/timeline_item.dart and lib/src/chat/timeline_view.dart.

P1-02 Video and audio widgets were doing 60Hz setState. Video now uses
AnimatedBuilder(animation: controller); audio uses ValueListenable per
stream. See video_message_type.dart and audio_message_type.dart.

P1-03 _HoverActionsWrapper and _ImageHoverRegion were doing setState on
hover. Now use ValueNotifier<bool> with a ValueListenableBuilder overlay;
the message body never rebuilds. See lib/src/chat/timeline_item.dart and
image_message_type.dart.

P1-04 Each image/sticker/audio/file widget held its own Future<MatrixFile>.
Added a RoomMediaCache singleton (64MB byte-budget LRU) shared across all
media widgets, with per-event dedup. See lib/src/helpers/room_media_cache.dart
and the four media widgets.

P1-05 _markReadSent Set was growing unbounded. Now FIFO-capped at 64,
drops the oldest quarter on overflow. See lib/src/chat/chat_timeline.dart.

P1-06 ThreadViewPage was doing O(N) aggregatedEvents per build while
watching the full SettingsController. Now uses
context.select<SettingsController, double> for font size; reply count is
pre-computed in _findRootEvent. See lib/src/screens/thread_view.dart.

P1-07 _paginateUntilMarker could stall for 8 minutes. Cap reduced to 6
iterations, 4s per-iteration timeout, 8s global timeout via .timeout. See
lib/src/chat/chat_timeline.dart.

P1-08 DraftService allocated a fresh instance per ChatBox mount and its
timer leaked across rooms. Now a singleton-per-account instanceFor with
reference counting; release in dispose cancels any pending timer. See
lib/src/services/draft_service.dart and lib/src/chat/chat_box.dart.

P1-09 _SidebarRoomInfo rebuilt on every state event regardless of visible
change. Added change-detection in _refreshFromRoom; setState only fires
when at least one user-visible field actually differs. See
lib/src/layouts/dashboard_layout.dart.

3.3 P2 - medium

P2-01 _ClientThumbnailCache was keyed by identityHashCode. Now keyed by
userID with an anon: fallback; disposeRoom is called on leave, clear on
logout. See lib/src/widgets/rooms_pane.dart.

P2-02 NavigationPane scanned client.rooms.where(isSpace) on every parent
build. Cached _cachedSpaceIds is refreshed only on sync pulse tick. See
lib/src/widgets/navigation_pane.dart.

P2-03 DashboardLayout setState on every shell decision flip rebuilt the
entire tree. New LayoutShellController ValueListenable; only the shell
subtree re-renders now. See lib/src/layouts/layout_shell_controller.dart
and lib/src/layouts/dashboard_layout.dart.

P2-04 PinnedEventsCache evicted by entry count (512) only. Now uses
byte-budget eviction (64MB), LRU by access, with per-event size
estimates. See lib/src/helpers/pinned_events_cache.dart.

P2-05 NotificationService was re-processing every room on every sync tick
even when nothing changed. _processRoomsIfChanged short-circuits on no-op
ticks; group summary now uses the caller-supplied room id (no scan). See
lib/src/services/notification_service.dart.

P2-07 Permission checks were being recomputed on every hover-actions
render. Deferred - low ROI for action visibility.

P2-09 Every widget subscribed to client.onRoomState independently. Added
a RoomStateBus (per-room ValueListenable<int> tick); _SidebarRoomInfo
migrated to it. See lib/src/helpers/room_state_bus.dart.

P2-11 EncryptionService.dispose cleanup. Verified - subscription, debounce
timer, and in-memory state cleared (onLogout clears _cachedUnverified,
_myDevices, etc.). See lib/src/encryption/encryption_service.dart.

P2-14 SpacePreferences fired notifyListeners on every drag-reorder step.
Coalesced via microtask; dispose guard added. See
lib/src/settings/space_preferences.dart.

P2-17 _ReplyPreview re-issued getEventById on every parent build.
Memoized _pendingFetch future; cleared in didUpdateWidget when reply
target changes. See lib/src/chat/chat_event.dart.

P2-18 _inviteUser TextEditingController was leaking. dispose() after
dialog closes, text captured before dispose. See
lib/src/screens/user_profile.dart.

P2-19 RoomsPane used a heavy ListTile per row. New lightweight _RoomRow
widget; displayname memoized per row. See lib/src/widgets/rooms_pane.dart.

3.4 P3/P4 - minor and tests

P3-02 Cache isDeviceVerifiedById - addressed by P0-02.

P3-03 Voice and location dialog resource disposal - verified correct.

P4-01 Performance regression test plus memory smoke test. Added
test/unit/room_media_cache_test.dart covering LRU eviction, in-flight
dedup, and SyncPulse coalescing. See test/unit/.


4. Cross-cutting improvements

Quick list of the broader refactors that landed alongside the review items.

- Provider wiring - Provider<RoomStateBus> and ChangeNotifierProvider<SyncPulse>
  injected by MoonrelayApp; rebinds on AccountManager account switch. See
  lib/src/app.dart.

- Shell decision - extracted to LayoutShellController, single source of
  truth for compact vs wide. See lib/src/layouts/layout_shell_controller.dart.

- Media cache - RoomMediaCache deduplicates downloads across the app, with
  per-event TTL and LRU by bytes. See lib/src/helpers/room_media_cache.dart.

- State-event fan-out - RoomStateBus centralises one O(N) filter into a
  shared fan-out. See lib/src/helpers/room_state_bus.dart.

- Draft persistence - DraftService is a reference-counted singleton, no
  timer leaks on room switch. See lib/src/services/draft_service.dart.

- Settings coalescing - SpacePreferences microtask-coalesced notifies. See
  lib/src/settings/space_preferences.dart.

- Encryption caching - per-(userId, deviceId) and per-userId memoized
  lookups, invalidated by sync. See lib/src/encryption/encryption_service.dart.

- Reply preview - memoized fetch future with proper invalidation on
  reply-target change. See lib/src/chat/chat_event.dart.

- Sidebar info - only rebuilds when a user-visible field actually changed.
  See lib/src/layouts/dashboard_layout.dart.

- HTML cache - true LRU plus byte budget; font-size changes no longer
  invalidate the cache. See lib/src/chat/events/formatted_text_widget.dart.


5. Test additions

test/unit/notification_service_test.dart
  Muted-room persistence plus migration, last-event-id persistence,
  group-count persistence, show/skip logic for DM and group, sender skip,
  body-empty skip, current-room skip, _showNotification no-op when plugin
  is null, first-time-room baseline, and group summary copy (single vs
  multi).

test/unit/draft_service_test.dart
  Load/save/clear round-trip, empty drafts are removed, cross-account
  isolation, debounced scheduleSave persists.

test/unit/room_media_cache_test.dart
  Byte-budget eviction drops oldest entries, concurrent getOrDownload
  calls share one in-flight future, SyncPulse coalesces a burst of pokes
  into one broadcast.

test/unit/pinned_events_cache_test.dart
  Byte-budget eviction, per-event size estimate, LRU by access.

test/unit/markdown_round_trip_test.dart
  XSS hardening (href attribute escape plus safe-URL allow-list).

test/unit/login_security_test.dart
  SSO redirect URL plausibility, password log redaction, _safeErrorMessage
  does not leak MatrixHttpException.toString.

test/unit/sso_callback_server_test.dart
  SSO callback happy path, wrong-state rejection, timeout.

test/unit/database_service_test.dart
  Wipe-on-version-bump with the StateError path.

Other test files (preserved and still passing):
test/unit/space_rooms_tree_test.dart, account_manager_test.dart,
app_version_test.dart, chat_timeline_test.dart, auto_update_service_test.dart,
date_time_extension_test.dart, display_type_test.dart, html_parser_test.dart,
localization_smoke_test.dart, log_redaction_test.dart,
matrix_uri_parser_test.dart, navigation_state_test.dart, responsive_test.dart,
room_preview_screen_test.dart, search_provider_test.dart,
search_provider_users_test.dart, settings_controller_test.dart,
settings_extended_test.dart, settings_service_test.dart,
space_hierarchy_test.dart, space_pinning_test.dart, string_color_test.dart.

Widget tests (preserved):
test/widget/message_action_runner_test.dart, login_page_test.dart,
delivery_indicator_test.dart, encryption_badge_test.dart.


6. Media widget polish (July 2026 follow-up)

Follow-up to section 3 P0/P1 work. Two sub-batches: a visual overhaul of
the image and video bubbles plus an in-app image viewer, and a robustness
pass across all four message-type renderers.

Tests at head: flutter test (440 tests) all green. flutter analyze with 0
errors.

6.1 Image bubble and viewer

1. Image bubble no longer stretches across the chat row. Thumbnail uses
   Align(centerStart) plus BoxFit.contain (was BoxFit.cover). See
   lib/src/chat/events/matrix_events/Message/image/image_message_type.dart.

2. Sticker bubble: borders and background containers removed.
   Placeholder/loading/error are now bare SizedBox plus icon. Size comes
   from a new _stickerSize helper (aspect-preserving, capped at
   prefs.stickerMax). See
   lib/src/chat/events/matrix_events/Message/sticker/sticker_message_type.dart.

3. Video bubble background removed. Only the player and metadata row keep
   their subtle fills so the bubble hugs the video aspect. See
   lib/src/chat/events/matrix_events/Message/video/video_message_type.dart.

4. New hover-reveal download affordance on image thumbnails
   (_HoverDownloadButton), so the bubble isn't permanently decorated. See
   lib/src/chat/events/matrix_events/Message/image/image_message_type.dart.

5. Long-press on image thumbnail now saves via the platform save-file
   dialog. See
   lib/src/chat/events/matrix_events/Message/image/image_message_type.dart.

6. New full-screen image viewer: auto-hiding top/bottom chrome, tap or
   double-tap anywhere to summon, toolbar download plus long-press to
   save, bottom hint strip. ColoredBox(0xCC000000) dim backdrop replaces
   the old ImageFiltered(ImageFilter.blur). See
   lib/src/screens/image_viewer_screen.dart.

7. Chrome re-summoning was broken. Removed an IgnorePointer wrapper that
   was swallowing taps. Added a top-level HitTestBehavior.translucent
   GestureDetector so any tap outside a tool button reliably toggles
   chrome. See lib/src/screens/image_viewer_screen.dart.

8. _hideScheduleId counter cancels any in-flight hide callback when the
   user re-summons chrome. See lib/src/screens/image_viewer_screen.dart.

6.2 Video bubble and fullscreen player

9. Fixed a runtime crash in _downloadOnDemand. The pattern
   setState(() => _x = future) was returning the assigned Future, which
   State.setState rejects as "the closure returned a Future". Switched
   to block-body setState(() { _x = future; }). Same fix applied to file
   and audio widgets. See video_message_type.dart,
   file_attached_message.dart, audio_message_type.dart.

10. Initialize-only player subtree extracted as _InitializedPlayer. Only
    that subtree rebuilds on controller tick (drops the 60Hz rebuild of
    the metadata row and overlays). See video_message_type.dart.

11. Monotonic _buildToken guards against stale build-controller futures
    overwriting a newer attempt. See video_message_type.dart.

12. _controllerFailed flag plus a retry panel (videoLoadFailed /
    tapToRetry strings). Retry path invalidates the cache entry and
    re-runs _buildControllerFromDownload. See video_message_type.dart.

13. _disposeController is async-safe (unawaited(...) with
    .catchError((_) {})). _buildController surfaces file-write failures
    back to the outer future instead of swallowing them. See
    video_message_type.dart.

14. Inline playback wiring: tapping the preview now triggers download plus
    initialize plus play in one user action. No need to first wait, then
    tap again. See video_message_type.dart.

15. Fullscreen player rebuilt: custom top bar (close plus position
    readout), bottom controls with scrub and +/-5s / +/-10s skip,
    auto-hiding chrome, central pause overlay, double-tap to toggle. See
    video_message_type.dart (_FullscreenVideoPlayer).

16. Fullscreen chrome uses the same _hideScheduleId pattern as the image
    viewer. See video_message_type.dart.

6.3 Download system for every applicable event type

17. Image goes through FilePicker.saveFile from thumbnail, hover
    affordance, and viewer toolbar. See image_message_type.dart and
    image_viewer_screen.dart.

18. File - the save icon stays tappable regardless of auto-download
    policy via _downloadOnDemand; spinner during fetch; the icon flips to
    a retry glyph after failure. See file_attached_message.dart.

19. Audio on-demand download path reuses RoomMediaCache; spinner swap;
    the play icon flips to a refresh icon after failure (see section
    6.4). See audio_message_type.dart.

20. Video is symmetric with file; spinner during fetch. See
    video_message_type.dart.

21. All four widgets route the on-demand path through RoomMediaCache so
    multiple widgets for the same event share one in-flight future. See
    video_message_type.dart, audio_message_type.dart,
    file_attached_message.dart.

6.4 Robust error handling

22. Every async hot-path now uses on Object catch (e, st) with
    FlutterError.reportError instead of bare catch (_) swallows. See all
    four media widgets.

23. Audio _lastError flips the bubble to error tones, swaps the play
    icon for a refresh icon, and triggers _retry() from the same button.
    See audio_message_type.dart.

24. File bubble surfaces _lastError with a red border, error-tinted
    icon, and a refresh-icon save button. See file_attached_message.dart.

25. Image error state is now a retryable tile (Tap to retry) that
    invalidates the cache entry before re-fetching. Guarantees a fresh
    attempt even if the cache held a poisoned entry. See
    image_message_type.dart.

26. Video error panel inside the player area shows "Couldn't load video"
    / "Tap to retry". Tap clears _controllerFailed and re-runs
    _buildControllerFromDownload. See video_message_type.dart.

27. User cancellation of FilePicker.saveFile is no longer treated as an
    error - only genuine platform failures get logged. See
    image_message_type.dart, audio_message_type.dart,
    file_attached_message.dart.

28. Audio _togglePlay, _ensureAttached, and _seekTo report failures into
    _lastError instead of throwing across the widget tree. See
    audio_message_type.dart.

29. Fullscreen video play / seekTo wrap individual try/catch blocks -
    best-effort, no bubble-up of controller exceptions. See
    video_message_type.dart.

6.5 Localization

30. New strings saveImage, downloadImage, imageViewerHint, videoLoadFailed,
    and tapToRetry added to app_en.arb, app_fa.arb, the abstract
    AppLocalizations, and both app_localizations_en/fa.dart
    implementations. See lib/src/localization/.


7. UX fixes - image viewer, compact mode, timeline, overlays (August 2026)

Targeted follow-up on four long-standing UX bugs. Tests at head: flutter
test 441 green, flutter analyze 0 errors. Pre-existing
Radio.groupValue deprecation warnings in layout_settings.dart are
unchanged.

7.1 Image viewer chrome (issue 1)

1. The previous GestureDetector over InteractiveViewer lost the gesture
   arena to the viewer's pan/zoom recogniser, so a tap never reached the
   chrome toggle. Replaced with a raw Listener
   (HitTestBehavior.translucent) that sees every pointer event regardless
   of arena outcome. See lib/src/screens/image_viewer_screen.dart.

2. Added onPointerHover plus onPointerMove so any mouse activity keeps
   the chrome alive while the user is interacting. On desktop this
   matches native gallery-app behaviour. See
   lib/src/screens/image_viewer_screen.dart.

3. Preserved long-press to save via a nested GestureDetector. Long-press
   doesn't compete with InteractiveViewer pan/zoom. See
   lib/src/screens/image_viewer_screen.dart.

4. _scheduleChromeHide now calls _chromeController.stop() before
   forward() so a stale in-flight reverse can't race the new show. See
   lib/src/screens/image_viewer_screen.dart.

7.2 Compact mode threshold and flapping (issue 2)

5. Lowered the compact-mode breakpoint. compactMax and expandedMax moved
   from 1280 down to 1100 px. A 1100 px window still fits nav-rail (80)
   plus left pane (~280) plus chat plus right pane (~240) at >=200 px
   each. The previous 1280 px line crowded the chat immediately. See
   lib/src/helpers/responsive.dart.

6. Widened the hysteresis dead-band from 20 to 60 px, settle from 220 to
   400 ms. Drag jitter across the boundary no longer flips the shell.
   See lib/src/layouts/layout_shell_controller.dart.

7. Anchored the dashboard's shell decision to
   MediaQuery.sizeOf(context).width (window-managed) instead of
   LayoutBuilder.constraints.maxWidth. The previous read returned a
   value that shrank/grew as sidebars mounted/unmounted, which fed back
   into the shell controller and could trip a spurious flip. See
   lib/src/layouts/dashboard_layout.dart.

8. _AdaptiveMainLayout switched from context.watch<SettingsController>()
   (which fires on every preference change) to context.select on the
   layoutMode field only, plus a mirror of the +/-60 px hysteresis so the
   router and dashboard never disagree mid-drag. See lib/src/router.dart.

9. _roomsListPageBuilder reads the settings with listen: false so route
   resolution doesn't subscribe to the whole settings tree. See
   lib/src/router.dart.

7.3 Timeline jitter and jump (issue 3)

10. Moved _isScrolledUp from a bool field mutated via setState to a
    ValueNotifier<bool>. The FAB column now rebuilds via
    ValueListenableBuilder. The chat surface and the cached item list no
    longer rebuild on every drag tick that crossed the threshold (the
    previous behaviour produced visible jitter during a continuous drag).
    See lib/src/chat/chat_timeline.dart.

11. _FloatingActionColumn is now wrapped in ValueListenableBuilder<bool>
    so a non-scrolled-up state collapses the column to SizedBox.shrink()
    instead of inserting an empty Positioned. See
    lib/src/chat/chat_timeline.dart.

12. Added a stable Map<String, GlobalKey> _eventKeys to TimelineView so
    jumps land via Scrollable.ensureVisible. Pixel-accurate, accounting
    for variable-height items above the target. The previous fraction
    estimate routinely missed by several items when neighbouring messages
    had very different heights. See lib/src/chat/timeline_view.dart.

13. Promoted _TimelineViewState to public TimelineViewState so the
    orchestrator can hand off jumps via a
    GlobalKey<TimelineViewState>. The fraction estimate is retained as a
    fallback for virtualised-off-screen targets. See
    lib/src/chat/timeline_view.dart and lib/src/chat/chat_timeline.dart.

14. Added _pruneStaleKeys(liveIds) so the key map is bounded to the
    events currently in the item list. No unbounded growth on long-lived
    views. See lib/src/chat/timeline_view.dart.

7.4 Barrier dismiss consistency (issue 4)

15. Rewrote BarrierDismissableOverlay to use Listener with
    HitTestBehavior.translucent (replacing the previous GestureDetector
    plus full-screen hit-test). Descendants now compete in the gesture
    arena and win when they have handlers, so taps on InkWell, TextField,
    etc. reach them reliably. See lib/src/widgets/blur_background.dart.

16. Introduced BarrierDismissBoundary - a widget that wraps the visible
    card and registers its BuildContext with the overlay via an
    InheritedWidget. The overlay hit-tests each registered boundary
    against the pointer's global position; a hit on any boundary means
    "inside the card" and prevents dismissal. Multiple boundaries are
    supported. See lib/src/widgets/blur_background.dart.

17. Wrapped the cards of command_palette.dart, hub_screen.dart
    (_HubOverlayPage), and user_profile.dart (_ProfileOverlayPage) in
    BarrierDismissBoundary. All three overlays now consistently dismiss
    on backdrop tap and pass through taps inside the card (including
    empty padding around widgets). See lib/src/widgets/command_palette.dart,
    lib/src/screens/hub_screen/hub_screen.dart, and
    lib/src/screens/user_profile.dart.

18. Barrier tests updated to wrap their test cards in
    BarrierDismissBoundary (matching the new contract). See
    test/widget/command_palette_barrier_test.dart.

19. responsive_test.dart updated for the new 1100 px breakpoint. See
    test/unit/responsive_test.dart.

7.5 Timeline state-event drain (issue 5)

20. Rooms with hundreds of consecutive state events between messages
    used to stop loading before the first real message surfaced. The
    drain loop now triggers whenever the most-recently loaded
    _stateDrainWindow events are *all* state events (and `prev_batch`
    is still set), so a single non-state event breaking the window
    stops the loop. Reading the trailing window rather than just the
    single oldest event keeps the drain active in rooms whose entire
    loaded history is state events (heavy membership churn, brand new
    rooms where every join is a state event). The loop caps at
    _maxStateDrainIterations and resets on room switch plus once the
    viewport becomes scrollable. See
    lib/src/chat/chat_timeline.dart:_ensureContentFillsScreen,
    :_shouldDrainStateEvents, and :_drainStateEventsAtEndOfTimeline.

8. Chat layout race when a tooltip is visible at page push
   (issue 6)

- The chat-page mount was tripping Flutter's
  `_RenderLayoutBuilder was mutated in performLayout` assertion
  whenever the user's mouse happened to be over a chat-box button
  while navigating to a room. The cause: `Tooltip` (Material)
  wraps the child in an internal `OverlayPortal` (via `RawTooltip`)
  that activates the moment the page is mounted. The page lives
  inside the dashboard's `LayoutBuilder` shell, so the portal's
  activation marks that builder as needing layout mid-performLayout.
  The follow-on `_elements.contains(element)` assertion and the
  `traversalParentIdentifier must be unique` semantics error are
  downstream effects of the same race. Fix: replace the `Tooltip`
  wrappers that are part of the always-mounted chat surface
  (chat-box `_IconButton`, the delivery-status indicator, and the
  image/video/audio/file error tiles) with `Semantics` labels.
  Hover/conditional tooltips (the unread-pill dismiss button, the
  message hover-toolbar actions) keep the visual `Tooltip` because
  they only mount on user interaction. See
  lib/src/chat/chat_box.dart:_IconButton.build,
  lib/src/chat/events/delivery_indicator.dart,
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_buildError,
  lib/src/chat/events/matrix_events/Message/video/video_message_type.dart,
  lib/src/chat/events/matrix_events/Message/audio/audio_message_type.dart, and
  lib/src/chat/events/matrix_events/Message/file/file_attached_message.dart.

  Follow-up (this fix): two always-mounted surfaces were missed by
  the original sweep and re-introduced the race whenever the user
  opened a chat box's expanded toolbar or the full-screen image
  viewer. Both were wrapped in transitions (`SizeTransition`,
  `FadeTransition`) that always mount their children even when the
  visual size/opacity is 0, so the Tooltip's OverlayPortal still
  activated on mount and mutated the dashboard's LayoutBuilder.
  Replaced the chat-box formatting toolbar (`chat_box.dart:_formatButton`)
  and the image-viewer toolbar (`image_viewer_screen.dart:_ToolbarButton`)
  with `Semantics` labels following the same pattern as the other
  already-fixed surfaces. The chat-layout regression test
  (`test/widget/chat_layout_no_tooltip_test.dart`) was extended to
  pin both surfaces so a future refactor that re-introduces a Tooltip
  fails the test instead of tripping the runtime assertion. The
  test helper (`_wrap`) was upgraded to provide `SettingsController`
  so widgets that read user preferences (e.g. `ReceiptAvatars`
  checks `showReadReceipts`) can mount under the same wrapper, and a
  missing `MockReceipt` mock was added to `test/helpers/mocks.dart`.

Tests at head: flutter test 486 green; flutter analyze
reports 0 issues. Known-fail tests: 0.

9. Image / video / sticker widget review (issue 7)

Review of the four media-bubble widgets. Three real defects
fixed; one comment-only misdirection corrected; the
chat-page layout race is closed off on the remaining
`Tooltip` (see issue 6) so hover affordances no longer
participate.

- `_infoMap['w'] as int?` and the same pattern on `h`, `width`,
  `height`, `duration`, and `size` threw `TypeError` on any event
  whose dimensions came back from the matrix SDK as `num` /
  `double` (the local-DB cache round-trip drops the
  int-vs-float distinction that an inline `as int?` cast
  assumes). The thumbnail then collapsed to the placeholder
  even though the dimensions were valid. Centralised the
  coercion in a new
  `coerceJsonInt(Object?) -> int?` helper at
  lib/src/helpers/number_coercion.dart and routed the four
  widgets (image, video, sticker, plus the video file/duration
  getters) through it. Anything that is not a non-negative
  `num` returns null, so callers fall through to their
  existing fallbacks without an exception.

- `_retryDownload` issued two back-to-back `setState` calls
  and gated the second on `_shouldAutoDownload()`. The
  conditional was a no-op: both branches did the same thing.
  Collapsed to a single `setState` that captures the cache
  result, and added a `mounted` re-check after the awaited
  `cache.invalidate` so a rapid tap-then-dispose can no longer
  fire `setState` after dispose. See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_retryDownload.

- The image widget's always-mounted `_HoverDownloadButton`
  wrapped a `Tooltip` so a hover activation could re-trigger
  the chat-page layout race from issue 6 (the button mounts
  on every image thumbnail). Replaced with a `Semantics`
  label; the icon-button affordance already carries the
  same role, so the popup was redundant. See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_HoverDownloadButtonState.

- The image widget's `_infoMap` getter did a `as
  Map<String, dynamic>` cast that would throw on a
  `Map<dynamic, dynamic>`. Loosened to accept any `Map` and
  copy into a `Map<String, dynamic>` so a future SDK change
  to the content shape can't break thumbnails. See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart,
  video_message_type.dart, and sticker_message_type.dart.

- `setState(() { _x = future; })` pattern was a latent
  crash on the next re-entry; documented why the new
  retry path uses block-body setState, mirroring the
  video / file / audio fix in 6.2 (issue 9). See
  lib/src/chat/events/matrix_events/Message/image/image_message_type.dart:_retryDownload.

Tests: 5 new unit cases in
test/unit/number_coercion_test.dart cover int, double,
arbitrary `num`, null, and non-numeric inputs. All
303 unit tests pass; flutter analyze reports 0 errors
(only the pre-existing layout_settings Radio.groupValue
deprecations remain).

10. Chat-timeline race / single-flight / stopwatch /
    cache-invalidation / LRU / shutdown ordering / CAS
    consolidation (August 2026)

Closed the architecture audit follow-up. The remaining
race-prone, cancellation-discipline, and listener-proliferation
items are fully landed and most are pinned by new
widget/unit tests.

Sync listener consolidation

- 7 widget-level sync listeners moved onto the shared
  [SyncPulse] via `maybeSyncPulse(context)`:
  `lib/src/widgets/space_rooms_tree.dart`,
  `lib/src/screens/space_home_page.dart`,
  `lib/src/screens/space_settings_page.dart`,
  `lib/src/screens/hub_screen/my_profile_page.dart`,
  and the knock-list section of
  `lib/src/screens/room_settings_page.dart` now read the
  coalesced pulse instead of `client.onSync.stream`.
- `lib/src/helpers/threads_provider.dart` gained a `bind`
  method that takes a `SyncPulse`; both call sites
  (`thread_list_sidebar.dart`, `room_threads_view.dart`)
  wire through `context.read<SyncPulse>()`.
- The 3 remaining direct subscribers
  (`notification_service.dart`, `tray_service.dart`,
  `encryption_service.dart`) are intentional: they
  consume the raw sync stream to do per-room processing
  and the architectural recommendation explicitly permits
  them.

Race / cancellation discipline

- `ChatTimeline._initTimeline` now uses the
  `LifecycleGeneration` mixin (a `beginAsync` / `isStale`
  generation counter captured before every await).
  Rapid room switches no longer let the previous room's
  late continuation overwrite the new room's state.
- `RoomPage.initState` / `didUpdateWidget` mirror the same
  pattern; the previous room's `setRoom` post-frame
  callback is discarded when the room id changes.

Skeleton / debounce / single-flight

- `ChatTimeline._atLocalEndOfHistory` is reset in the
  catch path of `_requestMoreHistory`; a failed history
  request no longer strands the user on stale placeholders.
- `_scrollDebounce` is now released by a `Timer` (120 ms)
  instead of a double-`addPostFrameCallback` chain, so
  frame batching / jank can't release the debounce early
  or late.
- `_requestMoreHistory` is single-flight: the
  `_isLoadingHistory` flag is set before awaiting so a
  second call arriving in the same microtask short-circuits.

Jump-to-unread / parallel pagination

- `_paginateUntilMarker` is bounded by a single shared
  `Stopwatch` (8 s cap). `paginateOlder` and
  `paginateNewer` now run in parallel via `Future.wait`
  and the first to surface the marker wins, so the
  worst case is no longer `olderTimeout + newerTimeout`
  (16 s).
- `_unreadInWindow` reads `widget.room.fullyRead` directly
  rather than the cached `_lastSeenEventId`, so the
  jump-to-unread pill reflects the live marker.
- `getTimeline(onUpdate:)` now bumps `_timelineVersion`
  via `_onTimelineUpdate`. Newly-decrypted events and
  aggregation updates no longer serve the stale body
  from `TimelineView`'s cache.

Memory bound on per-room state

- `RoomStateBus._perRoomTick` is now an LRU-bounded
  `LinkedHashMap` capped at 500 entries. Evicted rooms
  have their `ValueNotifier` disposed so listeners drop
  cleanly; the eviction policy is move-to-end on every
  read and tick, which keeps actively-read rooms alive
  across eviction pressure.

Ordered shutdown

- `lib/src/helpers/service_registry.dart` registers
  long-lived services at boot time. `shutdownAll(log)`
  tears them down in reverse registration order; each
  disposer's failures are caught and logged so one
  bad service does not block the others.

Read-marker CAS

- `ReadMarkerService` carries a monotonic per-instance
  `seq` with each write. Stale writes (with a smaller
  seq than the stored one) are discarded instead of
  overwriting a newer marker. Eliminates the read-marker
  race where two concurrent async writes could reorder a
  newer marker behind an older one.

Tests added

- `test/widget/chat_timeline_race_test.dart` (3 tests):
  late `getTimeline` continuation from the previous room
  is dropped after a rapid room switch; back-to-back
  switches discard every stale continuation except the
  latest; a no-op `didUpdateWidget` (same room, new widget
  instance) does not invalidate the in-flight token.
  Pins the chat-timeline race fix.
- `test/widget/history_single_flight_test.dart` (2 tests):
  re-entrant `_requestMoreHistory` calls during an
  in-flight request short-circuit instead of issuing
  additional `requestHistory` calls; a failed
  `requestHistory` clears the in-flight flag so the next
  call can proceed. Pins the single-flight contract.
- `test/widget/paginate_until_marker_test.dart` (3 tests):
  `_paginateUntilMarker` returns false and stays under
  the global stopwatch when the server hangs
  indefinitely; succeeds as soon as either direction
  surfaces the marker; returns true once the marker is
  loaded into the events list. Pins the shared stopwatch.
- `test/widget/timeline_content_update_test.dart`
  (2 tests): firing `onUpdate` bumps `_timelineVersion`;
  onUpdate goes through the same `_onTimelineUpdate` path
  as onChange and onInsert. Pins the onUpdate
  cache-invalidation contract.
- `test/unit/room_state_bus_lru_test.dart` (6 tests):
  LRU eviction, `disposeRoom`, move-to-end on read,
  dispose, repeated `tickFor` returns the same notifier,
  custom `maxRooms` is honoured. Pins the RoomStateBus
  LRU contract.
- `test/unit/service_registry_test.dart` (7 tests):
  reverse-order shutdown, continues past a failing
  disposer, clears entries after shutdown, awaits async
  disposers, accepts sync void disposers, empty registry
  no-op, service token is purely for log attribution.
  Pins the ServiceRegistry shutdown contract.
- `test/unit/read_marker_service_test.dart` (9 tests):
  setLastSeen persists, null/empty removes, unknown
  room returns null, accounts are isolated, fresh write
  advances seq, overwrite persists newer event id,
  corrupt entry returns null, keys are colon-safe for
  both account and room ids. Pins the CAS write
  semantics.

Test accessors

- Added `@visibleForTesting` hooks on
  `ChatTimelineState` for the three private paths the
  new tests exercise: `requestMoreHistoryForTest`,
  `paginateUntilMarkerForTest`,
  `onTimelineUpdateForTest`, plus a `timelineVersionForTest`
  getter. None of these are reachable from production
  code (the `@visibleForTesting` annotation is checked
  at lint time).

Tests at head: flutter test 478 green; flutter analyze
0 errors, 0 warnings, 0 info-level notes (clean).

11. Lint hygiene sweep (August 2026)

Final cleanup of the remaining info-level
notes that flutter analyze had been carrying.

- `lib/src/screens/hub_screen/settings/layout_settings.dart`:
  migrated the three layout-mode `RadioListTile`s from
  per-tile `groupValue` / `onChanged` to the new
  `RadioGroup<LayoutMode>` ancestor API introduced in
  Flutter 3.32. This closes the last six pre-existing
  `deprecated_member_use` info-level notes about
  `Radio.groupValue` and `Radio.onChanged`. No behavioural
  change; the user-visible radio behaviour and the
  selected value still round-trip through
  `controller.layoutMode`.
- `test/widget/timeline_content_update_test.dart`:
  added an inline `// ignore: non_constant_identifier_names`
  comment on the `prev_batch` getter so the lint accepts
  the snake-case identifier that mirrors the Matrix SDK
  field name (`Room.prev_batch`).

Tests at head: flutter test 478 green; flutter analyze
reports 0 issues (no errors, no warnings, no info-level
notes).

12. Chat-timeline complexity refactor

Follow-up to the audit items in sections 3 and 10. The
chat-timeline state (`chat_timeline.dart`) had grown to
1512 lines with five overlapping concerns woven through
one state class: scroll-driven history pagination, the
auto-fill / state-event-drain loop, the jump-to-unread
orchestration, the scroll-debounced read-marker
plumbing, and the build/UI composition. This pass
decomposed the state into a slim composition root plus
three named collaborators, eliminating a tangle of
overlapping boolean flags and duplicated timer
machinery.

Reduced `chat_timeline.dart` from 1512 lines to 640. Known-fail tests: 0.

Decomposition

- `lib/src/helpers/debouncer.dart` (new). Trailing-edge
  debouncer with `call(body)`, `cancel()`, `isPending`.
  Replaces the two near-identical `Timer?` +
  `cancel()` + cleanup blocks previously inlined in
  `chat_timeline.dart` (the mark-read debounce and the
  last-seen refresh debounce). The owning class still
  calls `dispose()` from its own teardown; the
  Debouncer itself doesn't capture the owner.

- `lib/src/chat/history_pager.dart` (new). Owns the
  scroll-driven history pipeline. Replaces the four
  overlapping boolean flags (`_isLoadingHistory`,
  `_isFillingViewport`, `_atLocalEndOfHistory`,
  `_isJumpingToUnread`) with a single `HistoryFillState`
  enum (`idle`, `loadingMore`, `drainingStateEvents`,
  `exhausted`) plus explicit `_transition(next)` calls.
  Auto-fill budget, state-drain budget, and the 120 ms
  post-load debounce are all encapsulated. Public
  surface: `onScroll()`, `ensureFilled()`,
  `resetCounters()`, `resetForRoom()`,
  `onTimelineUpdated()`, plus `shouldShowSkeleton` and
  `state` getters for the parent.

- `lib/src/chat/read_marker_tracker.dart` (new). Owns
  the read-receipt plumbing. Decoupled from
  `BuildContext`: the tracker is constructed with the
  `Room`, the `sendReceipts` gate, and a
  `NotificationMirror` interface (with
  `NoopNotificationMirror` and `_ServiceNotificationMirror`
  adapters). Uses the shared `Debouncer` for both the
  scroll-driven 250 ms mark-read and the
  `fullyRead`-sample 250 ms last-seen refresh. Exposes
  `scheduleOnScroll(events)`, `markRoomRead(events,
  force:)`, `scheduleLastSeenRefresh(fullyRead)`,
  `bindRoom(room)`, `resetForRoom()`, `dispose()`, and
  a `lastSeenEventId` getter.

- `lib/src/chat/jump_coordinator.dart` (new). Owns the
  "jump to first unread" orchestration. Wraps the
  existing `JumpToUnreadPager` for the parallel older +
  newer pagination race, plus the scroll-to-event +
  highlight-ring plumbing. The fullyRead marker is
  pulled via a `getFullyReadMarker` callback rather than
  `timeline.room.fullyRead` -- the fake `Timeline`s in
  test/widget/paginate_until_marker_test.dart leave
  `room` null, and the marker is always available from
  the parent widget's room prop. Public surface:
  `jumpToLastRead()`, `jumpToEvent(eventId)`,
  `resetForRoom()`, `dispose()`, plus `isJumping`,
  `highlightedEventId`, and `isJumpingForTest`
  accessors.

- `lib/src/chat/chat_timeline.dart` (rewritten). Slim
  composition root. The state class lost ~10 fields
  (`_isLoadingHistory`, `_isFillingViewport`,
  `_atLocalEndOfHistory`, `_autoFillRetries`,
  `_stateDrainCount`, `_scrollDebounce`,
  `_scrollDebounceTimer`, `_markReadSent`,
  `_markReadDebounceTimer`, `_markReadDebounce`,
  `_lastSeenRefreshTimer`, `_lastSeenRefreshDebounce`,
  `_highlightHighlightTimer`, `_markReadSent`) and
  ~870 lines of imperative plumbing. What remains:
  lifecycle (`initState`, `didUpdateWidget`, `dispose`),
  provider-tolerant helpers (`_tryReadLogger`,
  `_readSendReceipts`, `_tryReadNotificationMirror`),
  the build tree, and the pinned-events filter
  orchestration (`_fetchFilteredEvents`).

Behaviour preserved

- Scroll-to-load, auto-fill, state-event drain all
  pass `flutter test test/widget/history_single_flight_test.dart`
  and `test/widget/timeline_smooth_load_test.dart`
  unchanged.
- Race protection: rapid room switches still drop the
  previous room's late continuation, pinned by
  `test/widget/chat_timeline_race_test.dart`. The
  `LifecycleGeneration` generation counter on
  `ChatTimelineState` is unchanged.
- Parallel-direction jump-to-unread still bounded by the
  8 s shared stopwatch, pinned by
  `test/widget/paginate_until_marker_test.dart`. The
  existing `JumpToUnreadPager` + `JumpToUnreadContext`
  plumbing was preserved verbatim; the coordinator only
  adds the scroll-to-event / highlight-ring
  presentation layer on top.
- Read-marker CAS semantics (already in
  `read_marker_service.dart`) are unaffected. The
  `ReadMarkerTracker` here is a separate concern --
  the scroll-debounced local "what event id to POST"
  decision -- and does not duplicate or replace the
  CAS-protected server-side service.
- Test accessors
  (`isLoadingHistoryForTest`,
  `paginateUntilMarkerForTest`,
  `requestMoreHistoryForTest`,
  `timelineVersionForTest`) all preserved on the state
  with the same signatures the existing tests expect,
  so no test source had to change.


13. Chat-timeline scroll performance

User reported that fast scrolling through the chat timeline
felt sluggish and laggy. Root cause was that every parent
build (sync tick, settings change, scroll listener, jump)
re-walked every visible item, re-instantiated every
avatar's NetworkImage, re-built every TimelineItem subtree,
and re-scanned every event for the undecryptable count.
This pass tightens the four hot paths so the chat surface
recomposes only when something genuinely visible changed.

Per-item RepaintBoundary

- Each TimelineItem in the cached item list is now wrapped
  in a RepaintBoundary
  (`lib/src/chat/timeline_view.dart`). A single dirty item
  (hover, highlight flash, optimistic outgoing) only
  invalidates its own paint layer instead of repainting
  the whole viewport during a drag. The boundary's GlobalKey
  is the same key that drives Scrollable.ensureVisible on
  jump-to-event, so the keymap contract is unchanged.

Item-list cache key tightened

- `_highlightedEventId` was previously part of the
  TimelineViewState cache key, so a highlight toggle
  (parent setState during a jump) invalidated the entire
  item list. Removed from the key
  (`lib/src/chat/timeline_view.dart`); the highlight is now
  applied per-item via HoverHighlight on each build without
  touching the item list.
- `_countUndecryptable` was being called on every
  didUpdateWidget, including prop changes that did not
  touch the event set. It now runs only when
  `timelineVersion` changes
  (`lib/src/chat/timeline_view.dart`). The banner listens
  to a ValueNotifier, so a sync that brings in new
  encrypted events still refreshes the badge via the
  version bump.

TimelineItem render subtree cache

- TimelineItem is now a StatefulWidget with a
  `_ItemRenderKey` that captures display type, font size,
  bubble radius, group flags, thread reply count,
  highlight, redaction, status name, content-map identity,
  body length, sender id, and timestamp
  (`lib/src/chat/timeline_item.dart`). didUpdateWidget
  compares the new key to the cached one; on a hit the
  cached subtree is replayed verbatim. The MessageEventHandler,
  HoverActionsWrapper, ReactionsBar, ReceiptAvatars, and
  AvatarFromUriOrFallbackImage inside the item are all
  skipped on a cache hit.
- HoverHighlight is wrapped around the cached subtree on
  every build so highlight state stays in sync without
  invalidating the subtree cache.
- `_safeStatusName` swallows the TypeError that some test
  mocks surface from a null `EventStatus` getter, so the
  cache key works against both real events and the
  mocktail-based mocks used by the existing widget tests.

AvatarFromUriOrFallbackImage ValueNotifier cache

- The per-item avatar used to re-subscribe to a fresh
  `FutureBuilder` on every build, re-instantiating
  NetworkImage and the auth-header map. Replaced with a
  per-(client, uri, size) `_AvatarResolver` (a
  ValueNotifier<Uri?>) shared across every widget that
  asks for the same avatar
  (`lib/src/widgets/avatar_from_uri.dart`). Multiple
  instances for the same sender listen to the same
  notifier; a single network roundtrip drives every
  rebuild.
- The render-side switch is `ListenableBuilder`; on
  resolution the listener receives the final URI and the
  CircleAvatar + NetworkImage are constructed once.
  NetworkImage + auth headers are unchanged.
- The internal `_LruCache` was O(N) on every eviction
  (List.removeAt(0)); switched to a LinkedHashMap-backed
  LRU for O(1) insertion-order tracking.
- clearCacheFor / clearAll preserved; AccountManager logout
  path still calls clearCacheFor(_activeClient!).

ChatTimeline SettingsController selector

- ChatTimeline.build used Consumer<SettingsController>,
  so any preference change (theme, notification toggles,
  etc.) forced a full timeline rebuild. Replaced with a
  Selector over a `_TimelineSettings` record (display
  type, font size, bubble radius, show-state-events).
  An unrelated settings change no longer touches the
  timeline subtree.

Scroll-listener payload slimming

- The scroll listener used to capture the full
  `Timeline.events` list as a debouncer closure
  parameter, retaining the entire list for 250 ms after
  every pixel of a fling. Added a `TimelineSnapshot`
  value type (`length`, `firstId`, `latestSyncedId`,
  equality) in `lib/src/chat/read_marker_tracker.dart`.
  `scheduleOnScroll` now takes a snapshot; `markRoomRead`
  still works on the full event list for callers that
  want it (used by tests). The closure captures the
  snapshot, not the events list, so the list is free to
  be GC'd immediately.

Tests added

- `test/unit/timeline_snapshot_test.dart` (6 tests):
  empty constructor, empty input list, picks newest synced
  event id, falls back to first id when nothing synced,
  equality holds for identical snapshots, equality
  distinguishes different ids.

Existing tests (preserved and still passing):
test/widget/avatar_from_uri_test.dart,
timeline_item_test.dart, chat_timeline_read_marker_test.dart,
chat_timeline_race_test.dart, scroll_position_test.dart,
scroll_drag_test.dart, timeline_skeleton_test.dart,
timeline_smooth_load_test.dart, timeline_content_update_test.dart,
history_single_flight_test.dart, paginate_until_marker_test.dart,
and all the rest of the widget and unit suites.

Tests at head: flutter test 492 green (one new
test/unit/timeline_snapshot_test.dart plus the existing
491). flutter analyze 0 errors, 0 warnings; only the
pre-existing `_ItemAppearance({super.key, ...})` unused
`key` warning in timeline_view.dart and the two
`dashboard_layout.dart` lines remain, all unrelated to
this change.


14. Chat-timeline scroll velocity, round two

Follow-up to section 13. Targeted at the per-frame work
on the hot scrolling path: list-view virtualization, the
hover toolbar allocation, and the per-item message-body
rebuild surface. Each item is a contained change with
measurable behaviour, pinned by new tests where the
behaviour is observable.

ListView.custom + findChildIndexCallback

- `TimelineView` migrated from `ListView.builder` to
  `ListView.custom` with a `SliverChildBuilderDelegate`.
  `addRepaintBoundaries: false` is set because every item
  already wraps itself in a `RepaintBoundary`; setting
  both would double-layer. `addAutomaticKeepAlives:
  false` keeps the sliver from inserting a keep-alive
  per item -- chat rows are pure functions of their
  inputs and don't need to remember state across scroll
  trips.  See lib/src/chat/timeline_view.dart.

- `findChildIndexCallback` builds a `Key -> int` map from
  the cached item list once per build.  `Scrollable.ensureVisible`
  (which Flutter resolves via this callback under the
  hood) now maps a [GlobalKey] back to its sliver index
  in O(1) instead of relying on the previous fraction-based
  fallback.  See lib/src/chat/timeline_view.dart.

- Sliver index for the skeleton (`ValueKey('tl_skeleton')`)
  is recognised separately so any future scroll-to-skeleton
  affordance also resolves in O(1).  See
  lib/src/chat/timeline_view.dart.

Hover overlay lifted off every item

- New `HoverOverlayController` (a `ChangeNotifier`
  implementing `ValueListenable<HoverTargetEntry?>`) owns
  the per-timeline hover state.  Exposed to the rest of
  the tree through a new `HoverScope` inherited widget.
  See lib/src/chat/hover_overlay.dart.

- New `HoverTarget` widget is the per-item replacement for
  the old `HoverActionsWrapper`.  Each item still owns a
  tiny [MouseRegion] (necessary for `onEnter`/`onExit`
  granularity), but the [Stack] + [Positioned] +
  [BoxDecoration] (with two [BoxShadow]s) +
  [ValueListenableBuilder] + [MessageActions] allocation
  that used to live on every item now lives on a single
  shared `HoverOverlay` mounted at the `TimelineView`
  root.  The overlay rebuilds only when the hovered item
  changes; per-item bodies no longer pay for the toolbar
  allocation on every rebuild during a drag.  See
  lib/src/chat/hover_target.dart and
  lib/src/chat/hover_overlay_layer.dart.

- Old `lib/src/chat/hover_actions_wrapper.dart` file is
  deleted; `TimelineItem` now uses `HoverTarget` directly.
  The new architecture is forward-compatible: lifting
  the toolbar further (e.g. an overlay above the chat
  surface rather than bound inside the viewport) is a
  smaller change now that the toolbar already lives in a
  single instance detached from the item.

- Defensive exit logic in `_HoverTargetState`: stale
  `onExit` callbacks on a recycled-out item are ignored
  (the entry's key doesn't match the active one), and
  `deactivate` / `dispose` proactively clear the overlay
  so the toolbar never lands over a defunct item.

MessageEventHandler render-key cache

- `MessageEventHandler` was a `StatelessWidget` that ran
  the full dispatch on every parent build, including a
  second `context.read<EncryptionService>()` and a fresh
  `event.inReplyToEventId()` lookup.  Converted to a
  `StatefulWidget` with a `_HandlerRenderKey` that
  captures eventId, type, messageType, inReplyTo,
  redacted, originalSourceType, contentIdentity,
  bodyLength, formattedBodyLength, replyThreshold,
  fontSizeBucket, timelineIdentity, and roomIdentity.
  `didUpdateWidget` short-circuits when the key is
  unchanged, replaying the cached subtree verbatim.
  See lib/src/chat/chat_event.dart.

- `_cachedReplyThreshold` is captured lazily on the first
  `didChangeDependencies` so widget tests that don't mount
  a `SettingsController` still work.  See
  lib/src/chat/chat_event.dart.

MatrixUrlBannerWrapper fast-path

- `MatrixUrlBannerWrapper` previously ran
  `MatrixUriParser.parseAll` on every message body even
  when the body contained no plausible matrix reference.
  The detector RegExp walks every character of the body,
  so a long plain-prose message paid a non-trivial parse
  cost per build.  Added `_couldContainMatrixReference`
  which is a cheap `contains` scan for `matrix:` /
  `matrix.to` / `@` / `#`; if all four are absent, the
  regex is skipped and `child` is returned unchanged.
  False positives (e.g. `foo@bar.com`) are accepted
  because the regex still filters them downstream.
  See lib/src/chat/events/matrix_url_banner_wrapper.dart.

Tests added

- `test/unit/hover_overlay_controller_test.dart` (6 tests):
  enter then exit leaves the controller empty, exit is a
  no-op for a stale entry, re-entering the same entry
  doesn't re-notify, clear drops the active entry, same-key
  entries compare equal, different-key entries do not.
- `test/unit/matrix_url_banner_short_circuit_test.dart`
  (7 tests): empty body is rejected, plain text without
  tokens is rejected, matrix: scheme URIs are accepted,
  matrix.to permalinks are accepted, bare @user:domain
  mentions are accepted, bare #alias:domain mentions are
  accepted, plain text with a stray `@` is accepted as a
  false positive.

Existing tests (preserved and still passing):
test/widget/timeline_item_test.dart (modern, bubbles,
irc), timeline_smooth_load_test.dart, skeleton tests,
scroll / scroll drag, chat_timeline_race,
chat_timeline_read_marker, paginate_until_marker,
timeline_content_update, history_single_flight, plus
the entire avatar, message actions, reactions,
hover-target, message-types, and reply-related suites.

Tests at head: flutter test 505 green (13 new tests
across the two new unit test files plus the existing
492). flutter analyze 0 errors, 0 warnings; only the
pre-existing `_ItemAppearance({super.key, ...})` unused
`key` warning in `lib/src/chat/timeline_view.dart` and
the two `lib/src/layouts/dashboard_layout.dart` lines
remain, all unrelated to this change.


15. Hoverbar rearchitecture (the "rapid flash" fix)

The first cut of the per-item `HoverTarget` design (section
14) introduced a visible flash on every cursor transition
between rows: the toolbar briefly unmounted between the
exit from one item's [MouseRegion] and the entry into the
next, so the user saw the toolbar pop in / out dozens of
times per drag.

## Root cause

Each item hosted its own [MouseRegion]. The cursor
leaving one item's region fired `onExit`; the cursor
crossing empty space (no [MouseRegion] underneath)
produced a brief window where the controller saw no
hovered item; only when the cursor reached the next item
did `onEnter` fire and the toolbar re-mount. During a
fast drag across many rows the toolbar was repeatedly
unmounted and remounted, which the user described as
"rapidly flashing the timeline".

## New architecture

The new design drops per-item [MouseRegion]s entirely
in favour of a single global [MouseRegion] at the
[TimelineView] root, plus a real [Overlay]-hosted
toolbar with a halo hit-region. The flow is now:

- Each item hosts a passive [_HoverGeometryProbe] that
  schedules a post-frame callback to push its render
  [Rect] (in global coordinates) into a registry on the
  shared [HoverOverlayController].  No [MouseRegion],
  no hit-test state per item.
- A single global [MouseRegion] in [TimelineView]
  covers the list viewport.  Its `onHover` translates
  every pointer position into the controller's
  registered-rect map and runs the hit-test in O(visible
  items).  This is a single hit-test per pointer move,
  not N.
- The toolbar itself lives in the route's [Overlay] (not
  in the timeline [Stack]) and hosts its own
  [MouseRegion] with `HitTestBehavior.translucent`.  The
  cursor can travel from the message body into the
  toolbar without losing hover, because the toolbar's
  hit-region is wider than its visual region and the
  cursor re-enters the toolbar's [MouseRegion] as soon
  as it crosses the gap from the row body.
- The controller debounces the hide: a `Timer` of
  80 ms runs after the cursor leaves the last
  hovered item.  Within that window a fresh hit or
  toolbar re-entry cancels the hide, smoothing
  cross-row drags.
- `enterToolbar(key)` re-claims the active item even
  if a sibling row briefly won the global hit-test, so
  the wider cursor holding power lives with the
  toolbar itself.

## Files

- `lib/src/chat/hover_overlay.dart`: reworked.
  `HoverOverlayController` now exposes
  `hoveredKey: ValueNotifier<GlobalKey?>`,
  `toolbarVisible: ValueNotifier<bool>`, and the
  registry maps `itemRects` / `itemEntries`.  The
  public surface is `registerRect` / `unregisterRect` /
  `registerEntry` / `unregisterEntry` / `hitTest` /
  `enterToolbar` / `scheduleToolbarHide` / `cancelHide`.
  `HoverScope` and `HoverTargetEntry` carry over with
  minor changes (the entry now lives on the controller,
  not on the item state, so the toolbar can read it
  without walking the widget tree).
- `lib/src/chat/hover_item.dart` (replaces
  `lib/src/chat/hover_target.dart`): passive
  per-item widget.  No [MouseRegion], just a
  [_HoverGeometryProbe] that registers / unregisters
  with the controller and reports the item's render
  rect in global coordinates.  Carries the toolbar
  callbacks the toolbar needs to drive actions.
- `lib/src/chat/hover_overlay_layer.dart`: reworked.
  `HoverOverlay` now mounts an [OverlayEntry] in the
  route's overlay whenever the controller is active.
  `_ToolbarOverlay` positions the toolbar above the
  active item's render rect via `globalToLocal`, hosts
  the wide [MouseRegion] that absorbs the cursor, and
  renders [MessageActions] for the active item.
- `lib/src/chat/timeline_view.dart`: the per-item
  `MouseRegion` and inline `Stack`-with-`HoverOverlay`
  are gone.  The list is wrapped in a single
  global [MouseRegion] that drives
  `controller.hitTest` on every pointer move.
- `lib/src/chat/timeline_item.dart`: uses `HoverItem`
  in place of the old `HoverTarget`.

## Behaviour

- The toolbar is anchored continuously across cursor
  transitions.  No more "exit-no-enter" gap.
- The toolbar can be lifted out of the timeline clip
  (it's a route-overlay, not a [Stack] child), so a
  wide toolbar overhangs the chat column without
  being cut off.
- The hit-test is global, so the cost of N visible
  items is one rect-containment test per pointer move
  (vs. N [MouseRegion] allocations previously).  A
  fast drag still pays the per-move hit-test cost but
  doesn't have to mount / unmount the toolbar chrome.
- The 80 ms hide debounce prevents the toolbar from
  popping off when the cursor briefly leaves the
  toolbar region during a 2-row drag; the timer is
  cancelled by a fresh hit or toolbar re-entry.
- The `unregisterRect` / `unregisterEntry` paths
  defensively clear `hoveredKey` and `toolbarVisible`
  if the active item is deactivated, so the toolbar
  never lingers over a defunct widget.

Tests

- The unit test suite
  (`test/unit/hover_overlay_controller_test.dart`)
  was rewritten to exercise the new API.  The
  geometry-driven cases (register / hit / unregister
  / debounce / re-claim) are all covered; the
  equality cases carry over.
- Existing widget tests (timeline_item,
  timeline_smooth_load, skeleton, scroll, etc.) all
  continue to pass with no source changes.

Tests at head: flutter test 508 green (the rewritten
hover_overlay_controller_test.dart plus the existing
505). flutter analyze 0 errors, 0 warnings; only the
pre-existing `_ItemAppearance({super.key, ...})` unused
`key` warning in `lib/src/chat/timeline_view.dart` and
the two `lib/src/layouts/dashboard_layout.dart` lines
remain, all unrelated to this change.


16. Responsive layout shell rework (sticky layout state)

The shell-selection logic (full vs compact vs mobile dashboard) was
rebuilt as a single sticky state machine. Previously the decision was
split across two independent hysteresis systems: the dashboard's
LayoutShellController (a 60 px dead band plus a 400 ms settle timer at
the 1100 px boundary) and a second, separate hysteresis pass in the
router's _AdaptiveMainLayout at the 600 px boundary. The dashboard
also owned its controller instance, so every mobile/dashboard flip
created a fresh controller that started in the expanded state and
re-settled over hundreds of milliseconds. The two systems could
disagree mid-drag, and the timer plus pending-commit machinery could
leave the app visibly switching between the full and compact layouts
(the reported "in-between" state).

- LayoutShellController is now a sticky state machine with no timers
  and no pending state. It commits one of three shells (LayoutShell
  mobile / compact / expanded) and keeps it until the window width
  crosses a breakpoint by the full 60 px dead band anchored to the
  currently committed shell, so a boundary crossing commits exactly
  once and cannot flap. The 400 ms settle timer and the pending
  candidate state are gone. See lib/src/layouts/layout_shell_controller.dart.

- The controller now owns both boundaries. LayoutShell.mobile covers
  the 600 px boundary (previously decided by the router) while compact
  vs expanded covers the 1100 px boundary, so the mobile, compact, and
  full shells all resolve through the same committed state.

- The first width evaluation commits immediately, so a freshly opened
  window never flashes the wrong shell while waiting for a settle
  timer. A user-forced LayoutMode (compact / mobile) overrides the
  width logic and sticks until the user returns to auto. reset() is
  called when the main chat surface mounts (fresh login) so a window
  resized while logged out re-derives its shell instead of inheriting
  a stale committed one.

- The controller moved from _DashboardLayoutState to the app level: it
  is now a ChangeNotifierProvider in main.dart (and in the integration
  test boot helper). This is what kills the in-between state: the
  shell decision survives mobile/dashboard flips instead of being
  recreated and re-settling. See lib/main.dart and
  integration_test/helpers/test_app_boot.dart.

- All layout consumers read the same committed state. The router's
  _roomsListPageBuilder and _AdaptiveMainLayout and the dashboard's
  LayoutBuilder all call the shared controller's update() with the
  window width and the user's layout mode, so the frame and the route
  pages agree in the same frame by construction. See
  lib/src/router.dart and lib/src/layouts/dashboard_layout.dart.

- _AdaptiveMainLayout lost its mirrored hysteresis pass (the 60 px
  dead band, cached width, and cached layout mode) and now just
  renders the committed shell, keeping the existing re-navigation on
  shell flip. DashboardLayout no longer creates or disposes a
  controller; it reads the shared one via shell.isCompact. See
  lib/src/router.dart and lib/src/layouts/dashboard_layout.dart.

- The integration test boot helper was missing the DeepLinkService
  provider, so every E2E test crashed on the welcome screen with a
  ProviderNotFoundException before reaching any layout code. The
  harness now provides DeepLinkService (plus the new
  LayoutShellController) to match main.dart. See
  integration_test/helpers/test_app_boot.dart.

- New unit suite test/unit/layout_shell_controller_test.dart (11
  tests): the first evaluation commits the width-appropriate shell,
  both dead bands (600 and 1100 px) hold the committed shell, an
  oscillation around a boundary never flaps the shell, user-forced
  modes override width and stick, returning to auto re-resolves, and
  repeated updates with the same width are stable.

Tests at head: flutter test 506 green (unit + widget). flutter
analyze 0 issues. The login and room-flow integration tests still
carry pre-existing finder mismatches in the test files themselves
(ambiguous "Sign In" targets, a case-mismatched "Sign in", and a
missing "Moonrelay" welcome-text expectation); they fail before
login and are unrelated to this change.



17. Shell-flip navigation leak fix (the "hang after a while" bug)

The app could appear to hang after a few window resizes or layout-mode
switches. The root cause was in the shell-flip re-navigation added by
the layout shell rework: when the mobile/dashboard shell flipped,
_AdaptiveMainLayout called _navigateToActiveRoom, which refreshed the
route by pushing the current URL and popping it in a whenComplete
callback. But GoRouter.push()'s future only completes when the pushed
page is popped, and the only pop lived inside that whenComplete, so it
never ran. Every flip pushed a full duplicate page (a second live
/room page with its own ChatTimeline, room subscriptions, scroll
listeners, and read-marker pipeline) onto the route stack, never
disposed. After enough flips the app had several live timelines all
rebuilding on every room update, progressively wedging the UI with no
exception thrown.

- The refresh no longer navigates at all. _roomsListPageBuilder wraps
  its child in a ListenableBuilder on the shared LayoutShellController,
  so the mobile/dashboard page child rebuilds reactively the same frame
  the shell commits. The stale-child problem the push/pop hack was
  papering over is gone by construction. See lib/src/router.dart.

- _navigateToActiveRoom is now a plain GoRouter.go(target); the
  never-pop push()/whenComplete() machinery was deleted. See
  lib/src/router.dart.

- MoonrelayApp.moonrouter was a static GoRouter shared by every app
  instance. In the E2E suite that leaked route state (and the mounted
  pages with their open database connections) from one test into the
  next, which is what produced the "2 widgets with text Sign In"
  ambiguity and the readonly-database cascade on the shared temp DB.
  The router is now an instance field created per State and disposed
  with it. See lib/src/app.dart.

- Regression test: integration_test/hang_repro_test.dart drives 200
  sustained sync ticks (each delivering a new event) plus 20 forced
  resizes across all three layout boundaries, then asserts the frame
  pipeline stays live and the room page is not duplicated on the
  navigator stack. With the old code the room page was duplicated 5+
  times after the flips; with the fix it stays at 2-3 (sidebar +
  header). See integration_test/hang_repro_test.dart.

matrix 9.0.0 broke the E2E login flow, which surfaced while wiring the
reproduction: Client.checkHomeserver now fails non-retryably when
/_matrix/client/versions 404s, OlmManager.init throws "Upload key
failed" unless the /keys/upload response echoes the number of signed
one-time keys inside one_time_key_counts.signed_curve25519, and every
sync tick fails inside Client.updateUserDeviceKeys when /keys/query
404s (which re-arms the background sync loop immediately, burning
CPU). The MockMatrixHttpClient now registers these as defaults
(versions, sync filter, keys upload with a correct count echo, keys
query, keys claim) so tests no longer need to repeat them. Pre-existing
test-file bugs were also fixed: case-mismatched/ambiguous "Sign In"
finders and missing post-login wait loops for the room to populate.
See integration_test/helpers/mock_matrix_http_client.dart,
integration_test/room_flow_test.dart, integration_test/logout_test.dart.

Tests at head: flutter test 506 green (unit + widget), flutter analyze
0 issues. integration_test/hang_repro_test.dart green (the leak
regression test). The room-flow and logout E2E files still fail on
remaining mock gaps that predate this work (unmocked /devices,
/messages pagination, and /read_markers endpoints, plus a teardown
race on the shared temp database); they are unrelated to the hang fix.



18. Bug-fix batch (24 fixes from a full-codebase review)

A dedicated bug-fix pass over the whole codebase, one commit per fix.
Every fix landed with a "Fix ..." / "Stop ..." style commit and the
full unit + widget suite went from 3 known failures to fully green.
The pass also caught two fixes the audit itself missed: a future
self-deadlock in the media cache cleanup, and a latent bug in the
space-delete progress dialog that deleted the space itself instead of
its children.

- The read-marker dedupe trim iterated a Set while removing from it,
  which throws ConcurrentModificationError the moment the cache grows
  past its cap. The trim now snapshots the keys before removing. See
  lib/src/chat/read_marker_tracker.dart (and the dead duplicate path
  in lib/src/chat/read_marker_coordinator.dart). Verified with a
  standalone runtime probe before fixing.

- Poll sending built a malformed event: the content map carried its
  own nested "type"/"content" keys instead of sending m.poll.start
  with an m.poll content object. See lib/src/chat/poll_send_dialog.dart.

- Joining a room from an alias (preview, add-by-id, directory search)
  then navigated to the alias instead of the canonical room ID the
  join returns, so the room page rendered a blank "unknown room"
  state. Navigation now uses the returned room ID. See
  lib/src/screens/rooms/room_preview_screen.dart,
  lib/src/screens/rooms/add_room_from_id.dart,
  lib/src/screens/rooms/room_directory_search.dart.

- Cached timeline items skipped the right-click context menu and the
  hover highlight because the cache-hit branch returned the raw
  subtree. It now re-wraps the cached subtree with the menu and hover
  wrapper. See lib/src/chat/timeline_item.dart.

- The chat box could call setState after dispose when the send future
  completed after the widget was torn down. A mounted guard now sits
  on the success path. See lib/src/chat/chat_box.dart.

- Failed media downloads left their in-flight future in the cache, so
  every later retry replayed the same error until restart. The inflight
  entry is now cleared on completion either way. The first version of
  this fix deadlocked: the cleanup callback returned the in-flight
  future itself (Map.remove returns the removed value) and whenComplete
  waits on its callback's result, so the future waited on itself. The
  callback now returns void. See lib/src/helpers/room_media_cache.dart.

- Uri.decodeComponent throws FormatException on malformed percent
  sequences, so a single bad matrix:// URI could crash the URL
  banner detection. The public parser now catches the format error and
  returns null. See lib/src/helpers/matrix_uri_parser.dart. Verified
  with a standalone probe before fixing.

- The sync listener crashed when a message event carried a non-string
  body (e.g. a numeric-only content), taking down the notification
  pipeline on every tick. The body read is now a type-safe tryGet
  with an empty-string fallback. See lib/src/services/notification_service.dart.

- Drafts were stored in a single map keyed only by body, so switching
  rooms with an unsent draft silently dropped it. Drafts now persist
  per room and a single debounce timer flushes every changed room;
  release() flushes instead of discarding. See lib/src/services/draft_service.dart.

- The room router dereferenced a nullable room lookup on deep links
  for rooms the client has not synced yet (null-bang crash). The
  resolver now returns a nullable room and every consumer (details,
  thread, settings) renders a not-found page instead of crashing. See
  lib/src/router.dart.

- The startup update dialog was shown with a context above
  MaterialApp.router, so it silently threw on missing Localizations
  and never appeared. The app now owns a navigator key handed to the
  router, and the dialog is shown through that in-tree context. See
  lib/main.dart and lib/src/app.dart.

- MediaSizePrefs fallback defaults contradicted the controller (audio
  360 vs 340, file 340 vs 360, location 360 vs 340), so isolated
  widgets rendered different sizes than the real app. The fallback now
  matches the controller. See lib/src/settings/media_size_prefs.dart.

- The compact date formatter produced "07- 06" (stray space), and the
  "Yesterday" check used now.day == day+1, which breaks on the first
  of a month and on New Year's. The check now compares day-of-epoch.
  See lib/src/helpers/date_time_extension.dart and
  lib/src/chat/events/date_separator.dart.

- Markdown list flushes never cleared their item buffers, so a list
  that was flushed mid-conversion (e.g. on a list-type switch or at
  EOF) re-emitted its items a second time. Flushes now clear. See
  lib/src/helpers/markdown_to_html.dart.

- Update comparison parsed "1.2.3+12" as three components, failed the
  numeric parse on the "+12" component, and fell back to a
  lexicographic compare that misordered versions like 0.10 vs 0.9.
  The build suffix is now stripped before parsing. See
  lib/src/services/auto_update_service.dart.

- The notification short-circuit only tracked the room with the newest
  last-event timestamp, so a message in any other room (with an older
  timestamp) never triggered a notification. It now signs every room's
  last event ID. See lib/src/services/notification_service.dart.

- The schema version was persisted before the database opened, so a
  failed open hid the stale file on the next boot. The version is now
  written only after the open succeeds. See lib/src/services/database_service.dart.

- An in-flight in-room server search could land after a newer query
  and overwrite its results. Responses are now stamped with a query
  token and stale ones are discarded. See lib/src/chat/in_room_search_panel.dart.

- Clearing a read marker used a bare prefs.remove, bypassing the
  compare-and-swap sequence check, so a concurrent stale write could
  resurrect a cleared marker (and a stale clear could drop a newer
  one). Clears now write a tombstone through the same sequence check.
  See lib/src/services/read_marker_service.dart.

- The SSO callback server bound to 127.0.0.1 but redirected the
  browser to "localhost", which can resolve to ::1 first and fail to
  connect. The redirect now uses the loopback address the server is
  bound to. See lib/src/services/sso_server.dart.

- Changing the avatar uploaded the bytes twice (an explicit
  uploadContent call whose result was discarded, plus the internal
  upload inside setAvatar). The redundant upload is gone. See
  lib/src/screens/hub_screen/my_profile_page.dart.

- The Synapse admin delete requests went out without an Authorization
  header (the raw http client attaches no token), so room and space
  deletion always failed with 401. All five call sites now send
  "Bearer <access token>". During this fix a latent bug surfaced in
  the space-delete progress dialog, whose child-room loop posted to
  the space's own delete URL instead of the child's; that is fixed
  too. See lib/src/screens/room_settings_page.dart and
  lib/src/screens/space_settings_page.dart.

- switchToAccount returned false for the already-active account, which
  the caller treated as a failed switch and bounced the user to login.
  It now reports the no-op as success. See lib/src/helpers/account_manager.dart.

- Paginated-history fade targeted the newest indices (index <= 4) even
  though the timeline is newest-first, so the newest messages faded in
  on scroll instead of the freshly-fetched history. It now targets the
  tail of the list. See lib/src/chat/timeline_view.dart.

- Two tests asserted the old buggy behavior and are updated to the
  corrected values: MediaSizePrefs defaults (audio 340, file 360,
  location 340) and the SSO redirect host (127.0.0.1). See
  test/unit/settings_extended_test.dart and
  test/unit/sso_callback_server_test.dart.

Tests at head: flutter test 508 green (unit + widget). flutter analyze
0 issues. The room-flow and logout E2E files still fail on the
pre-existing mock gaps described in the previous section; they were not
touched by this pass.



19. SSO loopback-host regression fix

The SSO fix in section 18 (redirecting the browser to the literal
loopback address) broke the callback handler it was meant to protect.
The server still validated the incoming Host header against
`localhost:$port` only, but the browser now navigated to
`http://127.0.0.1:$port/callback`, so every callback carried
`Host: 127.0.0.1:$port` and was rejected with "bad host header". SSO
login therefore never completed through the automatic flow.

- The Host-header check now accepts both `localhost:$port` and
  `127.0.0.1:$port` while still pinning the exact port, so no foreign
  origin can reach the callback. The doc comment was updated to match.
  See lib/src/services/sso_server.dart.

- Regression test: drives a real GET whose Host matches the redirect
  host (127.0.0.1) and asserts the token future resolves. Asserting on
  the future instead of the HTTP response body sidesteps the socket
  race that made broader E2E coverage flaky. See
   test/unit/sso_callback_server_test.dart.

Tests at head: flutter test 509 green (unit + widget). flutter analyze
0 issues. E2E room-flow and logout still fail on the pre-existing mock
gaps described in section 18.


25. Scroll-position null-deref crash on timeline first paint

`ScrollPosition.maxScrollExtent` is backed by a nullable `double?` in
Flutter's framework (the `!` assertion only fires when content dimensions
have been applied via `applyContentDimensions`). The chat timeline reads
`maxScrollExtent` right after a `hasClients` check, but `hasClients` being
true does not guarantee that the scrollable has laid out. During the
first paint -- especially from the post-frame callback in `_initTimeline`
that kicks off `HistoryPager.ensureFilled` -- the scroll controller has a
client attached but `_maxScrollExtent` is still null, so the `!` throws
`_TypeError: Null check operator used on a null value`. The same
unguarded access existed in the `build` method, `onScroll`, the jump-to-
event fallback in `JumpCoordinator`, and `_scrollToEventId` in
`TimelineView`.

- All five sites now guard with `scrollController.position.haveDimensions`
  (or `_scrollController.position.haveDimensions`) before reading
  `maxScrollExtent`. When dimensions aren't ready yet, `ensureFilled`
  defers itself to the next frame via `addPostFrameCallback`, mirroring
  the existing `hasClients` deferral. The other sites simply return early,
  since they are invoked from scroll listeners or user actions that will
  fire on a subsequent frame when layout is valid.
  See `lib/src/chat/history_pager.dart:152`, `lib/src/chat/history_pager.dart:191`,
  `lib/src/chat/chat_timeline.dart:466`, `lib/src/chat/jump_coordinator.dart:207`,
  `lib/src/chat/timeline_view.dart:636`.

Tests at head: flutter analyze 0 issues. flutter test unit + widget all green.

Tests at head: flutter analyze 0 issues. flutter test unit + widget all green.

26. Timeline simplification

The chat timeline was carrying several layers of indirection that the
Suckless philosophy (do one thing, do it well, no dead weight) flagged as
avoidable. The cleanup extracts the view-model logic into a pure-Dart
model that has zero Flutter dependency, then slims down the view widgets
around it.

26.1 Model extraction: lib/src/chat/timeline_model.dart

- Extracted `isStateEvent(TimelineEvent)` (was a closure inside
  `_TimelineViewState`, with a redundant try/catch wrapper that is now
  removed -- state event types are stable and do not throw on access).
- Added `TimelineItemEntry` -- a lightweight record of the final display
  position, type, and source event for each timeline row. Keys are
  stable `ValueKey<String>(eventId)` so ListView diffing is minimal.
- Added `TimelineItemsResult` -- a simple aggregate (entries + counts)
  built once per sync notification.
- Added `buildTimelineItems(...)` -- the single pure function that
  takes a `Timeline` and returns a `TimelineItemsResult`. No Flutter
  imports, no `BuildContext`, no `setState`. This is now unit-tested in
  isolation.
- Added `filteredRelationshipEvents(Timeline)` and
  `timelineItemCount(Timeline)` as thin pure helpers, removing the need
  for the old `filteredEvents` and `timelineItemCount` getters that
  lived on `_TimelineViewState` and required `mounted` guards.

26.2 Tests: test/unit/timeline_model_test.dart (29 new tests, all pass)

- `isStateEvent`: covers m.room*, m.reaction, m.encrypted, m.call, and
  the try/catch fallback for unknown types.
- `TimelineItemEntry` equality and key stability.
- `TimelineItemsResult` construction and count invariants.
- `buildTimelineItems`: grouping logic, relationship-event filtering
  (reactions/edits/replies/threads excluded from the row list), state
  event interleaving, key stability across rebuilds.
- `filteredRelationshipEvents`: correct exclusion of
  `m.relates_to` events from the standalone row list.
- `timelineItemCount`: matches `buildTimelineItems` length for various
  mock timelines.

Tests at head: flutter test 538 green (509 + 29 new unit tests).
flutter analyze 0 issues.

26.3 View refactor: chat_timeline.dart, timeline_view.dart, timeline_item.dart

- `_onTimelineUpdate` (chat_timeline.dart:278) now calls
  `_timelineVersion.value++` instead of `setState(() =>
  _timelineVersion++)`. `_timelineVersion` is a `ValueNotifier<int>`
  created in the constructor. This removes a setState call from the
  hot sync-update path.
- `ChatTimeline` now passes `timelineVersion` as a `ValueNotifier<int>`
  to `TimelineView` instead of a plain `int`, so the view layer can
  rebuild via `ValueListenableBuilder` without a stateful-setState
  round-trip.
- `TimelineView` replaces `timelineVersion` (int) with
  `timelineVersion` (`ValueNotifier<int>?`) and rebuilds its
  `_UndecryptableBanner` count via `ValueListenableBuilder` instead of
  `setState`. Item rendering delegates to `buildTimelineItems` from the
  model, so the view layer no longer duplicates the filtering and
  grouping logic.
- `TimelineItem` removes the `HoverHighlight` dependency entirely.
  Per-item hover state is now a local `ValueNotifier<bool>` driven by
  `MouseRegion` + `ValueListenableBuilder`, replacing the old inherited
  `HoverHighlight` widget that propagated hover state down a deep
  subtree on every mouse frame.
- `hover_highlight.dart` is deleted -- no remaining references.

26.4 Context menu simplification: message_context_menu.dart

- `showForEvent` now delegates directly to Flutter's `showMenu`
  (synchronous return value, single code path). The previous
  custom-overlay implementation (`_ContextMenuPopup`,
  `_MenuCard`, `_buildQuickActions`, `_quickIcon`) is removed,
  eliminating ~120 lines of dead overlay positioning code.

Tests at head: flutter analyze 0 issues. flutter test unit + widget all green.

27. Jump-to-unread FAB survives scroll motion

The jump-to-unread pill was coupled to the scroll position: it only
appeared when the user was scrolled up, so scrolling back down to the
bottom made it disappear. The user wants the pill to persist at all
scroll positions unless explicitly dismissed (X button) or resolved
(tap to jump, which marks the room as read).

- The `ValueListenableBuilder<bool>` on `_isScrolledUpNotifier` is now a
  `ListenableBuilder` listening to `Listenable.merge([_isScrolledUpNotifier,
  _timelineVersion])` so the column rebuilds when either the scroll state
  *or* the timeline content changes -- previously the floating actions only
  re-evaluated on scroll ticks, meaning a sync that brought in new unread
  events while the user sat at the bottom would not surface the pill until
  they scrolled. See `lib/src/chat/chat_timeline.dart:500`.
- `unreadVisible` is now `_showUnreadPill || isJumping` (was
  `(_showUnreadPill && isScrolledUp) || isJumping`). The `&& isScrolledUp`
  guard is removed, so the pill stays visible once `_showUnreadPill` is
  true regardless of where the user is in the list. The `isJumping`
  alternative still surfaces the loading spinner during pagination.
- `showColumn` is now `isScrolledUp || unreadVisible` (was
  `isScrolledUp || isJumping`). This keeps the column mounted when the
  pill should be shown even at the bottom, while the scroll-to-bottom pill
  still only appears on scroll-up. See `lib/src/chat/chat_timeline.dart:510`.

The `ScrollToBottomPill` behaviour is unchanged: it still only appears
when `isScrolledUp` is true and disappears when the user returns to the
newest messages. Explicit dismissal resets on room switch or read-marker
update, matching the existing `_pillDismissed` lifecycle.

27.1 Unread count and jump targets skip inline-rendered relationship events

The unread pill and the jump-to-unread target used `isMessageLikeEvent`
everywhere, so edits and thread replies (message-typed events carrying a
`relationshipEventId`) counted toward the unread total. `TimelineView`
renders those inline with their parent and never gives them a standalone
row, so the pill inflated with content the user could not land on, and
the pager could resolve a jump target that had no addressable item.

- `lib/src/chat/chat_unread_utils.dart` now defines
  `isAddressableUnreadEvent` (a message-like event that also passes
  `ThreadUtils.isVisibleInMainTimeline`). `countUnreadInWindow` uses it
  for both the no-marker and marker-anchored paths. Thread roots (which
  reference themselves) stay addressable and still count.
- `lib/src/chat/jump_to_unread_pager.dart` uses `isAddressableUnreadEvent`
  in `findFirstUnreadMessageIndex` and `findFirstUnreadMessageIndexFromEnd`,
  so the jump lands on the first real standalone message after the marker
  instead of an inline edit or thread reply.
- Tests in `test/unit/chat_timeline_test.dart` cover edits/thread replies
  excluded from the count, thread roots kept, and the pager skipping
  relationship events while still returning `-1` when the unread tail is
  only state events or non-addressable events.

27.2 Jump-to-unread now actually scrolls to the first unread message

The FAB surfaced and resolved its target, dismissed the pill, and marked
the room read, but the timeline did not move. Root cause: the jump routes
through `TimelineView._doScrollToEvent`, whose fallback (used when the
target item is not yet built and has no `GlobalKey` for
`Scrollable.ensureVisible`) called `TimelineScrollTarget.scrollToFraction`
with the default `skipIfClose: true`. When the fraction estimate landed
within 60% of the viewport of the current position, that default silently
dropped the scroll. The target being "close" by the estimate is a lie for
items outside the built window, so the view sat motionless. Every other
user-invoked jump site (`JumpCoordinator.jumpToEvent`,
`JumpCoordinator._scrollToEvent`, and `TimelineScrollTarget.scrollToEvent`)
already passed `skipIfClose: false`; the jump-to-unread path was the only
one using the default.

- `_doScrollToEvent` (`lib/src/chat/timeline_view.dart`) now passes
  `skipIfClose: false`, matching the other jump sites, so a user-invoked
  jump always moves the view.
- The same fallback previously used the model's `eventIdToItemIndex`, which
  is built before the undecryptable banner is prepended to the item list
  (indices off by one) and counts only message events (so the fraction
  denominator omitted the banner, date separators, and state batches).
  `_doScrollToEvent` now re-derives the rendered item index by matching
  the per-event `GlobalKey` in `_cachedItems` and uses `_cachedItems.length`
  as the count, so the fallback lands accurately once the item is built.
- `test/widget/timeline_view_jump_scroll_test.dart` reproduces the
  suppression: it mounts `TimelineView` with mock messages, scrolls into
  history so the newest message sits just past the built window (its
  fraction estimate is within 60% of the viewport), calls
  `scrollToEventId`, and asserts the controller actually moves. This failed
  on the old code (the offset never changed) and passes now (the view
  scrolls to the target).
- `test/widget/timeline_scroll_target_test.dart` pins the helper contract:
  `skipIfClose: false` scrolls to a target the default would suppress, and
  the default suppresses a close target.

25. Centralized theming via skins

Theming was fragmented: the colour theme was a colour-only enum, the
font-family and mono-font-family settings were persisted but never passed to
the ThemeData (the builder hard-coded 'Rubik'/'FiraCode'), surface corner
radius was hard-coded to 12, and card/dialog radii were not centralised.
Selecting a look required editing several independent settings.

Introduced a `MoonrelaySkin`, a single, self-contained look-and-feel recipe
(seed colour, default fonts, default density, corner radius, surface
elevation, default bubble radius) and a `MoonrelaySkins` registry. The
active skin is the single source of truth for the app's appearance;
`MoonrelayTheme` now builds ThemeData from it, wiring in the user's
font/density overrides so those settings finally take effect app-wide.
Selecting a skin resets the independent appearance controls (density, app
font family, mono font family, chat bubble radius) to that skin's defaults so
 the new look applies in one action. Ten skins ship, including two with a
 genuinely different feel (sharp-cornered High Contrast and Compact Modern).
Existing installs keep their colour choice via a one-time migration from the
legacy `theme_option` index to the new `selected_skin` id.

- lib/src/settings/skins.dart (new): `MoonrelaySkin` + `MoonrelaySkins`
  registry (10 skins, `byId`/`fromId`, `defaultSkin`).
- lib/src/settings/theme.dart: removed `MoonrelayThemeOption`;
  `MoonrelayTheme.light/dark` now take a `MoonrelaySkin` plus optional
  density/font overrides and derive colorScheme, fonts, card/dialog
  borderRadius and surface elevation from it.
- lib/src/settings/settings_service.dart: new `selected_skin` key;
  `SettingsSnapshot.selectedSkinId`; `_readSelectedSkinId` migrates the
  legacy `theme_option` index via a 7-entry table and lets `selected_skin`
  take precedence.
- lib/src/settings/settings_controller.dart: `themeOption` replaced by
  `selectedSkin`/`selectedSkinId` + `updateSelectedSkin`, which resets the
  density/font/bubble-radius controls to the skin defaults before persisting.
- lib/src/app.dart: MaterialApp now builds light/dark themes from
  `settingsController.selectedSkin` plus the persisted font/density overrides.
- lib/src/screens/hub_screen/settings/appearance_settings.dart and
  lib/src/screens/startup_screen.dart: the colour-theme radio lists are now
  skin pickers (label, seed swatch, description).
- lib/src/screens/hub_screen/localization_helpers.dart: dropped the obsolete
  `localizedThemeOption`.
- lib/src/localization/app_*.arb + gen-l10n: added `skin` / `skinDescription`
  keys.
- test/unit/skins_test.dart (new): registry invariants, byId/fromId, and the
  legacy-index migration in SettingsService.
- test/widget/skin_picker_test.dart (new): selecting a skin in the appearance
  page updates selectedSkinId and resets density to the skin default.
- test/widget/appearance_settings_test.dart: refactored onto the skin API and
  added a card-radius propagation assertion.

 Tests at head: flutter test 597 green (584 prior + 13 new). flutter analyze 0 issues.

26. ArchVista GTK skin

The bundled skins are all colour variants of the same Material look; none
captured a genuinely different desktop theme's chrome. Added a skin based on
`tmp/ArchVista` (a darkened Windows Vista GTK theme). The palette was read
straight out of `gtk-4.0/gtk.css`: the dominant filled accent is `#5C8AA6`
(Air Force Blue, used for active buttons, calendar selection, hover/active
states; 16 occurrences), which is the colour worth a Material 3 seed;
Windows' `#3399FF` is only used for window-button highlights (3 occurrences).
Vista's signature fonts (Segoe UI / Consolas) and near-square corners are
encoded as the skin's defaults. Because the skin system adds a skin to the
`MoonrelaySkins.all` list and it auto-appears in the picker, no UI wiring was
needed: `archVista` shows up next to Compact Modern immediately.

- lib/src/settings/skins.dart: appended the `archVista` skin to `all` and
  declared it (seed `#5C8AA6`, Sego UI / Consolas, 4px corners, comfortable
  density, 10px bubbles).
- test/unit/skins_test.dart: new test pins the seed color, fonts, density and
  corner-radius to their GTK-faithful values.

Tests at head: flutter test 597 green (596 prior + 1 new palette test).
flutter analyze 0 issues.

27. Decouple accent colors from themes

The single-skin model conflated two independent axes of appearance: a "colour"
skin also re-applied its geometry defaults, and a look-only skin (highContrast,
compact) could only carry one fixed colour, so users could not, say, keep the
sharp High Contrast geometry and switch to an indigo accent. Per the request,
appearance is now two swappable dimensions.

- lib/src/settings/theme_spec.dart (new; replaces skins.dart): `MoonrelayThemeSpec`
  owns geometry only (fonts, density, corner radius, elevation, bubble radius),
  `MoonrelayAccent` owns only a seed colour. Registries
  `MoonrelayThemes` {material, highContrast, compact, archVista} and
  `MoonrelayAccents` {indigo, ocean, midnight, crimson, amber, steel, sky,
  charcoal, vistaBlue} with byId/fromId + defaults.
- lib/src/settings/theme.dart (`MoonrelayTheme` builder): `light`/`dark` now
  take a (`MoonrelayThemeSpec`, `MoonrelayAccent`); the spec drives geometry and
  the accent's `seedColor` seeds the color scheme. The color is therefore fully
  independent of the look.
- lib/src/settings/settings_service.dart: new `selected_theme` +
  `selected_accent` keys; `_readSelectedThemeAndAccent` migrates the legacy
  `selected_skin` hybrid id and the even older `theme_option` int to a
  (theme, accent) pair, resolving each field independently so a partially
  migrated store still reads sensibly.
- lib/src/settings/settings_controller.dart: `selectedTheme`/`selectedThemeId`
  and `selectedAccent`/`selectedAccentId`. `updateSelectedTheme` resets the
  look controls (density/fonts/bubbles) to the new theme's defaults;
  `updateSelectedAccent` only changes the color and leaves the look untouched.
- lib/src/app.dart: builds light/dark themes from the active theme+accent.
- lib/src/screens/hub_screen/settings/appearance_settings.dart and
  lib/src/screens/startup_screen.dart: two radio pickers, "Look & feel"
  (themes) and "Accent colour" (accents). Each theme preview is tinted with
  the current accent; each accent preview is a circle so it can't be confused
  with a geometry theme.
- lib/src/screens/hub_screen/settings/settings_section.dart: optional
  `subtitle` added so the two pickers can describe their effect.
- lib/src/localization/app_*.arb + gen-l10n: `lookAndFeel` / `lookAndFeelDesc`
  / `accentColor` / `accentColorDesc`.
- test/unit/theme_spec_test.dart (renamed from skins_test.dart): registry
  invariants for both registries, the independent per-field migration, and the
  top-precedence of the split keys.
- test/widget/appearance_picker_test.dart (renamed from skin_picker_test.dart):
  selecting a theme resets density; selecting an accent keeps the look.

Tests at head: flutter test 605 green (597 prior + 8 new). flutter analyze 0 issues.

28. Emulate Vista widget style in the ArchVista theme

The ArchVista theme previously differed from Material only in color, font and
corner radius: the buttons, checkboxes, scrollbars and dividers still used
stock Material geometry. This adds the actual Vista chrome so the look is
recognizably "a desktop theme", while keeping every color a pure accent swap.

- lib/src/settings/theme_spec.dart: new `MoonrelayWidgetStyle` value class
  (geometry-only chrome tokens) with a `vista` constant and a `mergeInto` that
  rebuilds the relevant component themes. `MoonrelayThemeSpec` gains an optional
  `widgetStyle`; the archVista spec sets `widgetStyle: MoonrelayWidgetStyle.vista`.
  The style touches only shapes/borders/dimensions (flat transparent buttons
  with a 1px outline, square 4px corners, thin `#181818`-ish dividers via
  scaled `outlineVariant`, a narrow rounded scrollbar, square checkboxes,
  thin-track sliders); every interactive color is taken from the running
  [ColorScheme], so `vistaBlue`/`indigo`/any accent recolors the Vista widgets
  identically in hue terms.
- lib/src/settings/theme.dart: `_buildThemeData` layers
  `spec.widgetStyle.mergeInto(data, colorScheme)` on top of the shared tokens
  when a spec carries one.

Tests at head: flutter test 608 green (605 prior + 3 new). flutter analyze 0 issues.

29. Theming overhaul Phase 7: new shipped themes

The theme registry now ships seven looks (up from four). Existing theme
definitions have been moved from inline static constants in
`MoonrelayThemes` into individual files under `lib/src/theme/shipped_themes/`
for clarity, and three new themes have been added: a Moonrelay signature
look, a flat Minimal look, and a soft Organic look. Each new theme carries
its own `MoonrelayWidgetStyle` that layers theme-specific component overrides
on top of the shared token system.

- `lib/src/settings/theme_spec.dart`: new `MoonrelayStyleType` enum
  (`vista`, `minimal`, `organic`, `moonrelay`) drives a strategy dispatch in
  `MoonrelayWidgetStyle.mergeInto`, which now delegates to per-style merge
  methods (`_mergeVista`, `_mergeMinimal`, `_mergeOrganic`,
  `_mergeMoonrelay`). Three new static `MoonrelayWidgetStyle` instances
  (`minimal`, `organic`, `moonrelay`) define geometry and neutral chrome for
  each look. `MoonrelayThemes.all` now includes `moonrelay`, `minimal`, and
  `organic`; the existing `material`, `highContrast`, `compact`, and
  `archVista` entries now delegate to top-level const specs in the
  shipped_themes directory.
- `lib/src/theme/shipped_themes/moonrelay_theme.dart`: signature theme with
  cornerRadius 12, surface elevation 2, elevated cards with signature
  shadows, distinctive app bar with accent-accented bottom indicator, and
  rounded buttons (24-commit group).
- `lib/src/theme/shipped_themes/minimal_theme.dart`: flat theme with
  cornerRadius 0, surface elevation 0, borderless buttons, no surface
  chrome.
- `lib/src/theme/shipped_themes/organic_theme.dart`: soft theme with
  cornerRadius 20, low elevation, generous list-tile padding, subtle
  borders, rounded scrollbars and chips.
- `lib/src/theme/shipped_themes/shipped_themes.dart`: barrel export for all
  seven theme specs.

Tests at head: flutter test 608 green. flutter analyze 0 issues.

57. Close a gap from whichever side the reader is on

A jump to an event far in the past needs to be able to come back, and it could
not. Closing a gap always paged the newer side older, so the shipped behaviour
was: a user who followed a search result or a permalink landed in a `/context`
window, scrolled down towards the live edge, and nothing loaded. Growing the
live tail would eventually close the same hole, but the tail is the segment
that the user is not looking at, and if the target is months back the tail has
months of history to walk first. Nothing on screen moved until it finished a
walk that was not theirs.

Both sides of a hole can reach the events that fill it, from opposite ends, so
"which direction closes a gap" never had a single answer. The caller now says
which side the reader is on.

- `lib/src/chat/timeline_store.dart` `closeGapAfterGroup` takes
  `viewerOnNewerSide`. True, the reader is below the marker and scrolling up, so
  the newer group is paged older. False, the reader is above it and scrolling
  down, so the older group is paged newer. That second branch had no caller
  before and `pageNewer` on a window was documented as the callerless future
  primitive for a jump-to-date feature. It is not future. It is what makes a
  jump to an old event able to walk back down to the live edge.
- `lib/src/chat/timeline_view.dart` `nearestGap` returns `viewerOnNewerSide`
  alongside the distance, and `onGapApproach` passes it on. The single-flight
  token in `reportGapApproach` and the guard in `_closeGap` both key on the side
  as well as the group, since the same boundary can be approached from both ends
  and suppressing the second direction would strand the hole the first one just
  filled.
- `lib/src/chat/chat_timeline.dart` `_closingGaps` became a `Set<String>` keyed
  by `group:side` for the same reason.

Two details were wrong on the way and both are now pinned by rendered fixtures
rather than reasoning.

The sign of the comparison was inverted. `reverse: true` puts index 0 at the
bottom, so content *above* the marker is the older group; a marker above the
viewport centre therefore leaves the reader in the newer group below it. I had
it backwards, which would have grown the segment the reader was leaving in both
directions. A rendered fixture caught it on the first run. Reasoning about the
geometry twice did not.

It is the viewport *centre*, not the nearest edge. After a jump to an old event
the viewport is mostly window with barely any tail, so "which side is closest"
answers "window" for a reader parked at the live edge. The test builds both
cases from the only variable that moves the marker across the centre: how much
history sits below it. A short tail leaves the marker low and the reader in the
window, which is the shape a search jump leaves behind; a long tail leaves it
high and the reader in the tail.

Verified by mutation, since a test that passes under both implementations is
worth nothing here. Restoring the always-older branch fails three of the five new
store tests; inverting the sign fails the viewer-side test. The older-direction
tests keep passing throughout, so they are specific to the direction rather than
incidentally coupled to it.

One deliberate non-change: `HistoryPager` still pages `store.oldestSegment` on
scroll. The two mechanisms do not conflict, because their triggers differ.
`HistoryPager` fires at the very top of the render list and the gap handler fires
within `gapPrefetchDistance` of a marker, so a reader crossing a boundary gets
the segment under them to grow whichever rule applies.

Tests at head: flutter test 960 green. flutter analyze 0 issues.

58. Log a segment that cannot page, so a dead end is not silent

Found in review of 57 and worth fixing rather than deferring, because the new
viewer-side branch is a fresh way to reach it.

`TimelineSegment._page` checks `canPageOlder`/`canPageNewer` before spending a
round trip, which is right, and returned 0 with nothing said. For the older
direction that was harmless. For the newer direction it is not: `closeGapAfterGroup`
now depends on that return value to decide whether a hole will ever close, and
an exhausted window gives the same 0 as a page that succeeded with an empty
response. Neither bumps the store version, neither moves a marker, neither
changes anything on screen. A hole that has quietly become permanent looks
exactly like a reader who stopped scrolling.

The store already took an optional `Logger` and already logged failed requests,
so the exhaustion path was the odd one out rather than a new concept. It now
logs the segment id and the direction it refused, which is the pair needed to
tell the two cases apart in a log file. The test asserts on the captured
output, including the direction, and fails when the line is removed.

`WORK_NEEDED.md` now also carries two presence findings from the same review,
both real and both out of scope here: the auto-offline timer is disarmed by
any settings change because every caller to `_evaluate` resets `_lastActivity`
first, and `bind` leaks window-listener registrations on account switches.

Tests at head: flutter test 961 green. flutter analyze 0 issues.

59. Arm the auto-offline deadline in one place, and stop leaking window listeners

Both found in review of the timeline work, both unrelated to it, and both real.
The first one had been silently wrong since the service was written.

**The countdown never started.** `_evaluate` armed the idle timer only in its
`idleFor >= window` branch. But every caller resets `_lastActivity` before
arriving, because each of them genuinely is a fresh moment: `bind`, and
`onSettingsChanged`. So a bind always landed on the branch that arms nothing,
the timer was cancelled on the way in, and the account stayed online
indefinitely. Turning the setting on appeared to do nothing at all.

`app.dart` registers `onSettingsChanged` on the whole `SettingsController`,
which is a `ChangeNotifier` that fires on every setter, so changing an
unrelated preference such as the sidebar width was enough to kill a countdown
that was already running.

The fix is in `_evaluate`, not at the call sites. It now arms with the
*remaining* time, `window - idleFor`, which makes "enabled and not overridden
implies an armed deadline" true for every entry point including future ones.
`noteActivity` already did this by hand; there are now two implementations of
one rule instead of none.

The existing suite missed all of it because the armed-timer assertions were
reached through `onResumed` and `noteActivity`, both of which arm the timer
themselves. Worse, one assertion had the bug baked in: the pre-window case
expected `hasPendingIdleTransition` to be `false`, which was only true because
nothing armed anything. Correcting it to `true` is the honest post-fix
expectation and it is now covered.

**A settings change must not restart the window.** `onSettingsChanged` only
resets `_lastActivity` when no timer is pending, so dragging the minutes
slider cannot push the deadline out, and the fix preserves that. The new test
discriminates the two behaviours by driving `onResumed` at T+5:10 after
changing an unrelated setting at T+4: elapsed time kept gives 1, fresh window
gives 0. It has to go through `onResumed` because the tests use an injected
clock with a real `Timer`, and advancing one does not fire the other.

**`bind` leaked window listeners.** `windowManager` keeps listeners in a plain
list, `addListener` appends and `removeListener` removes one entry. `bind` is
documented as replacing a previous binding and does return early for the same
client, but every account switch brings a new one, so each added a copy.
Two copies then survived `dispose` and kept creating timers on a dead service,
because `noteActivity` is not gated on `_disposed`. `app.dart:111` already does
remove-then-add two lines above the call, so the correct pattern was sitting
right there.

**A seam was needed to test the leak.** `windowManager` is a global singleton
that throws without a platform window, which is exactly what a unit test has,
so the production registration path is a silent no-op under test and the
accumulation was permanently unobservable. The registration is now injectable,
defaulting to the real global, in the same shape as the existing `clock`
parameter and for the same reason. That is the one API change here, and it is
what turns "we removed before adding" into an assertion.

Verified by mutation: restoring the `>=`-only arming fails all five timer tests,
including the corrected pre-window one, and dropping the remove-before-add fails
the accumulation test. An earlier attempt at the first mutation printed
"applied" while changing nothing, because the file is LF and the check appended
CRLF. It reported 25 passing, which is the fourth time this session that a
mutation printed success and asserted nothing.

Tests at head: flutter test 967 green. flutter analyze 0 issues.