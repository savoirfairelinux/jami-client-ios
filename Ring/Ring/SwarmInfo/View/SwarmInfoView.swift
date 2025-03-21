/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
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

/// Defines the available views in the swarm settings
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
        static let avatarSize: CGFloat = 80
        static let minimizedTopHeight: CGFloat = 50
        static let contentPadding: CGFloat = 20
        static let segmentedControlPadding: CGFloat = 20
        static let verticalSpacing: CGFloat = 20
        static let callButtonSize: CGFloat = 45
        static let callButtonSpacing: CGFloat = 20
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
    
    private var placeholderColor: Color {
        if viewModel.finalColor == "#CDDC39" || viewModel.finalColor == "#FFC107" {
            return Color.white.opacity(0.7)
        }
        
        let isLight = Color(hex: viewModel.finalColor)?.isLight(threshold: 0.8) ?? true
        return isLight ? Color.black.opacity(0.5) : Color.white.opacity(0.5)
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
        .ignoresSafeArea(edges: [.top])
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Main Content Components
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            topArea
            segmentedControl
            contentArea
        }
    }
    
    @ViewBuilder
    private var topArea: some View {
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
        VStack(spacing: Layout.verticalSpacing) {
            HStack {
                Spacer()
                VStack(spacing: Layout.verticalSpacing) {
                    Spacer().frame(height: 30)
                    avatarView
                    titleView
                    descriptionView
                    if viewModel.getContactJamiId() != nil {
                        callButtons
                    }
                }
                Spacer()
            }
        }
        .padding(Layout.contentPadding)
        .ignoresSafeArea(edges: [.top, .leading, .trailing])
        .background(Color(hex: viewModel.finalColor))
    }
    
    private var callButtons: some View {
        HStack(spacing: Layout.callButtonSpacing) {
            Spacer()
            
            callButton(
                systemName: "phone",
                action: placeAudioCall,
                accessibilityLabel: "Place audio call"
            )
            
            callButton(
                systemName: "video",
                action: placeVideoCall,
                accessibilityLabel: "Place video call"
            )
            
            Spacer()
        }
        .padding(.vertical, 5)
    }
    
    private func callButton(systemName: String, action: @escaping () -> Void, accessibilityLabel: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(lightOrDarkColor)
                .frame(width: Layout.callButtonSize, height: Layout.callButtonSize)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.white).opacity(0.2)))
        }
        .accessibilityLabel(accessibilityLabel)
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if viewModel.isAdmin {
            editableAvatar
        } else {
            nonEditableAvatar
        }
    }
    
    private var editableAvatar: some View {
        Button {
            showingOptions = true
        } label: {
            avatarImage
        }
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
    
    private var nonEditableAvatar: some View {
        avatarImage
    }
    
    private var avatarImage: some View {
        Image(uiImage: viewModel.finalAvatar)
            .renderingMode(.original)
            .resizable()
            .scaledToFill()
            .frame(width: Layout.avatarSize, height: Layout.avatarSize, alignment: .center)
            .clipShape(Circle())
    }
    
    @ViewBuilder
    private var titleView: some View {
        if viewModel.isAdmin {
            Text(viewModel.title)
                .font(Font.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .foregroundColor(lightOrDarkColor)
                .accentColor(lightOrDarkColor)
                .onTapGesture {
                    viewModel.presentTitleEditView()
                }
                .textFieldAlert(
                    isPresented: $viewModel.isShowingTitleAlert,
                    title: "Edit group title",
                    text: $viewModel.editableTitle,
                    placeholder: "Enter a new title",
                    onSave: {
                        viewModel.saveTitleEdit()

                    }
                )
        } else {
            titleLabel
        }
    }
    
    @ViewBuilder
    private var descriptionView: some View {
        if viewModel.isAdmin,
           let conversation = viewModel.conversation,
           !conversation.isCoredialog() {
            descriptionTextField
                .padding(.bottom, 10)
        } else if !viewModel.description.isEmpty {
            descriptionLabel
                .padding(.bottom, 10)
        }
    }
    
    @ViewBuilder
    private var segmentedControl: some View {
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
            .padding([.horizontal, .top], Layout.segmentedControlPadding)
        }
    }
    
    @ViewBuilder
    private var contentArea: some View {
        switch selectedView {
        case .about:
            SettingsView(viewmodel: viewModel, stateEmitter: stateEmitter)
        case .memberList:
            MemberList(viewmodel: viewModel)
        }
    }
    
    @ViewBuilder
    private var colorPickerOverlay: some View {
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
                .frame(height: 70)
                .background(Color.white)
                .onChange(of: viewModel.finalColor) { _ in
                    dismissColorPicker()
                }
                .ignoresSafeArea()
            }
        }
    }
    
    @ViewBuilder
    private var addParticipantsButton: some View {
        if !(viewModel.conversation?.isCoredialog() ?? true) {
            AddMoreParticipantsInSwarm(viewmodel: viewModel)
        }
    }
    
    // MARK: - Text Components
    
    private var titleLabel: some View {
        Text(viewModel.title)
            .font(Font.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
    }
    
    private var descriptionLabel: some View {
        Text(viewModel.description)
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(lightOrDarkColor)
            .accentColor(lightOrDarkColor)
    }
    
    private var descriptionTextField: some View {
        TextField(
            "",
            text: $viewModel.description,
            onCommit: {
                viewModel.updateSwarmInfo()
            })
            .placeholder(when: viewModel.description.isEmpty) {
                Text(L10n.Swarm.addDescription)
                    .foregroundColor(placeholderColor)
            }
            .accentColor(lightOrDarkColor)
            .foregroundColor(lightOrDarkColor)
            .font(.body)
            .multilineTextAlignment(.center)
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

// Helper view to make sheet background transparent
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Text Field Alert

// This struct allows a TextField within an Alert
struct TextFieldAlert: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    @Binding var text: String
    let placeholder: String
    let onSave: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
            alertView
        }
    }
    
    @ViewBuilder
    private var alertView: some View {
        if isPresented {
            AlertControllerWrapper(
                isPresented: $isPresented,
                title: title,
                text: $text,
                placeholder: placeholder,
                onSave: onSave
            )
        }
    }
}

// UIKit wrapper to show a UIAlertController with TextField
struct AlertControllerWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let title: String
    @Binding var text: String
    let placeholder: String
    let onSave: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = placeholder
                textField.text = text
                textField.delegate = context.coordinator
            }
            
            alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel) { _ in
                self.isPresented = false
            })
            
            alert.addAction(UIAlertAction(title: L10n.Global.save, style: .default) { _ in
                if let textField = alert.textFields?.first, let text = textField.text {
                    self.text = text
                    self.onSave()
                }
                self.isPresented = false
            })
            
            DispatchQueue.main.async {
                uiViewController.present(alert, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AlertControllerWrapper
        
        init(_ parent: AlertControllerWrapper) {
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

// Extension to make it easier to use
extension View {
    func textFieldAlert(
        isPresented: Binding<Bool>,
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        onSave: @escaping () -> Void
    ) -> some View {
        self.modifier(TextFieldAlert(
            isPresented: isPresented,
            title: title,
            text: text,
            placeholder: placeholder,
            onSave: onSave
        ))
    }
}
