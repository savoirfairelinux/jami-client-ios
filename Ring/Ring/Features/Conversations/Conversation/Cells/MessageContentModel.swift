//
//  MessageContentModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-27.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI
import RxSwift

enum TransferAction: Identifiable {
    var id: Self { self }

    case accept
    case cancel

    func toString() -> String {
        switch self {
        case .accept:
            return "Accept"
        case .cancel:
            return "Cancel"

        }
    }
}

class MessageContentModel: ObservableObject, MessageBased {

    // published properties
    @Published var content = "" {
        didSet {
            if self.type == .fileTransfer {
                self.updateTransferData()
            }
        }
    }
    @Published var image: UIImage?
    @Published var fileName: String = ""
    @Published var fileInfo: String = ""
    @Published var fileProgress: CGFloat = 0
    @Published var transferActions = [TransferAction]()
    @Published var showProgress: Bool = true

    // view parameters
    var borderColor: Color
    var backgroundColor: Color
    var textColor: Color
    var hasBorder: Bool
    var corners: UIRectCorner = .allCorners
    let cornerRadius: CGFloat = 15
    var textInset: CGFloat = 15
    var textFont: Font = .body

    // MessageBased
    var message: MessageModel

    var stateSubject: PublishSubject<State>

    required init(message: MessageModel, stateSubject: PublishSubject<State>) {
        self.stateSubject = stateSubject
        self.message = message
        self.type = message.type
        self.isIncoming = message.incoming
        self.isHistory = false
        self.content = message.content
        self.transferStatus = message.transferStatus
        if isHistory {
            self.sequencing = .firstOfSequence
            self.borderColor = Color(.secondaryLabel)
            self.textColor = Color(.secondaryLabel)
            self.hasBorder = true
            self.backgroundColor = Color(.white)
        } else {
            self.textColor = isIncoming ? Color(.darkText) : Color(.white)
            self.backgroundColor = isIncoming ? Color(.jamiMsgCellReceived) : Color(.jamiMsgCellSent)
            self.hasBorder = false
            self.borderColor = Color(.clear)
        }
        if self.content.containsOnlyEmoji {
            self.backgroundColor = .clear
            self.textFont = Font(UIFont.systemFont(ofSize: 40.0, weight: UIFont.Weight.medium))
            self.textInset = 0
        }
        if self.type == .fileTransfer {
            self.updateTransferData()
            self.updateTransferActions()
        }
    }
    var player: PlayerViewModel?

    var isIncoming: Bool
    var isHistory: Bool

    var type: MessageType = .fileTransfer
    var fileSize = ""
    var transferStatus: DataTransferStatus = .unknown

    private var sequencing: MessageSequencing = .unknown {
        didSet {
            guard !isHistory else { return }
            guard type == .text else { return }
            switch sequencing {
            case .firstOfSequence:
                self.corners = isIncoming ? [.topLeft, .topRight, .bottomRight] : [.topLeft, .topRight, .bottomLeft]
            case .lastOfSequence:
                self.corners = isIncoming ? [.topRight, .bottomLeft, .bottomRight] : [.topLeft, .bottomLeft, .bottomRight]
            case .middleOfSequence:
                self.corners = isIncoming ? [.topRight, .bottomRight] : [.topLeft, .bottomLeft ]
            case .singleMessage:
                corners = [.allCorners]
            case .unknown:
                break
            }
            // text need to be updated to trigger view redrowing
            let oldContent = self.content
            self.content = oldContent
        }
    }

    func setSequencing(sequencing: MessageSequencing) {
        if self.sequencing != sequencing {
            self.sequencing = sequencing
        }
    }

    func setTransferStatus(transferStatus: DataTransferStatus) {
        if self.transferStatus != transferStatus {
            self.transferStatus = transferStatus
            self.updateTransferActions()
        }
    }

    private func updateTransferActions() {
        DispatchQueue.main.async {
            switch self.transferStatus {
            case .created:
                self.transferActions = [.accept, .cancel]
            case .awaiting:
                self.transferActions = [.accept, .cancel]
            case .ongoing:
                self.transferActions = [.cancel]
            case .success, .error, .unknown, .canceled:
                self.transferActions = [TransferAction]()
            }
            self.showProgress = self.transferStatus == .ongoing ? true : false
            if self.transferStatus == .ongoing {
                self.stopProgressMonitor()
            } else {
                self.stopProgressMonitor()
            }
            self.updateFileInfo()
        }
    }

    private func updateFileInfo() {
        self.fileInfo = self.fileSize + " - " + self.transferStatus.description
    }

    func updateTransferData() {
        let contentArr = self.content.components(separatedBy: "\n")
        var name: String
        var identifier: String?
        var size: String?
        if contentArr.count > 2 {
            name = contentArr[0]
            size = contentArr[1]
            identifier = contentArr[2]
        } else if contentArr.count > 1 {
            name = contentArr[0]
            size = contentArr[1]
        } else {
            name = content
        }
        self.fileName = name
        if let size = size {
            self.fileSize = size + "Mb"
        }
    }

    var dataTransferProgressUpdater: Timer?

    func startProgressMonitor() {
        if self.dataTransferProgressUpdater != nil {
            self.stopProgressMonitor()
            return
        }
        if self.message.incoming {
            self.dataTransferProgressUpdater = Timer
                .scheduledTimer(timeInterval: 0.5,
                                target: self,
                                selector: #selector(self.updateProgressBar),
                                userInfo: nil,
                                repeats: true)
        }
    }

    func stopProgressMonitor() {
        guard let updater = self.dataTransferProgressUpdater else { return }
        updater.invalidate()
        self.dataTransferProgressUpdater = nil
    }

    @objc
    func updateProgressBar(timer: Timer) {
        self.stateSubject.onNext(MessageState.progress(transferId: self.message.daemonId, message: self))

    }

    func transferAction(action: TransferAction) {
        switch action {
        case .accept:
            self.stateSubject.onNext(MessageState.accept(message: self.message))
        case .cancel:
            self.stateSubject.onNext(MessageState.cancel(interactionId: self.message.daemonId))
        }
    }

}
