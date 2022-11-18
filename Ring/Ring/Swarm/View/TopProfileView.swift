//
//  SwarmSettingsViewController.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

let spaceBetweenProfilePhotos: CGFloat = 6
let profileImageSize: CGFloat = 100

enum SwarmSettingView: String {
    case about
    case memberList
}

public struct TopProfileView: View {

    var swarmViews: [SwarmSettingView] = [.about, .memberList]
    @SwiftUI.State var viewmodel: SwarmInfoViewModel!
    @SwiftUI.State private var selectedView: SwarmSettingView = .about

    @AppStorage("SWARM_COLOR") var swarmColor = Color.blue

    @SwiftUI.State private var textFieldInput: String = ""

    public var body: some View {
        VStack {
            VStack {
                HStack {
                    Spacer()
                }

                HStack(alignment: .center, spacing: spaceBetweenProfilePhotos) {
                    Button {
                        // Image left button action
                    } label: {
                        Image(systemName: viewmodel.profileImageLeft)
                            .resizable()
                            .scaledToFill()
                            .frame(width: profileImageSize, height: profileImageSize, alignment: .center)
                            .clipShape(Circle())
                            .frame(width: profileImageSize, height: profileImageSize)
                            .offset(x: profileImageSize / 2)
                            .clipped()
                            .offset(x: -profileImageSize / 4)
                            .frame(width: profileImageSize / 2)
                    }

                    Button {
                        // Image right button action
                    } label: {
                        Image(systemName: viewmodel.profileImageRight)
                            .resizable()
                            .scaledToFill()
                            .frame(width: profileImageSize, height: profileImageSize, alignment: .center)
                            .clipShape(Circle())
                            .frame(width: profileImageSize, height: profileImageSize)
                            .offset(x: -profileImageSize / 2)
                            .clipped()
                            .offset(x: profileImageSize / 4)
                            .frame(width: profileImageSize / 2)
                    }

                }
                .padding(.vertical)
                Text(viewmodel.title)
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Group {
                    TextField(
                        viewmodel.description,
                        text: $textFieldInput,
                        onCommit: {
                            viewmodel.description = textFieldInput
                        })
                        // Cursor color.
                        .accentColor(.white)
                        // Text color.
                        .foregroundColor(.white)
                        .font(.system(.body, design: .serif))
                        .multilineTextAlignment(.center)
                        .placeHolder(
                            Text("Add a description")
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            , show: textFieldInput.isEmpty)
                }
                .padding(.vertical, 15)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 30)
            .background(swarmColor)

            Picker("", selection: $selectedView) {
                ForEach(swarmViews, id: \.self) {
                    switch $0 {
                    case .about:
                        Text("About")
                    case .memberList:
                        Text("\(viewmodel.participantList.count) Members")
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.all, 20)

            switch selectedView {
            case .about:
                SettingsView(id: viewmodel.id, swarmType: viewmodel.swarmType)
            case .memberList:
                MemberList(members: viewmodel.participantList)
            }
        }
    }
}

// struct TopProfileView_Previews: PreviewProvider {
//    static var previews: some View {
//        TopProfileView(viewmodel: SwarmInfoViewModel())
//            .previewLayout(.sizeThatFits)
//    }
// }

struct PlaceHolder<T: View>: ViewModifier {
    var placeHolder: T
    var show: Bool
    func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            if show { placeHolder }
            content
        }
    }
}

extension View {
    func placeHolder<T: View>(_ holder: T, show: Bool) -> some View {
        self.modifier(PlaceHolder(placeHolder: holder, show: show))
    }
}
