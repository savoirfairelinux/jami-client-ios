/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import SwiftUI
import AVFoundation
import ContactsUI

struct ScanView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    let injectionBag: InjectionBag
    typealias UIViewControllerType = ScanViewController

    func makeUIViewController(context: Context) -> ScanViewController {
        let viewController = ScanViewController.instantiate(with: self.injectionBag)
        viewController.onCodeScanned = onCodeScanned
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScanViewController, context: Context) {
    }

    static func dismantleUIViewController(_ uiViewController: ScanViewController, coordinator: ()) {
    }
}

struct ContactPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onSelectContact: (String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onSelectContact: onSelectContact)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        var onSelectContact: (String) -> Void

        init(_ parent: ContactPicker, onSelectContact: @escaping (String) -> Void) {
            self.parent = parent
            self.onSelectContact = onSelectContact
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
            if phoneNumbers.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    // No numbers available
                    let alert = UIAlertController(title: L10n.Smartlist.noNumber,
                                                  message: nil,
                                                  preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: L10n.Global.ok,
                                                     style: .default) { (_: UIAlertAction!) -> Void in }
                    alert.addAction(cancelAction)
                    if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                        rootViewController.present(alert, animated: true, completion: nil)
                    }
                    self?.parent.presentationMode.wrappedValue.dismiss()
                }
            } else if phoneNumbers.count == 1 {
                DispatchQueue.main.async { [weak self] in
                    self?.onSelectContact(phoneNumbers[0])
                }
            } else {
                self.presentNumberSelection(from: picker, with: phoneNumbers)
            }
        }

        private func presentNumberSelection(from picker: UIViewController, with numbers: [String]) {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: L10n.Smartlist.selectOneNumber, message: nil, preferredStyle: .alert)
                numbers.forEach { number in
                    alert.addAction(UIAlertAction(title: number, style: .default, handler: { _ in
                        DispatchQueue.main.async {
                            self.onSelectContact(number)
                        }
                    }))
                }
                alert.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel, handler: nil))
                if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                    rootViewController.present(alert, animated: true, completion: nil)
                }
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

