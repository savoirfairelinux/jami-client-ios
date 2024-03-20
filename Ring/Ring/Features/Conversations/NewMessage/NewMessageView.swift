//
//  NewMessageView.swift
//  Ring
//
//  Created by kateryna on 2024-03-19.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct NewMessageView: View {
    @ObservedObject var model: ConversationsViewModel
    @Binding var isNewMessageViewPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var smartListState: SmartListState
    var body: some View {
        PlatformAdaptiveNavView {
            SearchableSmartList(model: model, mode: .newMessage, isNewMessageViewPresented: $isNewMessageViewPresented, dismissAction: {
               // smartListState.slideDirectionUp = false
                smartListState.navigationTarget = .smartList
                //presentationMode.wrappedValue.dismiss()
            })
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("New Message")
                .navigationBarItems(trailing: Button("Cancel") {
//                    DispatchQueue.main.async {
//                        isNewMessageViewPresented = false
//                    }
                    smartListState.slideDirectionUp = false
                    withAnimation {
                        smartListState.navigationTarget = .smartList
                    }
                   // presentationMode.wrappedValue.dismiss()
                })

        }
    }
}

