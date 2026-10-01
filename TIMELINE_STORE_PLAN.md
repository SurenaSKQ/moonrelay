# TimelineStore: replacing the substituted timeline

Design document for `WORK_NEEDED.md` section 8.5, step 5. Written before the
implementation so the reasoning survives the commits that will change the code
underneath it.

## 1. The problem

`ChatTimeline` holds a single `Timeline` field, and that field is being asked to
be two things at once:

- the room's live tail, which follows sync and must not be detached, and
- an arbitrary `/context` window around any event in the room's history.

A `Timeline` cannot be both, so `jumpToEvent` resolves the conflict by
**substitution**. `chat_timeline.dart:366` calls `_initTimeline(eventContextId:
eventId)`, which builds a *different* `Timeline` and assigns it over the live
one. `backToLive` (`chat_timeline.dart:830`) resolves it the same way in reverse,
throwing the window away and re-fetching the tail.

Substitution is a defensible first cut and it works, but every awkward thing
downstream is a consequence of it rather than an independent problem:

| Symptom | Root |
|---|---|
| `_anchoredEventId` is a nullable `String` acting as a type | It is the only record of *which* segment is displayed, so the segment identity has nowhere else to live |
| `isViewingHistoryWindow` is `_anchoredEventId != null` | Same cause. A window with no anchor, or a live timeline that happens to be an old window, is indistinguishable from the tail |
| The unread pill must be suppressed inside a window (`inHistoryWindow` at `chat_timeline.dart:612`) | A `/context` window does not contain the read marker, so every event in it counts as unread and the pill would offer a jump the window cannot serve |
| `TimelineView` cannot show two windows plus a tail | It receives a `Timeline` and reads `timeline.events` as its entire render list |
| Every jump is a full rebuild | `_cacheKey` embeds `identityHashCode(timeline)` (`timeline_view.dart:196`), and substitution replaces the object it hashes |

The audit's headline finding, restated: **the chat surface holds one `Timeline`
and every history feature reaches around it.** Four rounds of fixes have narrowed
the edges of that design without changing it. This is the change to the design.

## 2. Target shape

```
LiveSegment                HistorySegment              HistorySegment
(events, Timeline)         (events, Timeline)           (events, Timeline)
     |                          |                            |
     +--------------------------+----------------------------+
                                    |
                            TimelineStore
                     - ordered List<Segment>
                     - flatten() -> List<Event>  (newest-first)
                     - index: eventId -> (segment, position)
                     - gap markers at non-contiguous boundaries
```

**One segment type.** The live tail is a segment too, distinguished only by
`isLive`. A separate `LiveSegment` class would put an `is Live` branch in
`HistoryPager`, in `buildTimelineItems`, and in every gap calculation, for no
gain.

### 2.1 Proposed API

```dart
class TimelineSegment {
  final String id;              // stable identity for this segment
  final Timeline timeline;      // cancelled on eviction
  final bool isLive;
  final String? anchorEventId;  // the event this window was built around

  List<Event> get events => timeline.events;

  Future<int> pageOlder({int count});
  Future<int> pageNewer({int count});
  bool get canPageOlder;
  bool get canPageNewer;
}

class TimelineStore {
  List<Event> flatten();
  int indexOf(String eventId);        // -1 when not loaded
  TimelineSegment? segmentFor(String eventId);

  TimelineSegment get live;
  List<TimelineSegment> get history; // newest-first

  void addHistory(TimelineSegment segment);
  void removeHistory(String segmentId);
  void collapseHistory();            // replaces backToLive

  bool get isViewingHistory;         // replaces _anchoredEventId
  int get version;                   // bumps on any mutation
}
```

`version` replaces the `identityHashCode(timeline)` term in the view's cache key.
A store that survives a jump does not invalidate its cache; today every jump
discards it.

`collapseHistory()` is what `backToLatest` becomes. It is a store mutation
rather than a fresh `getTimeline`, because the live segment was never discarded.

## 3. SDK constraints

All four verified against `matrix-9.0.0` by reading the source. File and line
references are to the pub cache, and are the ones that made the naive version of
this plan not work.

### 3.1 A `/context` window is a `Timeline`, and it subscribes to sync

`Timeline`'s constructor wires `roomSub` to `_removeEventsNotInThisSync`,
filtered on `timeline.limited == true`:

