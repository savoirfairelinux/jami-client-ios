/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftyBeaver
import RxSwift
import RxCocoa

enum PresenceStatus: Int {
    case offline
    case available
    case connected
}

class PresenceService {

    private let presenceAdapter: PresenceAdapter
    private let log = SwiftyBeaver.self
    private var contactPresence: [String: BehaviorRelay<PresenceStatus>]
    private let presenceQueue = DispatchQueue(label: "com.presenceQueue", qos: .background) // used to protect access to contactPresence[]

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    private let disposeBag = DisposeBag()

    init(withPresenceAdapter presenceAdapter: PresenceAdapter) {
        self.contactPresence = [String: BehaviorRelay<PresenceStatus>]()
        self.presenceAdapter = presenceAdapter
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        PresenceAdapter.delegate = self
    }

    func getSubscriptionsForContact(contactId: String) -> BehaviorRelay<PresenceStatus>? {
        var value: BehaviorRelay<PresenceStatus>?
        presenceQueue.sync {[weak self] in
            value = self?.contactPresence[contactId]
        }
        return value
    }

    func subscribeBuddies(withAccount accountId: String,
                          withContacts contacts: [ContactModel],
                          subscribe: Bool) {
        for contact in contacts where !contact.blocked {
            self.subscribeBuddy(withAccountId: accountId,
                                withJamiId: contact.hash,
                                withFlag: subscribe)
        }
    }

    func subscribeBuddy(withAccountId accountId: String,
                        withJamiId jamiId: String,
                        withFlag flag: Bool) {
        presenceQueue.async { [weak self] in
            guard let self = self else { return }
            if flag && self.contactPresence[jamiId] != nil {
                // already subscribed
                return
            }
            self.presenceAdapter.subscribeBuddy(withJamiId: jamiId, withAccountId: accountId, withFlag: flag)
            if !flag {
                self.contactPresence[jamiId] = nil
                return
            }
            if let presenceForContact = self.contactPresence[jamiId] {
                presenceForContact.accept(.offline)
                return
            }
            let observableValue = BehaviorRelay<PresenceStatus>(value: .offline)
            self.contactPresence[jamiId] = observableValue
            DispatchQueue.global(qos: .background).async {
                var event = ServiceEvent(withEventType: .presenseSubscribed)
                event.addEventInput(.accountId, value: accountId)
                event.addEventInput(.uri, value: jamiId)
                self.responseStream.onNext(event)
            }
        }
    }
}

extension PresenceService: PresenceAdapterDelegate {
    func newBuddyNotification(withAccountId accountId: String,
                              withJamiId jamiId: String,
                              withStatus status: Int,
                              withLineStatus lineStatus: String) {
        presenceQueue.async {[weak self] in
            guard let self = self else { return }
            guard let presenceStatus = PresenceStatus(rawValue: status) else { return}
            if let presenceForContact = self.contactPresence[jamiId] {
                presenceForContact.accept(presenceStatus)
                return
            }
            let observableValue = BehaviorRelay<PresenceStatus>(value: presenceStatus)
            self.contactPresence[jamiId] = observableValue
        }
    }
}
