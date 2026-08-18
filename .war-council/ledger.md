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

---

2026-08-19 | feature | squads: death-knights(opus), abominations-harness(sonnet), abominations-ci(sonnet), skeletons(haiku) | gates: pre PASS, analyze SKIPPED, tests PASS (469 unit executed / 7 skipped by design / 0 fail; 6 UI / 0 fail), a11y PASS (47 / 0 fail), build PASS (0 warnings) | verdict: PARTIAL

### Mission

Issue #75 — snapshot harness over the editor view group. Framework, pinned CI
job, recording workflow, review discipline, proven end-to-end on one group.
PR #85 → `develop`. Commit `eadb307`. Anchor `2b5140c`.

### Verdict is PARTIAL, and why

The work is complete and every gate is green. **Sylvanas never ruled on this
diff.** She was mid-flight routing two record wounds when the session limit
ended the run, and could not be re-raised. A partial review was performed by
the commanding session in her place — seam production-safety, CI guard
integrity, dependency claims — which found one real wound (below). That is not
her pass and this entry does not record it as one. A mission whose review was
cut short is PARTIAL even when the gates are green.

### Thrones

**Throne demoted: fable → opus (limits).** The first Lich King fell to an API
529 mid-mission; the demotion rule was applied and a second was raised on opus.
The second fell to a session limit during the record. Two infrastructure
deaths, zero defeats in the work itself.

### Rulings

- Slice = the **editor group**, not the easier `ProjectListView`. A slice that
  dodges the hard problem (a deterministic stage) proves nothing end-to-end.
- `StageRendering` environment seam, default `.live`. Production reads, never
  writes; `StageRenderingTests` asserts the default so a flip fails a test.
- Snapshot-only CI job, runtime pinned, **fail loud, never fall back**. The
  main `test:` job keeps its documented highest-runtime float — 0 deleted
  lines in `ci.yml`.
- Baselines recorded on **CI only**. A fresh checkout has zero baselines and
  the snapshot job is knowingly red until the first record PR merges.

### The harness's first catch — the mission's own justification

`TransportBand` used SF Symbol names `gobackward.1` / `goforward.1`, which do
not exist (the family runs .5 / .10 / .15 / .30 / .45 / .60 / .75 / .90). Both
skip buttons drew missing-glyph placeholders on device. It merged in #84 the
previous day past the build gate, 47 a11y assertions, ViewInspector and a
Codex review — none of which look at pixels. Fixed to the unnumbered glyphs
with a regression test resolving each name against the system symbol set, and
the doc comment that justified the 1.0s interval by those glyphs corrected.

### The net was proven red

Required before belief: record (7/7, 7 PNGs) → perturb one fixture → **6
passed / 1 failed, "Snapshot does not match reference"** → revert (7/7) →
delete local baselines → no-env run (**7/7 skipped**, suite green). A snapshot
suite that has never failed on purpose is decoration.

### Wounds

- **BLOOD (CI, remedied):** the render-collect path looked for
  `Devices/<UDID>/tmp`, which does not exist. Real renders live under the app
  container's `tmp`. Replaced with a search; proved on a synthetic tree, on
  real PNGs from this machine, and on a filename-collision case.
- **Found by the commanding session in Sylvanas's absence:** DESIGN.md and
  CHANGELOG.md both claimed `swift-snapshot-testing ≥ 1.14.0` against a
  `1.19.4` pin in `project.yml`. Corrected in both files.
- **ASH:** exact executed-count assertion added to both workflows, so a
  snapshot that quietly stops running is a red. This closes the
  skipped-reads-as-coverage hole in config rather than in prose.

### Standing risks

- **Gates were run against a simulator UDID, not the `name=iPhone 17 Pro` in
  `war-council.yaml`.** Two devices on this machine share that name, so the
  configured selector is ambiguous and non-deterministic. Unfixed; it affects
  every gate, not just this mission.
- `@Environment(ToastCenter.self)` traps at host time even when never read.
  Worked around test-side only.
- No baselines exist yet. The harness is not proven against real committed
  references until the first record PR merges.
