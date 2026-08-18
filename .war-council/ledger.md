# Mission Ledger

The record of the War Council. One entry per mission. Append only; never amend a
closed entry — a correction is a new line, not an erasure.

Line format (the summary index):

    <ISO date> | <mission class> | squads: <list> | gates: <results> | verdict: <VICTORY/DEFEAT/PARTIAL>

Each summary line is followed by a detail block. Counts are transcribed from gate
output. Where a count was not observed, the record reads `unrecorded`. A false
ledger is treason.

**This file is `ledger.md`, not `ledger.log`.** The scribe's standing duty names
`.war-council/ledger.log`; the commander ruled for Markdown so the record renders
on GitHub and reads as prose for humans. Deviation recorded here so no future
scribe splits the record across two files. There is one ledger. It is this one.

**Gate counts are recorded against the tree that was actually measured.** A gate
run that predates a remedy pass is stale and does not count. Where an entry was
corrected after the fact, the correction is written into the entry — see the
Amendments block.

---

2026-08-18 | feature | squads: death-knights(opus), wardens(sonnet), skeletons(haiku) | gates: pre PASS, analyze SKIPPED, tests PASS (460 unit / 0 fail; 6 UI / 0 fail), a11y PASS (7 / 0 fail, blind), build PASS (0 warnings) | verdict: VICTORY

### Mission

GitHub issue **#73** — Transport band: play / skip / loop / fullscreen under the
stage. Target version **v0.9**. Branch `develop`. Mission anchor
`b99f8979c66c0d3c586c125dc9a5e78de268cc7e`.

Delivered: a transport band beneath the editor stage — skip-back · play/pause ·
skip-forward, a centred `elapsed / total` readout in tabular numerics, loop, and
fullscreen.

### The Host

| Squad | Model | Disposition |
|---|---|---|
| Death-knights | opus | Raised. Three production wounds routed to them on remedy. |
| Wardens | sonnet | Raised. Drew no blood. |
| Skeletons | haiku | Raised. Two false-record wounds routed to them on remedy. |
| Abominations | — | Held in reserve. Unspent. |

### The Gates

| Gate | Result | Counts |
|---|---|---|
| `pre` (`xcodegen generate`) | PASS | — |
| `analyze` | SKIPPED | Unconfigured in `war-council.yaml`; no swiftlint config or binary on this machine. |
| `tests` | PASS | Executed 460 unit tests, 0 failures; 6 UI tests, 0 failures. |
| `a11y` | PASS | `ProjectRowAccessibilityTests`, 7 tests, 0 failures. **Blind to this mission.** |
| `build` | PASS | BUILD SUCCEEDED, 0 warnings. |

**The a11y gate is blind to this mission.** It exercises the project-list row
and touches no transport control. It proves nothing about the band. Transport
accessibility coverage rode the `tests` gate instead: `TransportAccessibilityTests`,
15 tests — bundle-key resolution, state-dependent spoken labels, and the
two-part time readout. The record notes this so no future reader mistakes a
green a11y gate for accessibility assurance on the transport.

New coverage landing in the `tests` gate — 57 tests across two files:

| Suite | Tests |
|---|---|
| `TransportBandTests` | 28 |
| `EditorPlayheadPersistenceTests` | 9 |
| `CompositionIdentityTests` | 5 |
| `TransportAccessibilityTests` | 15 |

The first three share the file `Tests/ReelsStudioTests/TransportBandTests.swift`
(42 tests total in that file).

### Sylvanas

Verdict **UNWORTHY** on first review. Wounds routed for one remedy pass:

- Three production wounds → death-knights.
- Two false-record wounds → skeletons. Both were the same phantom: a claimed
  kadr-ui floor bump from 0.13.0 to 0.14.0, asserted in `CHANGELOG.md` and in
  `DESIGN.md`. 0.14.0 was already the floor, set by the chroma-key work. This
  feature *requires* that floor; it does not *raise* it. Both healed to
  "no floor change; already required by chroma-key work" — confirmed present in
  the diff at both sites.
- Wardens drew no blood.

All remedies landed. Gates then ran green. Second verdict: WORTHY.

### Rulings

1. **Skip is a fixed 1.0s, clamped to `[.zero, duration]`.** Frame-step was
   ruled out on evidence, not taste: kadr-ui's `VideoPreview` drops seeks below
   0.05s, and one frame at 30fps is 0.0333s — the button would have been
   silently inert on every press. Buttons disable at their bounds rather than
   silently clamping, so what VoiceOver reports and what the button does agree.
2. **Loop is app-side; `loops: false` is always passed to `VideoPreview`.**
   kadr-ui captures `loops` at player construction and `.task(id:)`'s identity
   does not include it, so a bound `loops:` toggle would read clean and be inert
   on device until something else rebuilt the player. The app watches the
   `isPlaying` fall and restarts.
3. **No schema change.** `isPlaying` / `isLooping` are session UX state on
   `ProjectStore`, excluded from undo, of the same kind as `currentTime`.
   `ProjectDocument` stays schema v5.
4. **No upstream kadr-ui work.** See the Sylvanas wound above.
5. **Playhead writes are gated during playback** via the pure
   `EditorView.playheadRecord(for:isPlaying:currentTime:documentID:)`, and still
   flush on `.sceneBackgrounded` and `.editorDismissed`.

### The Reckoning

Carried in the diff but not named in the mission brief — recorded so they are
not mistaken for scope creep by a later reader:

- An AVKit transport-chrome blocker in `PreviewArea`, plus
  `.accessibilityHidden(true)` on the preview subtree. kadr-ui exposes no
  `showsPlaybackControls`; without the blocker two transports drive one player
  with no synchronisation.
- `onLoadFailure` now clears `isPlaying` and surfaces the error on the existing
  toast path. Without it a failed load strands the band reading "Pause" forever.
- `PreviewArea.compositionIdentity(of:)` restates kadr-ui's private player-rebuild
  fingerprint so playback stops on rebuild, preventing an orphaned time observer
  from fighting its replacement over one binding. Pinned by `CompositionIdentityTests`.
  **This is the standing risk:** the fingerprint is a copy of a private upstream
  definition. Drift in kadr-ui breaks it silently. The tests pin the app's copy,
  not upstream's.

Follow-ups: none filed.

### Amendments

- **The first gate run was stale and was re-run.** The initial `tests` gate
  executed 446 unit tests against a tree that predated the death-knights' remedy
  pass; it never covered `EditorPlayheadPersistenceTests`,
  `CompositionIdentityTests`, the AVKit chrome blocker, the `onLoadFailure` toast
  path, or `compositionIdentity(of:)`. All three gates were re-run against the
  remedied tree. The true count is **460 unit tests, 0 failures** (`Suite 'All
  tests'` / `ReelsStudioTests.xctest` = 460; `ReelsStudioUITests.xctest` = 6),
  `** TEST SUCCEEDED **`. The figures above are the re-run's. The 57-test
  new-coverage total was correct before the correction and is unchanged by it.
- **Death-knights' open caveat: resolved by the build gate.** Dropping
  `import Kadr` / `import KadrUI` from `TransportBand.swift` compiles clean while
  still reading `store.video.duration`. `** BUILD SUCCEEDED **`, 0 warnings. No
  re-add required. Closed — not carried as an outstanding risk.

### Infrastructure

`.war-council/` is untracked and carries the mission anchor
(`last-mission-start`) and this ledger. It is War Council infrastructure, not
part of the #73 feature, and is excluded from the mission commit.
