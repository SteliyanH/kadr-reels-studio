import SwiftUI
import Kadr

/// Two-tier bottom toolbar — selection-driven swap. CapCut / VN pattern: the
/// row shows root verbs (Clip / Overlay / …) when nothing's selected, swaps to
/// clip-action verbs when a clip is selected, to overlay-action verbs when an
/// overlay is selected, and to the multi-select row during a long-press
/// selection.
///
/// v0.8 Tier 5b — every mode is now a **ruled modular row**: equal cells with
/// 2pt dividers between them, icon over label and both flush left inside the
/// cell (`ReelToolbarButtonStyle`), a gap, then the row's one trailing
/// action. Export takes the accent fill; Delete takes the accent *outline*
/// (Decision 4 — the accent already is red, so a second red fill can't read as
/// danger). The `Mode` state machine and the
/// `.interactiveSpring(response: 0.35, dampingFraction: 0.78)` crossfade are
/// untouched: this is a restyle, not a rewrite.
struct EditorToolbar: View {

    var store: ProjectStore
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.reelPalette) private var palette

    // Root-row callbacks — owned by `EditorView` so it can present sheets.
    var onAddClip: () -> Void
    var onAddOverlay: () -> Void
    var onLayers: () -> Void
    var onAddMusic: () -> Void
    var onAddSFX: () -> Void
    var onAddCaptions: () -> Void
    var onExport: () -> Void

    // Clip-row callbacks that need a sheet — also owned by the editor.
    var onSpeedCurve: (ClipID) -> Void
    var onFilters: (ClipID) -> Void = { _ in }
    var onTransition: (ClipID) -> Void = { _ in }

    private enum Mode: Equatable { case root, clip(ClipID), overlay(LayerID), multiSelect }

    private var mode: Mode {
        // Multi-select wins over everything — it's a transient mode the user
        // explicitly entered via long-press, so we don't fall back to the
        // single-select rows while it's active.
        if store.isMultiSelecting { return .multiSelect }
        if let id = store.selectedOverlayID { return .overlay(id) }
        if let id = store.selectedClipID { return .clip(id) }
        return .root
    }

    var body: some View {
        Group {
            switch mode {
            case .root:
                rootRow
                    .transition(.opacity)
            case .clip(let id):
                clipRow(id: id)
                    .transition(.opacity)
            case .overlay(let id):
                overlayRow(id: id)
                    .transition(.opacity)
            case .multiSelect:
                multiSelectRow
                    .transition(.opacity)
            }
        }
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: mode)
        .padding(.horizontal, Reel.Space.s3)
        .padding(.top, Reel.Space.s2)
        // The band's own chrome lives here rather than at the call site: this
        // view can read the studio palette from the environment, and
        // `EditorView` — which establishes that ground — cannot read it back
        // out for its own body.
        .padding(.bottom, Reel.toolbarBottomInset)
        .frame(maxWidth: .infinity)
        .background(palette.surface)
        .reelRule(.top)
    }

    // MARK: - Root row

    @ViewBuilder
    private var rootRow: some View {
        HStack(spacing: 0) {
            ruledCells([
                Cell(id: "clip", systemImage: "plus.rectangle", label: "Clip", action: onAddClip),
                Cell(id: "overlay", systemImage: "textformat", label: "Overlay", action: onAddOverlay),
                Cell(id: "layers", systemImage: "square.stack.3d.up", label: "Layers", action: onLayers),
                Cell(id: "music", systemImage: "music.note", label: "Music", action: onAddMusic),
                Cell(id: "sfx", systemImage: "speaker.wave.2", label: "SFX", action: onAddSFX),
                Cell(id: "captions", systemImage: "captions.bubble", label: "Captions", action: onAddCaptions)
            ])
            cell(
                Cell(
                    id: "export",
                    systemImage: "square.and.arrow.up",
                    label: "Export",
                    hint: EditorToolbar.exportTooltip(hasClips: !store.project.clips.isEmpty),
                    action: onExport
                ),
                isProminent: true
            )
            // The design's gap between the modular group and the row's one
            // primary action. Padding rather than a spacer so Export stays an
            // equal cell instead of collapsing to its label.
            .padding(.leading, Reel.Space.s2)
            // The style already dims a disabled cell to the repo's 45%; the
            // v0.5 rule is "disabled, never hidden", so nothing else to do.
            .disabled(store.project.clips.isEmpty)
        }
    }

    // MARK: - Clip-action row

    @ViewBuilder
    private func clipRow(id: ClipID) -> some View {
        HStack(spacing: 0) {
            ruledCells(clipCells(id: id))
            deleteCell(
                hint: "Removes this clip from the project"
            ) {
                HapticEngine.shared.thud()
                store.removeClip(id: id)
            }
        }
    }

    /// The clip row's leading cells. "Copy" and "Trans." are the approved
    /// design's cell labels; VoiceOver keeps the unabbreviated verbs, so the
    /// v0.5 sweep's audio output doesn't regress into an abbreviation.
    private func clipCells(id: ClipID) -> [Cell] {
        var cells: [Cell] = [
            Cell(
                id: "split",
                systemImage: "scissors",
                label: "Split",
                hint: "Splits the clip at the playhead"
            ) {
                let result = store.splitClip(id: id, at: store.currentTime)
                if result != .ok {
                    toasts.show(.transient(message: "Can't split", detail: EditorToolbar.splitFailureDetail(result)))
                }
            },
            Cell(
                id: "copy",
                systemImage: "doc.on.doc",
                label: "Copy",
                accessibilityLabel: "Duplicate",
                hint: "Inserts a copy of this clip after itself"
            ) {
                store.duplicateClip(id: id)
            },
            Cell(
                id: "speed",
                systemImage: "speedometer",
                label: "Speed",
                hint: "Opens the speed curve editor"
            ) {
                onSpeedCurve(id)
            },
            Cell(
                id: "filters",
                systemImage: "camera.filters",
                label: "Filters",
                hint: "Opens the filter stack editor"
            ) {
                onFilters(id)
            }
        ]
        // v0.7 Tier 2 — only shown when the clip has a successor (a
        // transition needs something to dissolve into). The check looks
        // at the top-level `project.clips` array; clips inside a Track
        // don't get the button because Track-internal transitions are
        // a separate cycle.
        if EditorToolbar.clipHasSuccessor(id: id, in: store.project.clips) {
            cells.append(
                Cell(
                    id: "transition",
                    systemImage: "rectangle.righthalf.inset.filled.arrow.right",
                    label: "Trans.",
                    accessibilityLabel: "Transition",
                    hint: "Edit the transition between this clip and the next"
                ) {
                    onTransition(id)
                }
            )
        }
        return cells
    }

    // MARK: - Overlay-action row

    @ViewBuilder
    private func overlayRow(id: LayerID) -> some View {
        HStack(spacing: 0) {
            ruledCells([
                Cell(
                    id: "duplicate-overlay",
                    systemImage: "doc.on.doc",
                    label: "Copy",
                    accessibilityLabel: "Duplicate",
                    hint: "Inserts a copy of this overlay one z-step above"
                ) {
                    store.duplicateOverlay(id: id)
                },
                Cell(
                    id: "forward",
                    systemImage: "square.3.stack.3d.top.fill",
                    label: "Forward",
                    hint: "Brings this overlay one step toward the front"
                ) {
                    store.moveOverlay(id: id, by: 1)
                },
                Cell(
                    id: "back",
                    systemImage: "square.3.stack.3d.bottom.fill",
                    label: "Back",
                    hint: "Sends this overlay one step toward the back"
                ) {
                    store.moveOverlay(id: id, by: -1)
                }
            ])
            deleteCell(
                hint: "Removes this overlay from the project"
            ) {
                HapticEngine.shared.thud()
                store.removeOverlay(id: id)
            }
        }
    }

    // MARK: - Multi-select row

    @ViewBuilder
    private var multiSelectRow: some View {
        HStack(spacing: Reel.Space.s3) {
            cell(
                Cell(
                    id: "cancel",
                    systemImage: "xmark",
                    label: "Cancel",
                    hint: "Exits multi-select mode without wrapping"
                ) {
                    store.isMultiSelecting = false
                }
            )
            // Two hit targets wide: this row's cells hug rather than divide
            // the row, so the count reads as the row's subject.
            .frame(maxWidth: Reel.minHitTarget * 2)

            Text("\(store.selectedClipIDs.count) selected")
                .font(Reel.Typography.caption.weight(Reel.Typography.emphasisWeight))
                .foregroundStyle(palette.textMuted)
                .accessibilityLabel("Selection")
                .accessibilityValue("\(store.selectedClipIDs.count) clips selected")

            Spacer(minLength: Reel.Space.s2)

            cell(
                Cell(
                    id: "wrap",
                    systemImage: "rectangle.stack",
                    label: "Wrap",
                    hint: "Wraps the selected clips in a track"
                ) {
                    let result = store.wrapInTrack(ids: store.selectedClipIDs)
                    if result != .ok {
                        toasts.show(
                            .transient(
                                message: "Can't wrap",
                                detail: EditorToolbar.wrapFailureDetail(result)
                            )
                        )
                    }
                }
            )
            .frame(maxWidth: Reel.minHitTarget * 2)
            .disabled(store.selectedClipIDs.isEmpty)
        }
    }

    // MARK: - Cells

    /// One toolbar cell's content. A value type rather than a view so a row
    /// can be built as a list and the 2pt dividers dropped between entries
    /// without every row hand-writing them.
    private struct Cell: Identifiable {
        let id: String
        let systemImage: String
        let label: String
        /// VoiceOver output when the visible label is abbreviated ("Trans.").
        var accessibilityLabel: String?
        /// Optional VoiceOver hint for non-obvious actions. The label alone is
        /// enough for `Clip` or `Export`; non-trivial verbs like `Split` or
        /// `Wrap` ride with a hint so VoiceOver users get the effect, not just
        /// the icon's name. v0.5 Tier 2.
        var hint: String?
        let action: () -> Void

        init(
            id: String,
            systemImage: String,
            label: String,
            accessibilityLabel: String? = nil,
            hint: String? = nil,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.systemImage = systemImage
            self.label = label
            self.accessibilityLabel = accessibilityLabel
            self.hint = hint
            self.action = action
        }
    }

    /// The leading group: equal cells, 2pt rules between them, no gaps. The
    /// rules do the organising — this is the system's modular row.
    ///
    /// Emitted straight into the row's own `HStack` rather than wrapped in a
    /// nested one: `ForEach` flattens into its container, so every cell —
    /// including the trailing Export / Delete — is a peer sharing the row's
    /// width equally. Nesting them would make the *group* one flexible child
    /// and hand the trailing cell half the row.
    ///
    /// The rule rides as a trailing *overlay* on each cell rather than as a
    /// sibling `Rectangle`. A sibling rectangle has no intrinsic height: it
    /// grows to whatever the stack offers, which made the toolbar band claim
    /// the editor's leftover height and squeeze the stage. An overlay is sized
    /// by its host, so the row stays exactly one cell tall.
    @ViewBuilder
    private func ruledCells(_ cells: [Cell]) -> some View {
        ForEach(Array(cells.enumerated()), id: \.element.id) { index, item in
            cell(item, isRuled: index < cells.count - 1)
        }
    }

    private func cell(
        _ item: Cell,
        isProminent: Bool = false,
        isRuled: Bool = false
    ) -> some View {
        Button(action: item.action) {
            cellLabel(systemImage: item.systemImage, label: item.label)
        }
        .buttonStyle(ReelToolbarButtonStyle(isProminent: isProminent))
        .overlay(alignment: .trailing) {
            if isRuled {
                Rectangle()
                    .fill(palette.divider)
                    .frame(width: palette.ruleWidth)
            }
        }
        // Default VoiceOver output combines the image's localized name and
        // the text — verbose ("plus rectangle Clip"). Replace it with just
        // the user-facing verb so the audio matches the visible text.
        .accessibilityLabel(item.accessibilityLabel ?? item.label)
        .accessibilityHint(item.hint ?? "")
        // v0.5 Tier 3 — tap-and-hold tooltip on iPadOS / pointer-hover on
        // macOS / Catalyst. Falls back to the visible label when no richer
        // hint is provided. iOS phones (no pointer) ignore .help silently.
        .help(item.hint ?? item.label)
    }

    /// Delete: the accent-*outlined* secondary style, same cell geometry as
    /// its neighbours. Decision 4 — a second red fill next to the accent
    /// can't read as danger, so the outline plus the trash glyph carries it.
    private func deleteCell(
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: .destructive, action: action) {
            cellLabel(systemImage: "trash", label: "Delete")
        }
        .buttonStyle(ReelSecondaryButtonStyle(isBlock: true))
        .padding(.leading, Reel.Space.s2)
        .accessibilityLabel("Delete")
        .accessibilityHint(hint)
        .help(hint)
    }

    /// Icon over label, both leading-aligned inside the cell. The explicit
    /// fonts here beat the button style's outer font, which is what keeps the
    /// glyph a glyph and the label a caption in *both* styles.
    private func cellLabel(systemImage: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Reel.Space.s1) {
            Image(systemName: systemImage)
                .font(.system(
                    size: Reel.Typography.Glyph.sm,
                    weight: Reel.Typography.emphasisWeight
                ))
            Text(LocalizedStringKey(label))
                .font(Reel.Typography.caption.weight(Reel.Typography.emphasisWeight))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension EditorToolbar {
    /// Whether `id` identifies a top-level clip that has a successor in
    /// `clips` (a transition needs something to dissolve into). v0.7 Tier 2.
    /// Returns false when the clip isn't at the top level (Track-internal
    /// clips don't get the toolbar transition button) or is the last entry.
    nonisolated static func clipHasSuccessor(id: ClipID, in clips: [any Clip]) -> Bool {
        guard let index = clips.firstIndex(where: { $0.clipID == id }) else {
            return false
        }
        return index + 1 < clips.count
    }

    /// User-facing detail for each `splitClip` failure mode.
    static func splitFailureDetail(_ result: ProjectStore.SplitResult) -> String {
        switch result {
        case .ok: return ""
        case .clipNotFound: return "The selected clip is no longer in the project."
        case .clipInsideTrack: return "Clips inside a track aren't splittable yet."
        case .offsetOutOfRange: return "Move the playhead inside the clip and try again."
        case .unsupportedSpeedRate: return "Clear the speed rate before splitting."
        }
    }

    /// User-facing detail for each `wrapInTrack` failure mode.
    static func wrapFailureDetail(_ result: ProjectStore.WrapInTrackResult) -> String {
        switch result {
        case .ok: return ""
        case .noSelection: return "Long-press a clip to start a selection."
        case .nonContiguous: return "Selection must be contiguous to wrap in a track."
        case .clipsNotAtTopLevel: return "Clips already inside a track can't be re-wrapped."
        }
    }

    /// Tooltip / VoiceOver hint for the Export button. Differs by whether
    /// the project has clips to export — disabled-state messages tell the
    /// user *why* the button is dimmed rather than just hiding it. Pure for
    /// testability; the toolbar inlines the call. v0.5 Tier 3.
    static func exportTooltip(hasClips: Bool) -> String {
        hasClips ? "Opens the export sheet" : "Add a clip first to enable export"
    }
}
