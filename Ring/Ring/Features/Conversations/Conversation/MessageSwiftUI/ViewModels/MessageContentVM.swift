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
    case reply

    func toString() -> String {
        switch self {
        case .preview:
            return L10n.Global.preview
        case .forward:
            return L10n.Global.forward
        case .share:
            return L10n.Global.share
        case .save:
            return L10n.Global.save
        case .copy:
            return L10n.Global.copy
        case .reply:
            return L10n.Global.reply
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
        case .reply:
            return "arrowshape.turn.up.left"
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
    @Published var playerHeight: CGFloat = 100
    @Published var playerWidth: CGFloat = 250
    @Published var image: UIImage?
    @Published var imageURL: URL?
    @Published var player: PlayerViewModel?
    @Published var corners: UIRectCorner = [.allCorners]
    @Published var menuItems = [ContextualMenuItem]()
    @Published var backgroundColor: Color
    var url: URL?
    var fileSize: Int64 = 0
    var transferStatus: DataTransferStatus = .unknown
    var dataTransferProgressUpdater: Timer?

    // view parameters
    var borderColor: Color
    var textColor: Color
    var secondaryColor: Color
    var hasBorder: Bool
    let cornerRadius: CGFloat = 15
    var textInset: CGFloat = 15
    var textVerticalInset: CGFloat = 10
    var textFont: Font = Font.body.weight(.regular)

    var message: MessageModel
    var isIncoming: Bool
    var isHistory: Bool
    var type: MessageType = .text
    var followEmogiMessage = false
    var followingByEmogiMessage = false

    private var sequencing: MessageSequencing = .unknown {
        didSet {
            guard !isHistory else { return }
            self.corners = self.updatedCorners()
            // text need to be updated to trigger view redrowing
            let oldContent = self.content
            self.content = oldContent
        }
    }

    func getURL() -> URL? {
        var withPrefix = content
        if !withPrefix.hasPrefix("http://") && !withPrefix.hasPrefix("https://") {
            withPrefix = "http://" + withPrefix
        }
        return URL(string: withPrefix)
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
            self.textFont = Font(UIFont.systemFont(ofSize: 38.0, weight: UIFont.Weight.medium))
            self.textInset = 0
            self.textVerticalInset = 2
        }
        if self.type == .fileTransfer {
            self.fileName = message.content
            self.textColor = Color(UIColor.label)
            self.borderColor = Color(UIColor.clear)
            self.updateTransferInfo()
        }
        if self.type == .contact {
            self.sequencing = .firstOfSequence
            self.hasBorder = true
            self.textColor = Color(UIColor.label)
            self.backgroundColor = Color(UIColor.clear)
            self.borderColor = Color(UIColor.secondaryLabel)
        }
        self.fetchMetadata()
    }

    func setSequencing(sequencing: MessageSequencing) {
        if self.sequencing != sequencing {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                self.sequencing = sequencing
            }
        }
    }

    func setTransferStatus(transferStatus: DataTransferStatus) {
        if self.transferStatus != transferStatus {
            self.transferStatus = transferStatus
            self.updateTransferInfo()
        }
    }

    private func updatedCorners() -> UIRectCorner {
        if self.followEmogiMessage && self.followingByEmogiMessage {
            return .allCorners
        }
        switch sequencing {
        case .firstOfSequence:
            if followingByEmogiMessage {
                return [.allCorners]
            } else {
                return isIncoming ? [.topLeft, .topRight, .bottomRight] : [.topLeft, .topRight, .bottomLeft]
            }
        case .lastOfSequence:
            if followEmogiMessage {
                return [.allCorners]
            } else {
                return isIncoming ? [.topRight, .bottomLeft, .bottomRight] : [.topLeft, .bottomLeft, .bottomRight]
            }
        case .middleOfSequence:
            if self.followEmogiMessage {
                return isIncoming ? [.topRight, .topLeft, .bottomRight] : [.topRight, .topLeft, .bottomLeft ]
            } else if self.followingByEmogiMessage {
                return isIncoming ? [.topRight, .bottomRight, .bottomLeft] : [.topLeft, .bottomLeft, .bottomRight]
            } else {
                return isIncoming ? [.topRight, .bottomRight] : [.topLeft, .bottomLeft]
            }
        case .singleMessage, .unknown:
            return [.allCorners]
        }
    }

    private func fetchMetadata() {
        guard self.type == .text, self.content.isValidURL, let url = URL(string: self.content) else { return }
        self.textColor = .blue
        DispatchQueue.global(qos: .background).async {
            LPMetadataProvider().startFetchingMetadata(for: url) {(metaDataObj, error) in
                guard error == nil else {
                    return
                }
                DispatchQueue.main.async { [weak self, weak metaDataObj] in
                    guard let self = self, let metaDataObj = metaDataObj else {
                        return
                    }
                    self.metadata = metaDataObj
                }
            }
        }
    }

    private func updateMenuitems() {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
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
    }

    private func updateTransferActions() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            if self.fileSize == 0 {
                self.fileInfo = self.transferStatus.description
            } else {
                self.fileInfo = self.getFileSizeString(bytes: self.fileSize) + " - " + self.transferStatus.description
            }
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showProgress = true
        }
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showProgress = false
        }
        guard let updater = self.dataTransferProgressUpdater else { return }
        updater.invalidate()
        self.dataTransferProgressUpdater = nil
    }

    @objc
    func updateProgressBar(timer: Timer) {
        self.transferState.onNext(TransferState.getProgress(viewModel: self))
    }

    func extractedVideoFrame(with height: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let player = self.player, let firstImage = player.firstFrame,
               let frameSize = firstImage.getNewSize(of: CGSize(width: self.maxDimension, height: self.maxDimension)) {
                self.playerHeight = frameSize.height
                self.playerWidth = frameSize.width
            } else {
                self.playerHeight = height
            }
            self.borderColor = Color(UIColor.tertiaryLabel)
        }
    }

    func updatePlayer(player: PlayerViewModel?) {
        guard let player = player else { return }
        var playerSize = CGSize(width: playerWidth, height: playerHeight)
        if let firstImage = player.firstFrame,
           let frameSize = firstImage.getNewSize(of: CGSize(width: maxDimension, height: maxDimension)) {
            playerSize = frameSize
            playerHeight = frameSize.height
            playerWidth = frameSize.width
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playerHeight = playerSize.height
            self.playerWidth = playerSize.width
            self.player = player
            self.player!.delegate = self
        }
    }

    func updateImage(image: UIImage?, url: URL?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.image = image
            self.imageURL = url
        }
    }

    func updateFileSize(size: Int64) {
        self.fileSize = size
    }

    func updateProgress(progress: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.fileProgress = progress
        }
    }

    func updateFileURL(url: URL?) {
        self.url = url
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
        case .reply:
            break
        // self.contextMenuState.onNext(ContextMenu.reply(messageId: self.message.id))
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

    func swarmColorUpdated(color: UIColor) {
        if self.message.incoming || self.content.containsOnlyEmoji {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.backgroundColor = Color(color)
        }
    }
}
