//
//  SwarmSettingsViewController.swift
//  Ring
//
//  Created by Alireza Toghiani on 11/4/22.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MemberList: View {

    @SwiftUI.State var members = [ConversationParticipant]()

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(members, id: \.self) {
                    ProfileItem(image: UIImage.createContactAvatar(username: $0.jamiId), name: $0.jamiId)
                }
            }
        }
    }
}

struct ProfileItem: View {
    var image: UIImage
    var name: String

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 45, alignment: .center)
                .clipShape(Circle())

            Text(name)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.light)

            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

struct MemberList_Previews: PreviewProvider {
    static var previews: some View {
        MemberList()
            .previewLayout(.sizeThatFits)
    }
}
