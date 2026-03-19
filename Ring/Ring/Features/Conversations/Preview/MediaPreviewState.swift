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

/// Manages the state for the full-screen media preview overlay.
/// Uses a separate UIWindow so the overlay covers the navigation bar
/// without blocking the main window's rendering pipeline.
class MediaPreviewState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var isDismissing: Bool = false
    @Published var model: MediaPreviewModel?
    var sourceFrame: CGRect = .zero
    /// True when the preview was opened with a real thumbnail frame.
    /// When false, dismiss uses a fade instead of a collapse animation.
    var hasSourceFrame: Bool = false
    /// Bottom Y of the navigation bar, computed at present/dismiss time.
    var navBarBottomY: CGFloat = 0
    /// Holder for the auto-hide controls timer so it can be cancelled on teardown.
    var autoHideTaskHolder = PreviewAutoHideTaskHolder()
    /// Closure that returns the current global frame of the source thumbnail.
    /// Called at dismiss time so the collapse animation targets the up-to-date
    /// position even if the message list has scrolled since the preview opened.
    var sourceFrameProvider: (() -> CGRect)?

    /// Duration of the dismiss spring animation.
    private let dismissAnimationDuration: TimeInterval = 0.35
    private var overlayWindow: PassthroughWindow?

    deinit {
        let window = overlayWindow
        let holder = autoHideTaskHolder
        if Thread.isMainThread {
            holder.task?.cancel()
            window?.isPresenting = false
            window?.isHidden = true
        } else {
            DispatchQueue.main.async {
                holder.task?.cancel()
                window?.isPresenting = false
                window?.isHidden = true
            }
        }
    }

    func present(model: MediaPreviewModel, sourceFrame: CGRect = .zero, sourceFrameProvider: (() -> CGRect)? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))
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

        let overlayView = MediaPreviewView(overlayState: self)
        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = .clear

        let window = PassthroughWindow(windowScene: scene)
        window.rootViewController = hostingController
        window.windowLevel = .normal + 1
        window.isHidden = false
        window.isPresenting = true
        self.overlayWindow = window

        // Force a layout pass so SwiftUI renders the initial (collapsed) frame
        // before we animate to the expanded state. Without this, the animation
        // can be skipped if the async block runs before the first render commit.
        hostingController.view.layoutIfNeeded()
        CATransaction.flush()

        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                self?.isExpanded = true
            }
        }
    }

    func dismiss() {
        dispatchPrecondition(condition: .onQueue(.main))
        autoHideTaskHolder.task?.cancel()
        // Recompute nav bar Y in case orientation changed while preview was showing.
        // Use the overlay window's own scene rather than searching connected scenes.
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
        withAnimation(.spring(response: dismissAnimationDuration, dampingFraction: 0.88)) {
            self.isExpanded = false
        }
        let tearDownDelay = dismissAnimationDuration + 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + tearDownDelay) { [weak self] in
            self?.tearDown()
        }
    }

    private func tearDown() {
        dispatchPrecondition(condition: .onQueue(.main))
        autoHideTaskHolder.task?.cancel()
        overlayWindow?.isPresenting = false
        overlayWindow?.isHidden = true
        overlayWindow = nil
        isDismissing = false
        model = nil
        sourceFrameProvider = nil
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

final class PreviewAutoHideTaskHolder {
    var task: Task<Void, Never>?
}


