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

    private var overlayWindow: UIWindow?

    func present(model: MediaPreviewModel, sourceFrame: CGRect = .zero) {
        guard overlayWindow == nil else { return }
        self.model = model
        self.hasSourceFrame = sourceFrame != .zero
        // When no source frame is provided (e.g. context menu),
        // use the full screen as the source so the content fades in at full size.
        if sourceFrame == .zero {
            let screen = UIScreen.main.bounds
            self.sourceFrame = screen
        } else {
            self.sourceFrame = sourceFrame
        }
        self.isExpanded = false
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }

        let overlayView = MediaPreviewView(overlayState: self)
        let hostingController = UIHostingController(rootView: overlayView)
        hostingController.view.backgroundColor = .clear

        let window = UIWindow(windowScene: scene)
        window.rootViewController = hostingController
        window.windowLevel = .normal + 1
        window.isHidden = false
        self.overlayWindow = window

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                self.isExpanded = true
            }
        }
    }

    func dismiss() {
        isDismissing = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            self.isExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.tearDown()
        }
    }

    private func tearDown() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        isDismissing = false
        model = nil
    }
}

// MARK: - Environment Key

private struct MediaPreviewStateKey: EnvironmentKey {
    static let defaultValue: MediaPreviewState? = nil
}

extension EnvironmentValues {
    var mediaPreviewOverlayState: MediaPreviewState? {
        get { self[MediaPreviewStateKey.self] }
        set { self[MediaPreviewStateKey.self] = newValue }
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