```dart
roomSub = room.client.onSync.stream
    .where((sync) => sync.rooms?.join?[room.id]?.timeline?.limited == true)
    .listen(_removeEventsNotInThisSync);          // timeline.dart:348-350
```

That handler deletes every event not present in the sync, so a detached window
that keeps its subscriptions is emptied by the next gap-limited sync.

**A segment's subscriptions must be cancelled at creation, not at eviction.**
The current code gets this half right: `_loadEventContext` cancels the timeline
it is *discarding* (`chat_timeline.dart:364`). The window it *creates* is never
cancelled, because substitution meant there was nothing to keep. Under a store
that inverts: the live segment is never cancelled, and every history segment is
cancelled the moment it is created.

### 3.2 `getRoomEvents` pages off the segment's own chunk, and mutates mid-flight

```dart
final resp = await room.client.getRoomEvents(
  room.id, direction,
  from: direction == Direction.b ? chunk.prevBatch : chunk.nextBatch,
  ...
);                                              // timeline.dart:231-237
```

It reads `chunk.prevBatch`/`chunk.nextBatch`, **not** `room.prev_batch`. It then
appends to `chunk.events` and fires `onInsert` per event before returning:

```dart
chunk.events.addAll(newEvents);
for (var i = 0; i < newEvents.length; i++) {
  onInsert?.call(i + offset);                   // timeline.dart:300-304
}
```

Two consequences. `onInsert` fires **during** the append, so anything reading
`chunk.events` from that callback sees a partially-appended list; the store must
not rebuild from inside the callback. And for `Direction.b`,
`chunk.prevBatch = newPrevBatch ?? ''` (`:296`), so **exhausted means an empty
string, not null**.

`getRoomEvents` returns `int`, the number of received events, and calls
`onUpdate` at the end (`:325-327`). That shape fits the existing `HistoryPager`.

### 3.3 A `/context` window is a *fragmented* timeline to the SDK

`getEventContext` builds a chunk with real pagination anchors:

```dart
final chunk = TimelineChunk(
  nextBatch: resp.end ?? '',
  prevBatch: resp.start ?? '',
  events: events,
);                                             // room.dart:1726-1730
```

Because `chunk.nextBatch != ''`, the `Timeline` constructor does this:

```dart
if (chunk.nextBatch != '') {
  allowNewEvent = false;
  isFragmentedTimeline = true;
  _fetchedAllDatabaseEvents = true;             // timeline.dart:365-370
}
```

So a history segment has `canRequestFuture == true` and
`_fetchedAllDatabaseEvents == true`. Paging it forward with
`getRoomEvents(direction: Direction.f)` is the supported path, and the SDK
restores live behaviour once the window reaches the tail:

```dart
if (!allowNewEvent) {
  if (resp.start == resp.end || (resp.end == null && direction == Direction.f)) {
    allowNewEvent = true;
  }
  ...
}                                             // timeline.dart:269-275
```

That is the mechanism for closing a gap between a window and the tail. The store
should expose it, not reimplement it.

### 3.4 `canRequestHistory` consults the wrong token

```dart
bool get canRequestHistory {
  if (!{Membership.join, Membership.leave}.contains(room.membership)) return false;
  if (events.isEmpty) return true;
  return !_fetchedAllDatabaseEvents ||
      (room.prev_batch != null && events.last.type != EventTypes.RoomCreate);
}                                             // timeline.dart:77-84
```

`room.prev_batch` is the room's live sync token. On a fully synced room it is
`null`, so a perfectly good window reports itself exhausted and silently refuses
to page. `HistoryPager._canPageOlder` already works around this:

```dart
if (timeline.canRequestHistory) return true;   // authoritative for the live tail
return timeline.chunk.prevBatch.isNotEmpty;   // the window's own token
```

**The store must reuse this rule.** It is the second time this bug has been
fixed in one place and would have been reintroduced in another. Section 53 fixed
it in `HistoryPager`; a store is exactly where it comes back.

### 3.5 Thread reply counts are computed from a `Timeline`

`buildTimelineItems` calls `ThreadUtils.buildThreadReplyCounts(timeline)`
(`timeline_model.dart:298`), which scans `timeline.events` (`thread_utils.dart:81`).
With a store there is no single timeline, so this must take a list.

## 4. Open questions

Both were settled on 2026-10-01. The answers are in section 8.

**Does `getEventContext` re-anchors correctly for events older than the tail?**
`room.dart:1791-1792` looks correct:

