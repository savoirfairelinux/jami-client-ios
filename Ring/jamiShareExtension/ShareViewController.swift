import UIKit
import SwiftUI
import Social
import RxSwift

@objc class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []

        let hostingController = UIHostingController(rootView:
            ShareView(
                items: sharedItems,
                closeAction: {
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                } 
            )
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}
