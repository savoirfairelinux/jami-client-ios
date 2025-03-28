import SwiftUI
import RxSwift

struct ActiveCallsView: View {
    @ObservedObject var viewModel: ActiveCallsViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.activeCallsByAccount.keys.sorted()), id: \.self) { accountId in
                if let calls = viewModel.activeCallsByAccount[accountId], !calls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(accountId)
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(calls, id: \.id) { call in
                            CallRowView(call: call, viewModel: viewModel)
                                .transition(.move(edge: .top))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemGroupedBackground))
            .cornerRadius(10)
            .shadow(radius: 5)
            .padding()
            Spacer()
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: viewModel.activeCallsByAccount)
        .onChange(of: viewModel.activeCallsByAccount) { accounts in
            if accounts.isEmpty || accounts.allSatisfy({ $0.value.isEmpty }) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct CallRowView: View {
    let call: ActiveCall
    @ObservedObject var viewModel: ActiveCallsViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                if let activeViewModel = viewModel.activeViewModelsByAccount[call.accountId],
                   let avatar = activeViewModel.avatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                }

                // Title
                VStack(alignment: .leading) {
                    Text(viewModel.activeViewModelsByAccount[call.accountId]?.title ?? call.uri)
                        .font(.headline)
                    Text("A call is in progress. Do you want to join the call?")
                }
            }
            .padding(.horizontal)

            HStack {
                Spacer()
                // Accept with video
                Button(action: {
                    viewModel.acceptCall(call)
                }) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.jamiColor)
                        .padding()
                }
                Spacer()
                // Accept with audio
                Button(action: {
                    viewModel.acceptAudioCall(call)
                }) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.jamiColor)
                        .padding()
                }
                Spacer()

                // Reject
                Button(action: {
                    viewModel.rejectCall(call)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 26))
                        .foregroundColor(.jamiColor)
                        .padding()
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

class ActiveViewModel: ObservableObject {
    @Published var title = ""
    @Published var avatar: UIImage?

    init(title: String = "", avatar: UIImage? = nil) {
        self.title = title
        self.avatar = avatar
    }
}

class ActiveCallsViewModel: ObservableObject, Stateable {
    @Published var activeCallsByAccount: [String: [ActiveCall]] = [:]
    @Published var activeViewModelsByAccount: [String: ActiveViewModel] = [:]
    private let conversationService: ConversationsService
    private let callService: CallsService
    private let callsProvider: CallsProviderService
    private let accountsService: AccountsService
    private let conversationsSource: ConversationDataSource
    private let disposeBag = DisposeBag()

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    init(injectionBag: InjectionBag, conversationsSource: ConversationDataSource) {
        self.conversationService = injectionBag.conversationsService
        self.callService = injectionBag.callService
        self.callsProvider = injectionBag.callsProvider
        self.accountsService = injectionBag.accountService
        self.conversationsSource = conversationsSource

        // Subscribe to active calls
        callService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] accountCalls in
                guard let self = self else { return }
                self.activeCallsByAccount = accountCalls.mapValues { accountCalls in
                    // Get all conversation IDs for this account
                    let conversationIds = accountCalls.allConversationIds
                    // Get all calls from all conversations, filtering out local device calls
                    return conversationIds.flatMap { conversationId in
                        accountCalls.notIgnoredCalls(for: conversationId)
                            .filter { !$0.isfromLocalDevice }
                    }
                }

                // Update ActiveViewModels for each account
                for (accountId, calls) in self.activeCallsByAccount {
                    if !calls.isEmpty {
                        // Get swarm info from conversationsSource for the first call's conversation
                        if let firstCall = calls.first,
                           let conversation = self.conversationsSource.conversationViewModels.first(where: { $0.conversation?.id == firstCall.conversationId }) {
                            if let swarmInfo = conversation.swarmInfo {
                                // Subscribe to swarm info updates
                                swarmInfo.finalTitle
                                    .subscribe(onNext: { [weak self] title in
                                        if let viewModel = self?.activeViewModelsByAccount[accountId] {
                                            viewModel.title = title
                                        } else {
                                            self?.activeViewModelsByAccount[accountId] = ActiveViewModel(title: title)
                                        }
                                    })
                                    .disposed(by: self.disposeBag)

                                swarmInfo.finalAvatar
                                    .subscribe(onNext: { [weak self] avatar in
                                        if let viewModel = self?.activeViewModelsByAccount[accountId] {
                                            viewModel.avatar = avatar
                                        } else {
                                            self?.activeViewModelsByAccount[accountId] = ActiveViewModel(avatar: avatar)
                                        }
                                    })
                                    .disposed(by: self.disposeBag)

                            }

                        }
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    func acceptCall(_ call: ActiveCall) {
        guard let account = self.accountsService.getAccount(fromAccountId: call.accountId) else { return }
        let uri = "rdv:" + call.conversationId + "/" + call.uri + "/" + call.device
            + "/" + call.id
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: uri, userName: ""))
    }

    func acceptAudioCall(_ call: ActiveCall) {
        guard let account = self.accountsService.getAccount(fromAccountId: call.accountId) else { return }
        let uri = "rdv:" + call.conversationId + "/" + call.uri + "/" + call.device
            + "/" + call.id
        self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: uri, userName: ""))
    }

    func rejectCall(_ call: ActiveCall) {
        self.callService.ignoreCall(call: call)
    }
}
