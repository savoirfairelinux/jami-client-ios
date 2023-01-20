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
    let callback: Callback? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil)
        controller.completionWithItemsHandler = callback
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var fileURL: URL

    func makeCoordinator() -> DocumentPickerCoordinator {
        return DocumentPickerCoordinator(fileURL: $fileURL)
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
    @Binding var fileURL: URL

    init(fileURL: Binding<URL>) {
        _fileURL = fileURL
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        fileURL = url
    }
}

struct LogUI: View {
    @StateObject var model: LogUIViewModel
    @SwiftUI.State private var filePath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @SwiftUI.State private var showButtons = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                if showButtons {
                    actions()
                }
                List {
                    ForEach(model.logEntries) { log in
                        if #available(iOS 15.0, *) {
                            Text(log.content)
                                .font(model.font)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, -5)
                        } else {
                            Text(log.content)
                                .font(.footnote)
                                .padding(.vertical, -5)
                        }
                    }
                    .flipped()
                }
                .flipped()
                .onAppear {
                    model.isViewDisplayed = true
                }
                .onDisappear {
                    model.isViewDisplayed = false
                }
                // .listRowInsets(EdgeInsets())
                .background(Color(UIColor.systemBackground))
                .listStyle(.plain)
            }
            Button {
                model.triggerLog()
            } label: {
                Text(model.buttonTitle)
                    .font(.system(size: 18))
                    .padding()
                    .foregroundColor(.white)
            }
            .swarmButtonStyle()
        }
        .sheet(isPresented: $model.showPicker) {
            DocumentPicker(fileURL: $filePath)
        }
        .sheet(isPresented: $model.showShare) {
            ShareSheet(activityItems: [model.shareFileURL!])
        }
        .alert(isPresented: $model.showErrorAlert) {
            Alert(
                title: Text(model.errorText),
                dismissButton: .default(Text(L10n.Global.ok))
            )
        }
        .onChange(of: model.editButtonsVisible, perform: { newValue in
            withAnimation {
                showButtons = newValue
            }
        })
        .onChange(of: filePath) { _ in
            model.saveLogTo(path: filePath)
        }
    }

    func actions() -> some View {
        return HStack {
            Button {
                model.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .resizable()
                    .menuItemStyle()
            }
            .frame(width: 50, height: 50)
            Spacer()
            Button {
                model.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .resizable()
                    .menuItemStyle()
            }
            .frame(width: 50, height: 50)
            Spacer()
            Button {
                model.clearLog()
            } label: {
                Image(systemName: "trash")
                    .resizable()
                    .menuItemStyle()
            }
            .frame(width: 50, height: 50)
            Spacer()
            Button {
                model.copy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .resizable()
                    .menuItemStyle()
            }
            .frame(width: 50, height: 50)
        }
        .background(Color(UIColor.systemBackground))
        .frame(maxWidth: .infinity)
    }
}
