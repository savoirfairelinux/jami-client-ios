import SwiftUI
import RxSwift

struct ActiveCallsView: View {
    @ObservedObject var viewModel: ActiveCallsViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.activeCalls, id: \.id) { call in
                CallBannerView(call: call, viewModel: viewModel)
                    .transition(.move(edge: .top))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: viewModel.activeCalls)
        .onChange(of: viewModel.activeCalls) { calls in
            if calls.isEmpty {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct CallBannerView: View {
    let call: ActiveCall
    @ObservedObject var viewModel: ActiveCallsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(call.uri)
                    .font(.headline)
                Text("Incoming call")
                    .font(.subheadline)
            }

            Spacer()

            HStack(spacing: 20) {
                Button(action: {
                    viewModel.acceptCall(call)
                }) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.green)
                }

                Button(action: {
                    viewModel.rejectCall(call)
                }) {
                    Image(systemName: "phone.down.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}

class ActiveCallsViewModel: ObservableObject {
    @Published var activeCalls: [ActiveCall] = []
    private let conversationService: ConversationsService
    private let callService: CallsService
    private let callsProvider: CallsProviderService
    private let disposeBag = DisposeBag()

    init(conversationService: ConversationsService, callService: CallsService, callsProvider: CallsProviderService) {
        self.conversationService = conversationService
        self.callService = callService
        self.callsProvider = callsProvider

        // Subscribe to active calls
        conversationService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] calls in
                self?.activeCalls = Array(calls.values)
            })
            .disposed(by: disposeBag)
    }

    func acceptCall(_ call: ActiveCall) {
        // Implement call acceptance logic
    }

    func rejectCall(_ call: ActiveCall) {
        // Implement call rejection logic
    }
}
