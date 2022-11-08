//
//  ContactListViewModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift

class ContactListViewModel: ViewModel, Stateable {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    private let contactsService: ContactsService

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
    }

}
