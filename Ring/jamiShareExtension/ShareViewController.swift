import UIKit
import SwiftUI
import Social

@objc class ShareViewController: UIViewController {
    private var adapter: Adapter!

    func sendSwarmMessage(conversationId: String, accountId: String, message: String, parentId: String) {
        guard adapter != nil else {
            print("Adapter is not initialized")
            return
        }
        
        adapter.setAccountActive(accountId, active: true)
        adapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
        adapter.setAccountActive(accountId, active: false)
        print("*** Message sent ***")
    }
    
    func sendSwarmFile(conversationId: String, accountId: String, filePath: String, fileName: String, parentId: String) {
        guard let adapter = adapter else {
            print("Adapter is not initialized")
            return
        }

        let cleanedPath = filePath.replacingOccurrences(of: "file://", with: "")
        let fileManager = FileManager.default

        // Create a destination path in the temporary directory
        let tempDirectory = NSTemporaryDirectory()
        let duplicatedFilePath = (tempDirectory as NSString).appendingPathComponent(fileName)

        do {
            // Remove existing file if it already exists
            if fileManager.fileExists(atPath: duplicatedFilePath) {
                try fileManager.removeItem(atPath: duplicatedFilePath)
            }

            // Copy the original file to the temporary location
            try fileManager.copyItem(atPath: cleanedPath, toPath: duplicatedFilePath)

            // Proceed to send the duplicated file
            adapter.setAccountActive(accountId, active: true)
            adapter.sendSwarmFile(withName: fileName, accountId: accountId, conversationId: conversationId, withFilePath: duplicatedFilePath, parent: parentId)
            adapter.setAccountActive(accountId, active: false)

            print("*** File duplicated and sent successfully ***")

        } catch {
            print("Error duplicating file: \(error.localizedDescription)")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        adapter = Adapter()
        adapter.initDaemon()
        adapter.startDaemon()

        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []

        let accountList = adapter.getAccountList() as? [String] ?? []

        var conversationsByAccount: [String: [String]] = [:]
        for accountId in accountList {
            let conversations = adapter.getSwarmConversations(forAccount: accountId) as? [String] ?? []
            conversationsByAccount[accountId] = conversations
        }

        let hostingController = UIHostingController(rootView:
            ShareView(
                items: sharedItems,
                accountList: accountList,
                conversationsByAccount: conversationsByAccount,
                closeAction: {
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                },
                sendAction: { conversationId, accountId, message, parentId in
                    self.sendSwarmMessage(conversationId: conversationId, accountId: accountId, message: message, parentId: parentId)
                },
                sendFileAction: { conversationId, accountId, filePath, fileName, parentId in
                    self.sendSwarmFile(conversationId: conversationId, accountId: accountId, filePath: filePath, fileName: fileName, parentId: parentId)
                }

            )
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
