//
//  ContactListViewModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift

class SwarmCreationViewModel: ViewModel, Stateable {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    var searching = PublishSubject<Bool>()

    private let contactsService: ContactsService
    private let accountsService: AccountsService

    var currentAccount: AccountModel? { self.accountsService.currentAccount }

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.accountService
    }
    func showQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode)
    }

}
