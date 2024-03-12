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
                    .font(.system(size: 15.0, weight: .regular, design: .default))
                    .padding(.leading, 8.0)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Circle()
                    .strokeBorder(Color.gray, lineWidth: 1) // Border for the circle
                    .background(Circle().fill(isSelected ? Color.green : Color.clear)) // Fill circle if selected
                    .frame(width: 20, height: 20)
//                HStack {
//                    if self.isSelected {
//                        Image(systemName: "checkmark")
//                            .frame(width: 20, height: 20, alignment: .trailing)
//                    }
//                }
            }
        }
    }
}
struct SwarmCreationUI: View {
    @StateObject var list: SwarmCreationUIModel
    @SwiftUI.State private var showingOptions = false
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var swarmImage: UIImage = UIImage(asset: Asset.editSwarmImage)!

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 10)
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    self.hideKeyboard()
                    showingOptions = true
                }) {
                    if let image = list.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(uiImage: swarmImage)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fill)
                            .foregroundColor(Color.white)
                            .frame(width: 30, height: 30, alignment: .center)
                    }
                }
                .frame(width: 70, height: 70, alignment: .center)
                .background(Color(UIColor.jamiButtonDark))
                .clipShape(Circle())
                .padding(.leading, 20)
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
                        ImagePicker(sourceType: .photoLibrary, showingType: $showingType, image: $list.image)
                    } else {
                        ImagePicker(sourceType: .camera, showingType: $showingType, image: $list.image)

                    }
                }
                VStack {
                    TextField(L10n.Global.name, text: $list.swarmName)
                        .font(.system(size: 17.0, weight: .semibold, design: .default))
                    TextField(L10n.Swarmcreation.addADescription, text: $list.swarmDescription)
                        .font(.system(size: 15.0, weight: .regular, design: .default))
                }
                Spacer()
            }
        }.onTapGesture {
            self.hideKeyboard()
        }
        ZStack(alignment: .bottomTrailing) {
            List {
                ForEach(list.participantsRows) { contact in
                    ParticipantListCell(participant: contact, isSelected: list.selections.contains(contact.id)) {
                        if list.selections.contains(contact.id) {
                            list.selections.removeAll(where: { $0 == contact.id })
                        } else {
                            list.selections.append(contact.id)
                        }
                        self.hideKeyboard()
                    }
                }
                if #available(iOS 15.0, *) {
                    Spacer()
                        .frame(height: 60)
                        .listRowSeparator(.hidden)
                } else {
                    Spacer()
                        .frame(height: 60)
                }
            }
            .listStyle(PlainListStyle())
            .frame(width: nil, height: nil, alignment: .leading)
            .accentColor(Color.black)

            //createTheSwarmButtonView()
        }
    }

    func createTheSwarmButtonView() -> some View {
        return Button(action: {
                        self.hideKeyboard()
                        list.createTheSwarm() }) {
            Text(L10n.Swarmcreation.createTheSwarm)
                .swarmButtonTextStyle()
        }
        .swarmButtonStyle()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    @Binding var showingType: PhotoSheetType?
    @Binding var image: UIImage?

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
            self.picker.image = image
            self.picker.showingType = nil
        }
    }
}
