//
//  MessagesListModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-26.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

class MessagesListModel: ObservableObject {

    @Published var messagesModels = [MessageViewModel]()
    let disposeBag = DisposeBag()

    init (messages: Observable<[MessageModel]>, bag: InjectionBag) {
        messages.subscribe { messages in
            var models = [MessageViewModel]()
            for message in messages {
                models.append(MessageViewModel(withInjectionBag: bag, withMessage: message, isLastDisplayed: false))
            }
            self.messagesModels = models
        } onError: { _ in

        }
        .disposed(by: self.disposeBag)
    }

    init() {

    }
}
