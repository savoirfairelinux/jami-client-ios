/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import UIKit
import RxSwift
import SwiftUI
import Combine

final class CallScreenPresenter {

    private let callService: CallService
    private let injectionBag: InjectionBag
    private weak var navigationController: UINavigationController?
    private let disposeBag = DisposeBag()

    var onOpenConversation: ((CallConversationRoute) -> Void)?

    private var callController: UIViewController?
    private var model: CallViewModel?
    private var dismissCancellable: AnyCancellable?
    private var isMinimized = false
    private var pendingDismissal = false
    private var inCallDeviceStateActive = false

    init(callService: CallService, navigationController: UINavigationController,
         injectionBag: InjectionBag) {
        self.callService = callService
        self.injectionBag = injectionBag
        self.navigationController = navigationController
        subscribeToPresentation()
    }

    private func subscribeToPresentation() {
        guard let manager = injectionBag.callsManager else { return }
        manager.callToPresent
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] call in
                Task { @MainActor in self?.presentCallScreen(for: call) }
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Presentation

    @MainActor
    private func presentCallScreen(for call: CallState) {
        if model?.currentCallId == call.id, callController != nil, !isMinimized {
            return
        }

        let account = injectionBag.accountService.getAccount(fromAccountId: call.accountId)
        let localJamiId = account?.jamiId ?? ""
        let model = CallViewModel(call: call,
                                  callService: callService,
                                  videoService: injectionBag.videoService,
                                  audio: injectionBag.audioService,
                                  profileService: injectionBag.profileService,
                                  nameService: injectionBag.nameService,
                                  isSipAccount: account?.type == .sip,
                                  localJamiId: localJamiId)
        model.onAddParticipant = { [weak self, weak model] in
            Task { @MainActor in
                self?.presentContactPicker(for: model?.currentCallId ?? call.id,
                                           requestedBy: localJamiId)
            }
        }
        model.onMinimize = { [weak self] route in
            Task { @MainActor in
                self?.minimizeCallScreen(for: route)
            }
        }
        model.onRestore = { [weak self] completion in
            guard let self = self else {
                completion(false)
                return
            }
            Task { @MainActor in
                self.restoreCallScreen(completion: completion)
            }
        }
        let view = CallScreenView(model: model)
        let controller = UIHostingController(rootView: view)
        controller.modalPresentationStyle = .overFullScreen

        let present = { [weak self] in
            guard let self = self, let top = self.topController() else { return }
            top.present(controller, animated: false) { [weak self, weak controller] in
                guard let self = self, let controller = controller else { return }
                self.drainPendingDismissal(controller)
            }
            self.callController = controller
            self.pendingDismissal = false
            self.isMinimized = false
            self.model = model
            self.dismissCancellable = model.$shouldDismiss
                .filter { $0 }
                .sink { [weak self, weak controller] _ in
                    Task { @MainActor in self?.dismissCallScreen(controller) }
                }
            self.setInCallDeviceState(active: true)
        }

        if let existing = callController, !isMinimized {
            existing.dismiss(animated: false, completion: present)
            callController = nil
        } else {
            callController = nil
            isMinimized = false
            present()
        }
    }

    // MARK: - Picture in picture

    @MainActor
    private func minimizeCallScreen(for route: CallConversationRoute) {
        guard let controller = callController, !isMinimized else { return }
        isMinimized = true
        controller.dismiss(animated: false) { [weak self, weak controller] in
            guard let self = self, let controller = controller,
                  self.callController === controller, self.isMinimized else { return }
            self.onOpenConversation?(route)
        }
    }

    @MainActor
    private func restoreCallScreen(completion: @escaping PiPRestoreCompletion) {
        guard let controller = callController else {
            completion(false)
            return
        }
        guard isMinimized else {
            completion(true)
            return
        }
        guard let top = topController() else {
            completion(false)
            return
        }
        top.present(controller, animated: false) { [weak self, weak controller] in
            guard let self = self, let controller = controller,
                  self.callController === controller else {
                completion(false)
                return
            }
            self.isMinimized = false
            completion(true)
            self.drainPendingDismissal(controller)
        }
    }

