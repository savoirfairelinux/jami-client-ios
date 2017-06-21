/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

enum ProfileCreationType {
    case linkDeviceToAccount
    case createProfile
}

class CreateProfileViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var profileCreationType :ProfileCreationType?

    fileprivate let disposeBag = DisposeBag()
    fileprivate let viewModel = CreateProfileViewModel()

    fileprivate let textFieldCellId = "TextFieldCellId"
    fileprivate let textCellId = "TextCellId"
    fileprivate let profileImageCellId = "ProfileImageCellId"

    fileprivate let noticeCellIndex = 0
    fileprivate let profileImageCellIndex = 1
    fileprivate let profileNameFieldCellIndex = 2

    override func viewDidLoad() {
        super.viewDidLoad()

        self.registerCells()
        self.setupUI()
    }

    fileprivate func registerCells() {
        self.tableView.register(UINib.init(nibName: "TextFieldCell", bundle: nil),
                                forCellReuseIdentifier: textFieldCellId)

        self.tableView.register(UINib.init(nibName: "TextCell", bundle: nil),
                                forCellReuseIdentifier: textCellId)

        self.tableView.register(UINib.init(nibName: "ProfileImageCell", bundle: nil),
                                forCellReuseIdentifier: profileImageCellId)
    }

    fileprivate func setupUI() {
        self.tableView.estimatedRowHeight = 44.0
        self.tableView.rowHeight = UITableViewAutomaticDimension
    }

    @IBAction func skip(_ sender: Any) {
        if profileCreationType == .linkDeviceToAccount {
            performSegue(withIdentifier: "ProfileToLinkSegue", sender: sender)
        } else if profileCreationType == .createProfile {
            performSegue(withIdentifier: "ProfileToAccountSegue", sender: sender)
        }
    }

    fileprivate func showCamera() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = .camera
        self.present(picker, animated: true, completion: nil)
    }

    fileprivate func showPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        self.present(picker, animated: true, completion: nil)
    }

    //MARK: TableView delegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.row == noticeCellIndex {

            let cell = tableView.dequeueReusableCell(withIdentifier: textCellId,
                                                     for: indexPath) as! TextCell

            cell.label.textAlignment = .center
            cell.label.text = NSLocalizedString("ProfileNameNotice", tableName: "Walkthrough", comment: "")

            return cell
            
        } else if indexPath.row == profileImageCellIndex {

            let cell = tableView.dequeueReusableCell(withIdentifier: profileImageCellId,
                                                     for: indexPath) as! ProfileImageCell

            //Take Photo button
            cell.takePhotoButton.rx.tap.takeUntil(self.rx.deallocated).subscribe(onNext: { [unowned self] _ in
                self.showCamera()
            }).addDisposableTo(disposeBag)

            //Pick from Library button
            cell.pickFromLibraryButton.rx.tap.takeUntil(self.rx.deallocated).subscribe(onNext: { [unowned self] _ in
                self.showPhotoLibrary()
            }).addDisposableTo(disposeBag)

            return cell
        } else {

            let cell = tableView.dequeueReusableCell(withIdentifier: textFieldCellId,
                                                     for: indexPath) as! TextFieldCell

            cell.textField.placeholder = NSLocalizedString("ProfileNamePlaceholder", tableName: "Walkthrough", comment: "")
            cell.textField.isSecureTextEntry = false

            //Binds the username field value to the ViewModel
            _ = cell.textField.rx.text.orEmpty
                .throttle(textFieldThrottlingDuration, scheduler: MainScheduler.instance)
                .distinctUntilChanged()
                .bind(to: self.viewModel.profileName)
                .addDisposableTo(disposeBag)

            return cell
        }
    }

    //MARK: ImagePicker delegate

    private func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            //TODO: Convert to ARGB8888 base64 string...
        } else{
            print("UIImagePickerController error...")
        }

        self.dismiss(animated: true, completion: nil)
    }
}
