//
//  AdapterDelegate.swift
//  jamiNotificationServiceExtension
//
//  Created by kateryna on 2021-06-08.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

import Foundation

@objc protocol AdapterDelegate {

    func didReceiveMessage(_ message: [String: String],
                           from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String)
    func receivingCall(withAccountId accountId: String, callId: String, fromURI uri: String)

}
