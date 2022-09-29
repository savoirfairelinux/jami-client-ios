//
//  MessageContentModel.swift
//  Ring
//
//  Created by kateryna on 2022-09-27.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI

enum TransferAction: Identifiable {
    var id: Self { self }

    case accept
    case refuse
    case cancel

    func toString() -> String {
        switch self {
        case .accept:
            return "Accept"
        case .refuse:
            return "Refuse"
        case .cancel:
            return "Cancel"

        }
    }

}

class MessageContentModel: ObservableObject {
    // published properties
    @Published var content = "" {
        didSet {
            self.transferData = updateTransferData()
        }
    }

    @Published var image: UIImage?// UIImage(asset: Asset.fallbackAvatar)
    // @Published var image: UIImage? = UIImage(asset: Asset.fallbackAvatar)
    @Published var fileName: String = "file.txt"
    @Published var fileInfo: String = "45Mb"
    @Published var fileProgress: CGFloat = 0
    // @Published var transferActions = [TransferAction]()
    @Published var transferActions = [TransferAction.accept, TransferAction.refuse]
    @Published var showProgress: Bool = true

    var textFont: Font = .body

    var isIncoming: Bool
    var isHistory: Bool

    // view parameters
    var borderColor: Color
    var backgroundColor: Color
    var textColor: Color
    var hasBorder: Bool
    var corners: UIRectCorner = .allCorners
    let cornerRadius: CGFloat = 15
    var textInset: CGFloat = 15
    var type: MessageType = .fileTransfer
    var fileSize = "45Mb"
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

    init(isIncoming: Bool, isHistory: Bool, type: MessageType) {
        self.type = type
        self.isIncoming = isIncoming
        self.isHistory = isHistory
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
    }

    convenience init(message: MessageModel, sequensing: MessageSequencing) {
        self.init(isIncoming: message.incoming, isHistory: false, type: message.type)
        self.content = message.content
        if self.content.containsOnlyEmoji {
            self.backgroundColor = .clear
            self.textFont = Font(UIFont.systemFont(ofSize: 40.0, weight: UIFont.Weight.medium))
            self.textInset = 0
        }
        self.sequencing = sequensing
    }

    convenience init() {
        self.init(isIncoming: true, isHistory: false, type: .fileTransfer)
    }

    func setSequencing(sequencing: MessageSequencing) {
        // print("&&&&&&&&set sequensing: \(sequencing)")
        if self.sequencing != sequencing {
            // print("&&&&&&&&set sequensing: \(sequencing)")
            self.sequencing = sequencing
        }
    }

    func setTransferStatus(transferStatus: DataTransferStatus) {
        if self.transferStatus != transferStatus {
            self.transferStatus = transferStatus
        }
        // self.updateFileInfo()
        self.updateTransferActions()
    }

    private func updateTransferActions() {
        //                switch self.transferStatus {
        //                    case .created
        //                }

    }

    private func updateFileInfo() {
        self.fileInfo = self.fileSize + " " + self.transferStatus.description
    }

    typealias FileData = (name: String, size: String?, identifier: String?)

    func updateTransferData() -> FileData {
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
        return (name, size, identifier)
    }

    var transferData: FileData?

    func transferAction(action: TransferAction) {

    }

}
