import Foundation
import RxSwift
import RxRelay
import SwiftUI

class CallBannerViewModel: ObservableObject {
    @Published var isVisible = false
    @Published var activeCalls: [ActiveCall] = []

    private let callService: CallsService
    private let conversationService: ConversationsService
    private let profileService: ProfilesService
    private let conversation: ConversationModel
    private let disposeBag = DisposeBag()
    
    init(injectionBag: InjectionBag, conversation: ConversationModel) {
        self.callService = injectionBag.callService
        self.conversationService = injectionBag.conversationsService
        self.profileService = injectionBag.profileService
        self.conversation = conversation
        
        setupCallSubscription()
    }
    
    private func setupCallSubscription() {
        callService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] accountCalls in
                guard let self = self,
                      let accountCalls = accountCalls[self.conversation.accountId] else {
                    self?.isVisible = false
                    self?.activeCalls = []
                    return
                }
                
                let calls = accountCalls.calls(for: self.conversation.id)
                if calls.isEmpty {
                    self.isVisible = false
                    self.activeCalls = []
                } else {
                    self.activeCalls = calls
                    self.isVisible = true
                }
            })
            .disposed(by: disposeBag)
    }
    
    func acceptVideoCall(for call: ActiveCall) {
        callService.accept(callId: call.id)
            .subscribe(onCompleted: { [weak self] in
                self?.isVisible = false
            })
            .disposed(by: disposeBag)
    }
    
    func acceptAudioCall(for call: ActiveCall) {
        callService.accept(callId: call.id)
            .subscribe(onCompleted: { [weak self] in
                self?.isVisible = false
            })
            .disposed(by: disposeBag)
    }
    
    func declineCall(for call: ActiveCall) {
        callService.refuse(callId: call.id)
            .subscribe(onCompleted: { [weak self] in
                self?.isVisible = false
            })
            .disposed(by: disposeBag)
    }
} 
