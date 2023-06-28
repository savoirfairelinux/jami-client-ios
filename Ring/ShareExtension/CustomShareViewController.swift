/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

@objc(ShareExtensionViewController)
class CustomShareViewController: UIViewController {

    private let daemonService = ShareAdapterService(withAdapter: ShareAdapter())

    override func viewDidLoad() {
        super.viewDidLoad()

        self.handleSharedFile()
    }

    private func handleSharedFile() {
        // extracting the path to the URL that is being shared
        let attachments = (self.extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []
        let types: [String] = [UTType.data.identifier, UTType.audio.identifier, UTType.movie.identifier, UTType.item.identifier]
        for provider in attachments {
            for type in types {
                // Check if the content type is the same as we expected
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadItem(forTypeIdentifier: type,
                                      options: nil) { [unowned self] (data, error) in
                        // Handle the error here if you want
                        guard error == nil else { return }

                        if let url = data as? URL,
                           let fileData = try? Data(contentsOf: url) {
                            // Use a switch statement to handle each type of file differently
                            switch type {
                            case UTType.data.identifier:
                                print("Received data file with size \(fileData.count) bytes")
                            // Handle data file here
                            case UTType.audio.identifier:
                                print("Received audio file with size \(fileData.count) bytes")
                            // Handle audio file here
                            case UTType.movie.identifier:
                                print("Received video file with size \(fileData.count) bytes")
                            // Handle video file here
                            case UTType.item.identifier:
                                print("Received generic file with size \(fileData.count) bytes")
                            // Handle generic file here
                            default:
                                break
                            }
                        } else {
                            // Handle this situation as you prefer
                            fatalError("Impossible to save file")
                        }
                    }
                }
            }
        }
    }

    func startDaemon() {

    }
}