```dart
if (eventContextId != null) {
  if (!events.any((e) => e.eventId == eventContextId)) {
    chunk = await getEventContext(eventContextId) ?? TimelineChunk(events: []);
  }
}
```

Unverified against a real server. Decision: **write the guard now** rather than
assume. See 8.2.

**What should `oldestVisibleEventId` report when the viewport sits on a gap?**
Decision: **report the event below the gap.** See 8.1.

## 5. Stages

Each stage leaves the suite green and is individually revertable.

### Stage 1: `TimelineStore` as a pure-Dart value

New file `lib/src/chat/timeline_store.dart`. No UI, no SDK calls. `flatten()`
concatenates segments newest-first. **Dedupe on `eventId`**: a `/context` window
frequently overlaps the live tail, and rendering the same event twice in one list
is worse than a wasted fetch.

This is the only piece of genuine new logic, so it gets the most tests:

- overlapping segments flatten without duplicates, preserving newest-first order
- `indexOf` agrees with `flatten` on every index
- removing a middle segment leaves no dangling index
- `version` bumps on every mutation and only on mutations
- `isViewingHistory` is false for a live-only store, true with a segment added
- `collapseHistory` drops history segments and leaves live untouched

### Stage 2: segments page themselves

`TimelineSegment.pageOlder()` / `pageNewer()` wrap `getRoomEvents`.
`cancelSubscriptions()` in the factory (see 3.1). Reuse `_canPageOlder`'s rule
(see 3.4).

Tests: a segment with a non-empty `chunk.prevBatch` reports itself pageable even
when `room.prev_batch` is null. That is the 3.4 regression, pinned at the layer
where it would otherwise return.

### Stage 3: `TimelineView` renders `flatten()`

`buildTimelineItems` and `buildThreadReplyCounts` change from `Timeline` to
`List<Event>`. `TimelineView` takes a store plus a version `ValueListenable`
instead of a `Timeline`, and `_cacheKey` swaps `identityHashCode(timeline)` for
`store.version`.

**This is the risky stage and the reason 1 and 2 come first.** `TimelineView` is
the read surface for the whole app; swapping its data source touches the render
cache, the index map, and the read-position walk simultaneously. The mutation
rule from WORK_DONE section 55 applies: verify each claim by breaking it.

### Stage 4: gap separators

A new `TimelineItemKind.gap` for non-contiguous boundaries. Without it, two
adjacent windows render as one continuous conversation and the user cannot tell
there is a hole. Most likely stage to be deferred, and the one that makes stage 3
visible rather than a silent merge.

### Stage 5: `jumpToEvent` adds instead of replaces

Delete `_loadEventContext`'s substitution, `_anchoredEventId`, `backToLive`,
`isViewingHistoryWindow`, and the `inHistoryWindow` pill suppression. The
suppression goes because with the segments in one list there *is* a read marker
in it.

## 6. Explicit non-goals

- **The store does not know about encryption, drafts, or read receipts.** The
  read marker is an event id in the list; `ReadMarkerTracker` keeps working
  unchanged.
- **The store does not own segment lifetimes.** Segments are created and
  cancelled at the edges. A store that also owned their lifetimes would need to
  know about `getRoomEvents` and `cancelSubscriptions` at once.
- **Do not touch `_ItemRenderKey` or the FAB column while this is in flight**
  (standing note from section 8.5). Neither is a source of the unreliability,
  and the FAB column has already been touched once for the back-to-latest pill
  that stage 5 removes.

## 7. Status

| Stage | State |
|---|---|
| 1. `TimelineStore` pure-Dart | done, `timeline_store.dart` + `test/unit/timeline_store_test.dart` (27 tests) |
| 2. Segment paging | done, 44 tests in the same file |
| 3. `TimelineView` renders `flatten()` | done, 10 tests in `timeline_view_render_source_test.dart` |
| 4. Gap separators | done, 19 tests in `timeline_gap_test.dart` plus 4 in `timeline_view_render_source_test.dart` |
| 5. `jumpToEvent` adds segments | done, `timeline_event_context_test.dart` + `chat_fab_test.dart` |

**All five stages are shipped.** The plan stays as the record of why the design
is shaped this way; the open work below is what a jump still does not do.

### 7.1 Stage 1 notes

Two things the stage 1 tests found, both worth recording because they are the
same class of problem this whole project keeps meeting.

