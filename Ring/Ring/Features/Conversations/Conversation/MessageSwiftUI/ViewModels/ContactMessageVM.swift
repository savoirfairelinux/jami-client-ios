/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
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

import Foundation
import SwiftUI
import RxSwift
import RxRelay

protocol AvatarImageObserver: AnyObject {
    var avatarImage: UIImage? { get set }
    var disposeBag: DisposeBag { get }

    func subscribeToAvatarObservable(_ avatarObservable: BehaviorRelay<UIImage?>)
}

extension AvatarImageObserver {
    func subscribeToAvatarObservable(_ avatarObservable: BehaviorRelay<UIImage?>) {
        avatarObservable
            .observe(on: MainScheduler.instance)
            .startWith(avatarObservable.value)
            .subscribe(onNext: { [weak self] newImage in
                self?.avatarImage = newImage
            })
            .disposed(by: disposeBag)
    }
}

protocol MessageReadObserver: AnyObject {
    var read: [UIImage]? { get set }
    var disposeBag: DisposeBag { get }

    func subscribeToReadObservable(_ imagesObservable: BehaviorRelay<[String: UIImage]>)
}

extension MessageReadObserver {
    func subscribeToReadObservable(_ imagesObservable: BehaviorRelay<[String: UIImage]>) {
        imagesObservable
            .observe(on: MainScheduler.instance)
            .startWith(imagesObservable.value)
            .subscribe(onNext: { [weak self] lastReadAvatars in
                let values: [UIImage] = lastReadAvatars.map { value in
                    return value.value
                }
                let newValue = values.isEmpty ? nil : values
                self?.read = newValue
            })
            .disposed(by: disposeBag)
    }
}

protocol NameObserver: AnyObject {
    var username: String { get set }
    var disposeBag: DisposeBag { get }

    func subscribeToNameObservable(_ nameObservable: BehaviorRelay<String>)
}

extension NameObserver {
    func subscribeToNameObservable(_ nameObservable: BehaviorRelay<String>) {
        nameObservable
            .observe(on: MainScheduler.instance)
            .startWith(nameObservable.value)
            .subscribe(onNext: { [weak self] newName in
                self?.username = newName
            })
            .disposed(by: disposeBag)
    }
}

class ContactMessageVM: ObservableObject, MessageAppearanceProtocol, AvatarImageObserver, NameObserver {
    @Published var avatarImage: UIImage?
    @Published var content: String
    @Published var borderColor: Color
    @Published var backgroundColor: Color
    var disposeBag = DisposeBag()
    let cornerRadius: CGFloat = 20
    let avatarSize: CGFloat = 15
    var inset: CGFloat
    var height: CGFloat
    var styling: MessageStyling = MessageStyling()

    var message: MessageModel
    var username = "" {
        didSet {
            self.content = self.username.isEmpty ? self.message.content : self.username + " " + self.message.content
        }
    }
    private var infoState: PublishSubject<State>?

    init(message: MessageModel) {
        self.message = message
        self.backgroundColor = Color(UIColor.clear)
        self.inset = message.type == .initial ? 0 : 7
        self.height = message.type == .initial ? 25 : 45
        self.borderColor = message.type == .initial ? Color(UIColor.clear) : Color(UIColor.secondaryLabel)
        self.content = message.content
        if message.type != .initial {
            self.styling.textFont = self.styling.secondaryFont
            self.styling.textColor = self.styling.defaultSecondaryTextColor
        }
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
        if message.type == .contact && message.incoming {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let jamiId = message.uri.isEmpty ? message.authorId : message.uri
                self.infoState?.onNext(MessageInfo.updateAvatar(jamiId: jamiId, message: self))
                self.infoState?.onNext(MessageInfo.updateDisplayname(jamiId: jamiId, message: self))
            }
        }
    }

    func swarmColorUpdated(color: UIColor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.borderColor = self.message.type != .initial ? Color(color) : Color(UIColor.clear)
        }
    }

    //    func updateUsername(name: String, jamiId: String) {
    //        let jamiIdForMessage = message.uri.isEmpty ? message.authorId : message.uri
    //        guard jamiIdForMessage == jamiId, !name.isEmpty, message.incoming, message.type == .contact else { return }
    //        self.username = name
    //    }
    //
    //    func updateAvatar(image: UIImage, jamiId: String) {
    //        let jamiIdForMessage = message.uri.isEmpty ? message.authorId : message.uri
    //        guard jamiIdForMessage == jamiId, message.incoming, message.type == .contact else { return }
    //        self.avatarImage = image
    //    }
}
