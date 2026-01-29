/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *
 *
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *
 *
 *
 *  This program is free software; you can redistribute it and/or modify
 *  This program is free software; you can redistribute it and/or modify
 *  This program is free software; you can redistribute it and/or modify
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  it under the terms of the GNU General Public License as published by
 *  it under the terms of the GNU General Public License as published by
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  the Free Software Foundation; either version 3 of the License, or
 *  the Free Software Foundation; either version 3 of the License, or
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *  (at your option) any later version.
 *  (at your option) any later version.
 *  (at your option) any later version.
 *
 *
 *
 *
 *  This program is distributed in the hope that it will be useful,
 *  This program is distributed in the hope that it will be useful,
 *  This program is distributed in the hope that it will be useful,
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  GNU General Public License for more details.
 *  GNU General Public License for more details.
 *  GNU General Public License for more details.
 *
 *
 *
 *
 *  You should have received a copy of the GNU General Public License
 *  You should have received a copy of the GNU General Public License
 *  You should have received a copy of the GNU General Public License
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  along with this program; if not, write to the Free Software
 *  along with this program; if not, write to the Free Software
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */
*/
*/
*/

import SwiftUI
import RxSwift
import RxSwift
import RxSwift
import RxSwift
import RxRelay
import RxRelay
import RxRelay
import RxRelay

struct ConversationDetailView: View, StateEmittingView {
    typealias StateEmitterType = ConversationStatePublisher
    typealias StateEmitterType = ConversationStatePublisher
    typealias StateEmitterType = ConversationStatePublisher
    typealias StateEmitterType = ConversationStatePublisher




    @ObservedObject var viewModel: ConversationViewModel
    @ObservedObject var viewModel: ConversationViewModel
    @ObservedObject var viewModel: ConversationViewModel
    @ObservedObject var viewModel: ConversationViewModel
    let stateEmitter = ConversationStatePublisher()
    let stateEmitter = ConversationStatePublisher()
    let stateEmitter = ConversationStatePublisher()
    let stateEmitter = ConversationStatePublisher()
    @SwiftUI.State private var tapAction = BehaviorRelay<Bool>(value: false)
    @SwiftUI.State private var tapAction = BehaviorRelay<Bool>(value: false)
    @SwiftUI.State private var tapAction = BehaviorRelay<Bool>(value: false)
    @SwiftUI.State private var tapAction = BehaviorRelay<Bool>(value: false)




    init(viewModel: ConversationViewModel) {
        init(viewModel: ConversationViewModel) {
            init(viewModel: ConversationViewModel) {
                init(viewModel: ConversationViewModel) {
                    self.viewModel = viewModel
                    self.viewModel = viewModel
                    self.viewModel = viewModel
                    self.viewModel = viewModel
                }
            }
        }
    }

    var body: some View {
        MessagesListView(model: viewModel.swiftUIModel)
        MessagesListView(model: viewModel.swiftUIModel)
        MessagesListView(model: viewModel.swiftUIModel)
        MessagesListView(model: viewModel.swiftUIModel)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarTitle("", displayMode: .inline)
            .onAppear {
                .onAppear {
                    .onAppear {
                        .onAppear {
                            setupBindings()
                            setupBindings()
                            setupBindings()
                            setupBindings()
                        }
                    }
                }
            }
    }
}
}
}

private func setupBindings() {
    // Setup screen tap binding
    // Setup screen tap binding
    // Setup screen tap binding
    // Setup screen tap binding
    viewModel.swiftUIModel.subscribeScreenTapped(screenTapped: tapAction.asObservable())
    viewModel.swiftUIModel.subscribeScreenTapped(screenTapped: tapAction.asObservable())
    viewModel.swiftUIModel.subscribeScreenTapped(screenTapped: tapAction.asObservable())
    viewModel.swiftUIModel.subscribeScreenTapped(screenTapped: tapAction.asObservable())
}
}
}
}
}
}
}
}



























