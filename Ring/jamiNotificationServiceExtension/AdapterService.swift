//
//  AdapterService.swift
//  jamiNotificationServiceExtension
//
//  Created by kateryna on 2021-06-08.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

import Foundation

class AdapterService: AdapterDelegate {

    enum EventType: Int {
        case call = 0
        case message = 1
        case fileTransfer = 2
    }

    private let adapter: Adapter
    var eventHandler: ((EventType) -> Void)?

    init(withAdapter adapter: Adapter, withEventHandler eventHandler: @escaping (EventType) -> Void) {
        self.eventHandler = eventHandler
        self.adapter = adapter
    }
    func didReceiveMessage(_ message: [String: String],
                           from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String) {
        if self.eventHandler != nil {
            self.eventHandler!(.call)
        }
    }
    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String) {
        if self.eventHandler != nil {
            self.eventHandler!(.message)
        }
    }
    func startDaemon() {
        adapter.startDaemon()
    }
    func pushNotificationReceived(from: String, message: [AnyHashable: Any]) {
        adapter.pushNotificationReceived(from, message: message)
    }

}
