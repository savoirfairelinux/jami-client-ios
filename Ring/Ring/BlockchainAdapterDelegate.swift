//
//  BlockchainAdapterDelegate.swift
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-04-04.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

@objc protocol BlockchainAdapterDelegate {
    func registeredNameFound(with accountId: String,
                             state: LookupNameState,
                             address: String,
                             name: String)
}
