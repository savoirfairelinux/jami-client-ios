//
//  PermissionsViewController.swift
//  Ring
//
//  Created by Edric on 16-08-01.
//  Copyright © 2016 Savoir-faire Linux. All rights reserved.
//

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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateSwitchStatus(microphoneSwitch, status: requestMicrophonePermissionStatus())
        self.updateSwitchStatus(cameraSwitch, status: requestCameraPermissionStatus())
        self.updateSwitchStatus(contactSwitch, status: requestContactListPermissionStatus())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Refresh permission status function

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

    // MARK: - Switch Action

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
