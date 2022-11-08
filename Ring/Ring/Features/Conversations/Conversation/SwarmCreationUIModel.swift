//
//  SwiftCreationUIModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-16.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

class SwarmCreationUIModel: ObservableObject {
    @Published var participantsRows = [ParticipantRow]()
    let disposeBag = DisposeBag()

    var swarmInfo: SwarmInfo

    required init(with injectionBag: InjectionBag, accountId: String) {
        self.swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: accountId)
        injectionBag
            .contactsService
            .contacts
            .asObservable()
            .subscribe { contacts in
                self.swarmInfo.addContacts(contacts: contacts)
            } onError: { _ in
            }.disposed(by: self.disposeBag)

        self.swarmInfo.contacts.subscribe { infos in
            for info in infos {
                let participant = ParticipantRow(participantData: info)
                self.participantsRows.append(participant)
            }
        } onError: { _ in

        }.disposed(by: self.disposeBag)

    }

}