**`indexOf` initially disagreed with `flatten`.** It traversed the segments
without the dedupe, so it counted the events `flatten` had dropped and returned
an index too high by however many duplicates preceded the target. Two traversals
of one list disagreeing about what the list contains is precisely the failure
that `WORK_DONE.md` section 55 just fixed in the model's index map, introduced
again one file over. The test that caught it is the one asserting `indexOf`
agrees with `flatten` on every index, which is the assertion that would have
been written if the bug were expected rather than accidental.

**`cancel()` guarding the live segment was untested.** Removing the
`if (isLive) return` guard failed nothing, because `addHistory` is the only
caller and it rejects live segments before reaching `cancel`. The guard was
therefore correct and completely unverified. A test now calls `cancel()` on a
live segment directly, with a comment saying why: a later eviction path will
call it on whatever it removed, and that is the assertion saying the tail is
not one of those.

Mutations verified against stage 1: dropping the dedupe (4 failures), moving
the cancel into the factory (1), removing the live guard (1, after the fix
above), reversing the history order (1), and bumping `version` on reads (3).

### 7.2 Stage 2 notes

`TimelineSegment` gains `canPageOlder`, `canPageNewer`, `pageOlder` and
`pageNewer`; the store gains `pageOlder(id)` / `pageNewer(id)` that also bump
`version`. Two SDK details turned up that the plan had not settled.

**`canPageNewer` does not consult the SDK flag.** The plan assumed the same
"ask the SDK, fall back to the chunk" shape as `canPageOlder`. A test showed
that is wrong: the SDK clears its own forward flag once a page reaches the end
(`timeline.dart:269-275`), but until it does, `canRequestFuture` is true for a
window that has nothing left to give. Forward paging is therefore gated on the
segment's own `chunk.nextBatch` and nothing else. The live segment is the only
kind that can never page forward, and it is identified by `isLive`.

This is the plan's 3.4 lesson applied in the other direction: the SDK's flag is
convenient, the segment's own anchor is authoritative, and conflating the two is
how this bug happened once already.

**`getRoomEvents`'s `direction` parameter is untyped (`dynamic`), not
`Direction`.** The SDK declares `direction = Direction.b` with no type
annotation, so the value is `dynamic` at the call site. The overrides in the
test double must be declared `dynamic` too, or they do not override. Worth
knowing before writing the mock, since the mismatch is a compile error with a
confusing message about covariance.

**The version bump belongs on the store, not the segment.** `getRoomEvents`
fires `onInsert` once per event *while* it is appending to `chunk.events`
(`timeline.dart:302-304`), so anything rebuilding from inside that callback
would read a half-appended list. The page returns before the store touches
anything, and the bump happens once, after the list is whole. A test asserts
`version` moves by exactly one for a page that delivered events.

**`TimelineChunk` is not exported** by `package:matrix/matrix.dart`; only
`src/timeline.dart` imports it. Tests construct one via
`package:matrix/src/models/timeline_chunk.dart`, the same deep import
`test/helpers/renderable_timeline.dart` already uses. Production code never
needs it, because windows are built by `room.getEventContext`.

Mutations verified against stage 2: dropping the `chunk.prevBatch` fallback
from `canPageOlder` (4 failures, which is the section 3.4 regression), paging
through `requestHistory` instead of `getRoomEvents` (5), removing the version
bump (1), and dropping the `canPage` guard so an exhausted segment still hits
the network (1).

### 7.3 Stage 3 notes

The seam is a `List<Event>` parameter, not a store. `TimelineView` takes both
`events` (the render list) and `timeline` (the live tail, still needed for the
aggregation lookups each `TimelineItem` performs), so wiring the store in is
stage 5's one-line change rather than a second refactor of the view.

`buildTimelineItems` and `ThreadUtils.buildThreadReplyCounts` both moved from
`Timeline` to `List<Event>`. Thread counts specifically have to be computed
across the whole flattened list: counting within one segment would drop a
thread whose root sits in a window and whose replies sit in the tail.

**The cache key hashes the event list, not the timeline.** They differ in a
way that matters: the live tail keeps the same `Timeline` object across a
history jump, so hashing it would miss a swap of the render list.

**The list identity does not drive invalidation, and the first draft of the
test asserted the opposite.** `chunk.events` is mutated in place by the SDK, so
its identity never changes when the contents do; if the key alone drove the
rebuild it would serve stale items for as long as the version notifier was
silent. The notifier is the invalidation signal, which is why `events` and
`timelineVersion` are a pair. There is now a test for both halves: a bumped
version re-renders a mutated list, and a silent version serves the cache.

