//
//  AddMoreParticipantsInSwarm.swift
//  Ring
//
//  Created by Binal Ahiya on 2023-01-10.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct AddMoreParticipantsInSwarm: View {
    @StateObject var viewmodel: SwarmInfoViewModel
    @SwiftUI.State var showAddMember = false
    @SwiftUI.State private var addMorePeople: UIImage = UIImage(asset: Asset.addPeopleInSwarm)!

    var body: some View {
        Button(action: {
            viewmodel.selections.removeAll()
            showAddMember = true
            viewmodel.showColorSheet = false
            viewmodel.updateContactList()
        }, label: {
            Image(uiImage: addMorePeople)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fill)
                .foregroundColor(Color(hex: viewmodel.finalColor)?.isLight(threshold: 0.8) ?? true ? Color(UIColor.jamiButtonDark) : Color.white)
                .frame(width: 30, height: 30, alignment: .center)

        })
        .frame(width: 50, height: 50, alignment: .center)
        .background(Color(hex: viewmodel.finalColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
        .sheet(isPresented: $showAddMember, onDismiss: {
            viewmodel.removeExistingSubscription()
        }, content: {
            let currentCount = viewmodel.addMemberCount - viewmodel.selections.count
            Text(L10n.Swarm.addMorePeople(viewmodel.selections.isEmpty ? viewmodel.addMemberCount : currentCount))
                .opacity(currentCount > 0 ? 1 : 0)
                .padding(.top, 20)
                .font(.system(size: 15.0, weight: .semibold, design: .default))
            List {
                ForEach(viewmodel.participantsRows) { contact in
                    ParticipantListCell(participant: contact, isSelected: viewmodel.selections.contains(contact.id)) {
                        if viewmodel.selections.contains(contact.id) {
                            viewmodel.selections.removeAll(where: { $0 == contact.id })
                        } else {
                            if viewmodel.selections.count < viewmodel.addMemberCount {
                                viewmodel.selections.append(contact.id)
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .frame(width: nil, height: nil, alignment: .leading)
            if !viewmodel.selections.isEmpty {
                addMember()
            }
        })
    }

    func addMember() -> some View {
        return Button(action: {
                        showAddMember = false
                        viewmodel.addMember()}) {
            Text(L10n.Swarm.addMember)
                .swarmButtonTextStyle()
        }
        .swarmButtonStyle()
    }
}
