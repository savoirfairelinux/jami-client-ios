/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

struct ContainerView: View {
    @ObservedObject var model: ContainerViewModel
    @SwiftUI.State var isAnimatingTopMainGrid = false
    @SwiftUI.State var showMainGridView = true
    @SwiftUI.State var showTopGridView = true
    var body: some View {
        VStack {
            if !showMainGridView && showTopGridView {
                TopView(participants: model.participants)
            }
            MainGridView(isAnimatingTopMainGrid: $isAnimatingTopMainGrid,
                         showMainGridView: $showMainGridView,
                         model: model.mainGridViewModel,
                         participants: $model.participants)
                .frame(minWidth: 200, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                .background(Color.green)
        }
        .onChange(of: model.layout) { _ in
            switch model.layout {
            case .one:
                withAnimation {
                    self.showTopGridView = false
                }
            case .grid:
                self.showMainGridView = true
                self.isAnimatingTopMainGrid = false
                self.showTopGridView = false
            case .oneWithSmal:
                self.showMainGridView = false
                withAnimation {
                    self.isAnimatingTopMainGrid = true
                    self.showTopGridView = true
                }
            }
        }
        .padding(5)
        .background(Color.black)
        .ignoresSafeArea()
    }
}
