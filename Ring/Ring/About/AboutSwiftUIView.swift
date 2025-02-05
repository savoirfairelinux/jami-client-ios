/*
 * Copyright (C) 2024 Savoir-faire Linux Inc. *
 *
 * Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

struct AboutSwiftUIView: View {
    let model = AboutSwiftUIVM()
    let dismissHandler = DismissHandler()
    let padding: CGFloat = 20
    var body: some View {
        VStack(spacing: padding) {
            ZStack {
                HStack {
                    Spacer() // Push the close button to the right
                    CloseButton(
                        action: { [weak dismissHandler] in
                            dismissHandler?.dismissView()
                        },
                        accessibilityIdentifier: SmartListAccessibilityIdentifiers.closeAboutView
                    )
                }

                Image("jami_gnupackage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .accessibilityLabel(L10n.Accessibility.aboutJamiTitle)
                    .frame(maxWidth: .infinity, alignment: .center) // This will center the image horizontally
            }

            ScrollView {
                VStack(alignment: .leading, spacing: padding) {
                    VStack(alignment: .center) {
                        Text(Constants.versionName)
                            .bold()
                        Text("Version: \(model.fullVersion)")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                    Text(.init(model.declarationText))
                    Text(.init(model.noWarrantyText))
                    Text(.init(model.mainUrlText))
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.createdLabel)
                                .bold()
                                .font(.caption)
                            Spacer()
                                .frame(height: 10)
                            Text(contributorsDevelopers)
                                .font(.caption)
                            Spacer()
                                .frame(height: 10)
                            Text(model.artworkLabel)
                                .bold()
                                .font(.caption)
                            Spacer()
                                .frame(height: 10)
                            Text(contributorsArts)
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            HStack {
                Spacer()
                Button(action: {
                    model.openContributeLink()
                }, label: {
                    Text(model.contributeLabel)
                })
                Spacer()
                    .frame(width: 30)
                Button(action: {
                    model.sendFeedback()
                }, label: {
                    Text(model.feedbackLabel)
                })
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}
