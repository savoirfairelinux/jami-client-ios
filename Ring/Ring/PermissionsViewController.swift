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
        case Granted
        case Undetermined
        case Denied
    }

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateSwitchStatus(microphoneSwitch, status: requestMicrophonePermissionStatus())
        self.updateSwitchStatus(cameraSwitch, status: requestCameraPermissionStatus())
        self.updateSwitchStatus(contactSwitch, status: requestContactListPermissionStatus())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Refresh UI with permission status

    func updateSwitchStatus(button: UISwitch, status: Permissions) {
        dispatch_async(dispatch_get_main_queue()) {
            switch status {
            case .Denied:
                button.setOn(true, animated: false)
                button.onTintColor = UIColor.redColor()
            case .Undetermined:
                button.setOn(false, animated: false)
                button.tintColor = UIColor.darkGrayColor()
            case .Granted:
                button.setOn(true, animated: false)
            }
        }

    }

    // MARK: Get permissions status

    func requestMicrophonePermissionStatus() -> Permissions {
        let recordPermission = AVAudioSession.sharedInstance().recordPermission()
        switch recordPermission {
        case AVAudioSessionRecordPermission.Denied:
            return .Denied
        case AVAudioSessionRecordPermission.Undetermined:
            return .Undetermined
        case AVAudioSessionRecordPermission.Granted:
            return .Granted
        default:
            break
        }
        return .Undetermined
    }

    func requestCameraPermissionStatus() -> Permissions {
        let cameraPermission = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch cameraPermission {
        case .Authorized:
            return .Granted
        case .Denied:
            return .Denied
        case .NotDetermined:
            return .Undetermined
        case .Restricted:
            break
        }
        return .Undetermined
    }

    func requestContactListPermissionStatus() -> Permissions {
        if #available(iOS 9.0, *) {
            let status = CNContactStore.authorizationStatusForEntityType(.Contacts)
            switch status {
            case .Authorized:
                return .Granted
            case .Restricted, .Denied:
                return .Denied
            case .NotDetermined:
                return .Undetermined
            }
        } else {
            let status = ABAddressBookGetAuthorizationStatus()
            switch status {
            case .Authorized:
                return .Granted
            case .Restricted, .Denied:
                return .Denied
            case .NotDetermined:
                return .Undetermined
            }
        }

    }

    // MARK: - Switch Actions

    @IBAction func requestMicrophonePermission(sender: UISwitch) {
        let recordPermission = requestMicrophonePermissionStatus()
        switch recordPermission {
        case .Undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                let status = granted ? Permissions.Granted : Permissions.Denied
                self.updateSwitchStatus(sender, status: status)
            })
        default:
            break
        }

    }

    @IBAction func requestCameraPermission(sender: UISwitch) {
        let cameraPermission = requestCameraPermissionStatus()
        switch cameraPermission {
        case .Undetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo,
                completionHandler: { granted in
                    let status = granted ? Permissions.Granted : Permissions.Denied
                    self.updateSwitchStatus(sender, status: status)
            })
        default:
            break
        }

    }

    @IBAction func requestContactListPermission(sender: UISwitch) {
        let contactPermission = requestContactListPermissionStatus()
        switch contactPermission {
        case .Undetermined:
            if #available(iOS 9.0, *) {
                CNContactStore().requestAccessForEntityType(.Contacts, completionHandler: {
                    success, error in
                    let status = success ? Permissions.Granted : Permissions.Denied
                    self.updateSwitchStatus(sender, status: status)
                })
            } else {
                ABAddressBookRequestAccessWithCompletion(nil) { success, error in
                    let status = success ? Permissions.Granted : Permissions.Denied
                    self.updateSwitchStatus(sender, status: status)
                }
            }
        default:
            break
        }

    }
}
