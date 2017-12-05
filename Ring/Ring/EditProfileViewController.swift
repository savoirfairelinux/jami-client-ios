/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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
import Reusable
import RxSwift

class EditProfileViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - outlets
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var profileName: UITextField!

    // MARK: - members
    var model: EditProfileViewModel!
    fileprivate let disposeBag = DisposeBag()

    // MARK: - functions

    override func viewDidLoad() {
        super.viewDidLoad()
        self.model = EditProfileViewModel()
        self.setupUI()
    }

    func setupUI() {

        self.model.image.asObservable()
            .bind(to: self.profileImageView.rx.image)
            .disposed(by: disposeBag)

        self.model.profileName.asObservable()
            .bind(to: self.profileName.rx.text)
            .disposed(by: disposeBag)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(tapGestureRecognizer)

        //Binds the keyboard Send button action to the ViewModel
        self.profileName.rx.controlEvent(.editingDidEndOnExit).subscribe(onNext: { [unowned self] _ in
           self.model.updateName(self.profileName.text!)
        }).disposed(by: disposeBag)
    }

    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {

        let alert = UIAlertController.init(title: nil,
                                           message: nil,
                                           preferredStyle: .actionSheet)

        let cameraAction = UIAlertAction(title: L10n.Alerts.profileTakePhoto, style: UIAlertActionStyle.default) { _ in
            self.takePicture()
        }

        let pictureAction = UIAlertAction(title: L10n.Alerts.profileUploadPhoto, style: UIAlertActionStyle.default) { _ in
            self.importPicture()
        }

        let cancelAction = UIAlertAction(title: L10n.Alerts.profileCancelPhoto, style: UIAlertActionStyle.cancel)

        alert.addAction(cameraAction)
        alert.addAction(pictureAction)
        alert.addAction(cancelAction)
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxX, width: 0, height: 0)
        self.present(alert, animated: true, completion: nil)
    }

    func takePicture() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera
            imagePicker.cameraDevice = UIImagePickerControllerCameraDevice.front
            imagePicker.allowsEditing = true
            imagePicker.modalPresentationStyle = .overFullScreen
            self.present(imagePicker, animated: true, completion: nil)
        }
    }

    func importPicture() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        imagePicker.modalPresentationStyle = .overFullScreen
        self.present(imagePicker, animated: true, completion: nil)
    }

    // MARK: - Delegates
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        var image: UIImage!

        if let img = info[UIImagePickerControllerEditedImage] as? UIImage {
            image = img

        } else if let img = info[UIImagePickerControllerOriginalImage] as? UIImage {
            image = img
        }

        image = image.convert(toSize: CGSize(width: 100.0, height: 100.0), scale: UIScreen.main.scale)
        self.model.updateImage(image)
        profileImageView.contentMode = .scaleAspectFit
        profileImageView.image = image.circleMasked
        dismiss(animated: true, completion: nil)
    }

    //hide keyboard when touch outside of text field
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.profileName.resignFirstResponder()
//        self.profileName.text = self.model.profileName.value
//    }
}
