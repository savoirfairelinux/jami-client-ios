//
//  ContactListUI.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

enum PhotoSheetType: Identifiable {
    var id: UUID {
        UUID()
    }
    case gallery
    case picture
}
struct ParticipantListCell: View {
    var participant: ParticipantRow
    var isSelected: Bool
    var action: () -> Void

    @ViewBuilder
    var body: some View {
        Button(action: self.action) {

            HStack(alignment: .center, spacing: nil) {
                Image(uiImage: participant.imageDataFinal)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40, alignment: .center)
                    .clipShape(Circle())
                Text(participant.name)
                    .font(.custom("Ubuntu", size: 13))
                HStack {
                    if self.isSelected {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
                Spacer()
            }
        }
    }
}
struct SwarmCreationUI: View {
    @ObservedObject var list: SwarmCreationUIModel
    @SwiftUI.State private var swarmName: String = ""
    @SwiftUI.State private var swarmDescription: String = ""
    @SwiftUI.State private var searchParticipant: String = ""
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State var imageTemp: Data = (UIImage(asset: Asset.addAvatar)?.convertToData(ofMaxSize: 1))!
    @SwiftUI.State var selections: [String] = []

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    showingOptions = true
                }) {
                    Image(uiImage: UIImage(data: imageTemp)!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60, alignment: .center)
                        .clipShape(Circle())
                        .padding(.leading, 20)
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
                    if type == .gallery {
                        ImagePicker(sourceType: .photoLibrary, showingType: $showingType, image: self.$imageTemp)
                    } else {
                        ImagePicker(sourceType: .camera, showingType: $showingType, image: self.$imageTemp)

                    }
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
                ParticipantListCell(participant: contact, isSelected: self.selections.contains(contact.id)) {
                    if self.selections.contains(contact.id) {
                        self.selections.removeAll(where: { $0 == contact.id })
                    } else {
                        self.selections.append(contact.id)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .frame(width: nil, height: nil, alignment: .leading)
        .accentColor(Color.black)

    }
}
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    @Binding var showingType: PhotoSheetType?
    @Binding var image: Data

    func makeCoordinator() -> ImagePicker.Coordinator {
        return ImagePicker.Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {

    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let picker: ImagePicker

        init(_ picker: ImagePicker) {
            self.picker = picker
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.picker.showingType = nil
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            let data = image.jpegData(compressionQuality: 0.45)
            self.picker.image = data!
            self.picker.showingType = nil
        }
    }
}
