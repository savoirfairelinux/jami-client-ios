import Foundation
import RxSwift
import RxCocoa
import SwiftUI

class ActiveCallsCoordinator: Coordinator, StateableResponsive {
    func start() {
        let activeCallsViewModel = ActiveCallsViewModel(
            conversationService: injectionBag.conversationsService,
            callService: injectionBag.callService,
            callsProvider: injectionBag.callsProvider
        )
        let activeCallsView = ActiveCallsView(viewModel: activeCallsViewModel)
        let viewController = createHostingVC(activeCallsView)
        viewController.view.backgroundColor = .clear

        // Get the root view controller from the parent coordinator
        if let parentCoordinator = parentCoordinator {
            parentCoordinator.present(viewController: viewController,
                                    withStyle: .overCurrentContext,
                                    withAnimation: true,
                                    disposeBag: self.disposeBag)
        }
    }

    var presentingVC = [String: Bool]()
    
    var rootViewController: UIViewController {
        // Use parent's root view controller if available
        if let parentCoordinator = parentCoordinator {
            return parentCoordinator.rootViewController
        }
        return UIViewController() // Fallback, should never be used
    }
    
    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?
    
    let injectionBag: InjectionBag
    var disposeBag = DisposeBag()
    
    let stateSubject = PublishSubject<State>()
    
    required init(injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
    }
    
    func addLockFlags() {
        // No flags needed for active calls
    }
} 
