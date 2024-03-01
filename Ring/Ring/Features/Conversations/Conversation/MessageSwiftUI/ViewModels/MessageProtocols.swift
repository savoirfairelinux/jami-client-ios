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

import Foundation
import SwiftUI
import RxSwift
import RxRelay

protocol AvatarImageObserver: AnyObject {
    var avatarImage: UIImage? { get set }
    var disposeBag: DisposeBag { get }
    var infoState: PublishSubject<State>? { get set }

    func subscribeToAvatarObservable(_ avatarObservable: BehaviorRelay<UIImage?>)

    func requestAvatar(jamiId: String)
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

    func requestAvatar(jamiId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.infoState?.onNext(MessageInfo.updateAvatar(jamiId: jamiId, message: self))
        }
    }
}

protocol MessageReadObserver: AnyObject {
    var read: [UIImage]? { get set }
    var disposeBag: DisposeBag { get }
    var infoState: PublishSubject<State>? { get set }

    func subscribeToReadObservable(_ imagesObservable: BehaviorRelay<[String: UIImage]>)
    func requestReadStatus(messageId: String)
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

    func requestReadStatus(messageId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.infoState?.onNext(MessageInfo.updateRead(messageId: messageId, message: self))
        }
    }
}

protocol NameObserver: AnyObject {
    var username: String { get set }
    var disposeBag: DisposeBag { get }
    var infoState: PublishSubject<State>? { get set }

    func subscribeToNameObservable(_ nameObservable: BehaviorRelay<String>)
    func requestName(jamiId: String)
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

    func requestName(jamiId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.infoState?.onNext(MessageInfo.updateDisplayname(jamiId: jamiId, message: self))
        }
    }
}

struct MessageStyling {
    let defaultTextColor: Color = Color(UIColor.label)
    let defaultSecondaryTextColor: Color = Color.secondary
    let defaultTextFont: Font = Font.callout.weight(.regular)
    let defaultSecondaryFont: Font = Font.footnote.weight(.regular)
    var textColor: Color
    var secondaryTextColor: Color
    var textFont: Font
    var secondaryFont: Font

    init() {
        self.textColor = defaultTextColor
        self.secondaryTextColor = defaultSecondaryTextColor
        self.textFont = defaultTextFont
        self.secondaryFont = defaultSecondaryFont
    }
}

protocol MessageAppearanceProtocol {
    var styling: MessageStyling { get }
}
