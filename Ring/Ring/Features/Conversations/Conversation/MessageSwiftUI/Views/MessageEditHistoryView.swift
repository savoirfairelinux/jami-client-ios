/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

struct MessageEditHistoryView: View {
    let versions: [MessageAction]
    @Environment(\.presentationMode)
    private var presentationMode

    var body: some View {
        NavigationView {
            List(versions) { version in
                VStack(alignment: .leading, spacing: 4) {
                    if let date = version.date {
                        Text(date.conversationTimestamp())
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Text(version.content)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
            .navigationTitle(L10n.Conversation.editHistory)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(L10n.Global.close) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .accentColor(.jami)
        .optionalMediumPresentationDetents()
    }
}
