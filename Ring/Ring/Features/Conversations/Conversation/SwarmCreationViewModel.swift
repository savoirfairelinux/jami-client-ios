//
//  ContactListViewModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class SwarmCreationViewModel: ViewModel, Stateable {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    private let accountsService: AccountsService
    var currentAccount: AccountModel? { self.accountsService.currentAccount }

    required init(with injectionBag: InjectionBag) {
        self.accountsService = injectionBag.accountService
        self.injectionBag = injectionBag
    }
}
