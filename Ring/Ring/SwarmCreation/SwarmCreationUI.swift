/*
 *  Copyright (C) 2022 - 2025 Savoir-faire Linux Inc.
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

    @ViewBuilder var body: some View {
        Button(action: self.action) {
            HStack(alignment: .center, spacing: nil) {
                AvatarSwiftUIView(source: participant.avatarProvider)
                    .frame(width: Constants.defaultAvatarSize, height: Constants.defaultAvatarSize, alignment: .center)
                Text(participant.name)
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

    @ViewBuilder var body: some View {
        Button(action: self.action) {
            VStack(alignment: .center, spacing: nil) {
                ZStack(alignment: .topTrailing) {
                    AvatarSwiftUIView(source: participant.avatarProvider)
                        .frame(width: Constants.defaultAvatarSize, height: Constants.defaultAvatarSize, alignment: .center)
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
    @ObservedObject var list: SwarmCreationUIModel
    @SwiftUI.State private var showingType: PhotoSheetType?
    @SwiftUI.State private var swarmImage: UIImage = UIImage(asset: Asset.editSwarmImage)!
    @SwiftUI.State private var isPresentingProfile = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            swarmProfileButton()
                .sheet(isPresented: $isPresentingProfile) {
                    SwarmProfile(model: list, isPresentingProfile: $isPresentingProfile)
                }
            if !list.selections.isEmpty {
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
        .background(Color(UIColor.systemBackground))
    }

    func swarmProfileButton() -> some View {
        Button(action: {
            isPresentingProfile = true
        }, label: {
            HStack {
                if let image = list.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20, alignment: .center)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person")
                        .resizable()
                        .foregroundColor(Color.jamiColor)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 10, height: 10, alignment: .center)
                        .padding(4)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.jamiColor, lineWidth: 1))
                }
                Spacer()
                    .frame(width: 12)
                Text(L10n.Swarm.customize)
                    .foregroundColor(Color(UIColor.label))
                Spacer()
                Image(systemName: "pencil")
                    .resizable()
                    .foregroundColor(Color.jamiColor)
                    .frame(width: 18, height: 18, alignment: .center)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.jamiTertiaryControl)
            .cornerRadius(12)
            .padding(.horizontal)
        })
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
