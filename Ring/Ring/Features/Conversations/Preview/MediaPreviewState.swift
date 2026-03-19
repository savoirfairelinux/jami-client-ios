/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI

/// A UIWindow subclass that avoids becoming the key window
/// so the overlay does not steal first-responder or input focus.
/// When VoiceOver is running and the preview is actively presented,
/// it allows key status so accessibility focus can be properly
/// trapped by the modal trait.
private final class PassthroughWindow: UIWindow {
    var isPresenting = false

    override var canBecomeKey: Bool {
        isPresenting && UIAccessibility.isVoiceOverRunning
    }
}

// MARK: - Animation State (ObservableObject for SwiftUI binding)

/// Pure observable state consumed by ``MediaPreviewView``.
/// Contains only published properties and the auto-hide timer.
/// No UIKit window references or lifecycle logic.
@MainActor
class MediaPreviewAnimationState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var isDismissing: Bool = false
    @Published var model: MediaPreviewModel?
    @Published var sourceFrame: CGRect = .zero
    /// True when the preview was opened with a real thumbnail frame.
    /// When false, dismiss uses a fade instead of a collapse animation.
    @Published var hasSourceFrame: Bool = false
    /// Bottom Y of the navigation bar, computed at present/dismiss time.
    @Published var navBarBottomY: CGFloat = 0

    // MARK: - Drag-to-Dismiss State

    /// Vertical drag offset during an interactive dismiss gesture.
    @Published var dragOffset: CGFloat = 0
    /// Background opacity — animated from 1 to 0 during drag and dismiss.
    @Published var backgroundAlpha: Double = 0
    /// Whether a drag gesture is actively in progress.
    var isDragging: Bool { dragOffset != 0 }

    /// Closure that returns the current global frame of the source thumbnail.
    /// Called at dismiss time so the collapse animation targets the up-to-date
    /// position even if the message list has scrolled since the preview opened.
    var sourceFrameProvider: (() -> CGRect)?

    // MARK: - Auto-Hide Timer

    private var autoHideTask: Task<Void, Never>?

    /// Schedules an auto-hide timer. Cancels any existing timer first.
    /// - Parameter action: Closure executed on the main actor when the timer fires.
    func scheduleAutoHide(after seconds: UInt64 = 5, action: @escaping () -> Void) {
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancelAutoHide() {
        autoHideTask?.cancel()
    }

    // MARK: - Reset

    /// Resets all state to initial values. Called by the presenter during teardown.
    func reset() {
        isDismissing = false
        model = nil
        sourceFrameProvider = nil
        dragOffset = 0
        backgroundAlpha = 0
        autoHideTask?.cancel()
    }
}

// MARK: - Presenter (owns window lifecycle)

/// Manages the full-screen media preview overlay window.
/// Owns a ``MediaPreviewAnimationState`` for SwiftUI binding and a
/// ``PassthroughWindow`` that covers the navigation bar.
/// The window instance is reused across present/dismiss cycles to
/// avoid repeated UIWindow creation and scene registration overhead.
@MainActor
class MediaPreviewPresenter: ObservableObject {
    let animationState = MediaPreviewAnimationState()

    private let dismissAnimationDuration: TimeInterval = 0.35
    private var overlayWindow: PassthroughWindow?
    /// Incremented on each dismiss to invalidate stale fallback timers.
    private var dismissGeneration: UInt = 0

    func present(model: MediaPreviewModel, sourceFrame: CGRect = .zero, sourceFrameProvider: (() -> CGRect)? = nil) {
        // If currently dismissing, tear down immediately to allow re-presentation.
        if animationState.isDismissing {
            tearDown()
        }
        guard !(overlayWindow?.isPresenting ?? false) else { return }
        animationState.model = model
        animationState.hasSourceFrame = sourceFrame != .zero
        animationState.sourceFrameProvider = sourceFrameProvider

        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }

        let screenBounds = scene.screen.bounds

        // When no source frame is provided (e.g. context menu),
        // use the full screen as the source so the content fades in at full size.
        if sourceFrame == .zero {
            animationState.sourceFrame = screenBounds
        } else {
            animationState.sourceFrame = sourceFrame
        }
        animationState.navBarBottomY = Self.computeNavBarBottomY(in: scene)
        animationState.isExpanded = false
        animationState.backgroundAlpha = 0

        let overlayView = MediaPreviewView(
            animationState: animationState,
            dismissAction: { [weak self] in self?.dismiss() }
        )

        // Reuse existing window or create a new one.
        let window: PassthroughWindow
        if let existing = overlayWindow, existing.windowScene == scene {
            window = existing
        } else {
            overlayWindow?.isHidden = true
            window = PassthroughWindow(windowScene: scene)
            window.windowLevel = .normal + 1
            self.overlayWindow = window
        }

        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.isHidden = false
        window.isPresenting = true

        Task { [weak self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                self?.animationState.isExpanded = true
                self?.animationState.backgroundAlpha = 1
            }
        }
    }

    func dismiss() {
        guard !animationState.isDismissing else { return }
        animationState.cancelAutoHide()
        // Recompute nav bar Y in case orientation changed while preview was showing.
        if let scene = overlayWindow?.windowScene {
            animationState.navBarBottomY = Self.computeNavBarBottomY(in: scene)
        }
        // Refresh the source frame so the collapse animation targets the
        // thumbnail's current position (it may have scrolled since present).
        if animationState.hasSourceFrame, let provider = animationState.sourceFrameProvider {
            let currentFrame = provider()
            if currentFrame != .zero {
                animationState.sourceFrame = currentFrame
            }
        }
        animationState.isDismissing = true
        animationState.dragOffset = 0

        dismissGeneration += 1
        let currentGeneration = dismissGeneration

        withAnimation(.spring(response: dismissAnimationDuration, dampingFraction: 0.88)) {
            self.animationState.isExpanded = false
            self.animationState.backgroundAlpha = 0
        }

        // Tear down after the spring animation settles.
        // The spring with response=0.35 and damping=0.88 settles within
        // ~3x the response time. We use a conservative multiplier.
        let settleDuration = dismissAnimationDuration * 3
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(settleDuration * 1_000_000_000))
            guard let self = self,
                  self.dismissGeneration == currentGeneration,
                  self.animationState.isDismissing else { return }
            self.tearDown()
        }
    }

    private func tearDown() {
        overlayWindow?.isPresenting = false
        overlayWindow?.rootViewController = nil
        overlayWindow?.isHidden = true
        // Keep overlayWindow alive for reuse; just reset state.
        animationState.reset()
    }

    /// Computes the bottom Y of the navigation bar in global coordinates.
    private static func computeNavBarBottomY(in scene: UIWindowScene) -> CGFloat {
        for window in scene.windows where window.windowLevel == .normal {
            guard let rootVC = window.rootViewController else { continue }
            var candidate: UINavigationController?
            var current: UIViewController = rootVC
            if let nav = current as? UINavigationController {
                candidate = nav
            }
            while let presented = current.presentedViewController {
                if let nav = presented as? UINavigationController {
                    candidate = nav
                } else if let nav = presented.navigationController {
                    candidate = nav
                }
                current = presented
            }
            if let nav = candidate {
                let bar = nav.navigationBar
                let barFrame = bar.convert(bar.bounds, to: window)
                return barFrame.maxY
            }
        }
        return UIWindow.currentSafeAreaInsets.top
    }
}

// MARK: - UIWindow Helpers

extension UIWindow {
    static var currentKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first { $0.isKeyWindow }
    }

    static var currentSafeAreaInsets: UIEdgeInsets {
        currentKeyWindow?.safeAreaInsets ?? .zero
    }
}
