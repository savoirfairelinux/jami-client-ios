/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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

enum PhotoSheetType: Identifiable {
    var id: UUID {
        UUID()
    }

    case gallery
    case picture
}
struct ParticipantListCell: View {
    @StateObject var participant: ParticipantRow
    var isSelected: Bool
    var action: () -> Void

    @ViewBuilder
    var body: some View {
        Button(action: self.action) {
            HStack(alignment: .center, spacing: nil) {
                Image(uiImage: participant.imageDataFinal)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipShape(Circle())
                Text(participant.name)
                    .font(.system(size: 15.0, weight: .bold, design: .default))
                    .padding(.leading, 8.0)
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
    @StateObject var list: SwarmCreationUIModel
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    showingOptions = true
                }) {
                    Image(uiImage: UIImage(data: list.imageData)!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 70, alignment: .center)
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
                        ImagePicker(sourceType: .photoLibrary, showingType: $showingType, image: $list.imageData)
                    } else {
                        ImagePicker(sourceType: .camera, showingType: $showingType, image: $list.imageData)

                    }
                }
                VStack {
                    TextField(L10n.Global.name, text: $list.swarmName)
                        .font(.system(size: 18.0, weight: .semibold, design: .default))
                    TextField(L10n.Swarmcreation.addADescription, text: $list.swarmDescription)
                        .font(.system(size: 17.0, weight: .regular, design: .default))
                }
                Spacer()
            }
            if !list.selections.isEmpty && (list.maximumLimit - list.selections.count) > 0 {
                Text("You can add \(list.maximumLimit - list.selections.count) more people in the Swarm ")
                    .padding(.leading, 20)
                    .font(.system(size: 15.0, weight: .regular, design: .default))
            }
        }
        List {
            ForEach(list.participantsRows) { contact in
                ParticipantListCell(participant: contact, isSelected: list.selections.contains(contact.id)) {
                    if list.selections.contains(contact.id) {
                        list.selections.removeAll(where: { $0 == contact.id })
                    } else {
                        list.selections.append(contact.id)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .frame(width: nil, height: nil, alignment: .leading)
        .accentColor(Color.black)
        if !list.selections.isEmpty {
            Button(L10n.Swarmcreation.createTheSwarm) {
                list.createTheSwarm()
            }
            .frame(width: 300, height: 60, alignment: .center)
            .background(Color(UIColor.jamiButtonDark))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
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
