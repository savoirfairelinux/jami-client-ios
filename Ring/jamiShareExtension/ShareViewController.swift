import UIKit
import SwiftUI
import Social

@objc class ShareViewController: UIViewController {
    private var adapter: Adapter?

    override func viewDidLoad() {
        super.viewDidLoad()

        adapter = Adapter()

        print("hi")
        
        adapter?.initDaemon()
        adapter?.startDaemon()
        
        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        
        let accountList = adapter?.getAccountList() as? [String] ?? []

        let hostingController = UIHostingController(rootView:
            ShareView(items: sharedItems,
                      accountList: accountList,
                      closeAction: {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            })
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
