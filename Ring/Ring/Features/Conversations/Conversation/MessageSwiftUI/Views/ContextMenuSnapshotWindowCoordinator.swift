/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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
import UIKit

/// Captures a screenshot of the key window and hosts the context menu in a
/// high-level UIWindow so that it covers the navigation bar as well.
struct ContextMenuSnapshotWindowCoordinator: UIViewRepresentable {
    let snapshot: UIImage?
    let presentingState: ContextMenuPresentingState
    let model: ContextMenuVM
    @Binding var presentingStateBinding: ContextMenuPresentingState

    private static let overlayWindowLevel = UIWindow.Level(rawValue: 20_000_000)

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let shouldShow = snapshot != nil
        && presentingState == .shouldPresent
        && model.presentingMessageView != nil

        if shouldShow {
            showOverlayWindow(containerView: uiView, coordinator: context.coordinator)
        } else {
            hideOverlayWindow(coordinator: context.coordinator)
        }
    }

    private func showOverlayWindow(containerView: UIView, coordinator: Coordinator) {
        guard let snapshot = snapshot else { return }
        let windowScene = containerView.window?.windowScene ?? Self.currentWindowScene
        guard let windowScene = windowScene else { return }

        let content = ZStack {
            Image(uiImage: snapshot)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea(.all)
            ContextMenuView(model: model, presentingState: $presentingStateBinding)
        }
            .edgesIgnoringSafeArea(.all)

        if let window = coordinator.overlayWindow,
           window.windowScene == windowScene,
           let hosting = window.rootViewController as? UIHostingController<AnyView> {
            hosting.rootView = AnyView(content)
            window.frame = windowScene.coordinateSpace.bounds
            window.isHidden = false
            return
        }

        coordinator.releaseWindow()

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = Self.overlayWindowLevel
        window.backgroundColor = .clear

        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear
        window.rootViewController = hosting
        window.frame = windowScene.coordinateSpace.bounds
        window.isHidden = false
        coordinator.overlayWindow = window
    }

    private func hideOverlayWindow(coordinator: Coordinator) {
        coordinator.releaseWindow()
    }

    private static var currentWindowScene: UIWindowScene? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.keyWindow != nil }
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var overlayWindow: UIWindow?

        func releaseWindow() {
            overlayWindow?.isHidden = true
            overlayWindow?.rootViewController = nil
            overlayWindow = nil
        }
    }
}

func captureKeyWindowSnapshot(erasingRect: CGRect? = nil) -> UIImage? {
    let keyWindow: UIWindow?
    if #available(iOS 15.0, *) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        keyWindow = scene?.keyWindow
    } else {
        keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
    }
    guard let window = keyWindow else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
    return renderer.image { ctx in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        if let rect = erasingRect {
            UIColor.systemBackground.setFill()
            ctx.fill(rect)
        }
    }
}

