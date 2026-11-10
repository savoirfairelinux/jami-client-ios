/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import Foundation
import RxSwift

enum MessageSendError: Error, Equatable {
    case permissionDenied
    case failed
    case unconfirmed

    var localizedMessage: String {
        switch self {
        case .permissionDenied: return L10n.Conversation.sendPermissionDenied
        case .failed: return L10n.Conversation.sendFailed
        case .unconfirmed: return L10n.Conversation.sendUnconfirmed
        }
    }
}

struct ConversationFailure {
    let accountId: String
    let conversationId: String
    let code: Int
    let message: String
}

/// libjami's public send calls return void. A successful dispatch is not a
/// receipt: wait for local commit/file creation, never for an offline peer.
/// An inconclusive timeout retains the draft and must not trigger an automatic retry.
enum SwarmSendConfirmation {
    static func wait(receipts: Observable<Bool>, timeout: RxTimeInterval = .seconds(30),
                     dispatch: @escaping () -> Bool) -> Single<Void> {
        Single.create { observer in
            let receipt = receipts.take(1)
                .timeout(timeout, scheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
                .subscribe(onNext: { accepted in
                    observer(accepted ? .success(()) : .failure(MessageSendError.failed))
                }, onError: { _ in
                    observer(.failure(MessageSendError.unconfirmed))
                })
            // Subscribe first: daemon callbacks may happen during dispatch.
            if !dispatch() {
                receipt.dispose()
                observer(.failure(MessageSendError.permissionDenied))
            }
            return receipt
        }
    }
}
