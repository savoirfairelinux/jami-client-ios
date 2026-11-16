/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI

final class CallReturnWindow: UIWindow {

    private enum Metrics {
        static let navigationBarHeight: CGFloat = 44
        static let topSpacing: CGFloat = 8
        static let sideMargin: CGFloat = 16
    }

    init(windowScene: UIWindowScene, model: CallViewModel) {
        super.init(windowScene: windowScene)
        windowLevel = .normal + 1
        backgroundColor = .clear
        let root = UIViewController()
        root.view.backgroundColor = .clear
        let host = UIHostingController(rootView: CallReturnCapsule(model: model))
        host.view.backgroundColor = .clear
        if #available(iOS 16.0, *) {
            host.sizingOptions = .intrinsicContentSize
        }
        root.addChild(host)
        root.view.addSubview(host.view)
        host.didMove(toParent: root)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: root.view.centerXAnchor),
            host.view.topAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.topAnchor,
                                           constant: Metrics.navigationBarHeight
                                            + Metrics.topSpacing),
            host.view.widthAnchor.constraint(lessThanOrEqualTo: root.view.widthAnchor,
                                             constant: -2 * Metrics.sideMargin)
        ])
        rootViewController = root
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === rootViewController?.view ? nil : hit
    }
}

struct CallReturnCapsule: View {

    private enum Metrics {
        static let height: CGFloat = 48
        static let avatar: CGFloat = 36
        static let leadingPadding: CGFloat = 6
        static let trailingPadding: CGFloat = 16
        static let spacing: CGFloat = 10
        static let shadowRadius: CGFloat = 10
    }

    @ObservedObject var model: CallViewModel

    private var avatarUri: String {
        model.header.avatars.first?.uri ?? model.call?.peerUri ?? ""
    }

    var body: some View {
        Button(action: model.returnToCall) {
            content
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Calls.returnToCall)
        .accessibilityValue("\(model.header.title), \(model.statusLine)")
        .accessibilityAddTraits(.isButton)
    }

    private var content: some View {
        HStack(spacing: Metrics.spacing) {
            AvatarSwiftUIView(source: model.avatarProvider(forUri: avatarUri),
                              sizeOverride: Metrics.avatar)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.header.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(model.statusLine)
                    .font(.caption.monospacedDigit())
                    .opacity(0.85)
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            DisclosureChevron()
                .stroke(Color.white.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 4, height: 14)
                .flipsForRightToLeftLayoutDirection(true)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.leading, Metrics.leadingPadding)
        .padding(.trailing, Metrics.trailingPadding)
        .frame(height: Metrics.height)
        .modifier(DarkGlass())
        .shadow(color: .black.opacity(0.25), radius: Metrics.shadowRadius, y: 4)
        .contentShape(Capsule())
    }
}

private struct DarkGlass: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.background(Color.clear.glassEffect(.regular.tint(Color.black.opacity(0.45)),
                                                       in: Capsule()))
        } else {
            content
                .background(VisualEffect(style: .systemMaterialDark))
                .clipShape(Capsule())
        }
    }
}
