//
//  RequestsAdapterDelegate.swift
//  Ring
//
//  Created by kateryna on 2021-07-07.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//
@objc protocol RequestsAdapterDelegate {
    func incomingTrustRequestReceived(from senderAccount: String,
                                      to accountId: String,
                                      withPayload payload: Data,
                                      receivedDate: Date)
    func conversationRequestReceived(conversationId: String, accountId: String, metadata: [String: String])
//    func incomingTrustRequestReceived(from senderAccount: String,
//                                      to accountId: String,
//                                      withPayload payload: Data,
//                                      receivedDate: Date)
//    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool)
//    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool)
}
