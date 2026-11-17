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
    var acceptsKeyboard = false

    override var canBecomeKey: Bool {
        isPresenting && (acceptsKeyboard || UIAccessibility.isVoiceOverRunning)
    }
}

// MARK: - Media Preview Presenter

@MainActor
class MediaPreviewPresenter: ObservableObject {

    // MARK: - Published State (observed by MediaPreviewView)

    @Published var isExpanded: Bool = false
    @Published var isDismissing: Bool = false
    @Published var model: MediaPreviewModel?

    @Published var backgroundAlpha: Double = 0

    // MARK: - Non-Published State (read by view body, mutated by presenter)

    var sourceFrame: CGRect = .zero
    var hasSourceFrame: Bool = false
    var navBarBottomY: CGFloat = 0
    var messagePanelTopY: CGFloat = 0
    var sourceFrameProvider: (() -> CGRect)?

    // MARK: - Window Lifecycle

    private let dismissAnimationDuration: TimeInterval = 0.35
    private var overlayWindow: PassthroughWindow?
    private weak var previousKeyWindow: UIWindow?
    private var dismissGeneration: UInt = 0
    private var dismissCompletion: (() -> Void)?

    var presentationHost: UIViewController? {
        guard let window = overlayWindow, window.isPresenting, !isDismissing,
              var top = window.rootViewController else { return nil }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    func closeImmediately(then completion: (() -> Void)? = nil) {
        guard let window = overlayWindow else {
            completion?()
            return
        }
        let close = { [weak self] in
            guard let self = self else { return }
            UIView.performWithoutAnimation {
                window.endEditing(true)
                self.previousKeyWindow?.endEditing(true)
            }
            self.dismissGeneration += 1
            self.dismissCompletion = completion
            self.tearDown()
        }
        if let presented = window.rootViewController?.presentedViewController {
            presented.dismiss(animated: false, completion: close)
        } else {
            close()
        }
    }

    func keyboardOverlap(for screenFrame: CGRect) -> CGFloat {
        guard let window = overlayWindow, !screenFrame.isEmpty else { return 0 }
        let frame = window.convert(screenFrame, from: window.screen.coordinateSpace)
        let overlap = window.bounds.intersection(frame)
        return overlap.isNull ? 0 : window.bounds.maxY - overlap.minY
    }

    func setAcceptsKeyboard(_ accepts: Bool) {
        guard let window = overlayWindow, window.acceptsKeyboard != accepts else { return }
        window.acceptsKeyboard = accepts
        if accepts {
            previousKeyWindow = UIWindow.currentKeyWindow
            window.makeKey()
        } else {
            restoreKeyWindow()
        }
    }

    private func restoreKeyWindow() {
        guard let previous = previousKeyWindow, !previous.isHidden else { return }
        previous.makeKey()
        previousKeyWindow = nil
    }

    func present(model: MediaPreviewModel, sourceFrame: CGRect = .zero, sourceFrameProvider: (() -> CGRect)? = nil) {
        // If currently dismissing, tear down immediately to allow re-presentation.
        if isDismissing {
            tearDown()
        }
        guard overlayWindow == nil else { return }
        UIWindow.currentKeyWindow?.endEditing(true)
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
        window.overrideUserInterfaceStyle = .dark
        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.isHidden = false
        window.isPresenting = true
        self.overlayWindow = window

        hostingController.view.layoutIfNeeded()
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeOut(duration: 0.15)) {
                self?.backgroundAlpha = 1
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                self?.isExpanded = true
            }
        }
    }

    func dismiss(completion: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        if let model = model, model.isReplying {
            overlayWindow?.endEditing(true)
            model.cancelReply()
        }
        dismissCompletion = completion
        if let scene = overlayWindow?.windowScene {
            navBarBottomY = Self.computeNavBarBottomY(in: scene)
        }
        if hasSourceFrame, let provider = sourceFrameProvider {
            let currentFrame = provider()
            if currentFrame != .zero {
                sourceFrame = currentFrame
            }
        }
        isDismissing = true

        dismissGeneration += 1
        let currentGeneration = dismissGeneration

        withAnimation(.spring(response: dismissAnimationDuration, dampingFraction: 0.88)) {
            self.isExpanded = false
        }

        withAnimation(.easeIn(duration: 0.15).delay(dismissAnimationDuration * 0.5)) {
            self.backgroundAlpha = 0
        }

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
        if overlayWindow?.acceptsKeyboard == true {
            overlayWindow?.acceptsKeyboard = false
            restoreKeyWindow()
        }
        overlayWindow?.isPresenting = false
        overlayWindow?.isHidden = true
        overlayWindow = nil
        isDismissing = false
        model = nil
        sourceFrameProvider = nil
        backgroundAlpha = 0
        let completion = dismissCompletion
        dismissCompletion = nil
        completion?()
    }

    /// Computes the bottom Y of the navigation bar in global coordinates.
    private static func computeNavBarBottomY(in scene: UIWindowScene) -> CGFloat {
        for window in scene.windows where window.windowLevel == .normal {
            guard let rootVC = window.rootViewController else { continue }
            var candidate = firstNavigationController(in: rootVC)
            var current: UIViewController = rootVC
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

    private static func firstNavigationController(in controller: UIViewController) -> UINavigationController? {
        if let nav = controller as? UINavigationController {
            return nav
        }
        for child in controller.children {
            if let nav = firstNavigationController(in: child) {
                return nav
            }
        }
        return nil
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
