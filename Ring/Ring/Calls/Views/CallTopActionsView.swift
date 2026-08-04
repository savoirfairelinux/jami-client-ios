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
