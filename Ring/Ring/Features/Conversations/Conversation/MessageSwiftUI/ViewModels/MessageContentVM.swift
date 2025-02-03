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
    case deleteMessage
    case deleteFile
    case edit

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
        case .deleteMessage:
            return L10n.Global.deleteMessage
        case .deleteFile:
            return L10n.Global.deleteFile
        case .edit:
            return L10n.Global.editMessage
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
        case .deleteMessage:
            return "xmark.bin"
        case .deleteFile:
            return "xmark.bin"
        case .edit:
            return "pencil"
        }
    }
}

// swiftlint:disable type_body_length
class MessageContentVM: ObservableObject, PreviewViewControllerDelegate, PlayerDelegate, MessageAppearanceProtocol, NameObserver {

    @Published var content = ""
    @Published var metadata: LPLinkMetadata?

    // file transfer
    @Published var fileName: String = ""
    @Published var fileInfo: String = ""
    @Published var fileProgress: CGFloat = 0
    @Published var transferActions = [TransferAction]()
    @Published var showProgress: Bool = true
    @Published var playerHeight: CGFloat = 80
    @Published var playerWidth: CGFloat = 250
    @Published var player: PlayerViewModel?
    @Published var corners: UIRectCorner = [.allCorners]
    @Published var menuItems = [ContextualMenuItem]()
    @Published var backgroundColor: Color = Color(.jamiMsgCellReceived)
    @Published var finalImage: UIImage?
    @Published var messageDeleted = false
    @Published var messageEdited = false
    @Published var messageDeletedText = ""
    @Published var editIndicator = L10n.Conversation.edited
    @Published var editionColor = Color.secondary
    @Published var scale: CGFloat = 1
    var url: URL?
    var fileSize: Int64 = 0
    var transferStatus: DataTransferStatus = .unknown
    var dataTransferProgressUpdater: Timer?

    // view parameters
    var borderColor: Color = .clear
    var hasBorder: Bool = false
    let cornerRadius: CGFloat = 15
    var textInset: CGFloat = 15
    var textVerticalInset: CGFloat = 10
    var styling: MessageStyling = MessageStyling()

    var message: MessageModel
    var isIncoming: Bool
    var isHistory: Bool
    var type: MessageType = .text
    var maxImageSize: CGFloat = 300
    let screenScale: CGFloat = UIScreen.main.scale
    var imageSize: CGFloat {
        return maxImageSize * screenScale
    }
    var disposeBag = DisposeBag()

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

