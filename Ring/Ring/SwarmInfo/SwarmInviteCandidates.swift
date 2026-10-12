/*
 * Copyright (C) 2026 Savoir-faire Linux Inc. *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import RxSwift
import RxRelay

class SwarmInviteCandidates {
    let candidates = BehaviorRelay(value: [ParticipantInfo]())

    private let injectionBag: InjectionBag
    private let requestsService: RequestsService
    private let accountId: String
    private let localJamiId: String?
    private let disposeBag = DisposeBag()

    init(injectionBag: InjectionBag, accountId: String, members: Observable<[ParticipantInfo]>) {
        self.injectionBag = injectionBag
        self.requestsService = injectionBag.requestsService
        self.accountId = accountId
        self.localJamiId = injectionBag.accountService.getAccount(fromAccountId: accountId)?.jamiId

        injectionBag.contactsService.contacts
            .withLatestFrom(members) { contacts, members in
                (contacts, Set(members.map(\.jamiId)))
            }
            .subscribe(onNext: { [weak self] contacts, memberIds in
                guard let self = self else { return }
                self.candidates.accept(self.makeCandidates(from: contacts, excluding: memberIds))
            })
            .disposed(by: disposeBag)
    }

    private func makeCandidates(from contacts: [ContactModel], excluding memberIds: Set<String>) -> [ParticipantInfo] {
        let requests = requestsService.requests.value
        return contacts.compactMap { contact in
            let hasPendingRequest = requests.contains { request in
                request.participants.contains { $0.jamiId == contact.hash }
            }
            if contact.banned || hasPendingRequest || memberIds.contains(contact.hash) {
                return nil
            }
            return ParticipantInfo.loaded(jamiId: contact.hash, role: .unknown, accountId: accountId,
                                          isLocal: contact.hash == localJamiId,
                                          injectionBag: injectionBag)
        }
    }
}
