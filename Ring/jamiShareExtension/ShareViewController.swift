import UIKit
import SwiftUI
import Social

@objc class ShareViewController: UIViewController {
    private var adapter: Adapter!
    private var adapterService: AdapterService!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        adapter = Adapter()
        adapter.initDaemon()
        adapter.startDaemon()

        adapterService = AdapterService(withAdapter: adapter)
        
        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []

        let accountList = adapterService.getAccountList()
        var conversationsByAccount = adapterService.getConversationsByAccount()

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
                    self.adapterService.sendSwarmMessage(accountId: accountId, conversationId: conversationId, message: message, parentId: parentId)
                },
                sendFileAction: { conversationId, accountId, filePath, fileName, parentId in
                    self.adapterService.sendSwarmFile(accountId: accountId, conversationId: conversationId, filePath: filePath, fileName: fileName, parentId: parentId)
                }

            )
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
