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

// Removed legacy AvatarImageObserver in favor of using AvatarProvider for SwiftUI views

protocol MessageReadObserver: AnyObject {
    var readIds: [String]? { get set }
    var readDisposeBag: DisposeBag { get  set }
    var infoState: PublishSubject<State>? { get set }

    func subscribeToReadObservable(_ idsObservable: BehaviorRelay<[String]>)
    func requestReadStatus(messageId: String)
}

extension MessageReadObserver {
    func subscribeToReadObservable(_ idsObservable: BehaviorRelay<[String]>) {
        readDisposeBag = DisposeBag()
        idsObservable
            .startWith(idsObservable.value)
            .subscribe(onNext: { [weak self] ids in
                DispatchQueue.main.async {[weak self] in
                    let newValue = ids.isEmpty ? nil : ids
                    self?.readIds = newValue
                }
            })
            .disposed(by: readDisposeBag)
    }

    func requestReadStatus(messageId: String) {
        DispatchQueue.global(qos: .background).async {[weak self] in
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
            .startWith(nameObservable.value)
            .subscribe(onNext: { [weak self] newName in
                DispatchQueue.main.async {[weak self] in
                    self?.username = newName
                }
            })
            .disposed(by: disposeBag)
    }

    func requestName(jamiId: String) {
        DispatchQueue.global(qos: .background).async {[weak self] in
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
