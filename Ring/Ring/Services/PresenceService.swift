/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftyBeaver
import RxSwift
import RxCocoa

class PresenceService {

    private let presenceAdapter: PresenceAdapter
    private let log = SwiftyBeaver.self
    private var contactPresence: [String: BehaviorRelay<Bool>]
    private let presenceQueue = DispatchQueue(label: "com.presenceQueue", qos: .background) // used to protect access to contactPresence[]

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    private let disposeBag = DisposeBag()

    init(withPresenceAdapter presenceAdapter: PresenceAdapter) {
        self.contactPresence = [String: BehaviorRelay<Bool>]()
        self.presenceAdapter = presenceAdapter
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        PresenceAdapter.delegate = self
    }

    func getSubscriptionsForContact(contactId: String) -> BehaviorRelay<Bool>? {
        var value: BehaviorRelay<Bool>?
        presenceQueue.sync {[weak self] in
            value = self?.contactPresence[contactId]
        }
        return value
    }

    func subscribeBuddies(withAccount accountId: String,
                          withContacts contacts: [ContactModel],
                          subscribe: Bool) {
        for contact in contacts where !contact.banned {
            self.subscribeBuddy(withAccountId: accountId,
                                withUri: contact.hash,
                                withFlag: subscribe)
        }
    }

    func subscribeBuddy(withAccountId accountId: String,
                        withUri uri: String,
                        withFlag flag: Bool) {
        presenceQueue.async { [weak self] in
            guard let self = self else { return }
            if flag && self.contactPresence[uri] != nil {
                // already subscribed
                return
            }
            self.presenceAdapter.subscribeBuddy(withURI: uri, withAccountId: accountId, withFlag: flag)
            if !flag {
                self.contactPresence[uri] = nil
                return
            }
            if let presenceForContact = self.contactPresence[uri] {
                presenceForContact.accept(false)
                return
            }
            let observableValue = BehaviorRelay<Bool>(value: false)
            self.contactPresence[uri] = observableValue
            DispatchQueue.global(qos: .background).async {
                var event = ServiceEvent(withEventType: .presenseSubscribed)
                event.addEventInput(.accountId, value: accountId)
                event.addEventInput(.uri, value: uri)
                self.responseStream.onNext(event)
            }
        }
    }
}

extension PresenceService: PresenceAdapterDelegate {
    func newBuddyNotification(withAccountId accountId: String,
                              withUri uri: String,
                              withStatus status: Int,
                              withLineStatus lineStatus: String) {
        presenceQueue.async {[weak self] in
            guard let self = self else { return }
            let value = status > 0 ? true : false
            if let presenceForContact = self.contactPresence[uri] {
                presenceForContact.accept(value)
                return
            }
            let observableValue = BehaviorRelay<Bool>(value: value)
            self.contactPresence[uri] = observableValue
        }
    }
}
