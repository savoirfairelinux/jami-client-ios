import UIKit
import SwiftUI
import Social
import RxSwift

@objc class ShareViewController: UIViewController {
    private var viewModel: ShareViewModel!  

    override func viewDidLoad() {
        super.viewDidLoad()

        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        viewModel = ShareViewModel(sharedItems: sharedItems)  

        let hostingController = UIHostingController(rootView:
            ShareView(
                items: sharedItems,
                viewModel: viewModel,
                closeAction: { [weak self] in
                    self!.viewModel.closeShareExtension()
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
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
