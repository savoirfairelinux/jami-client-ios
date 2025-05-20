import RxSwift

class ConversationViewModel: ObservableObject, Identifiable, Equatable {
    let id: String
    let accountId: String
    @Published var name: String
    @Published var avatar: String
    @Published var accountType: String

    private let adapterService: AdapterService
    private let disposeBag = DisposeBag()

    init(id: String, accountId: String, adapterService: AdapterService, initialName: String = "", initialAvatar: String = "") {
        self.id = id
        self.accountId = accountId
        self.adapterService = adapterService
        self.name = initialName
        self.avatar = initialAvatar
        self.accountType = initialName
        fetchConversationDetails()
    }

    static func == (lhs: ConversationViewModel, rhs: ConversationViewModel) -> Bool {
        lhs.id == rhs.id && lhs.accountId == rhs.accountId
    }

    private func fetchConversationDetails() {
        adapterService.getConversationInfo(accountId: accountId, conversationId: id)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background)) 
            .observe(on: MainScheduler.instance)                               
            .subscribe(onSuccess: { [weak self] details in
                self?.name = details.name
                self?.avatar = details.avatar ?? ""
                self?.accountType = details.accountType
            })
            .disposed(by: disposeBag)
    }
}
