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
                                                            closeAction: { [weak self] in
                                                                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                                                                print("======CLOSEDSHEET") // For manual close
                                                            }
                                                        )
        )

        addChild(hostingController)
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("======CLOSEDSHEET") // For swipe-down dismiss
    }
}
