//
//  ContactListViewModel.swift
//  Ring
//
//  Created by Binal Ahiya on 2022-11-08.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class SwarmCreationViewModel: ViewModel, Stateable {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    var searching = PublishSubject<Bool>()
    //    var contactItems = [ParticipantList]()
    var partcipantName: String = ""
    var imageData: UIImage = UIImage()
    var imageFlag: Bool = false

    private let contactsService: ContactsService
    private let accountsService: AccountsService
    private let presenceService: PresenceService
    private let nameService: NameService
    private let callService: CallsService
    var currentAccount: AccountModel? { self.accountsService.currentAccount }

    lazy var itemList: Observable<[ParticipantList]> = {
        return self.contactsService.contacts
            .asObservable()
            .map { contact in
                var contactItems = [ParticipantList]()
                self.addToContacts(contacts: contact, participantList: &contactItems)
                return contactItems
            }
        /*        self.contactsService.contacts
         //            .asObservable()
         //            .subscribe { contact in
         //                self.addToContacts(contacts: contact)
         //            }
         //            .disposed(by: disposeBag)

         //        self.contactsService.contacts.bind(onNext: { contact in
         //            print(contact.count)
         //            self.addToContacts(contacts: contact)
         //        })
         //        .disposed(by: disposeBag)*/
    }()

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.accountService
        self.presenceService = injectionBag.presenceService
        self.callService = injectionBag.callService
        self.nameService = injectionBag.nameService
        self.injectionBag = injectionBag
    }

    func addToContacts(contacts: [ContactModel], participantList: inout [ParticipantList]) {
        guard let currentAccount = currentAccount else {
            return
        }
        contacts.forEach { contact in
            guard let contactUri = contact.uriString else { return }
            let jamiid = contactUri.replacingOccurrences(of: "ring:", with: "")

            let profile = self.contactsService.getProfile(uri: contactUri, accountId: currentAccount.id)
            guard let strName = profile?.alias else { return }
            guard let strPhoto = profile?.photo else { return }

            /*            if let contactProfile = profile, let strName = contactProfile.alias {
             //                if strName.isEmpty {
             //                    self.getParticipantName(jamiid: jamiid, accountId: currentAccount.id)
             //                } else {
             //                    partcipantName = strName
             //                }
             //            }*/
            if !strPhoto.isEmpty, !strName.isEmpty,
               let data = NSData(base64Encoded: strPhoto, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                partcipantName = strName
                imageData = UIImage(data: data)!
            } else if strPhoto.isEmpty, !strName.isEmpty {
                partcipantName = strName
                imageData = self.createContactAvatar(username: partcipantName)
            } else if !strPhoto.isEmpty, strName.isEmpty, let data = NSData(base64Encoded: strPhoto, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                imageFlag = true
                self.getParticipantName(jamiid: jamiid, accountId: currentAccount.id)
                imageData = UIImage(data: data)!
            } else if strPhoto.isEmpty, strName.isEmpty {
                imageFlag = false
                self.getParticipantName(jamiid: jamiid, accountId: currentAccount.id)
            }

            if !participantList.contains(where: { list in
                list.id == contactUri
            }) {
                print("Final Participant ->\(partcipantName)")
                participantList.append(ParticipantList(id: contactUri, imageDataFinal: imageData, name: partcipantName))
            }
        }
    }
    func showQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode)
    }
    func createContactAvatar(username: String) -> UIImage {
        let image = UIImage(asset: Asset.icContactPicture)!
            .withAlignmentRectInsets(UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        let scanner = Scanner(string: username.toMD5HexString().prefixString())
        var index: UInt64 = 0
        if scanner.scanHexInt64(&index) {
            let fbaBGColor = avatarColors[Int(index)]
            if !username.isSHA1() && !username.isEmpty {
                if let avatar = image.drawText(text: username.prefixString().capitalized, backgroundColor: fbaBGColor, textColor: UIColor.white, size: CGSize(width: 60, height: 60)) {
                    return avatar
                }
            }
        }
        return image
    }

    func getParticipantName(jamiid: String, accountId: String) {
        self.nameService.usernameLookupStatus
            .filter({ lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == jamiid
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if let name = lookupNameResponse.name, !name.isEmpty {
                    print("Local ParticipantName ->\(name)")
                    self?.partcipantName = name
                    self?.imageData = (self?.createContactAvatar(username: name))!
                } else {
                    print("Jami ID ->\(jamiid)")
                    self?.partcipantName = jamiid
                    self?.imageData = UIImage(asset: Asset.addAvatar)!
                }
            })
            .disposed(by: disposeBag)
        self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: jamiid)
    }
}
