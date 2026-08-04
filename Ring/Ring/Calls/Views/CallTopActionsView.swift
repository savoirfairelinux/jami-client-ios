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

struct CallTopActionsView: View {

    private enum Metrics {
        static let additionalHeaderHorizontalPadding: CGFloat = 6
    }

    @ObservedObject var model: CallViewModel
    let availableWidth: CGFloat

    var body: some View {
        let plan = model.controlsPlan
        let metrics = BarMetrics(availableWidth: availableWidth, plan: plan)
        let sideLane = plan?.pictureInPicture == nil ? 0 : metrics.button + metrics.gap
        let identityWidth = max(0, availableWidth - 2 * sideLane)

        ZStack {
            CallHeaderView(
                model: model,
                horizontalInset: metrics.contentInset
                    + Metrics.additionalHeaderHorizontalPadding)
                .onVideoGlass(Capsule())
                .frame(maxWidth: identityWidth)

            HStack(spacing: 0) {
                if let action = plan?.pictureInPicture {
                    topButton(action, metrics: metrics)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func topButton(_ action: ControlAction, metrics: BarMetrics) -> some View {
        Button {
            model.perform(action.intent)
        } label: {
            CallControlIcon(action: action,
                            metrics: metrics,
                            showsBorder: false)
        }
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.accessibilityLabel)
    }
}
