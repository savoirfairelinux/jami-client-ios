import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    private let appGroupIdentifier = "group.com.savoirfairelinux.ring"
    private let server = ""
    private let targetConversationId = ""
    private let targetAccountId: String = ""

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // Save the shared item to the app group and trigger the background push
        self.handleShareAndNotify()
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}

// MARK: - Private helpers
extension ShareViewController {
    private func handleShareAndNotify() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            self.complete()
            return
        }

        let uploadsDir = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("ShareUploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: uploadsDir, withIntermediateDirectories: true, attributes: nil)

        let items = (self.extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var processed = false
        for item in items where !processed {
            guard let providers = item.attachments else { continue }
            for provider in providers where !processed {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                        guard let self = self else { return }
                        if let url = item as? URL {
                            self.persistFile(fromURL: url, uploadsDir: uploadsDir)
                        } else {
                            self.complete()
                        }
                    }
                    processed = true
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                        guard let self = self else { return }
                        if let url = item as? URL {
                            self.persistFile(fromURL: url, uploadsDir: uploadsDir)
                        } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                            let filename = "shared-image-\(Int(Date().timeIntervalSince1970)).jpg"
                            self.persistData(data: data, suggestedName: filename, uploadsDir: uploadsDir)
                        } else {
                            self.complete()
                        }
                    }
                    processed = true
                } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] item, _ in
                        guard let self = self else { return }
                        if let url = item as? URL {
                            self.persistFile(fromURL: url, uploadsDir: uploadsDir)
                        } else if let data = item as? Data {
                            let filename = "shared-data-\(Int(Date().timeIntervalSince1970)).bin"
                            self.persistData(data: data, suggestedName: filename, uploadsDir: uploadsDir)
                        } else {
                            self.complete()
                        }
                    }
                    processed = true
                }
            }
        }

        if !processed {
            self.complete()
        }
    }

    private func persistFile(fromURL sourceURL: URL, uploadsDir: URL) {
        let originalName = sourceURL.lastPathComponent
        let destinationURL = uniqueDestination(for: originalName, in: uploadsDir)
        do {
            if sourceURL.isFileURL, FileManager.default.isReadableFile(atPath: sourceURL.path) {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } else {
                let data = try Data(contentsOf: sourceURL)
                try data.write(to: destinationURL, options: .atomic)
            }
            self.enqueuePendingShare(fileURL: destinationURL, displayName: originalName)
        } catch {
            self.complete()
        }
    }

    private func persistData(data: Data, suggestedName: String, uploadsDir: URL) {
        let destinationURL = uniqueDestination(for: suggestedName, in: uploadsDir)
        do {
            try data.write(to: destinationURL, options: .atomic)
            self.enqueuePendingShare(fileURL: destinationURL, displayName: suggestedName)
        } catch {
            self.complete()
        }
    }

    private func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(fileName)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    private func enqueuePendingShare(fileURL: URL, displayName: String) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        var pending = defaults?.array(forKey: "pendingShares") as? [[String: String]] ?? []
        var entry: [String: String] = [:]
        entry["filePath"] = fileURL.path
        entry["fileName"] = displayName
        entry["conversationId"] = targetConversationId
        entry["accountId"] = targetAccountId
        entry["createdAt"] = ISO8601DateFormatter().string(from: Date())
        pending.append(entry)
        defaults?.set(pending, forKey: "pendingShares")

        guard let apnsToken = defaults?.string(forKey: "APNsToken"),
              let topic = defaults?.string(forKey: "APNsTopic"),
              !apnsToken.isEmpty, !topic.isEmpty else {
            self.complete()
            return
        }
        self.dev_triggerGorush(token: apnsToken, topic: topic)
        self.complete()
    }

    private func complete() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func dev_triggerGorush(token: String, topic: String) {

        guard let url = URL(string: "http://\(server):8088/api/push") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "notifications": [[
                "platform": 1,
                "tokens": [token],
                "topic": topic,
                "push_type": "background",
                "message": "",
                "data": ["type": "share-start"],
                "content_available": true,
                "priority": "normal",
                "production": false
            ]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }
}
