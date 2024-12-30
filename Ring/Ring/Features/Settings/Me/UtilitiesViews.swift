/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

protocol AvatarViewDataModel: ObservableObject {
    var profileImage: UIImage? {get set }
    var profileName: String {get set }

    var username: String? {get set }

    func getProfileColor() -> UIColor
}

extension AvatarViewDataModel {
    func getProfileColor() -> UIColor {
        let unwrappedUserName: String = self.username ?? ""
        let name = self.profileName.isEmpty ? unwrappedUserName : self.profileName
        let scanner = Scanner(string: name.toMD5HexString().prefixString())
        var index: UInt64 = 0

        scanner.scanHexInt64(&index)
        return avatarColors[Int(index)]
    }
}

struct AvatarImageView<Model>: View where Model: AvatarViewDataModel {
    @ObservedObject var model: Model
    @SwiftUI.State var width: CGFloat
    @SwiftUI.State var height: CGFloat
    var textSize: CGFloat = 24
    var body: some View {
        if let image = model.profileImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipShape(Circle())
        } else if !model.profileName.isEmpty {
            Circle()
                .fill(Color(model.getProfileColor()))
                .frame(width: width, height: height)
                .overlay(
                    Text(String(model.profileName.prefix(1)).uppercased())
                        .font(.system(size: textSize))
                        .foregroundColor(.white)
                )
        } else if let registeredName = model.username {
            Circle()
                .fill(Color(model.getProfileColor()))
                .frame(width: width, height: height)
                .overlay(
                    Text(String(registeredName.prefix(1)).uppercased())
                        .font(.system(size: textSize))
                        .foregroundColor(.white)
                )
        } else {
            Image(systemName: "person")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .padding(20)
                .background(Color(model.getProfileColor()))
                .foregroundColor(Color.white)
                .frame(width: width, height: height)
                .clipShape(Circle())
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareButtonView<ButtonContent: View>: View {
    let infoToShare: String
    @SwiftUI.State private var showShareView = false
    let buttonContent: ButtonContent
    
    init(infoToShare: String, @ViewBuilder content: () -> ButtonContent) {
        self.infoToShare = infoToShare
        self.buttonContent = content()
    }
    
    var body: some View {
        VStack {
            if #available(iOS 16.0, *) {
                shareLinkButton
            } else {
                shareButtonFallback
            }
        }
    }
    
    // ShareLink for iOS 16 and above
    @available(iOS 16.0, *)
    private var shareLinkButton: some View {
        ShareLink(item: infoToShare) {
            buttonContent
        }
    }
    
    // Fallback for iOS versions prior to 16
    private var shareButtonFallback: some View {
        Button {
            showShareView = true
        } label: {
            buttonContent
        }
        .sheet(isPresented: $showShareView) {
            ActivityViewController(activityItems: [infoToShare])
        }
    }
}

// Default button style using AnyView
extension ShareButtonView where ButtonContent == AnyView {
    init(infoToShare: String) {
        self.init(infoToShare: infoToShare) {
            AnyView(
                Label("Share", systemImage: "square.and.arrow.up.fill")
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.jamiColor)
                    .cornerRadius(10)
            )
        }
    }
}

struct QRCodeView: View {
    let jamiId: String
    var size: CGFloat = 270
    @SwiftUI.State var image: UIImage?

    var body: some View {
        VStack {
//            Spacer()
//                .frame(height: 20)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(10)
                    //.padding()
            }
            Spacer()
        }
        .onAppear {
            image = jamiId.generateQRCode()
        }
    }
}

struct QRCodePresenter: View {
    @Binding var isPresented: Bool
    let jamiId: String
    @SwiftUI.State var image: UIImage?

    var body: some View {
        NavigationView {
            QRCodeView(jamiId: jamiId)
                .padding()
                .padding(.top, 30)
            .navigationBarItems(leading: Button(action: {
                isPresented = false
            }) {
                Text(L10n.Global.cancel)
                    .foregroundColor(.jamiColor)
            })
        }
        .onTapGesture {
            isPresented = false
        }
        .optionalMediumPresentationDetents()
    }
}

struct CustomAlert<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            content
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding()
                .shadow(radius: 10)
                .transition(.scale)
        }
    }
}

struct AlertFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
    }
}

extension View {
    func textFieldStyleInAlert() -> some View {
        self.modifier(AlertFieldStyle())
    }
}

struct PasswordFieldView: View {
    @Binding var text: String
    @SwiftUI.State private var isVisible: Bool = false
    var placeholder: String
    var identifier: String = ""

    var body: some View {
        HStack {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .accessibilityIdentifier(identifier)
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .accessibilityIdentifier(identifier)
                }
            }
            .disableAutocorrection(true)
            .autocapitalization(.none)

            Spacer()

            Button(action: {
                isVisible.toggle()
            }, label: {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .foregroundColor(.gray)
            })
            .padding(.leading, 10)
        }
    }
}

struct FocusableTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var placeholder: String = ""
    var identifier: String = ""

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isFirstResponder: Bool

        init(text: Binding<String>, isFirstResponder: Binding<Bool>) {
            _text = text
            _isFirstResponder = isFirstResponder
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            self.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if self.isFirstResponder { return }
            self.isFirstResponder = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if !self.isFirstResponder { return }
            self.isFirstResponder = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isFirstResponder: $isFirstResponder)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.accessibilityIdentifier = identifier
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        /*
         No need to wait to resign the first responder.
         Ensure the state is not updated directly in updateUIView.
         */
        if !isFirstResponder && uiView.isFirstResponder {
            DispatchQueue.main.async {  [weak uiView] in
                guard let uiView = uiView else { return }
                uiView.resignFirstResponder()
            }
            return
        }
        // Wait untill view shows.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak uiView] in
            guard let uiView = uiView else { return }
            if uiView.window != nil, !uiView.isFirstResponder, isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }
}

extension Binding {
    static func customBinding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding<Bool>(
            get: get,
            set: set
        )
    }
}

struct DurationPickerView: View {
    @Binding var duration: Int
    @Binding var isPresented: Bool
    let maxHours = 10

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }, label: {
                    Text(L10n.Global.close)
                        .foregroundColor(.jamiColor)
                })
            }
            DurationPickerWrapper(duration: $duration, maxHours: maxHours)
                .frame(height: 250)
        }
        .padding()
    }
}

struct DurationPickerWrapper: UIViewRepresentable {
    @Binding var duration: Int
    var maxHours: Int

    func makeUIView(context: Context) -> DurationPicker {
        let picker = DurationPicker(maxHours: maxHours, duration: duration)
        picker.onDurationChanged = { duration in
            if self.duration == duration {
                return
            }
            UserDefaults.standard.set(duration, forKey: locationSharingDurationKey)
            self.duration = duration
        }
        return picker
    }

    func updateUIView(_ uiView: DurationPicker, context: Context) {
        uiView.duration = duration
    }
}

struct EditableFieldView: View {
    @Binding var value: String
    var title: String
    var placeholder: String
    @SwiftUI.State private var isTextFieldFocused = true
    var onDisappearAction: () -> Void // Closure to handle save action on disappear

    var body: some View {
        Form {
            Section {
                FocusableTextField(text: $value, isFirstResponder: $isTextFieldFocused, placeholder: placeholder)
            }
        }
        .navigationTitle(L10n.Global.edit + " \(title)")
        .onDisappear {
            onDisappearAction() // Call the action when the view disappears
        }
    }
}

struct FieldRowView: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }
}

struct SettingsRow: View {
    var iconName: String
    var title: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(.secondary)
                .padding(.trailing, 5)
            Text(title)
        }
    }
}
