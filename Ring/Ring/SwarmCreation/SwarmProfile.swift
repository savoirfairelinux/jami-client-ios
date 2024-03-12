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
    @SwiftUI.State private var showView = false
    @SwiftUI.State private var iconScale: CGFloat = 1
    @SwiftUI.State private var offset: CGFloat = -200
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
                            EditImageIcon(width: 100, height: 100)
                                .frame(width: 100, height: 100)
                                .scaleEffect(iconScale)
                            Text("Swarm's name")
                                .opacity(showView ? 1 : 0)
                                .scaleEffect(iconScale)
                            Spacer()
                                .frame(height: 40)
                            Text("You can add or invite members at any time after the swarm has been created.")
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                                .padding()
                                .opacity(showView ? 1 : 0)
                                .scaleEffect(iconScale)
                            Spacer()
                        }
                        Spacer()
                    }
                    .offset(y: geometry.size.height * 0.3 - 60)
                }
            }
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatCount(1, autoreverses: false)) {
                    showView = true
                }
                withAnimation(Animation.easeInOut(duration: 0.3).repeatCount(1, autoreverses: true)) {
                    iconScale = 1.1
                    offset = 100
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(Animation.easeInOut(duration: 0.15).repeatCount(1, autoreverses: true)) {
                            iconScale = 0.9
                            offset = 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(Animation.easeInOut(duration: 0.15)) {
                                    iconScale = 1
                                }
                            }
                        }
                    }
                }
            }
            HStack {
                Button("Back") {

                }
                .foregroundColor(Color(UIColor(named: "jamiMain")!))
                Spacer()
                Text("Customize swarm's profile")
                Spacer()
                Button("Save") {

                }
                .foregroundColor(Color(UIColor(named: "jamiMain")!))
            }
            .padding()
        }
    }
}

struct EditImageIcon: View {
    @SwiftUI.State var width: CGFloat
    @SwiftUI.State var height: CGFloat
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color(UIColor.systemGray2))
            Image(systemName: "pencil")
                .resizable()
                .foregroundColor(Color(UIColor(named: "jamiMain")!))
                .frame(width: 12, height: 12)
                .padding(4)
                .clipShape(Rectangle())
                .background(Color(UIColor(named: "donationBanner")!))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(width: width, height: height)
    }
}

