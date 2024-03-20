/*
 *  Copyright (C) 2023-2024 Savoir-faire Linux Inc.
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
import RxSwift

class ReactionsRowVM: Identifiable, ObservableObject, AvatarImageObserver, NameObserver {
    let jamiId: String
    let messageId: String
    @Published var avatarImage: UIImage?
    @Published var username: String = ""
    @Published var content = [String: String]()
    @Published var isPortrait: Bool = true
    var disposeBag = DisposeBag()

    var infoState: PublishSubject<State>?

    init(reaction: MessageAction) {
        self.jamiId = reaction.author
        self.username = self.jamiId
        self.messageId = reaction.id
        self.avatarImage = UIImage()
        self.content[reaction.id] = reaction.content
        self.setupOrientation()
    }

    func setupOrientation() {
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                guard let self = self,
                      UIDevice.current.portraitOrLandscape else { return }
                self.updateOrientation(isPortrait: UIDevice.current.orientation.isPortrait)
            })
            .disposed(by: self.disposeBag)
    }

    func updateOrientation(isPortrait: Bool) {
        print("KESS: \(isPortrait)")
        self.isPortrait = isPortrait
        //        self.numCols = ...
        //        self.defaultSize = ...
    }

    func addReaction(reaction: MessageAction) {
        if self.content.keys.contains(reaction.id) { return }
        self.content[reaction.id] = reaction.content
    }

    func toString() -> String {
        return content.values.joined(separator: " ")
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        requestAvatar(jamiId: jamiId)
        requestName(jamiId: jamiId)
    }
}

class ReactionsContainerModel: ObservableObject {
    @Published var reactionsRow = [ReactionsRowVM]()
    @Published var displayValue: String = ""
    var swarmColor: UIColor = UIColor.defaultSwarmColor
    let message: MessageModel
    private var infoState: PublishSubject<State>?
    var reactionsRowCreated = false
    var localJamiId: String
    @Published var isPortrait = true

    init(message: MessageModel, localJamiId: String) {
        self.message = message
        self.localJamiId = localJamiId
        self.updateDisplayValue()
        self.setupOrientation()
    }

    init(message: MessageModel, swarmColor: UIColor, localJamiId: String) {
        self.swarmColor = swarmColor
        self.message = message
        self.localJamiId = localJamiId
        self.updateDisplayValue()
        self.setupOrientation()
    }

    let disposeBag = DisposeBag()

    func setupOrientation() {
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                guard let self = self,
                      UIDevice.current.portraitOrLandscape else { return }
                self.updateOrientation(isPortrait: UIDevice.current.orientation.isPortrait)
            })
            .disposed(by: self.disposeBag)
    }

    func updateOrientation(isPortrait: Bool) {
        self.isPortrait = isPortrait
        //        self.numCols = ...
        //        self.defaultSize = ...
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        reactionsRow.forEach { reaction in
            reaction.setInfoState(state: state)
        }
    }

    func onAppear() {
        if self.reactionsRowCreated { return }
        self.reactionsRowCreated.toggle()
        self.update()
    }

    func reactionsUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateDisplayValue()
            if self.reactionsRowCreated {
                self.update()
            }
        }
    }

    private func updateDisplayValue() {
        self.displayValue = self.toString()
    }

    private func updateReaction(reaction: MessageAction) {
        if let existingReaction = getReaction(jamiId: reaction.author) {
            existingReaction.addReaction(reaction: reaction)
        } else {
            self.addReaction(reaction: reaction)
        }
    }

    private func addReaction(reaction: MessageAction) {
        let reactionRow = ReactionsRowVM(reaction: reaction)
        self.reactionsRow.append(reactionRow)
        if let state = self.infoState {
            reactionRow.setInfoState(state: state)
        }
    }

    private func update() {
        self.reactionsRow = [ReactionsRowVM]()
        self.message.reactions.forEach { reaction in
            self.updateReaction(reaction: reaction)
        }
    }

    private func getReaction(jamiId: String) -> ReactionsRowVM? {
        return self.reactionsRow.filter({ reaction in
            reaction.jamiId == jamiId
        }).first
    }

    private func toString() -> String {
        let reactions = self.message.reactions.map { reaction in
            reaction.content
        }

        return constructString(from: reactions, spaceBetweenCharacters: "  ", spaceBetweenCharAndCount: "")
    }

    private func constructString(from strings: [String], spaceBetweenCharacters: String, spaceBetweenCharAndCount: String) -> String {
        let charCounts = Dictionary(strings.map { ($0, 1) }, uniquingKeysWith: +)
        let result = charCounts
            .map { (str, count) in
                count > 1 ? "\(str)\(spaceBetweenCharAndCount)\(count)" : str
            }
            .joined(separator: spaceBetweenCharacters)

        return result
    }
}
