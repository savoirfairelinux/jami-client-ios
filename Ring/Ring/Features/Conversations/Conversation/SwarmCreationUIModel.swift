//
//  SwiftCreationUIModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-16.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift
import RxRelay
import SwiftUI

class SwarmCreationUIModel: ObservableObject {
    @Published var participantsRows = [ParticipantRow]()
    var filteredArray = [ParticipantRow]()
    let disposeBag = DisposeBag()
    var model: SwarmCreationViewModel!
    let strFinalSet = BehaviorRelay<String>(value: "")

    var swarmInfo: SwarmInfo

    required init(with injectionBag: InjectionBag, accountId: String) {
        self.swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: accountId)
        self.model = SwarmCreationViewModel(with: injectionBag)
        self.strFinalSet.subscribe { str in
            print(str)
            if !str.isEmpty {
                let flatArr = self.filteredArray.compactMap { $0 }
                self.participantsRows = flatArr.filter { (item) -> Bool in
                    return item.match(string: str)
                }
            } else {
                self.participantsRows = self.filteredArray
            }
        } onError: { _ in

        }
        .disposed(by: disposeBag)

        self.swarmInfo.contacts.subscribe { infos in
            self.participantsRows = [ParticipantRow]()
            for info in infos {
                let participant = ParticipantRow(participantData: info)
                self.participantsRows.append(participant)
                self.filteredArray.append(participant)
            }
        } onError: { _ in

        }
        .disposed(by: self.disposeBag)
        injectionBag
            .contactsService
            .contacts
            .asObservable()
            .subscribe { contacts in
                self.swarmInfo.addContacts(contacts: contacts)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)

    }

}
