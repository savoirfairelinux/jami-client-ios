/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani <alireza.toghiani@savoirfairelinux.com>
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

import Reusable
import RxSwift
import UIKit

class EditProfileViewController: UIViewController, UITextFieldDelegate,
                                 UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: - outlets

    @IBOutlet var profileImageView: UIImageView!
    @IBOutlet var profileName: UITextField!

    // MARK: - members

    var model: EditProfileViewModel!
    private let disposeBag = DisposeBag()

    // MARK: - functions

    override func viewDidLoad() {
        super.viewDidLoad()
        model.profileImage
            .bind(to: profileImageView.rx.image)
            .disposed(by: disposeBag)

        model.profileName
            .bind(to: profileName.rx.text)
            .disposed(by: disposeBag)

        // Binds the keyboard Send button action to the ViewModel
        profileName.rx.controlEvent(.editingDidEndOnExit)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.model.updateName(self.profileName.text!)
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupUI()
    }

    func setupUI() {
        profileName.returnKeyType = .done
        profileName.autocorrectionType = .no

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(imageTapped(tapGestureRecognizer:))
        )
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(tapGestureRecognizer)
    }

    func resetProfileName() {
        profileName.text = model.name
    }

    @objc
    func imageTapped(tapGestureRecognizer _: UITapGestureRecognizer) {
        let alert = UIAlertController(title: nil,
                                      message: nil,
                                      preferredStyle: .actionSheet)

        let cameraAction = UIAlertAction(
            title: L10n.Alerts.profileTakePhoto,
            style: UIAlertAction.Style.default
        ) { _ in
            self.takePicture()
        }

        let pictureAction = UIAlertAction(
            title: L10n.Alerts.profileUploadPhoto,
            style: UIAlertAction.Style.default
        ) { _ in
            self.importPicture()
        }

        let cancelAction = UIAlertAction(
            title: L10n.Global.cancel,
            style: UIAlertAction.Style.cancel
        )

        alert.addAction(cameraAction)
        alert.addAction(pictureAction)
        alert.addAction(cancelAction)
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.maxX,
            width: 0,
            height: 0
        )
        present(alert, animated: true, completion: nil)
    }

    func takePicture() {
        if UIImagePickerController
            .isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerController.SourceType.camera
            imagePicker.cameraDevice = UIImagePickerController.CameraDevice.front
            imagePicker.allowsEditing = true
            imagePicker.modalPresentationStyle = .overFullScreen
            present(imagePicker, animated: true, completion: nil)
        }
    }

    func importPicture() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
        imagePicker.modalPresentationStyle = .overFullScreen
        present(imagePicker, animated: true, completion: nil)
    }

    // MARK: - Delegates

    func imagePickerController(_: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController
                                .InfoKey: Any]) {
        var image: UIImage?

        if let img = info[.editedImage] as? UIImage {
            image = img

        } else if let img = info[.originalImage] as? UIImage {
            image = img
        }

        guard let avatar = image?.resizeProfileImage() else { return }
        model.updateImage(avatar)
        profileImageView.image = avatar
        dismiss(animated: true, completion: nil)
    }
}
