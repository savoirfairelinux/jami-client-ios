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

private enum Layout {
    static let touchTarget: CGFloat = 44
    static let largeButton: CGFloat = 72
    static let maxContentWidth: CGFloat = 360
    static let spacing: CGFloat = 24
}

struct DialpadView: View {
    @ObservedObject var viewModel: DialpadViewModel
    @Environment(\.presentationMode) private var presentationMode

    private static let keys: [DialpadKeyModel] = [
        DialpadKeyModel(value: "1", letters: ""),
        DialpadKeyModel(value: "2", letters: "ABC"),
        DialpadKeyModel(value: "3", letters: "DEF"),
        DialpadKeyModel(value: "4", letters: "GHI"),
        DialpadKeyModel(value: "5", letters: "JKL"),
        DialpadKeyModel(value: "6", letters: "MNO"),
        DialpadKeyModel(value: "7", letters: "PQRS"),
        DialpadKeyModel(value: "8", letters: "TUV"),
        DialpadKeyModel(value: "9", letters: "WXYZ"),
        DialpadKeyModel(value: DialpadViewModel.displayStar, letters: ""),
        DialpadKeyModel(value: "0", letters: "+", longPressValue: "+"),
        DialpadKeyModel(value: "#", letters: "")
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.spacing), count: 3)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                numberDisplay
                Spacer(minLength: Layout.spacing)
                keypad
                Spacer(minLength: Layout.spacing)
                callButton
            }
            .padding(.vertical, 20)
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Global.close) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    /// Spells the composed number out so VoiceOver reads it digit by digit
    /// instead of as one large number.
    private var spelledOutNumber: String {
        viewModel.phoneNumber.map { String($0) }.joined(separator: " ")
    }

    private var numberDisplay: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: Layout.touchTarget, height: Layout.touchTarget)
            Text(viewModel.phoneNumber)
                .font(.system(size: 36, weight: .regular))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(spelledOutNumber)
            Group {
                if !viewModel.phoneNumber.isEmpty {
                    Button(action: viewModel.deleteLast) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 24, weight: .regular))
                            .frame(width: Layout.touchTarget, height: Layout.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel(L10n.Actions.deleteAction)
                }
            }
            .frame(width: Layout.touchTarget, height: Layout.touchTarget)
        }
        .frame(height: Layout.touchTarget)
        .padding(.horizontal, Layout.touchTarget)
        .frame(maxWidth: Layout.maxContentWidth)
        .padding(.top, Layout.spacing)
    }

    private var keypad: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Self.keys) { key in
                // "+" (long-press on 0) is only offered while composing a
                // number; it is not a valid DTMF tone during a call.
                let activeLongPressValue = viewModel.inCallDialpad ? nil : key.longPressValue
                DialpadKeyButton(
                    key: key,
                    onTap: { viewModel.numberPressed(key.value) },
                    onLongPress: activeLongPressValue.map { value in
                        { viewModel.numberPressed(value) }
                    })
            }
        }
        .padding(.horizontal, Layout.touchTarget)
        .frame(maxWidth: Layout.maxContentWidth)
    }

    @ViewBuilder
    private var callButton: some View {
        if viewModel.showsCallButton {
            let enabled = !viewModel.phoneNumber.isEmpty
            Button {
                viewModel.startCall()
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: Layout.largeButton, height: Layout.largeButton)
                    .background(Circle().fill(Color.jamiSuccess))
            }
            .accessibilityLabel(L10n.Global.call)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.15), value: enabled)
        }
    }
}

private struct DialpadKeyModel: Identifiable {
    let value: String
    let letters: String
    let longPressValue: String?
    var id: String { value }

    init(value: String, letters: String, longPressValue: String? = nil) {
        self.value = value
        self.letters = letters
        self.longPressValue = longPressValue
    }
}

private struct DialpadKeyButton: View {
    let key: DialpadKeyModel
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

    var body: some View {
        keyButton
            .accessibilityLabel(key.value == DialpadViewModel.displayStar ? "*" : key.value)
            .accessibilityModifier(longPressValue: key.longPressValue, action: onLongPress)
    }

    @ViewBuilder private var keyButton: some View {
        let button = Button(action: onTap) { label }
            .buttonStyle(DialpadKeyStyle())
        if let onLongPress = onLongPress {
            // A long press inserts the secondary value (e.g. "+") instead of
            // the digit; a normal tap still types the digit.
            button.onLongPressGesture(minimumDuration: 0.4, perform: onLongPress)
        } else {
            button
        }
    }

    private var label: some View {
        VStack(spacing: 1) {
            Text(key.value)
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(.primary)
            if !key.letters.isEmpty {
                Text(key.letters)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: Layout.largeButton, height: Layout.largeButton)
        .frame(maxWidth: .infinity)
        .contentShape(Circle())
    }
}

private extension View {
    /// Exposes a long-press value as a VoiceOver custom action, since a long
    /// press itself is hard to perform with assistive technologies.
    @ViewBuilder
    func accessibilityModifier(longPressValue: String?, action: (() -> Void)?) -> some View {
        if let longPressValue = longPressValue, let action = action {
            self.accessibilityAction(named: Text(longPressValue), action)
        } else {
            self
        }
    }
}

private struct DialpadKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color(configuration.isPressed ? .systemFill : .secondarySystemFill))
                    .frame(width: Layout.largeButton, height: Layout.largeButton)
            )
    }
}
