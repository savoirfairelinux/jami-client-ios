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

struct CallChromeView: View {

    private enum Metrics {
        static let controlsBottomPadding: CGFloat = 12
    }

    @ObservedObject var model: CallViewModel

    var body: some View {
        ZStack {
            if model.showsChrome {
                if model.moreExpanded {
                    Button(action: collapseMoreActions) {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHidden(true)
                    .transition(.opacity)
                }

                GeometryReader { geometry in
                    VStack {
                        CallHeaderView(model: model)
                        Spacer()
                        CallControlsView(model: model, availableWidth: geometry.size.width)
                            .padding(.bottom, Metrics.controlsBottomPadding)
                    }
                }
                .padding()
                .transition(.opacity)
            }
        }
        .allowsHitTesting(model.showsChrome)
        .animation(.easeInOut(duration: 0.3), value: model.showsChrome)
    }

    private func collapseMoreActions() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            model.setMoreExpanded(false)
        }
    }
}

extension View {
    func onVideoCapsule() -> some View {
        self.background(
            VisualEffect(style: .systemUltraThinMaterialDark)
                .overlay(Color.jamiOnVideoGlass)
        )
        .clipShape(Capsule())
    }
}
