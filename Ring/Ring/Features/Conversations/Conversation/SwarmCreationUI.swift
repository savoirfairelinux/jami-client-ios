//
//  ContactListUI.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

enum PhotoSheetType: Identifiable { /// 1.
    var id: UUID {
        UUID()
    }
    case gallery
    case picture
}
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
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var imgShow: UIImage = UIImage(asset: Asset.addAvatar)!
    @SwiftUI.State var imageTemp: Data = (UIImage(systemName: "photo.on.rectangle.angled")?.jpegData(compressionQuality: 1))!

    let imageGroupIcon = UIImage(asset: Asset.addAvatar) as UIImage?

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    print("Hi! Binal")
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
                ParticipantListCell(participant: contact)
            }
        }
        .listStyle(PlainListStyle())
        .frame(width: UIScreen.main.bounds.width, height: nil, alignment: .leading)
        .accentColor(Color.black)

    }
}
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    @Binding var showingType: PhotoSheetType?
    @Binding var image: Data

    func makeCoordinator() -> ImagePicker.Coordinator {
        // let imagePicker = UIImagePickerController()
        return ImagePicker.Coordinator(child1: self)
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
        var child: ImagePicker
        init(child1: ImagePicker) {
            child = child1
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.child.showingType = nil /// set to nil here
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as! UIImage
            let data = image.jpegData(compressionQuality: 0.45)
            self.child.image = data!
            self.child.showingType = nil /// set to nil here
        }
    }
}
