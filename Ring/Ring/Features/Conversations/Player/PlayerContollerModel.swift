//
//  PlayerViewModel.swift
//  Ring
//
//  Created by kateryna on 2020-08-27.
//  Copyright © 2020 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import RxDataSources

class PlayerControllerModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let disposeBag = DisposeBag()

    var path = ""

    var playerViewModel: PlayerViewModel?

    required init (with injectionBag: InjectionBag) {
    }
}
