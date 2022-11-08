//
//  ContactListUI.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ParticipantListCell: View {
    var participant: ParticipantRow
    // Image(uiImage: UIImage(data: participant.image!) ?? UIImage(asset: Asset.addAvatar))
    @ViewBuilder
    var body: some View {
        HStack(alignment: .center, spacing: nil) {

            Image(uiImage: participant.imageDataFinal)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40, alignment: .center)
                .clipShape(Circle())
            Text(participant.name)
                .font(.custom("Ubuntu", size: 13))
            Spacer()
        }
    }
}
struct SwarmCreationUI: View {
    @ObservedObject var list: SwarmCreationUIModel
    @SwiftUI.State private var swarmName: String = ""
    @SwiftUI.State private var swarmDescription: String = ""
    @SwiftUI.State private var searchParticipant: String = ""
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var selection = "None"

    let imageGroupIcon = UIImage(asset: Asset.addAvatar) as UIImage?

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    print("Hi! Binal")
                    showingOptions = true
                }) {
                    Image(uiImage: imageGroupIcon!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60, alignment: .center)
                        .clipShape(Circle())
                        .padding(.leading, 20)
                }.actionSheet(isPresented: $showingOptions) {
                    ActionSheet(
                        title: Text(""),
                        buttons: [
                            .default(Text(L10n.Alerts.profileTakePhoto)) {
                                selection = "Red"
                                ImagePickerView(sourceType: .camera) { _ in

                                }
                            },
                            .default(Text(L10n.Alerts.profileUploadPhoto)) {
                                selection = "Green"
                                ImagePickerView(sourceType: .photoLibrary) { _ in

                                }
                            },
                            .default(Text(L10n.Alerts.profileCancelPhoto)) {
                                selection = "Blue"
                            }
                        ]
                    )
                }
                VStack {
                    TextField("Name", text: $swarmName)
                        .font(.custom("Ubuntu-Medium", size: 15))
                    TextField("Add description", text: $swarmDescription)
                        .font(.custom("Ubuntu-Medium", size: 14))
                }
                Spacer()
            }
        }
        List {
            ForEach(list.participantsRows) { contact in
                ParticipantListCell(participant: contact)
            }
        }
        .listStyle(PlainListStyle())
        .frame(width: UIScreen.main.bounds.width, height: nil, alignment: .leading)
        .accentColor(Color.black)

    }
}
public struct ImagePickerView: UIViewControllerRepresentable {

    private let sourceType: UIImagePickerController.SourceType
    private let onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    public init(sourceType: UIImagePickerController.SourceType, onImagePicked: @escaping (UIImage) -> Void) {
        self.sourceType = sourceType
        self.onImagePicked = onImagePicked
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = self.sourceType
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            onDismiss: { self.presentationMode.wrappedValue.dismiss() },
            onImagePicked: self.onImagePicked
        )
    }

    public final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

        private let onDismiss: () -> Void
        private let onImagePicked: (UIImage) -> Void

        init(onDismiss: @escaping () -> Void, onImagePicked: @escaping (UIImage) -> Void) {
            self.onDismiss = onDismiss
            self.onImagePicked = onImagePicked
        }

        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                self.onImagePicked(image)
            }
            self.onDismiss()
        }

        public func imagePickerControllerDidCancel(_: UIImagePickerController) {
            self.onDismiss()
        }

    }

}

// struct SwarmCreationUI_Previews: PreviewProvider {
//    static var previews: some View {
//        SwarmCreationUI().previewDevice("iPhone SE (2nd generation)")
//    }
// }