    @Published var username = "" {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messageDeletedText = L10n.Conversation.deletedMessage(self.username)
            }
        }
    }

    // state
    var contextMenuState: PublishSubject<State>
    var transferState: PublishSubject<State>
    var infoState: PublishSubject<State>?
    var preferencesColor: UIColor

    required init(message: MessageModel, contextMenuState: PublishSubject<State>, transferState: PublishSubject<State>, isHistory: Bool, preferencesColor: UIColor) {
        self.contextMenuState = contextMenuState
        self.transferState = transferState
        self.message = message
        self.type = message.type
        self.isIncoming = message.incoming
        self.isHistory = isHistory
        if self.isHistory {
            maxImageSize = 100
        }
        self.content = message.content
        self.transferStatus = message.transferStatus
        self.preferencesColor = preferencesColor
        self.updateMessageStyle()
        if self.type == .fileTransfer {
            self.fileName = message.content
            self.updateTransferInfo()
        }
        self.updateMessageEditions()
        self.fetchMetadata()
    }

    func setInfoState(state: PublishSubject<State>) {
        self.infoState = state
    }

    private func updateMessageStyle() {
        self.updateBackgroundColor()
        self.updateTextColor()
        self.updateTextFont()
        self.updateInset()
        self.editionColor = self.isIncoming ? styling.secondaryTextColor : Color(red: 0.95, green: 0.95, blue: 0.95)
    }

    private func updateTextColor() {
        if self.isLink() {
            let backgroundIsLightColor: Bool = self.backgroundColor.isLight(threshold: 0.8) ?? true
            self.styling.textColor = backgroundIsLightColor ? .blue : .white
        } else if !self.isIncoming && !self.type.isContact {
            self.styling.textColor = Color.white
        } else {
            self.styling.textColor = self.styling.defaultTextColor
        }
    }

    private func updateTextFont() {
        if self.content.containsOnlyEmoji && !self.messageDeleted && !self.messageEdited {
            self.styling.textFont = Font(UIFont.systemFont(ofSize: 38.0, weight: UIFont.Weight.medium))
        } else {
            self.styling.textFont = self.styling.defaultTextFont
        }
    }

    private func updateBackgroundColor() {
        if self.type.isContact || self.content.containsOnlyEmoji && !self.messageDeleted && !self.messageEdited {
            self.backgroundColor = .clear
        } else {
            self.backgroundColor = isIncoming ? Color(.jamiMsgCellReceived) : Color(preferencesColor)
        }
    }

    private func updateInset() {
        if self.content.containsOnlyEmoji && !self.messageDeleted && !self.messageEdited {
            self.textInset = 0
            self.textVerticalInset = 2
        } else {
            self.textInset = 15
            self.textVerticalInset = 10
        }
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
        switch sequencing {
        case .firstOfSequence:
            return isIncoming ? [.topLeft, .topRight, .bottomRight] : [.topLeft, .topRight, .bottomLeft]
        case .lastOfSequence:
            return isIncoming ? [.topRight, .bottomLeft, .bottomRight] : [.topLeft, .bottomLeft, .bottomRight]
        case .middleOfSequence:
            return isIncoming ? [.topRight, .bottomRight] : [.topLeft, .bottomLeft]
        case .singleMessage, .unknown:
            return [.allCorners]
        }
    }

    private func isLink() -> Bool {
        return self.type == .text &&
            self.content.isValidURL &&
            URL(string: self.content) != nil
    }

    private func fetchMetadata() {
        guard self.type == .text, self.content.isValidURL, let url = URL(string: self.content) else { return }
        self.updateTextColor()
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
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            if self.type == .text {
                if self.isIncoming {
                    self.menuItems = [.reply, .copy, .forward]
                } else {
                    self.menuItems = [.reply, .edit, .copy, .forward, .deleteMessage]
                }
            }
            guard self.type == .fileTransfer else { return }
            if self.url != nil {
                self.menuItems = [.reply, .save, .forward, .preview, .share]
            } else {
                self.menuItems = [.reply, .forward, .preview, .share]
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
        if self.transferStatus != .success {
            return
        }
        if self.player == nil {
            self.transferState.onNext(TransferState.getPlayer(viewModel: self))
        }
        if self.url == nil {
            self.transferState.onNext(TransferState.getURL(viewModel: self))
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            _ = self.getImage(maxSize: self.imageSize)
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
               let image = UIImage.createFrom(sampleBuffer: firstImage),
               let frameSize = image.getNewSize(of: CGSize(width: self.maxDimension, height: self.maxDimension)) {
                self.playerHeight = frameSize.height
                self.playerWidth = frameSize.width
            } else {
                self.playerHeight = height
            }
        }
    }

    func updatePlayer(player: PlayerViewModel?) {
        guard let player = player else { return }
        var playerSize = CGSize(width: playerWidth, height: playerHeight)
        if let firstImage = player.firstFrame,
           let image = UIImage.createFrom(sampleBuffer: firstImage),
           let frameSize = image.getNewSize(of: CGSize(width: maxDimension, height: maxDimension)) {
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
            self.borderColor = Color(UIColor.tertiaryLabel)
        }
    }

    func swarmColorUpdated(color: UIColor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.preferencesColor = color
            self.updateBackgroundColor()
        }
    }

    func updateMessageEditions() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.content = self.message.content
            self.messageDeleted = self.message.isMessageDeleted()
            self.messageEdited = self.message.isMessageEdited()
            if self.messageDeleted || self.messageEdited {
                self.updateMessageStyle()
            }
        }
        if self.message.isMessageDeleted() {
            self.requestName(jamiId: self.message.authorId)
        }
    }

    func updateUserName() {
        if !self.message.authorId.isEmpty {
            self.requestName(jamiId: self.message.authorId)
        }
    }

    func updateUsername(name: String, jamiId: String) {
        guard message.authorId == jamiId, !name.isEmpty else { return }
        self.username = name
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

    func startTargetReplyAnimation() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) { [weak self] in
                guard let self = self else { return }
                self.scale = 1.3
            }
            withAnimation(Animation.easeInOut(duration: 0.1).delay(0.3)) {[weak self] in
                guard let self = self else { return }
                self.scale = 1
            }
        }
    }

    func isGifImage() -> Bool {
        return self.url?.pathExtension == "gif"
    }

    func getImage(maxSize: CGFloat) -> UIImage? {
        guard let url = self.url else { return nil }

        // If maxSize is 0, load the biggest size possible for preview
        if maxSize == 0 {
            return loadImage(from: url, withMaxSize: maxSize)
        }

        // Return cached image if available
        if let image = self.finalImage {
            return image
        }

        // Load and cache the image
        self.finalImage = loadImage(from: url, withMaxSize: maxSize)
        return self.finalImage
    }

    private func loadImage(from url: URL, withMaxSize maxSize: CGFloat) -> UIImage? {
        return isGifImage() ? UIImage.gifImageWithUrl(url, maxSize: maxSize) : UIImage.getImagefromURL(fileURL: url, maxSize: maxSize)
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
            self.transferState.onNext(TransferState.getPlayer(viewModel: self))
            self.transferState.onNext(TransferState.getURL(viewModel: self))
            _ = getImage(maxSize: self.imageSize)
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
            forwardFile()
        case .share:
            shareFile()
        case .save:
            saveFile()
        case .reply:
            reply()
        case .deleteMessage:
            delete()
        case .deleteFile:
            delete()
        case .edit:
            edit()
        }
    }
}

extension MessageContentVM {
    func deleteFile() {}

    func shareFile() {
        guard let url = self.url else { return }
        let item: Any? = url
        guard let item = item else {
            return
        }
        self.contextMenuState.onNext(ContextMenu.share(items: [item]))
    }

    func forwardFile() {
        self.contextMenuState.onNext(ContextMenu.forward(message: self))
    }

    func reply() {
        self.contextMenuState.onNext(ContextMenu.reply(message: self))
    }

    func saveFile() {
        guard let fileURL = self.url else { return }
        self.contextMenuState.onNext(ContextMenu.saveFile(url: fileURL))
    }

    func delete() {
        if self.message.type == .text {
            self.contextMenuState.onNext(ContextMenu.delete(message: self))
        }
    }

    func edit() {
        if self.message.type == .text {
            self.contextMenuState.onNext(ContextMenu.edit(message: self))
        }
    }
}
