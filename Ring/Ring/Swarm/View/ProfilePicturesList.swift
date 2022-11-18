//
//  SwarmSettingsViewController.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MemberList: View {

    @SwiftUI.State var members = [ParticipantInfo]()

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(members, id: \.self) {
                    ProfileItem(image: $0.avatar.value, name: $0.name.value.isEmpty ? $0.jamiId : $0.name.value, role: $0.role == .member ? "" : $0.role.stringValue, isInvited: $0.role == .invited)
                }
            }
        }
    }
}

struct ProfileItem: View {
    var image: UIImage?
    var name: String
    var role: String
    var isInvited: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: image ?? UIImage())
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45, alignment: .center)
                .clipShape(Circle())
            
            HStack {
                Text(name)
                    .font(.system(.title2, design: .rounded))
                Spacer()
                Text(role)
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.light)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .opacity(isInvited ? 0.5 : 1)
    }
}

struct MemberList_Previews: PreviewProvider {
    static var previews: some View {
        MemberList()
            .previewLayout(.sizeThatFits)
    }
}
