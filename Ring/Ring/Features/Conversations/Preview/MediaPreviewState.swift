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
private final class PassthroughWindow: UIWindow {
    var isPresenting = false

    override var canBecomeKey: Bool {
        isPresenting && UIAccessibility.isVoiceOverRunning
    }
}

// MARK: - Media Preview Presenter

@MainActor
class MediaPreviewPresenter: ObservableObject {

    // MARK: - Published State (observed by MediaPreviewView)

    @Published var isExpanded: Bool = false
    @Published var isDismissing: Bool = false
    @Published var model: MediaPreviewModel?

    /// Vertical drag offset during an interactive dismiss gesture.
    @Published var dragOffset: CGFloat = 0
    @Published var backgroundAlpha: Double = 0

    // MARK: - Non-Published State (read by view body, mutated by presenter)

    var sourceFrame: CGRect = .zero
    var hasSourceFrame: Bool = false
    var navBarBottomY: CGFloat = 0
    var sourceFrameProvider: (() -> CGRect)?
    var isDragging: Bool { dragOffset != 0 }

    // MARK: - Auto-Hide Timer

    private var autoHideTask: Task<Void, Never>?

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

    // MARK: - Window Lifecycle

    private let dismissAnimationDuration: TimeInterval = 0.35
    private var overlayWindow: PassthroughWindow?
    /// Incremented on each dismiss to invalidate stale fallback timers.
    private var dismissGeneration: UInt = 0

    func present(model: MediaPreviewModel, sourceFrame: CGRect = .zero, sourceFrameProvider: (() -> CGRect)? = nil) {
        // If currently dismissing, tear down immediately to allow re-presentation.
        if isDismissing {
            tearDown()
        }
        guard overlayWindow == nil else { return }
        self.model = model
        self.hasSourceFrame = sourceFrame != .zero
        self.sourceFrameProvider = sourceFrameProvider

        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }

        let screenBounds = scene.screen.bounds

        // When no source frame is provided (e.g. context menu),
        // use the full screen as the source so the content fades in at full size.
        if sourceFrame == .zero {
            self.sourceFrame = screenBounds
        } else {
            self.sourceFrame = sourceFrame
        }
        self.navBarBottomY = Self.computeNavBarBottomY(in: scene)
        self.isExpanded = false
        self.backgroundAlpha = 0

        let overlayView = MediaPreviewView(overlayState: self)

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .normal + 1
        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.isHidden = false
        window.isPresenting = true
        self.overlayWindow = window

        Task { [weak self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                self?.isExpanded = true
                self?.backgroundAlpha = 1
            }
        }
    }

    func dismiss() {
        guard !isDismissing else { return }
        cancelAutoHide()
        if let scene = overlayWindow?.windowScene {
            navBarBottomY = Self.computeNavBarBottomY(in: scene)
        }
        // Refresh the source frame so the collapse animation targets the
        // thumbnail's current position (it may have scrolled since present).
        if hasSourceFrame, let provider = sourceFrameProvider {
            let currentFrame = provider()
            if currentFrame != .zero {
                sourceFrame = currentFrame
            }
        }
        isDismissing = true
        dragOffset = 0

        dismissGeneration += 1
        let currentGeneration = dismissGeneration

        withAnimation(.spring(response: dismissAnimationDuration, dampingFraction: 0.88)) {
            self.isExpanded = false
            self.backgroundAlpha = 0
        }

        // Tear down after the spring animation settles.
        let settleDuration = dismissAnimationDuration + 0.15
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(settleDuration * 1_000_000_000))
            guard let self = self,
                  self.dismissGeneration == currentGeneration,
                  self.isDismissing else { return }
            self.tearDown()
        }
    }

    private func tearDown() {
        autoHideTask?.cancel()
        overlayWindow?.isPresenting = false
        overlayWindow?.isHidden = true
        overlayWindow = nil
        isDismissing = false
        model = nil
        sourceFrameProvider = nil
        dragOffset = 0
        backgroundAlpha = 0
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
