/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import UIKit
import RxSwift
import Reusable
import SwiftyBeaver

class InvitationViewController: UIViewController, StoryboardBased, ViewModelBased {

    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var refuseButton: UIButton!
    @IBOutlet weak var banButton: UIButton!
    @IBOutlet weak var inviteButton: UIButton!
    @IBOutlet weak var contactAvatar: UIImageView!
    @IBOutlet weak var invitationLabel1: UILabel!
    @IBOutlet weak var invitationLabel2: UILabel!
    @IBOutlet weak var invitationLabel3: UILabel!
    @IBOutlet weak var buttonsContainer: UIStackView!

    private let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self
    var viewModel: InvitationViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.contactAvatar
            .addSubview(AvatarView(profileImageData: self.viewModel.profileImageData.value,
                                   username: self.viewModel.displayName.value,
                                   size: 90))
        self.setUpBinding()
    }

    private func setUpBinding() {
        self.viewModel.invitationStatus
            .observe(on: MainScheduler.instance)
            .startWith(self.viewModel.invitationStatus.value)
            .subscribe { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .temporary:
                    self.setTemporaryContactView()
                case .pending:
                    self.setPendingContactView()
                case .synchronizing:
                    self.setSynchronizationContactView()
                case .added, .refused:
                    self.removeChildController()
                    self.dismiss(animated: false, completion: nil)
                case .invalid:
                    self.setTemporaryContactView()
                }
            } onError: { [weak self] _ in
                self?.log.error("error in invitation status")
            }
            .disposed(by: self.disposeBag)
        self.viewModel.profileImageData
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] data in
                guard let self = self, let data = data else { return }
                self.contactAvatar
                    .addSubview(AvatarView(profileImageData: data,
                                           username: self.viewModel.displayName.value,
                                           size: 90))
            } onError: { [weak self] _ in
                self?.log.error("error in getting profile image")
            }
            .disposed(by: self.disposeBag)

        self.acceptButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.acceptRequest()
            })
            .disposed(by: self.disposeBag)

        self.refuseButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.refuseRequest()
            })
            .disposed(by: self.disposeBag)

        self.banButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.banRequest()
            })
            .disposed(by: self.disposeBag)

        self.inviteButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.sendRequest()
            })
            .disposed(by: self.disposeBag)
    }

    private func setTemporaryContactView() {
        buttonsContainer.isHidden = true
        inviteButton.isHidden = false
        invitationLabel1.isHidden = true
        invitationLabel3.isHidden = false
        invitationLabel2.text = L10n.Conversation.notContact(self.viewModel.displayName.value)
        invitationLabel3.text = L10n.Conversation.sendRequest
        inviteButton.setTitle(L10n.Conversation.sendRequestTitle, for: .normal)
    }
    private func setPendingContactView() {
        buttonsContainer.isHidden = false
        inviteButton.isHidden = true
        invitationLabel1.isHidden = false
        self.viewModel.displayName
            .asObservable()
            .subscribe(onNext: { [weak self] name in
                self?.invitationLabel1.text = L10n.Conversation.receivedRequest(name)
            })
            .disposed(by: self.disposeBag)
        invitationLabel2.text = L10n.Conversation.requestMessage
        invitationLabel3.isHidden = true
        acceptButton.setTitle(L10n.Global.accept, for: .normal)
        refuseButton.setTitle(L10n.Global.refuse, for: .normal)
        banButton.setTitle(L10n.Global.block, for: .normal)
    }
    private func setSynchronizationContactView() {
        buttonsContainer.isHidden = true
        inviteButton.isHidden = true
        invitationLabel1.isHidden = true
        invitationLabel3.isHidden = false
        invitationLabel2.text = L10n.Conversation.synchronizationTitle
        self.viewModel.displayName
            .asObservable()
            .subscribe(onNext: { [weak self] name in
                self?.invitationLabel3.text = L10n.Conversation.synchronizationMessage(name)
            })
            .disposed(by: self.disposeBag)
    }

}
