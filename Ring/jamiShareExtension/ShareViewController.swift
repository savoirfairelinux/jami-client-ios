import UIKit
import SwiftUI
import Social

@objc class ShareViewController: UIViewController {
    private var adapter: Adapter!

    // MARK: - Swarm Message Sender
    func sendSwarmMessage(conversationId: String, accountId: String, message: String, parentId: String) {
        print("sendSwarmMessage(\(conversationId.debugDescription), \(accountId.debugDescription), \(message.debugDescription), \(parentId.debugDescription))")
        
        guard adapter != nil else {
            print("Adapter is not initialized")
            return
        }
        
        adapter.setAccountActive(accountId, active: true)
        adapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
        print("*** Message sent ***")
    }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Adapter
        adapter = Adapter()
        adapter.initDaemon()
        adapter.startDaemon()

        print("hi")

        // Get shared items from the extension context
        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []

        // Fetch accounts and their conversations
        let accountList = adapter.getAccountList() as? [String] ?? []

        var conversationsByAccount: [String: [String]] = [:]
        for accountId in accountList {
            let conversations = adapter.getSwarmConversations(forAccount: accountId) as? [String] ?? []
            conversationsByAccount[accountId] = conversations
        }

        // Build and add SwiftUI view
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
                }
            )
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
