//
//  SwarmSettingsViewController.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

enum SwarmSettingView: String {
    case about
    case memberList
}

public struct TopProfileView: View {

    var swarmViews: [SwarmSettingView] {
        if viewmodel.swarmInfo.participants.value.count == 2 {
            return [.about]
        } else {
            return [.about, .memberList]
        }
    }
    @SwiftUI.State var viewmodel: SwarmInfoViewModel!
    @SwiftUI.State private var selectedView: SwarmSettingView = .about

    @AppStorage("SWARM_COLOR") var swarmColor = Color.blue

    @SwiftUI.State private var descriptionTextFieldInput: String = ""
    @SwiftUI.State private var titleTextFieldInput: String = ""

    public var body: some View {
        VStack {
            VStack {
                HStack {
                    Spacer()
                }
                Button {
                    // Image right button action
                } label: {
                        Image(uiImage: viewmodel.finalAvatar)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewmodel.swarmInfo.avatarHeight, height: viewmodel.swarmInfo.avatarHeight, alignment: .center)
                            .clipShape(Circle())
                }
                .padding(.vertical)
                
                TextField(
                    viewmodel.finalTitle,
                    text: $titleTextFieldInput,
                    onCommit: {
                        viewmodel.title = titleTextFieldInput
                    })
                // Text color.
                .foregroundColor(.white)
                // Cursor color.
                .accentColor(.white)
                .disabled(!viewmodel.isAdmin)
                .font(.system(.largeTitle, design: .serif))
                .multilineTextAlignment(.center)

                
                TextField(
                    viewmodel.swarmInfo.description.value,
                    text: $descriptionTextFieldInput,
                    onCommit: {
                        viewmodel.description = descriptionTextFieldInput
                    })
                .disabled(!viewmodel.isAdmin)
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
                    , show: viewmodel.swarmInfo.description.value.isEmpty)
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
                        Text("\(viewmodel.swarmInfo.participants.value.count) Members")
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.all, 20)

            switch selectedView {
            case .about:
                SettingsView(id: viewmodel.swarmInfo.id, swarmType: viewmodel.swarmInfo.type.value.stringValue)
            case .memberList:
                MemberList(members: viewmodel.swarmInfo.participants.value)
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
