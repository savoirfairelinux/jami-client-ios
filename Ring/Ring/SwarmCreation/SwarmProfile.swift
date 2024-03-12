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

struct SwarmProfile: View {
    @ObservedObject var model: SwarmCreationUIModel
    @Binding var isPresentingProfile: Bool

    @SwiftUI.State private var showingImagePicker = false
    @SwiftUI.State private var imagePickerType: PhotoSheetType?
    // animation
    @SwiftUI.State private var showView = false
    @SwiftUI.State private var iconScale: CGFloat = 1.2
    @SwiftUI.State private var offset: CGFloat = 300
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                GeometryReader { geometry in
                    Ellipse()
                        .fill(Color(UIColor(named: "donationBanner")!))
                        .frame(width: geometry.size.width * 1.4, height: geometry.size.height * 1.1)
                        .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.8)
                        .opacity(showView ? 1 : 0)
                    HStack {
                        Spacer()
                        VStack {
                            imagePickerButton()
                            VStack(alignment: .center) {
                                TextField("Swarm's name", text: $model.swarmName)
                                    .disableAutocorrection(true)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 200, minHeight: 40)
                                TextField(L10n.Swarmcreation.addADescription, text: $model.swarmDescription)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 200, minHeight: 40)
                            }
                            .opacity(showView ? 1 : 0)
                            .scaleEffect(iconScale)
                            .padding(.vertical, 10)
                            Spacer()
                            Text("You can add or invite members at any time after the swarm has been created.")
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                                .padding()
                                .opacity(showView ? 1 : 0)
                                .scaleEffect(iconScale)
                            Spacer()
                            Spacer()
                                .frame(height: 20)
                        }
                        Spacer()
                    }
                    .offset(y: geometry.size.height * 0.3 - 60)
                }
            }
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatCount(1, autoreverses: false)) {
                    showView = true
                    offset = 1
                    iconScale = 1
                }
            }
            ZStack {
                HStack {
                    Button("Cancel") {
                        model.setDataToInitial()
                        isPresentingProfile = false
                    }
                    .foregroundColor(Color(UIColor(named: "jamiMain")!))
                    Spacer()
                    Button("Save") {
                        isPresentingProfile = false
                    }
                    .foregroundColor(Color(UIColor(named: "jamiMain")!))
                }
                Text("Customize swarm's profile")
            }
            .padding()
        }
        .onTapGesture {
            self.hideKeyboard()
        }
    }

    private func imagePickerButton() -> some View {
        Button(action: {
            self.hideKeyboard() // Assuming you've defined this method
            showingImagePicker = true
        }) {
            EditImageIcon(model: model, width: 100, height: 100)
                .frame(width: 100, height: 100)
                .scaleEffect(iconScale)
        }
        .actionSheet(isPresented: $showingImagePicker) {
            ActionSheet(
                title: Text("Change swarm picture"),
                buttons: [
                    .default(Text("Take Photo")) {
                        imagePickerType = .picture
                    },
                    .default(Text("Upload Photo")) {
                        imagePickerType = .gallery
                    },
                    .cancel()
                ]
            )
        }
        .sheet(item: $imagePickerType) { type in
            let sourceType: UIImagePickerController.SourceType = type == .picture ? .camera : .photoLibrary
            ImagePicker(sourceType: sourceType, showingType: $imagePickerType, image: $model.image)
        }
    }
}

struct EditImageIcon: View {
    @ObservedObject var model: SwarmCreationUIModel
    @SwiftUI.State var width: CGFloat
    @SwiftUI.State var height: CGFloat
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = model.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(UIColor.systemGray2))
                    .frame(width: width, height: height)
            }

            //            Image(systemName: "pencil")
            //                .resizable()
            //                .foregroundColor(Color(UIColor(named: "jamiMain")!))
            //                .frame(width: 12, height: 12)
            //                .padding(4)
            //                .clipShape(Rectangle())
            //                .background(Color(UIColor(named: "donationBanner")!))
            //                .clipShape(RoundedRectangle(cornerRadius: 3))

            Image(systemName: "pencil")
                .resizable()
                .foregroundColor(Color(UIColor(named: "jamiMain")!))
                .frame(width: 12, height: 12)
                .padding(6)
                .background(Color(UIColor.systemBackground))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(UIColor(named: "donationBanner")!), lineWidth: 3)
                )
        }
        .frame(width: width, height: height)
    }
}