    @MainActor
    private func deferUntilChildTransitionEnds(_ controller: UIViewController) -> Bool {
        guard let child = controller.presentedViewController,
              child.isBeingPresented || child.isBeingDismissed,
              let coordinator = child.transitionCoordinator else { return false }
        pendingDismissal = true
        let queued = coordinator.animate(alongsideTransition: nil) { [weak self, weak controller] _ in
            guard let controller = controller else { return }
            self?.drainPendingDismissal(controller)
        }
        guard queued else {
            pendingDismissal = false
            return false
        }
        return true
    }

    @MainActor
    private func drainPendingDismissal(_ controller: UIViewController) {
        guard pendingDismissal else { return }
        pendingDismissal = false
        dismissCallScreen(controller)
    }

    @MainActor
    private func dismissCallScreen(_ controller: UIViewController?) {
        guard let controller = controller, controller === callController else { return }
        guard !controller.isBeingPresented else {
            pendingDismissal = true
            return
        }
        guard !deferUntilChildTransitionEnds(controller) else { return }
        guard !isMinimized else {
            clearCallScreenState(controller)
            return
        }
        (controller.presentingViewController ?? controller)
            .dismiss(animated: false) { [weak self, weak controller] in
                guard let controller = controller else { return }
                self?.clearCallScreenState(controller)
            }
    }

    @MainActor
    private func clearCallScreenState(_ controller: UIViewController) {
        guard controller === callController else { return }
        setInCallDeviceState(active: false)
        callController = nil
        model = nil
        dismissCancellable = nil
        isMinimized = false
    }

    // MARK: - Add participant

    @MainActor
    private func presentContactPicker(for callId: CallId, requestedBy localJamiId: String) {
        guard let host = callController, !isMinimized else { return }
        let viewModel = ContactPickerViewModel(with: injectionBag)
        viewModel.type = .forCall
        viewModel.currentCallId = callId.raw
        viewModel.contactSelectedCB = { [weak self, weak host] items in
            guard let self = self,
                  let contact = items.first?.contacts.first else { return }
            self.callService.addParticipant(uri: contact.uri, toCall: callId,
                                            requestedBy: localJamiId)
            Task { @MainActor in
                host?.presentedViewController?.dismiss(animated: true)
            }
        }
        viewModel.bind()
        let picker = UIHostingController(rootView: ContactPickerView(
                                            viewModel: viewModel, onDismissed: nil))
        host.present(picker, animated: true)
    }

    // MARK: - Device state

    @MainActor
    private func setInCallDeviceState(active: Bool) {
        guard active != inCallDeviceStateActive else { return }
        inCallDeviceStateActive = active
        UIApplication.shared.isIdleTimerDisabled = active
        UIDevice.current.isProximityMonitoringEnabled = active
    }

    @MainActor
    private func topController() -> UIViewController? {
        guard let root = navigationController else { return nil }
        var controller: UIViewController = root
        while let presented = controller.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}

struct CallConversationRoute: Equatable {
    let conversationId: String?
    let peerUri: String
    let accountId: String

    init(conversationId: String?, peerUri: String, accountId: String) {
        self.conversationId = conversationId
        self.peerUri = peerUri
        self.accountId = accountId
    }

    init?(call: CallState?, conference: ConferenceState?) {
        guard let call = call else { return nil }
        let conferenceConversation = conference?.conversationId
            .flatMap { $0.isEmpty ? nil : $0 }
        let callConversation = call.conversationId
            .flatMap { $0.isEmpty ? nil : $0 }
        self.init(conversationId: conferenceConversation ?? callConversation,
                  peerUri: call.peerUri,
                  accountId: call.accountId)
    }
}
