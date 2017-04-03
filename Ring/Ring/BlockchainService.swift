//
//  BlockchainService.swift
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-04-04.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift

class BlockchainService: BlockchainAdapterDelegate {

    static let sharedInstance = BlockchainService()

    fileprivate let blockchainAdapter = BlockchainAdapter.sharedManager()

    fileprivate let responseStream = PublishSubject<ServiceEvent>()

    let sharedResponseStream: Observable<ServiceEvent>

    init() {

        //self.responseStream.addDisposableTo(disposeBag)

        sharedResponseStream = responseStream.share()

        self.blockchainAdapter?.delegate = self
    }

    func lookupName(with account: String, nameserver: String, name: String) {
        blockchainAdapter?.lookupName(withAccount: account, nameserver: nameserver, name: name)
    }

    //MARK: BlockchainService delegate

    func registeredNameFound(with accountId: String,state: LookupNameState,address: String,name: String) {

        var event = ServiceEvent.init(withEventType: .RegisterNameFound)
        if state == .Found {
            event.addEventInput(.LookupNameState, value: LookupNameState.Found)
        } else if state == .InvalidName {
            event.addEventInput(.LookupNameState, value: LookupNameState.InvalidName)
        } else {
            event.addEventInput(.LookupNameState, value: LookupNameState.Error)
        }
        self.responseStream.onNext(event)
    }
}
