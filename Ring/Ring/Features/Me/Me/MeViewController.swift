/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

class MeViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, StoryboardBased, ViewModelBased {

    // MARK: - outlets
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var ringIdLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var importButton: UIButton!
    @IBOutlet weak var photoButton: UIButton!

    // MARK: - members
    var viewModel: MeViewModel!
    fileprivate let disposeBag = DisposeBag()

    // MARK: - functions
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L10n.Global.meTabBarTitle
        self.navigationItem.title = L10n.Global.meTabBarTitle
        self.setupUI()
    }

    func setupUI() {

        self.viewModel.userName.asObservable()
            .bind(to: self.nameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.ringId.asObservable()
            .bind(to: self.ringIdLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.image?.asObservable()
            .bind(to: self.profileImageView.rx.image)
            .disposed(by: disposeBag)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(tapGestureRecognizer)

        photoButton.rx.tap.subscribe(onNext: {
            self.takePicture()
        }).disposed(by: self.disposeBag)
        photoButton.backgroundColor = UIColor(white: 1, alpha: 0)

        importButton.rx.tap.subscribe(onNext: {
            self.importPicture()
        }).disposed(by: self.disposeBag)
        importButton.backgroundColor = UIColor(white: 1, alpha: 0)
    }

    func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {

    }

    func takePicture() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera
            imagePicker.cameraDevice = UIImagePickerControllerCameraDevice.front
            imagePicker.allowsEditing = true
            self.present(imagePicker, animated: true, completion: nil)
        }
    }

    func importPicture() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        self.present(imagePicker, animated: true, completion: nil)
    }

    // MARK: - Delegates
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        var image: UIImage!

        if let img = info[UIImagePickerControllerEditedImage] as? UIImage {
            image = img

        } else if let img = info[UIImagePickerControllerOriginalImage] as? UIImage {
            image = img
        }

        image = image.convert(toSize:CGSize(width:100.0, height:100.0), scale: UIScreen.main.scale)
        self.viewModel.saveProfile(withImage: image)
        profileImageView.contentMode = .scaleAspectFit
        profileImageView.image = image.circleMasked
        dismiss(animated:true, completion: nil)
    }

    // MARK: - QRCode
//    func createQRFromString(_ str: String) {
//
//        let data = str.data(using: String.Encoding.isoLatin1, allowLossyConversion: false)
//
//        let filter = CIFilter(name: "CIQRCodeGenerator")
//        filter!.setValue(data, forKey: "inputMessage")
//
//        let qrImage: CIImage = filter!.outputImage!
//
//        let scaleX = qrImageView.frame.size.width / qrImage.extent.size.width
//        let scaleY = qrImageView.frame.size.height / qrImage.extent.size.height
//
//        let resultQrImage = qrImage.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
//        qrImageView.image = UIImage(ciImage: resultQrImage)
//    }

}
