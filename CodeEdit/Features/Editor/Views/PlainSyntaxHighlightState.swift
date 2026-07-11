//
//  PlainSyntaxHighlightState.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Foundation
import CodeEditHighlighting

// Per-document highlight state. Every NSTextStorage (one per open document
// window) owns its own generation counter and span cache, so one window's
// request can never invalidate another window's in-flight compute. A single
// shared static counter would let window B's request bump the generation and
// strand window A's ~6 s cold result at the post-compute guard.
@MainActor
final class HighlightState {
    var cachedLanguage = ""
    var cachedText = ""
    var cachedSpans: [HighlightSpan] = []
    // The theme name last applied to this storage. Starts at the bundled
    // default so the very first highlight pass (which also resolves to
    // the bundled default in the common case) does not spuriously log a
    // SETTINGS_APPLIED marker; only an actual Settings-driven change to a
    // different theme name logs one, matching the font marker's
    // create-vs-update distinction in PlainTextEditorView.
    var lastAppliedThemeName = ThemeRepository.bundledDefaultThemeName
    // Monotonic request token for THIS storage. Every request captures the
    // current value; a background result whose token no longer matches is
    // stale (a newer request for this same storage superseded it).
    var latestGeneration = 0
    // The most recently scheduled highlight task for this storage. A newer
    // request cancels this one before starting its own, so a superseded pass
    // is cancelled (structured, not abandoned) rather than left to run its
    // now-useless compute to completion (docs/SWIFT_STYLE.md section 4).
    var currentTask: Task<Void, Never>?
    #if DEBUG
    // Highest generation whose highlight pass has reached a terminal state
    // (applied its result, or was dropped as superseded, or hit the drift
    // cap). The keystroke bench's completion seam waits on this so it can
    // time the full mutation -> span compute -> paint window per edit.
    var lastSettledGeneration = 0
    // Callbacks waiting for a specific generation (or newer) to settle.
    var settleCallbacks: [HighlightSettleCallback] = []
    #endif
}

#if DEBUG
// One waiter registered through the DEBUG completion seam. Keyed on the
// generation the caller wants to observe settling; resumed once
// `lastSettledGeneration` reaches or passes it.
struct HighlightSettleCallback {
    let targetGeneration: Int
    let perform: () -> Void
}
#endif

// Owns the per-storage highlight state and the DEBUG completion seam the
// keystroke bench times against. Every scheduling path routes its terminal
// states through `settle`, so a generation always settles exactly once no
// matter which of the five terminal paths (coalesce, supersede, cancel, drift
// cap, applied) it reaches.
@MainActor
enum HighlightStateStore {
    // Weak-to-strong with POINTER identity keys: the key (storage) is held
    // weakly, so when a document window closes and its storage deallocs, the
    // entry is dropped automatically and the state does not leak; auto-cleanup
    // also avoids the ObjectIdentifier address-reuse hazard of a plain
    // dictionary. `.objectPointerPersonality` is essential: NSTextStorage is an
    // NSMutableAttributedString, which implements content-based hash/isEqual, so
    // the default object personality would rehash a storage on every edit and
    // lose its state (resetting the per-document generation on each keystroke).
    // Pointer personality keys on object identity, which is stable across edits.
    private static let states = NSMapTable<NSTextStorage, HighlightState>(
        keyOptions: [.weakMemory, .objectPointerPersonality],
        valueOptions: [.strongMemory],
        capacity: 4
    )

    static func state(for storage: NSTextStorage) -> HighlightState {
        if let existing = states.object(forKey: storage) {
            return existing
        }
        let created = HighlightState()
        states.setObject(created, forKey: storage)
        return created
    }

    // Settles a generation on the DEBUG completion seam. A no-op in release, so
    // the bounded and full scheduling paths can mark terminal states uniformly
    // without scattering `#if DEBUG` around every early return.
    static func settle(state: HighlightState, generation: Int) {
        #if DEBUG
        markGenerationSettled(state: state, generation: generation)
        #endif
    }

    #if DEBUG
    // Set once the initial Swift highlight has logged its milestone token
    // summary; the command self-test then suppresses further per-edit
    // rehighlights so the smoke log stays clean.
    static var didLogSmokeTokenSummary = false

    // DEBUG-only completion seam for the keystroke bench. Runs `completion` on
    // the main actor once the highlight pass for `storage`'s current latest
    // generation (or a newer superseding one) has fully settled, including
    // applyHighlight's attribute painting and layoutLines. If that generation
    // has already settled, `completion` runs on the next main-actor turn.
    //
    // A superseded generation still settles (it stops at the coalesce or drift
    // guard and marks itself settled there), so a waiter never deadlocks on a
    // request that a newer edit replaced.
    static func onHighlightSettled(storage: NSTextStorage, perform completion: @escaping () -> Void) {
        let state = state(for: storage)
        let target = state.latestGeneration
        if state.lastSettledGeneration >= target {
            // Nothing outstanding for this generation; run now. The bench's
            // callbacks each mutate the document and register a fresh waiter for
            // the next (still in-flight) generation, so this cannot recurse
            // unboundedly.
            completion()
            return
        }
        state.settleCallbacks.append(HighlightSettleCallback(targetGeneration: target, perform: completion))
    }

    // Records `generation` as terminally settled for this storage and runs any
    // waiting completion callbacks whose target generation has now been reached.
    private static func markGenerationSettled(state: HighlightState, generation: Int) {
        if generation > state.lastSettledGeneration {
            state.lastSettledGeneration = generation
        }
        guard !state.settleCallbacks.isEmpty else { return }
        var stillWaiting: [HighlightSettleCallback] = []
        var readyToRun: [HighlightSettleCallback] = []
        for callback in state.settleCallbacks {
            if callback.targetGeneration <= state.lastSettledGeneration {
                readyToRun.append(callback)
            } else {
                stillWaiting.append(callback)
            }
        }
        state.settleCallbacks = stillWaiting
        for callback in readyToRun {
            callback.perform()
        }
    }
    #endif
}
