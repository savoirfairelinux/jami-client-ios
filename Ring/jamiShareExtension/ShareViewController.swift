import UIKit
import SwiftUI
import Social
import RxSwift

@objc class ShareViewController: UIViewController {
    private var viewModel: ShareViewModel!  // <-- declare property

    override func viewDidLoad() {
        super.viewDidLoad()

        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        viewModel = ShareViewModel(sharedItems: sharedItems)  // <-- set property

        let hostingController = UIHostingController(rootView:
            ShareView(
                items: sharedItems,
                viewModel: viewModel,
                closeAction: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    print("======CLOSEDSHEET")
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
        viewModel.closeShareExtension()
    }
}
