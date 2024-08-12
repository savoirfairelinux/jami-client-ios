//
//  SwiftUIView.swift
//  Ring
//
//  Created by kateryna on 2024-08-15.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var fileURL: URL?
    var type: UTType

    func makeCoordinator() -> DocumentPickerCoordinator {
        return DocumentPickerCoordinator(fileURL: $fileURL)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
        let controller =
        UIDocumentPickerViewController(forOpeningContentTypes: [type])
        controller.allowsMultipleSelection = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
        @Binding var fileURL: URL?

        init(fileURL: Binding<URL?>) {
            _fileURL = fileURL
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            fileURL = url
        }
    }
}
