import UIKit
import SwiftUI
import Social
import RxSwift

@objc class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let viewModel = ShareViewModel(sharedItems: sharedItems)

        let hostingController = UIHostingController(rootView:
            ShareView(
                items: sharedItems,
                accountList: viewModel.accountList,
                conversationsByAccount: viewModel.conversationsByAccount,
                closeAction: {
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                },
                sendAction: { conversationId, accountId, message, parentId in
                    viewModel.sendMessage(accountId: accountId, conversationId: conversationId, message: message, parentId: parentId)
                },
                sendFileAction: { conversationId, accountId, filePath, fileName, parentId in
                    viewModel.sendFile(accountId: accountId, conversationId: conversationId, filePath: filePath, fileName: fileName, parentId: parentId)
                },
                viewModel: viewModel
            )
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
