/*
 * Copyright (C) 2022-2025 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 * Author: Binal Ahiya binal.ahiya@savoirfairelinux.com *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @ObservedObject var viewmodel: SwarmInfoVM
    let stateEmitter: ConversationStatePublisher

    // MARK: - Layout Constants
    private let textSpacing: CGFloat = 10
    private let iconSize: CGFloat = 15
    private let iconStrokeWidth: CGFloat = 5
    private let iconFrameSize: CGFloat = 25
    private let iconPadding: CGFloat = 10
    private let pickerCircleSize: CGFloat = 40
    private let pickerCircleStrokeSize: CGFloat = 50
    private let pickerCirclePadding: CGFloat = 5
    private let pickerSpacing: CGFloat = 10

    enum PresentingAlert: Identifiable {
        case removeConversation
        case blockContact
        case clearConversation

        var id: Self { self }
    }

    // MARK: - State
    @SwiftUI.State private var showQRcode = false
    @SwiftUI.State private var presentingAlert: PresentingAlert?
    @SwiftUI.State private var showColorPicker = false

    // MARK: - Body
    var body: some View {
        Form {
            contactSection
            conversationSection
        }
        .alert(item: $presentingAlert) { alert in
            createAlert(for: alert)
        }
    }

    // MARK: - Contact Section
    @ViewBuilder private var contactSection: some View {
        if let jamiId = viewmodel.getContactJamiId() {
            Section(header: Text(L10n.Swarm.contactHeader)) {
                identifierView(label: L10n.Swarm.identifier, value: jamiId)
                qrCodeButton(jamiId: jamiId)
                shareContactButton(jamiId: jamiId)
                blockContactButton()
            }
        }
    }

    private func identifierView(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: textSpacing) {
            Text(label + ":")
            selectableText(value)
        }
    }

    private func qrCodeButton(jamiId: String) -> some View {
        Button(action: {
            showQRcode = true
        }, label: {
            HStack {
                Image(systemName: "qrcode")
                    .foregroundColor(Color.jamiColor)
                    .accessibility(hidden: true)
                Text(L10n.Swarm.showContactQRCode)
                    .foregroundColor(Color.jamiColor)
            }
        })
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showQRcode) {
            QRCodePresenter(isPresented: $showQRcode, jamiId: jamiId, accessibilityLabel: L10n.Swarm.accessibilityContactQRCode)
        }
        .accessibilityLabel(L10n.Swarm.accessibilityContactQRCode)
        .accessibilityHint(L10n.Swarm.accessibilityContactQRCodeHint)
    }

    private func shareContactButton(jamiId: String) -> some View {
        ShareButtonView(infoToShare: viewmodel.createShareInfo(for: jamiId)) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(Color.jamiColor)
                    .accessibility(hidden: true)
                Text(L10n.Swarm.shareContactInfo)
                    .foregroundColor(Color.jamiColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(L10n.Swarm.shareContactInfo)
        .accessibilityHint(L10n.Swarm.accessibilityContactShareHint)
    }

    private func blockContactButton() -> some View {
        Button(action: {
            presentingAlert = .blockContact
        }, label: {
            HStack {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .foregroundColor(Color(UIColor.jamiFailure))
                    .accessibility(hidden: true)
                Text(L10n.Global.blockContact)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Color(UIColor.jamiFailure))
            }
        })
        .accessibilityLabel(L10n.Global.blockContact)
    }

    // MARK: - Conversation Section
    private var conversationSection: some View {
        Section(header: Text(L10n.Swarm.conversationHeader)) {
            identifierView(label: L10n.Swarm.conversationId, value: viewmodel.swarmInfo.id)
            swarmTypeView
            colorPickerView
            if viewmodel.isCoreDialog {
                clearConversationButton
            }
            leaveConversationButton
        }
    }

    private var swarmTypeView: some View {
        HStack {
            Text(L10n.Swarm.typeOfSwarm)
            Spacer()
            Text(viewmodel.swarmInfo.type.value.stringValue)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }

    private var colorPickerView: some View {
        HStack {
            Text(L10n.Swarm.chooseColor)
            Spacer()
            colorCircle
        }
    }

    private var colorCircle: some View {
        ZStack {
            Circle()
                .fill(Color(hex: viewmodel.finalColor) ?? .gray)
                .frame(width: iconSize, height: iconSize)
                .onTapGesture {
                    showColorPicker = true
                }
                .sheet(isPresented: $showColorPicker) {
                    AccessibleCustomColorPicker(isPresented: $showColorPicker, selectedColor: $viewmodel.selectedColor,
                                                currentColor: viewmodel.finalColor)
                }
                .onChange(of: viewmodel.selectedColor) { newValue in
                    viewmodel.updateSwarmColor(selectedColor: newValue)
                }
                .padding(iconPadding)

            Circle()
                .stroke(Color(hex: viewmodel.finalColor) ?? .gray, lineWidth: iconStrokeWidth)
                .frame(width: iconFrameSize, height: iconFrameSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Swarm.chooseColor)
        .accessibilityValue(viewmodel.finalColor)
    }

    private var leaveConversationButton: some View {
        Button(action: {
            presentingAlert = .removeConversation
        }, label: {
            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(Color(UIColor.jamiFailure))
                    .accessibility(hidden: true)
                Text(viewmodel.removeConversationText)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Color(UIColor.jamiFailure))
            }
        })
        .accessibilityLabel(viewmodel.removeConversationText)
    }

    private var clearConversationButton: some View {
        Button(action: {
            presentingAlert = .clearConversation
        }, label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(Color.jamiColor)
                    .accessibility(hidden: true)
                Text(L10n.Swarm.restartConversation)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Color.jamiColor)
            }
        })
        .accessibilityLabel(L10n.Swarm.restartConversation)
    }

    // MARK: - Helper Methods
    private func createAlert(for alertType: PresentingAlert) -> Alert {
        switch alertType {
        case .removeConversation:
            return Alert(
                title: Text(L10n.Swarm.confirmLeaveConversation),
                primaryButton: .destructive(Text(L10n.Swarm.leave)) {
                    viewmodel.leaveSwarm(stateEmitter: stateEmitter)
                },
                secondaryButton: .cancel()
            )
        case .blockContact:
            return Alert(
                title: Text(L10n.Alerts.confirmBlockContact),
                primaryButton: .destructive(Text(L10n.Global.block)) {
                    viewmodel.blockContact(stateEmitter: stateEmitter)
                },
                secondaryButton: .cancel()
            )
        case .clearConversation:
            return Alert(
                title: Text(L10n.Swarm.restartConversation),
                message: Text(L10n.Alerts.confirmRestartConversation),
                primaryButton: .destructive(Text(L10n.Global.restart)) {
                    viewmodel.restartSwarm(stateEmitter: stateEmitter)
                },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private func selectableText(_ text: String) -> some View {
        if #available(iOS 15.0, *) {
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.trailing)
                .truncationMode(.middle)
                .lineLimit(1)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.trailing)
                .truncationMode(.middle)
                .lineLimit(1)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

struct AccessibleCustomColorPicker: View {
    @Binding var isPresented: Bool
    @Binding var selectedColor: String
    let currentColor: String

    // MARK: - Layout Constants
    private let circleSize: CGFloat = 40
    private let circleStrokeWidth: CGFloat = 5
    private let circleStrokeSize: CGFloat = 50
    private let circlePadding: CGFloat = 5
    private let spacing: CGFloat = 10

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack {
                    Spacer()

                    let columns = [
                        GridItem(.adaptive(minimum: circleSize + circlePadding * 2), spacing: spacing)
                    ]

                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(Array(Constants.swarmColors.keys), id: \.self) { color in
                            CircleView(
                                colorString: color,
                                selectedColor: $selectedColor,
                                circleSize: circleSize,
                                circleStrokeWidth: circleStrokeWidth,
                                circleStrokeSize: circleStrokeSize,
                                circlePadding: circlePadding
                            )
                        }
                    }
                    .padding()
                    .frame(maxHeight: 300) // Optional max height to avoid huge grids

                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationTitle(Text(L10n.Swarm.chooseColor))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: {
                isPresented = false
            }, label: {
                Text(L10n.Global.cancel)
                    .foregroundColor(.jamiColor)
            }))
        }
        .optionalMediumPresentationDetents()
        .accessibilityAutoFocusOnAppear()
    }
}

struct CircleView: View {
    // MARK: - Properties
    let colorString: String
    @Binding var selectedColor: String

    // MARK: - Layout Constants
    let circleSize: CGFloat
    let circleStrokeWidth: CGFloat
    let circleStrokeSize: CGFloat
    let circlePadding: CGFloat

    // MARK: - Body
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorString) ?? .gray)
                .frame(width: circleSize, height: circleSize)
                .onTapGesture {
                    selectedColor = colorString
                }
                .padding(circlePadding)

            if selectedColor == colorString {
                Circle()
                    .stroke(Color(hex: colorString) ?? .gray, lineWidth: circleStrokeWidth)
                    .frame(width: circleStrokeSize, height: circleStrokeSize)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Constants.swarmColors[colorString] ?? "")
        .accessibilityAddTraits(selectedColor == colorString ? .isSelected : [])
    }
}
