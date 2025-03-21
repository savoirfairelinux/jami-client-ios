/*
 * Copyright (C) 2022-2025 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 * Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
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
import Combine

// MARK: - Enums and Types

enum SwarmSettingView: String, CaseIterable {
    case about
    case memberList

    var title: String {
        switch self {
        case .about:
            return L10n.Swarm.settings
        case .memberList:
            return L10n.Swarm.members
        }
    }
}

// MARK: - SwarmInfoView

public struct SwarmInfoView: View, StateEmittingView {
    // MARK: - Type Definitions
    typealias StateEmitterType = ConversationStatePublisher

    // MARK: - Constants
    private enum Layout {
        static let verticalMargin: CGFloat = 10
        static let generalMargin: CGFloat = 20
        static let avatarSize: CGFloat = 80
        static let minimizedTopHeight: CGFloat = 50
        static let topSpacerHeight: CGFloat = 30
        static let callButtonSize: CGFloat = 45
        static let colorPickerHeight: CGFloat = 70
        static let callButtonsMargin: CGFloat = 5
    }

    // MARK: - Properties
    @ObservedObject var viewModel: SwarmInfoVM
    let stateEmitter = ConversationStatePublisher()

    // MARK: - State
    @SwiftUI.State private var selectedView: SwarmSettingView = .about
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var image: UIImage?
    @SwiftUI.State private var minimizedTopView: Bool = false

    // MARK: - Computed Properties
    private var swarmViews: [SwarmSettingView] {
        guard let conversation = viewModel.conversation, !conversation.isCoredialog() else {
            return [.about]
        }
        return [.about, .memberList]
    }

    private var lightOrDarkColor: Color {
        let isLight = Color(hex: viewModel.finalColor)?.isLight(threshold: 0.8) ?? true
        return isLight ? Color(UIColor.jamiMain) : Color.white
    }

    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(UIColor.systemGroupedBackground)
            mainContent
            colorPickerOverlay
            addParticipantsButton
        }
        .onReceive(orientationPublisher) { _ in
            minimizedTopView = shouldMinimizeTop()
        }
        .onAppear {
            minimizedTopView = shouldMinimizeTop()
        }
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }

    // MARK: - Main Content Components

    @ViewBuilder private var mainContent: some View {
        VStack(spacing: 0) {
            topArea
            segmentedControl
            contentArea
        }
    }

    @ViewBuilder private var topArea: some View {
        if minimizedTopView {
            minimizedTopBar
        } else {
            fullTopArea
        }
    }

    private var minimizedTopBar: some View {
        Color(hex: viewModel.finalColor)
            .frame(height: Layout.minimizedTopHeight)
            .ignoresSafeArea(edges: [.top, .leading, .trailing])
    }

    private var fullTopArea: some View {
        HStack {
            Spacer()
            VStack(spacing: Layout.generalMargin) {
                Spacer().frame(height: Layout.topSpacerHeight)
                avatarView
                titleView
                descriptionView
                if viewModel.getContactJamiId() != nil {
                    callButtons
                }
            }
            Spacer()
        }
        .padding(Layout.generalMargin)
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
        .background(Color(hex: viewModel.finalColor))
    }

    private var callButtons: some View {
        HStack(spacing: Layout.generalMargin) {
            Spacer()

            callButton(
                systemName: "phone",
                action: placeAudioCall,
                accessibilityLabel: L10n.Accessibility.conversationStartVoiceCall(viewModel.getContactDisplayName())
            )

            callButton(
                systemName: "video",
                action: placeVideoCall,
                accessibilityLabel: L10n.Accessibility.conversationStartVideoCall(viewModel.getContactDisplayName())
            )

            Spacer()
        }
        .padding(.vertical, Layout.callButtonsMargin)
    }

    private func callButton(systemName: String, action: @escaping () -> Void, accessibilityLabel: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(lightOrDarkColor)
                .frame(width: Layout.callButtonSize, height: Layout.callButtonSize)
                .background(RoundedRectangle(cornerRadius: Layout.verticalMargin).fill(lightOrDarkColor.opacity(0.2)))
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var avatarView: some View {
        if viewModel.isAdmin {
            editableAvatar
        } else {
            avatarImage
        }
    }

    private var editableAvatar: some View {
        Button {
            showingOptions = true
        } label: {
            avatarImage
        }
        .accessibilityLabel(L10n.Accessibility.swarmPicturePicker)
        .accessibilityHint(L10n.Accessibility.profilePicturePickerHint)
        .actionSheet(isPresented: $showingOptions) {
            ActionSheet(
                title: Text(""),
                buttons: [
                    .default(Text(L10n.Alerts.profileTakePhoto)) {
                        showingType = .picture
                    },
                    .default(Text(L10n.Alerts.profileUploadPhoto)) {
                        showingType = .gallery
                    },
                    .cancel()
                ]
            )
        }
        .sheet(item: $showingType) { type in
            ImagePicker(
                sourceType: type == .gallery ? .photoLibrary : .camera,
                showingType: $showingType,
                image: $image
            )
        }
        .onChange(of: image) { newValue in
            viewModel.updateSwarmAvatar(image: newValue)
        }
    }

    private var avatarImage: some View {
        Image(uiImage: viewModel.finalAvatar)
            .renderingMode(.original)
            .resizable()
            .scaledToFill()
            .frame(width: Layout.avatarSize, height: Layout.avatarSize, alignment: .center)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder private var titleView: some View {
        if viewModel.isAdmin {
            editableTextView(
                text: viewModel.title,
                placeholder: L10n.Swarm.titlePlaceholder,
                fontStyle: Font.title3.weight(.semibold),
                isEditing: $viewModel.isShowingTitleAlert,
                editableText: $viewModel.editableTitle,
                alertTitle: L10n.Swarm.titleAlertHeader,
                isEditable: true,
                onSave: viewModel.saveTitleEdit
            )
            .accessibilityLabel(viewModel.title.isEmpty ? L10n.Swarm.titleAlertHeader : viewModel.title)
            .accessibilityHint(L10n.Swarm.editTextHint)
        } else {
            titleLabel
        }
    }

    @ViewBuilder private var descriptionView: some View {
        if viewModel.isAdmin,
           let conversation = viewModel.conversation,
           !conversation.isCoredialog() {
            editableTextView(
                text: viewModel.description,
                placeholder: L10n.Swarm.addDescription,
                fontStyle: .body,
                isEditing: $viewModel.isShowingDescriptionAlert,
                editableText: $viewModel.editableDescription,
                alertTitle: L10n.Swarm.descriptionAlertHeader,
                isEditable: true,
                onSave: viewModel.saveDescriptionEdit
            )
            .accessibilityLabel(viewModel.description.isEmpty ? L10n.Swarm.addDescription : viewModel.description)
            .accessibilityHint(L10n.Swarm.editTextHint)
            .padding(.bottom, Layout.verticalMargin)
        } else if !viewModel.description.isEmpty {
            descriptionLabel
                .padding(.bottom, Layout.verticalMargin)
        }
    }

    @ViewBuilder private var segmentedControl: some View {
        if swarmViews.count > 1 {
            Picker("", selection: $selectedView) {
                ForEach(swarmViews, id: \.self) { view in
                    Text(view == .memberList ?
                            "\(viewModel.swarmInfo.participants.value.count) \(view.title)" :
                            view.title)
                }
            }
            .onChange(of: selectedView) { _ in
                viewModel.showColorSheet = false
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], Layout.generalMargin)
        }
    }

    @ViewBuilder private var contentArea: some View {
        switch selectedView {
        case .about:
            SettingsView(viewmodel: viewModel, stateEmitter: stateEmitter)
        case .memberList:
            MemberList(viewModel: viewModel)
        }
    }

    @ViewBuilder private var colorPickerOverlay: some View {
        if viewModel.showColorSheet {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .foregroundColor(.black.opacity(0.5))
                    .onTapGesture {
                        dismissColorPicker()
                    }
                    .ignoresSafeArea()

                CustomColorPicker(
                    selectedColor: $viewModel.selectedColor,
                    currentColor: $viewModel.finalColor
                )
                .frame(height: Layout.colorPickerHeight)
                .background(Color.white)
                .onChange(of: viewModel.finalColor) { _ in
                    dismissColorPicker()
                }
                .accessibilityLabel(L10n.Swarm.accessibilityColorPicker)
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder private var addParticipantsButton: some View {
        if !(viewModel.conversation?.isCoredialog() ?? true) && !viewModel.showColorSheet {
            AddMoreParticipantsInSwarm(viewmodel: viewModel)
                .accessibilityLabel("Add participants")
        }
    }

    // MARK: - Text Components

    private func editableTextView(
        text: String,
        placeholder: String,
        fontStyle: Font,
        isEditing: Binding<Bool>,
        editableText: Binding<String>,
        alertTitle: String,
        isEditable: Bool,
        onSave: @escaping () -> Void
    ) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .font(fontStyle)
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .lineLimit(2)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
            .onTapGesture {
                if isEditable {
                    editableText.wrappedValue = text
                    isEditing.wrappedValue = true
                }
            }
            .background(
                TextFieldAlertView(
                    isShowing: isEditing,
                    title: alertTitle,
                    text: editableText,
                    placeholder: placeholder,
                    onSave: onSave,
                    onCancel: {}
                )
            )
    }

    private var titleLabel: some View {
        Text(viewModel.title)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .lineLimit(2)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
            .accessibilityLabel(viewModel.title)
    }

    private var descriptionLabel: some View {
        Text(viewModel.description)
            .font(.body)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
            .accessibilityLabel(viewModel.description)
    }

    // MARK: - Action Methods

    private func placeAudioCall() {
        guard let jamiId = viewModel.getContactJamiId() else { return }
        stateEmitter.emitState(.startAudioCall(contactRingId: jamiId, userName: ""))
    }

    private func placeVideoCall() {
        guard let jamiId = viewModel.getContactJamiId() else { return }
        stateEmitter.emitState(.startCall(contactRingId: jamiId, userName: ""))
    }

    // MARK: - Helper Methods

    private func shouldMinimizeTop() -> Bool {
        return UIDevice.current.orientation.isLandscape &&
            UIDevice.current.userInterfaceIdiom == .phone
    }

    private func dismissColorPicker() {
        viewModel.showColorSheet = false
        viewModel.hideShowBackButton(colorPicker: false)
    }

    private var orientationPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
    }
}

// MARK: - Text Field Alert
struct TextFieldAlertView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    let title: String
    @Binding var text: String
    let placeholder: String
    let onSave: () -> Void
    let onCancel: () -> Void

    // Track if the alert has already been presented to avoid duplicate alerts
    class AlertState: ObservableObject {
        var alertController: UIAlertController?
        var hasBeenPresented = false
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<TextFieldAlertView>) -> UIViewController {
        let controller = UIViewController()
        context.coordinator.alertState.hasBeenPresented = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<TextFieldAlertView>) {
        let coordinator = context.coordinator

        // Show alert if requested and not already presented
        if isShowing && !coordinator.alertState.hasBeenPresented {
            coordinator.alertState.hasBeenPresented = true

            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            coordinator.alertState.alertController = alert

            alert.addTextField { textField in
                textField.placeholder = placeholder
                textField.text = text
                textField.delegate = coordinator
                textField.accessibilityLabel = placeholder
            }

            alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel) { _ in
                // First mark the alert as no longer presented
                coordinator.alertState.hasBeenPresented = false
                coordinator.alertState.alertController = nil
                // Then update the binding and call callback
                DispatchQueue.main.async {
                    isShowing = false
                    onCancel()
                }
            })

            alert.addAction(UIAlertAction(title: L10n.Global.save, style: .default) { _ in
                // Get text before dismissing
                var newText = ""
                if let textField = alert.textFields?.first {
                    newText = textField.text ?? ""
                }

                // First mark the alert as no longer presented
                coordinator.alertState.hasBeenPresented = false
                coordinator.alertState.alertController = nil

                // Then update the binding and call callback
                DispatchQueue.main.async {
                    text = newText
                    isShowing = false
                    onSave()
                }
            })

            DispatchQueue.main.async {
                uiViewController.present(alert, animated: true)
            }
        }

        // Dismiss if isShowing is false but alert is presented
        if !isShowing && coordinator.alertState.alertController != nil {
            DispatchQueue.main.async {
                uiViewController.dismiss(animated: true) {
                    coordinator.alertState.hasBeenPresented = false
                    coordinator.alertState.alertController = nil
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TextFieldAlertView
        let alertState = AlertState()

        init(_ parent: TextFieldAlertView) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let text = textField.text,
               let textRange = Range(range, in: text) {
                let updatedText = text.replacingCharacters(in: textRange, with: string)
                parent.text = updatedText
            }
            return true
        }
    }
}
