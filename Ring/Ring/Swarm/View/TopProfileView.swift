/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

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
                    if viewmodel.isAdmin {
                        // update swarm avatar
                    }
                } label: {
                    Image(uiImage: viewmodel.finalAvatar)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: viewmodel.swarmInfo.avatarHeight, height: viewmodel.swarmInfo.avatarHeight, alignment: .center)
                        .clipShape(Circle())
                }
                .padding(.vertical)
                
                if viewmodel.isAdmin {
                    TitleTextField
                } else {
                    TitleLabel
                }
                
                Group {
                    if viewmodel.isAdmin {
                        DescriptionTextField
                    } else {
                        DescriptionLabel
                    }
                }
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
                SettingsView(viewmodel: viewmodel, id: viewmodel.swarmInfo.id, swarmType: viewmodel.swarmInfo.type.value.stringValue)
            case .memberList:
                MemberList(members: viewmodel.swarmInfo.participants.value)
            }
        }
    }
}

private extension TopProfileView {
    var TitleLabel: some View {
        Text(viewmodel.finalTitle)
            .font(.system(.title, design: .serif))
            .multilineTextAlignment(.center)
        // Text color.
            .foregroundColor(.white)
        // Cursor color.
            .accentColor(.white)
            .padding()
    }
    
    var TitleTextField: some View {
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
        .font(.system(.title, design: .serif))
        .multilineTextAlignment(.center)
        .padding()
    }
    
    var DescriptionLabel: some View {
        Text(viewmodel.swarmInfo.description.value)
            .font(.system(.body, design: .serif))
            .multilineTextAlignment(.center)
        // Text color.
            .foregroundColor(.white)
        // Cursor color.
            .accentColor(.white)
    }
    
    var DescriptionTextField: some View {
        TextField(
            viewmodel.swarmInfo.description.value,
            text: $descriptionTextFieldInput,
            onCommit: {
                viewmodel.description = descriptionTextFieldInput
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
            , show: viewmodel.swarmInfo.description.value.isEmpty)
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