This matters for stage 5: `TimelineStore.flatten()` allocates a new list on
every call, so its identity is useless as a cache key and stage 5 must pair it
with `store.version` instead.

**`_targetInLiveTimeline` is only reachable through an in-place mutation.**
The stale-cache path where the index map misses but the event is present needs
the SDK's mutate-in-place behaviour to produce: a newly paginated event is in
`events` the instant the request lands, one build before the map catches up. A
test that swaps in a new list object cannot reach it, and one that inserts at
index 0 cannot observe it, because under `reverse: true` that is already at the
bottom. The test that does reach it appends to the *old* end so the refresh
must scroll.

Mutations verified against stage 3: reading the render list back out of
`timeline.events` (4 failures), hashing the timeline instead of the list in the
cache key (1), dropping the list from the cache key entirely (1), and pointing
`_targetInLiveTimeline` at the tail (1).

### 7.4 Stage 4 notes, including a stage 1 bug

**`_segmentsNewestFirst` was `[...history, live]`, which renders every room
upside down.** Index 0 of the render list must be the newest event, because
`reverse: true` puts index 0 at the bottom of the scroll view. History-first
put the oldest messages at the bottom. Nothing failed for three stages because
the list was internally consistent; it was only consistent about the wrong
axis, and the stage 1 tests asserted the wrong order with confident comments.

The contiguity check is what exposed it: a check between two groups is
meaningless unless the groups are in the right order, so a "distant window"
test failed while looking at an adjacent one.

Correcting the order also settled the dedupe winner. The tail is now walked
first, so its instance survives an overlap rather than the window's, which is
the better answer independently: the tail's copy is the one the app keeps
updating as sync brings in reactions and edits.

**Contiguity is a heuristic, and `kGapTolerance` is ten minutes.** A judgement
call: long enough that a busy room paging in one screenful does not produce a
marker, short enough that an afternoon's silence does. Events sharing a
timestamp are never a gap.

**`gapsAfter` is group-relative, not index-relative.** A raw index into the
flattened list is ambiguous once a filter hides events: a group's last event
may not be rendered at all, so an index-based marker is dropped along with it
and the hole silently closes. There is a test that hides a group's tail behind
a reaction and asserts the gap survives.

**A gap is the one null-id entry the read-position walk does not skip.** See
8.1.

Three findings from the tests, in order of how much damage they would have done:
the store ordering above; `_groupHasLaterVisible` bailing at the first event
belonging to another group instead of scanning for one of its own, which drew a
gap after every event; and a gap being drawn after the last group, which needs
two sides to exist.

Four of my own gap tests asserted the wrong thing, all the same way: calling
events an hour apart "adjacent". The tolerance is ten minutes, so an hour is a
gap. Fixing one of them revealed that neither event in a two-event list is ever
flagged as a group continuation, which is existing model behaviour and is now
described in the assertion rather than asserted around.

Mutations verified against stage 4: the walk skipping gaps instead of stopping,
the model never emitting one, the store order reverted, and the tolerance
collapsed to any nonzero difference.

## 8. Settled decisions

### 8.0 Known limits of stage 5, as shipped

**Resolved in `69c7195`.**

*Scrolling up from a window extends that window.* `HistoryPager` now takes a
`TimelineSegment` and is handed `store.oldestSegment`, so a scroll to the top of
the render list extends whatever is oldest rather than always the tail. It also
pages through `getRoomEvents` instead of `requestHistory`, which is the same
wrong-token bug for the third time, and it no longer keeps its own copy of the
`canPageOlder` rule.

*A gap is temporary.* The view reports the nearest gap marker and the group it
follows when it comes within `gapPrefetchDistance`, and the timeline grows that
group to close the hole.

The direction took three attempts, and the first two were wrong in opposite
directions. The first paged *newer*, on the reasoning that the gap needs "more of
the newer side". It is the other way round: the events that close a hole are older
than the one the gap follows, and newer is the only direction the live tail cannot
take at all, since it is anchored at the newest event in the room. The distance to
the viewport also started out signed upwards, which missed the gap sitting just
above the live edge, the one a user is closest to.

