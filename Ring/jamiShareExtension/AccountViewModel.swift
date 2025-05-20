import RxSwift

class AccountViewModel: ObservableObject, Identifiable, Equatable {
    let id: String
    @Published var name: String
    @Published var avatar: String

    private let adapterService: AdapterService
    private let disposeBag = DisposeBag()

    init(id: String, adapterService: AdapterService, initialName: String = "", initialAvatar: String = "") {
        self.id = id
        self.adapterService = adapterService
        self.name = initialName
        self.avatar = initialAvatar
        fetchAccountDetails()
    }

    static func == (lhs: AccountViewModel, rhs: AccountViewModel) -> Bool {
        lhs.id == rhs.id
    }

    private func fetchAccountDetails() {
        adapterService.resolveLocalAccountDetails(accountId: id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))  
            .observe(on: MainScheduler.instance)                                
            .subscribe(onSuccess: { [weak self] details in
                self?.name = details["accountName"] ?? self?.name ?? ""
                self?.avatar = details["accountAvatar"] ?? self?.avatar ?? ""
            })
            .disposed(by: disposeBag)
    }
}
