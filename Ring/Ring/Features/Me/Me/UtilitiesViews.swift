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
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareButtonView: View {
    let accountInfoToShare: String
    @SwiftUI.State private var showShareView = false

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
        ShareLink(item: accountInfoToShare) {
            shareView()
        }
    }

    // Fallback for iOS versions prior to 16
    private var shareButtonFallback: some View {
        Button {
            showShareView = true
        } label: {
            shareView()
        }
        .sheet(isPresented: $showShareView) {
            ActivityViewController(activityItems: [accountInfoToShare])
        }
    }

    func shareView() -> some View {
        HStack {
            Group {
                Image(systemName: "envelope")
                Text(L10n.Smartlist.inviteFriends)
            }
            .foregroundColor(.jamiColor)
        }
    }
}
struct QRCodeView: View {
    @Binding var isPresented: Bool
    let jamiId: String
    @SwiftUI.State var image: UIImage?

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                    .frame(height: 20)
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 270, height: 270)
                        .cornerRadius(10)
                        .padding()
                }
                Spacer()
            }
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
        .onAppear {
            image = jamiId.generateQRCode()
        }
        .optionalMediumPresentationDetents()
    }
}

struct CustomAlert<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            // Alert content
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
            .padding(.vertical, 5)
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

    var body: some View {
        HStack {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                }
            }
            .disableAutocorrection(true)
            .autocapitalization(.none)

            Spacer()

            Button(action: {
                isVisible.toggle()
            }) {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .foregroundColor(.gray)
            }
            .padding(.leading, 10)
        }
    }
}

struct FocusableTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

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
            self.isFirstResponder = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            self.isFirstResponder = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isFirstResponder: $isFirstResponder)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text

        if isFirstResponder {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }
}
