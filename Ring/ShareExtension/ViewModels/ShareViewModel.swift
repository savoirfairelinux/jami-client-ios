/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
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
import SwiftyBeaver

class ShareViewModel {
    private let log = SwiftyBeaver.self

    let dBManager: ShareDBManager!
    private let daemonService: ShareAdapterService!
    private let nameService = ShareNameService(withNameRegistrationAdapter: ShareAdapter())
    lazy var injectionBag: ShareInjectionBag = {
        return ShareInjectionBag(withDaemonService: self.daemonService, nameService: nameService)
    }()

    var contactSelectedCB: ((_ contact: [ShareSwarmInfo]) -> Void)?

    let conferensableItems = BehaviorSubject(value: [ShareContactPickerSection]())

    lazy var searchResultItems: Observable<[ShareContactPickerSection]> = {
        return search
            .startWith("")
            .distinctUntilChanged()
            .withLatestFrom(self.conferensableItems) { (search, targets) in (search, targets) }
            .map({ (arg) -> [ShareContactPickerSection] in
                var (search, targets) = arg
                if search.isEmpty {
                    return targets
                }
                let result = targets.map {(section: ShareContactPickerSection) -> ShareContactPickerSection in
                    var sectionVariable = section
                    let newItems = section.items.map { (item: ShareSwarmInfo) -> ShareSwarmInfo in
                        var mutabeItem = item
                        let newContacts = item.participants.value.filter { contact in
                            var mutableContact = contact
                            let searchLowercased = search.lowercased()
                            return mutableContact.finalName.value.lowercased().contains(searchLowercased) ||
                                mutableContact.profileName.value.lowercased()
                                .contains(searchLowercased) ||
                                mutableContact.registeredName.value.lowercased()
                                .contains(searchLowercased)
                        }
                        mutabeItem.participants.accept(newContacts)
                        return mutabeItem
                    }
                    .filter { (item: ShareSwarmInfo) -> Bool in
                        return !item.participants.value.isEmpty
                    }
                    sectionVariable.items = newItems
                    return sectionVariable
                }
                .filter { (section: ShareContactPickerSection) -> Bool in
                    return !section.items.isEmpty
                }
                return result
            })
    }()

    let search = PublishSubject<String>()
    private let disposeBag = DisposeBag()

    required init() {
        self.dBManager = ShareDBManager(profileHepler: ProfileDataHelper(),
                                        conversationHelper: ConversationDataHelper(),
                                        interactionHepler: InteractionDataHelper(),
                                        dbConnections: DBContainer())
        self.daemonService = ShareAdapterService(withAdapter: ShareAdapter(), dbManager: dBManager)
        self.daemonService.start()
        _ = self.daemonService.loadAccounts()

        self.daemonService.conversations
            .subscribe { list in
                let newList = (list.element ?? []).map({ ShareContactPickerSection(header: $0.0, items: $0.1.map({ ShareSwarmInfo(injectionBag: self.injectionBag, conversation: $0) })) })
                self.conferensableItems.onNext(newList)
            }
            .disposed(by: disposeBag)
    }

    func contactSelected(contacts: [ShareSwarmInfo]) {
        if contacts.isEmpty { return }
        if contactSelectedCB != nil {
            contactSelectedCB!(contacts)
        }
    }

    func startDaemon() {
        self.daemonService.start()
    }

    func stopDaemon() {
        self.daemonService.stop()
    }

    private func shareMessage(message: ShareMessageModel, with swarm: ShareSwarmInfo, fileURL: URL?, fileName: String) {
        if let url = fileURL {
            if let data = FileManager.default.contents(atPath: url.path),
               let conversation = swarm.conversation {
                swarm.sendAndSaveFile(displayName: fileName, imageData: data, conversation: conversation, accountId: conversation.accountId)
            }
            return
        }
    }

    func shareMessage(message: ShareMessageModel, with selectedConversations: [ShareSwarmInfo]) {
        // to send file we need to have file url or image
        let url = message.url
        var fileName = message.content
        if message.content.contains("\n") {
            guard let substring = message.content.split(separator: "\n").first else { return }
            fileName = String(substring)
        }
        selectedConversations.forEach { (item) in
            self.shareMessage(message: message, with: item, fileURL: url, fileName: fileName)
        }
    }
}
