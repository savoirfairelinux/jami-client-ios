//
//  CreateSipAccountViewModel.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2019-03-18.
//  Copyright © 2019 Savoir-faire Linux. All rights reserved.
//
import RxSwift
import RxCocoa

class CreateSipAccountViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    var userName = Variable<String>("")
    var password = Variable<String>("")
    var sipServer = Variable<String>("")
    var port = Variable<String>("")
    fileprivate let accountsService: AccountsService

    required init(with injectionBag: InjectionBag) {
        self.accountsService = injectionBag.accountService
    }

    func createSipaccount() {
        let created = self.accountsService.addSipAccount(userName: userName.value,
                                               password: password.value,
                                               sipServer: sipServer.value,
                                               port: port.value)
        if created {
            DispatchQueue.main.async {
                self.stateSubject.onNext(WalkthroughState.accountCreated)
            }
        }
    }
}
