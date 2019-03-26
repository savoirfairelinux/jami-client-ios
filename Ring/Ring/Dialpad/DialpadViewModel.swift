//
//  DialpadViewModel.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2019-03-26.
//  Copyright © 2019 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift

class DialpadViewModel: ViewModel, Stateable {
    private var injectionBag: InjectionBag
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    // MARK: functions
    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
    }
}
