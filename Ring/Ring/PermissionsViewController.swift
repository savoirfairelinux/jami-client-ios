/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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
import AVFoundation
import Contacts
import AddressBook

class PermissionsViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet weak var microphoneSwitch: UISwitch!
    @IBOutlet weak var cameraSwitch: UISwitch!
    @IBOutlet weak var contactSwitch: UISwitch!

    enum Permissions {
        case granted
        case undetermined
        case denied
    }

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        updateAllSwitch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Refresh UI with permission status

    func updateAllSwitch() {
        updateSwitchStatus(microphoneSwitch, status: requestMicrophonePermissionStatus())
        updateSwitchStatus(cameraSwitch, status: requestCameraPermissionStatus())
        updateSwitchStatus(contactSwitch, status: requestContactListPermissionStatus())
    }

    func updateSwitchStatus(_ button: UISwitch, status: Permissions) {
        DispatchQueue.main.async {
            switch status {
            case .denied:
                button.setOn(false, animated: false)
                button.tintColor = UIColor.red
            case .undetermined:
                button.setOn(false, animated: false)
                button.tintColor = UIColor.darkGray
            case .granted:
                button.setOn(true, animated: false)
            }
        }
    }

    // MARK: - Handle denied permissions

    func showAlertDeniedPermissions(_ button: UISwitch, permissionName: String) {
        updateSwitchStatus(button, status: .denied)
        let alertController = UIAlertController(title: "Permission for was denied.",
            message: "Please enable access to in the Settings app",
            preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK",
            style: .cancel,
            handler: nil))
        alertController.addAction(UIAlertAction(title: "Show me",
            style: .default,
            handler: { action in
                self.goToApplicationsSettings()
            }))
        self.present(alertController, animated: true, completion: nil)
    }

    func goToApplicationsSettings() {
        let settingsUrl = URL(string: UIApplicationOpenSettingsURLString)
        UIApplication.shared.openURL(settingsUrl! as URL)
    }

    // MARK: - Get permissions status

    func requestMicrophonePermissionStatus() -> Permissions {
        let recordPermission = AVAudioSession.sharedInstance().recordPermission()
        switch recordPermission {
        case AVAudioSessionRecordPermission.denied:
            return .denied
        case AVAudioSessionRecordPermission.undetermined:
            return .undetermined
        case AVAudioSessionRecordPermission.granted:
            return .granted
        default:
            break
        }
        return .undetermined
    }

    func requestCameraPermissionStatus() -> Permissions {
        let cameraPermission = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        switch cameraPermission {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .undetermined
        case .restricted:
            break
        }
        return .undetermined
    }

    func requestContactListPermissionStatus() -> Permissions {
        if #available(iOS 9.0, *) {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            switch status {
            case .authorized:
                return .granted
            case .restricted, .denied:
                return .denied
            case .notDetermined:
                return .undetermined
            }
        } else {
            let status = ABAddressBookGetAuthorizationStatus()
            switch status {
            case .authorized:
                return .granted
            case .restricted, .denied:
                return .denied
            case .notDetermined:
                return .undetermined
            }
        }

    }

    // MARK: - Switch Actions

    @IBAction func requestMicrophonePermission(_ sender: UISwitch) {
        let recordPermission = requestMicrophonePermissionStatus()
        switch recordPermission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                let status = granted ? Permissions.granted : Permissions.denied
                self.updateSwitchStatus(sender, status: status)
            })
        case .denied:
            showAlertDeniedPermissions(sender, permissionName: "Microphone")
        default:
            break
        }
    }

    @IBAction func requestCameraPermission(_ sender: UISwitch) {
        let cameraPermission = requestCameraPermissionStatus()
        switch cameraPermission {
        case .undetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo,
                completionHandler: { granted in
                    let status = granted ? Permissions.granted : Permissions.denied
                    self.updateSwitchStatus(sender, status: status)
            })
        case .denied:
            showAlertDeniedPermissions(sender, permissionName: "Camera")
        default:
            break
        }
    }

    @IBAction func requestContactListPermission(_ sender: UISwitch) {
        let contactPermission = requestContactListPermissionStatus()
        switch contactPermission {
        case .undetermined:
            if #available(iOS 9.0, *) {
                CNContactStore().requestAccess(for: .contacts, completionHandler: {
                    success, error in
                    let status = success ? Permissions.granted : Permissions.denied
                    self.updateSwitchStatus(sender, status: status)
                })
            } else {
                ABAddressBookRequestAccessWithCompletion(nil) { success, error in
                    let status = success ? Permissions.granted : Permissions.denied
                    self.updateSwitchStatus(sender, status: status)
                }
            }
        case .denied:
            showAlertDeniedPermissions(sender, permissionName: "Contact List")
        default:
            break
        }
    }
}
