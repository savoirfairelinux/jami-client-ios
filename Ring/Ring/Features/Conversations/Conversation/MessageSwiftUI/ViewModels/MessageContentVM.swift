/*
 *  Copyright (C) 2017-2022 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import SwiftUI
import RxSwift
import LinkPresentation

enum TransferViewType: Equatable {
    case playerView(player: PlayerViewModel)
    case imageView(image: UIImage)
    case defaultView

    func toString() -> String {
        switch self {
        case .playerView:
            return "playerView"
        case .imageView:
            return "imageView"
        case .defaultView:
            return "defaultView"
        }
    }

    static func == (lhs: TransferViewType, rhs: TransferViewType) -> Bool {
        return lhs.toString() == rhs.toString()
    }
}

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

enum ContextualMenuItem: Identifiable {
    var id: Self { self }

    case preview
    case forward
    case share
    case save
    case copy

    func toString() -> String {
        switch self {
        case .preview:
            return "Preview"
        case .forward:
            return "Forward"
        case .share:
            return "Share"
        case .save:
            return "Save"
        case .copy:
            return "Copy"
        }
    }

    func image() -> String {
        switch self {
        case .preview:
            return "arrow.up.left.and.arrow.down.right"
        case .forward:
            return "arrowshape.turn.up.right"
        case .share:
            return "square.and.arrow.up"
        case .save:
            return "square.and.arrow.down"
        case .copy:
            return "doc.on.doc"
        }
    }
}

class MessageContentVM: ObservableObject, PreviewViewControllerDelegate {

    @Published var content = ""
    @Published var metadata: LPLinkMetadata?

    // file transfer
    @Published var fileName: String = ""
    @Published var fileInfo: String = ""
    @Published var fileProgress: CGFloat = 0
    @Published var transferActions = [TransferAction]()
    @Published var showProgress: Bool = true
    var transferViewType: TransferViewType = .defaultView
    var shouldUpdateTransferView = true
    @Published var playerHeight: CGFloat = 100
    @Published var playerWidth: CGFloat = 250
    var image: UIImage? {
        didSet {
            updaTetransferViewType()
        }
    }
    var player: PlayerViewModel? {
        didSet {
            // self.updaTetransferViewType()
            if player != nil {
                self.player!.delegate = self
                self.updaTetransferViewType()
                // self.showPlayer = true
            }
        }
    }
    var url: URL?
    var fileSize: Int64 = 0
    var transferStatus: DataTransferStatus = .unknown
    var dataTransferProgressUpdater: Timer?

    @Published var menuItems = [ContextualMenuItem]()

    // view parameters
    var borderColor: Color
    var backgroundColor: Color
    var textColor: Color
    var secondaryColor: Color
    var hasBorder: Bool
    var corners: UIRectCorner = .allCorners
    let cornerRadius: CGFloat = 15
    var textInset: CGFloat = 15
    var textFont: Font = .body

    var message: MessageModel
    var isIncoming: Bool
    var isHistory: Bool
    var type: MessageType = .text

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

    // state
    var contextMenuState: PublishSubject<State>
    var transferState: PublishSubject<State>

    required init(message: MessageModel, contextMenuState: PublishSubject<State>, transferState: PublishSubject<State>) {
        self.contextMenuState = contextMenuState
        self.transferState = transferState
        self.message = message
        self.type = message.type
        self.isIncoming = message.incoming
        self.isHistory = false
        self.content = message.content
        self.transferStatus = message.transferStatus
        self.secondaryColor = Color(UIColor.secondaryLabel)
        if isHistory {
            self.sequencing = .firstOfSequence
            self.borderColor = Color(.secondaryLabel)
            self.textColor = Color(.secondaryLabel)
            self.hasBorder = true
            self.backgroundColor = Color(.white)
        } else {
            self.textColor = isIncoming ? Color(UIColor.label) : Color(.white)
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
            self.fileName = message.content
            self.textColor = Color(UIColor.label)
            self.updateTransferInfo()
        }
        self.fetchMetadata()
    }

    func setSequencing(sequencing: MessageSequencing) {
        if self.sequencing != sequencing {
            self.sequencing = sequencing
        }
    }

    func setTransferStatus(transferStatus: DataTransferStatus) {
        if self.transferStatus != transferStatus {
            self.transferStatus = transferStatus
            self.updateTransferInfo()
        }
    }

    private func fetchMetadata() {
        guard self.type == .text, self.content.isValidURL, let url = URL(string: self.content) else { return }
        LPMetadataProvider().startFetchingMetadata(for: url) {(metaDataObj, error) in
            DispatchQueue.main.async { [weak self, weak metaDataObj] in
                guard let self = self else { return }
                guard error == nil, let metaDataObj = metaDataObj else {
                    return
                }
                self.metadata = metaDataObj
            }
        }
    }

    private func updateMenuitems() {
        if self.type == .text {
            self.menuItems = [.copy, .forward]
        }
        guard self.type == .fileTransfer else { return }
        if self.url != nil {
            if self.image != nil {
                self.menuItems = [.save, .forward, .preview, .share]
            } else {
                self.menuItems = [.forward, .preview, .share]
            }
        }
    }

    // MARK: file transfer

    private func updateTransferInfo() {
        self.updateTransferActions()
        self.updateFileDescription()
        self.updateMenuitems()
        if self.fileSize == 0 {
            self.transferState.onNext(TransferState.getSize(viewModel: self))
        }
        if self.transferStatus == .ongoing {
            self.startProgressMonitor()
        } else {
            self.stopProgressMonitor()
        }
        if (self.transferStatus == .success || !self.message.incoming), self.image == nil, self.player == nil {
            self.transferState.onNext(TransferState.getImage(viewModel: self))
            self.transferState.onNext(TransferState.getPlayer(viewModel: self))
        }
        if (self.transferStatus == .success || !self.message.incoming), self.url == nil {
            self.transferState.onNext(TransferState.getURL(viewModel: self))
        }
        self.updaTetransferViewType()
    }

    private func updaTetransferViewType() {
        guard self.message.type == .fileTransfer else { return }
        var newType: TransferViewType = .defaultView
        if let image = self.image {
            newType = .imageView(image: image)
        } else if let player = self.player {
            newType = .playerView(player: player)
        }
        if newType != self.transferViewType {
            self.transferViewType = newType
            self.shouldUpdateTransferView = true
        }
    }

    private func updateTransferActions() {
        DispatchQueue.main.async {
            switch self.transferStatus {
            case .created, .awaiting:
                self.transferActions = !self.isIncoming ? [.cancel] : [.accept, .cancel]
            case .ongoing:
                self.transferActions = [.cancel]
            case .success, .error, .unknown, .canceled:
                self.transferActions = [TransferAction]()
            }
        }
    }

    private func updateFileDescription() {
        if self.fileSize == 0 {
            self.fileInfo = self.transferStatus.description
        } else {
            self.fileInfo = self.getFileSizeString(bytes: self.fileSize) + " - " + self.transferStatus.description
        }
    }

    private func getFileSizeString(bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            return "\(bytes / 1024) KB"
        } else if bytes < 1024 * 1024 * 1024 {
            return "\(bytes / (1024 * 1024)) MB"
        }
        return "\(bytes / (1024 * 1024 * 1024)) GB"
    }

    private func startProgressMonitor() {
        self.showProgress = true
        if self.dataTransferProgressUpdater != nil {
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

    private func stopProgressMonitor() {
        self.showProgress = false
        guard let updater = self.dataTransferProgressUpdater else { return }
        updater.invalidate()
        self.dataTransferProgressUpdater = nil
    }

    @objc
    func updateProgressBar(timer: Timer) {
        self.transferState.onNext(TransferState.getProgress(viewModel: self))
    }

    func extractedVideoFrame(with height: CGFloat) {
        if let player = player, let firstImage = player.firstFrame,
           let frameSize = firstImage.getNewSize(of: CGSize(width: maxDimension, height: maxDimension)) {
            playerHeight = frameSize.height
            playerWidth = frameSize.width
        } else {
            playerHeight = height
        }
    }

    var maxDimension: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        // iPhone 5 width
        if screenWidth <= 320 {
            return 200
            // iPhone 6, iPhone 6 Plus and iPhone XR width
        } else if screenWidth > 320 && screenWidth <= 414 {
            return 250
            // iPad width
        } else if screenWidth > 414 {
            return 300
        }
        return 250
    }

    // MARK: actions received from UI

    func onAppear() {
        if self.type == .fileTransfer {
            self.transferState.onNext(TransferState.getImage(viewModel: self))
            self.transferState.onNext(TransferState.getPlayer(viewModel: self))
            self.transferState.onNext(TransferState.getURL(viewModel: self))
        }
        updateMenuitems()
    }

    func transferAction(action: TransferAction) {
        switch action {
        case .accept:
            self.transferState.onNext(TransferState.accept(viewModel: self))
        case .cancel:
            self.transferState.onNext(TransferState.cancel(viewModel: self))
        }
    }

    func contextMenuSelect(item: ContextualMenuItem) {
        switch item {
        case .copy:
            UIPasteboard.general.string = self.content
        case .preview:
            self.contextMenuState.onNext(ContextMenu.preview(message: self))
        case .forward:
            self.contextMenuState.onNext(ContextMenu.forward(message: self))
        case .share:
            let item: Any? = self.url != nil ? self.url : self.image
            guard let item = item else {
                return
            }
            self.contextMenuState.onNext(ContextMenu.share(items: [item]))
        case .save:
            guard let image = self.image else { return }
            self.contextMenuState.onNext(ContextMenu.save(image: image))
        }
    }
}

extension MessageContentVM: PlayerDelegate {
    func deleteFile() {}

    func shareFile() {
        let item: Any? = self.url != nil ? self.url : self.image
        guard let item = item else {
            return
        }
        self.contextMenuState.onNext(ContextMenu.share(items: [item]))
    }

    func forwardFile() {
        self.contextMenuState.onNext(ContextMenu.forward(message: self))
    }

    func saveFile() {
        guard let image = self.image else { return }
        self.contextMenuState.onNext(ContextMenu.save(image: image))
    }
}
