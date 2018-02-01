//
//  CallableCoordinator.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2018-02-01.
//  Copyright © 2018 Savoir-faire Linux. All rights reserved.
//

import RxSwift

enum PlaceCallState: State {
    case startCall(contactRingId: String, userName: String)
    case startAudioCall(contactRingId: String, userName: String)
}

protocol CallMakeable: class {

    var injectionBag: InjectionBag { get }
}

extension CallMakeable where Self: Coordinator, Self: StateableResponsive {

     func callbackPlaceCall() {
        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? PlaceCallState else { return }
            switch state {
            case .startCall(let contactRingId, let name):
                self.startOutgoingCall(contactRingId: contactRingId, userName: name)
            case .startAudioCall(let contactRingId, let name):
                self.startOutgoingCall(contactRingId: contactRingId, userName: name, isAudioOnly: true)
            }
        }).disposed(by: self.disposeBag)

    }

    func startOutgoingCall(contactRingId: String, userName: String, isAudioOnly: Bool = false) {
        let callViewController = CallViewController.instantiate(with: self.injectionBag)
        callViewController.viewModel.placeCall(with: contactRingId, userName: userName, isAudioOnly: isAudioOnly)
        self.present(viewController: callViewController, withStyle: .present, withAnimation: false)
    }
}