The second attempt stopped at "always page the newer side older" and declared the
missing direction unnecessary. That reasoning was about *feasibility for one
particular segment*, standing in for correctness, and it was wrong. See 8.3.

### 8.3 The two directions, and who takes which

Both sides of a hole can reach the events that fill it, from opposite ends, so
"which direction closes a gap" has no answer on its own. The caller has to say
which side the viewer is on, and that is what `closeGapAfterGroup` now takes:

- `viewerOnNewerSide: true`, the viewer is below the marker in group *i* and
  scrolling up, so group *i* is paged **older**.
- `false`, the viewer is above the marker in group *i+1* and scrolling down, so
  group *i+1* is paged **newer**.

**Why the second direction is not optional.** The search case is the one that needs
it. A user opens a search result from months ago, or follows a permalink to an
old message, and lands in a `/context` window that is nowhere near anything
already loaded. The render list is then:

```
index 0            the live tail (a few hundred synced events)
                   ---- gap: the whole skipped distance ----
higher indices     the window around the target
```

That user scrolls *down*, towards the live edge, and the events they want are
**newer** than their window's newest. Only `pageNewer` on the window can produce
them. Growing the tail would eventually close the same hole, and that is what the
shipped code did, but the tail is the segment the user is not looking at and has
months of history to walk. From the user's side nothing moves until it has
finished a walk that is not theirs.

So `pageNewer` is no longer the callerless future primitive. It is the direction a
jump to an old event needs in order to be able to come back. What remains genuinely
unbuilt is *jumping forward* to an arbitrary date, which is a different feature and
would reuse this.

**Which side the viewer is on** comes from the viewport centre against the marker's
screen position, in `TimelineView.nearestGap`. Two details are worth stating because
both were wrong first:

- The centre, not the nearest edge. After a jump to an old event the viewport is
  mostly window with barely any tail, so "which side is closest" answers "window"
  for a reader who is in fact parked at the live edge.
- The sign. `reverse: true` puts index 0 at the bottom, so content *above* the
  marker is the older group. A marker above the centre therefore leaves the reader
  in the newer group below it. This was written inverted and only a rendered
  fixture caught it; reasoning about it twice did not.

**Both hands at once.** Scrolling up at the top of the list still goes through
`HistoryPager` on `store.oldestSegment`, and a gap met in passing still goes through
`closeGapAfterGroup`. They do not conflict, because their triggers are different:
`HistoryPager` fires at the very top of the render list, and the gap handler fires
when a marker comes within `gapPrefetchDistance`. A reader crossing a boundary in
either direction now gets the segment under them to grow, and `_closingGaps` is
keyed by group *and* side so one direction cannot strand the other's fetch.

### 8.1 Read position at a gap: report the event below it

When the viewport rests entirely on a gap, the read position names the oldest
real event **below** the gap, and everything above it stays unread.

The reasoning: a gap is a hole in a conversation, not a boundary the user has
crossed. Everything below it is above the fold in the sense that matters, which
is "the user has actually seen it", and everything above it has not been
scrolled past. Reporting the event below the gap is therefore the only answer
that cannot retire something the user has not read.

The rejected alternatives, for the record. Reporting **nothing** would leave the
marker where it was, so the user scrolls across a gap and the position does not
advance, which reads as the pill being stuck. Reporting the event **above** the
gap would retire the messages in between, which the user never saw.

Implementation: the read-position walk treats a gap as a hard stop. It keeps the
last real event it saw below the gap and returns that, rather than continuing
across. This matters because the existing walk already skips null-id entries,
which is how it handles separators and date dividers, so a gap would otherwise
be transparent to it and the walk would continue into the segment above.

### 8.2 A window with no anchor is an error, not an empty view

`getEventContext` builds the window's `prevBatch` from the response's `start`
token (`room.dart:1726-1730`). If that token is empty the window holds a
handful of events and cannot page in either direction, so it renders as a dead
end: a short conversation stub with no way to reach anything else.

Since whether the SDK re-anchors correctly was not verified against a real
server, this is treated as possible rather than impossible. The guard:

- A window is constructed only if it can page, or it is already anchored to
  something usable.
- A window that fails the check is not added to the store, and the jump reports
  the failure through the existing "that message is no longer available" path
  rather than substituting in a dead view.

The alternative, showing the stub anyway, is worse than it looks: the user gets
a screen that looks like the room and is not, and the only sign is that
scrolling does nothing. A failure that says so is more useful than a view that
lies quietly.