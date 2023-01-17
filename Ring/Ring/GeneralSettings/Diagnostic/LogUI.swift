/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void

    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
struct DocumentPicker: UIViewControllerRepresentable {

    @Binding var fileContent: URL

    func makeCoordinator() -> DocumentPickerCoordinator {
        return DocumentPickerCoordinator(fileContent: $fileContent)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
        let controller: UIDocumentPickerViewController
        controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<DocumentPicker>) {
    }
}

class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {

    @Binding var fileContent: URL

    init(fileContent: Binding<URL>) {
        _fileContent = fileContent
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        fileContent = url
    }
}

struct LogUI: View {
    @StateObject var model: LogUIViewModel
    @SwiftUI.State private var filePath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                Text("")
                Spacer()
            }
            Button(action: {
                model.triggerLog()
            }) {
                Text("Start Logging")
                    .font(.system(size: 18))
                    .padding()
                    .foregroundColor(.white)
            }
            .swarmButtonStyle()
        }
        .sheet(isPresented: $model.showPicker) {
            DocumentPicker(fileContent: $filePath)
        }
        .sheet(isPresented: $model.showShare) {
            ShareSheet(activityItems: [model.shareFileURL!])
        }
        .alert(isPresented: $model.showErrorAlert) {
            Alert(
                title: Text(model.errorText),
                dismissButton: .default(Text("Ok"))
            )
        }

        .onChange(of: filePath) { _ in
            model.saveLogTo(path: filePath)
        }

    }
}
