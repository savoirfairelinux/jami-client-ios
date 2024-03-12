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
                if isSelected {
                    Image("message_sent_indicator")
                        .resizable()
                        .background(Circle().fill(Color.clear))
                        .frame(width: 15, height: 15)
                } else {
                    Circle()
                        .strokeBorder(Color.gray, lineWidth: 1)
                    .background(Circle().fill(isSelected ? Color.green : Color.clear))
                    .frame(width: 15, height: 15)
                }
            }
        }
    }
}

struct SelectedParticipantItem: View {
    @StateObject var participant: ParticipantRow
    var action: () -> Void

    @ViewBuilder
    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .center, spacing: nil) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: participant.imageDataFinal)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50, alignment: .center)
                        .clipShape(Circle())
                    Image(systemName: "xmark")
                        .resizable()
                        .foregroundColor(Color(UIColor.label))
                        .frame(width: 6, height: 6, alignment: .center)
                        .padding(4)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(Circle())
                }
                Text(participant.name)
                    .foregroundColor(Color(UIColor.label))
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 50)
        }
    }
}

struct SwarmCreationUI: View {
    @StateObject var list: SwarmCreationUIModel
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var swarmImage: UIImage = UIImage(asset: Asset.editSwarmImage)!
    @SwiftUI.State private var isPresentingProfile = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Button(action: {
                isPresentingProfile = true
            }, label: {
                Text("Customize swarm")
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor(named: "donationBanner")!))
                    .cornerRadius(8)
                    .padding(.horizontal)
            })
            .sheet(isPresented: $isPresentingProfile) {
                SwarmProfile(model: list)
            }
            if list.selections.count > 0 {
                Spacer()
                    .frame(height: 15)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(list.selections, id: \.self) { selection in
                            if let participant = list.getParticipant(id: selection) {
                                SelectedParticipantItem(participant: participant) {
                                    list.selections.removeAll(where: { $0 == selection })
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
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
            .padding(.vertical, 5)
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
