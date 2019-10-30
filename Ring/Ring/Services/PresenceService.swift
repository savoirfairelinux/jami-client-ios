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

class PresenceService {

    fileprivate let presenceAdapter: PresenceAdapter
    fileprivate let log = SwiftyBeaver.self
    var contactPresence: [String: Variable<Bool>]

    fileprivate let disposeBag = DisposeBag()
    //fileprivate let responseStream = PublishSubject<ServiceEvent>()
   // var sharedResponseStream: Observable<ServiceEvent>

    init(withPresenceAdapter presenceAdapter: PresenceAdapter) {
       // self.responseStream.disposed(by: disposeBag)
       // self.sharedResponseStream = responseStream.share()
        self.contactPresence = [String: Variable<Bool>]()
        self.presenceAdapter = presenceAdapter
        PresenceAdapter.delegate = self
    }

    func subscribeBuddies(withAccount account: AccountModel, withContacts contacts: [ContactModel]) {
        for contact in contacts where !contact.banned {
            subscribeBuddy(withAccountId: account.id,
                           withUri: contact.hash,
                           withFlag: true)
        }
    }

    func subscribeBuddy(withAccountId accountId: String,
                        withUri uri: String,
                        withFlag flag: Bool) {
        presenceAdapter.subscribeBuddy(withURI: uri, withAccountId: accountId, withFlag: flag)
        contactPresence[uri]?.value = false
    }
}

extension PresenceService: PresenceAdapterDelegate {
    func newBuddyNotification(withAccountId accountId: String,
                              withUri uri: String,
                              withStatus status: Int,
                              withLineStatus lineStatus: String) {
        contactPresence[uri]?.value = status > 0 ? true : false

        /*
         The subscriber is intended to query the contactPresence dictionary
         with the contact's ringId
         */
//        var event = ServiceEvent(withEventType: .presenceUpdated)
//        event.addEventInput(.uri, value: uri)
//        self.responseStream.onNext(event)

        log.debug("newBuddyNotification: uri=\(uri), status=\(status)")
    }
}
