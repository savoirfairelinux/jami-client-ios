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
    
    func sendSwarmFile(conversationId: String, accountId: String, filePath: String, parentId: String) {
        guard adapter != nil else {
            print("Adapter is not initialized")
            return
        }
        
        adapter.setAccountActive(accountId, active: true)
        adapter.sendSwarmFile(withName: "Demo.txt", accountId: accountId, conversationId: conversationId, withFilePath: filePath, parent: parentId)
        adapter.setAccountActive(accountId, active: false)
        print("*** File sent ***")
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
                sendFileAction: { conversationId, accountId, filePath, parentId in
                    self.sendSwarmFile(conversationId: conversationId, accountId: accountId, filePath: filePath, parentId: parentId)
                }

            )
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
