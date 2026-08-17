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

    @ObservedObject var model: CallViewModel
    let availableWidth: CGFloat

    var body: some View {
        let plan = model.controlsPlan
        let metrics = BarMetrics(availableWidth: availableWidth, plan: plan)
        let hasSideAction = plan?.pictureInPicture != nil || model.canAddParticipant
        let sideLane = hasSideAction ? metrics.button + metrics.gap : 0
        let identityWidth = max(0, availableWidth - 2 * sideLane)

        ZStack {
            CallHeaderView(model: model, horizontalInset: metrics.contentInset)
                .onVideoLegible()
                .frame(maxWidth: identityWidth)

            HStack(spacing: 0) {
                if let action = plan?.pictureInPicture {
                    topButton(action, metrics: metrics)
                }
                Spacer(minLength: 0)
                if model.canAddParticipant {
                    addParticipantButton(metrics: metrics)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func topButton(_ action: ControlAction, metrics: BarMetrics) -> some View {
        Button {
            model.perform(action.intent)
        } label: {
            CallControlIcon(action: action, metrics: metrics)
        }
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private func addParticipantButton(metrics: BarMetrics) -> some View {
        Button(action: model.addParticipantTapped) {
            Label(L10n.Accessibility.Calls.Default.addParticipant,
                  systemImage: "person.badge.plus")
                .labelStyle(IconOnlyLabelStyle())
                .font(.system(size: metrics.icon, weight: .medium))
                .foregroundColor(.white)
                .frame(width: metrics.button, height: metrics.button)
                .onVideoGlass(Circle())
        }
    }
}
