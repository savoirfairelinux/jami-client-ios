/*
 *  Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

import UIKit
import PhotosUI
import RxSwift
import SwiftyBeaver
import Photos
import MobileCoreServices
import SwiftUI
import RxRelay
import CoreLocation
import UniformTypeIdentifiers

enum DocumentPickerMode {
    case picking
    case saving
    case none
}

enum ContextMenu: State {
    case preview(message: MessageContentVM)
    case forward(message: MessageContentVM)
    case share(items: [Any])
    case saveFile(url: URL)
    case reply(message: MessageContentVM)
    case delete(message: MessageContentVM)
    case edit(message: MessageContentVM)
    case scrollToReplyTarget(messageId: String)
}

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class ConversationViewController: UIHostingController<ConversationContainerView>,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate,
                                  PHPickerViewControllerDelegate {

    let disposeBag = DisposeBag()
    let log = SwiftyBeaver.self

    var viewModel: ConversationViewModel!
    var currentDocumentPickerMode: DocumentPickerMode = .none

    let tapAction = BehaviorRelay<Bool>(value: false)
    var screenTapRecognizer: UITapGestureRecognizer!

    private lazy var locationManager: CLLocationManager = { return CLLocationManager() }()

    private var isLocationSharingDurationLimited: Bool {
        return UserDefaults.standard.bool(forKey: limitLocationSharingDurationKey)
    }
    private var locationSharingDuration: Int {
        return UserDefaults.standard.integer(forKey: locationSharingDurationKey)
    }

    convenience init(viewModel: ConversationViewModel) {
        let containerView = ConversationContainerView(viewModel: viewModel)
        self.init(rootView: containerView)
        self.viewModel = viewModel
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScreenTap()
        setupBindings()
        subscribeMessagePanelState()
        subscribeContextMenuState()
        subscribeLastMessage()
        view.backgroundColor = UIColor.systemBackground
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.setMessagesAsRead()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.setMessagesAsRead()
    }

    // MARK: - Setup

    private func setupScreenTap() {
        screenTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        screenTapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(screenTapRecognizer)
        viewModel.swiftUIModel.subscribeScreenTapped(screenTapped: tapAction.asObservable())
    }

    @objc func screenTapped() {
        tapAction.accept(true)
    }

    private func setupBindings() {
        viewModel.shouldDismiss
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] dismiss in
                guard let self = self, dismiss else { return }
                _ = self.navigationController?.popViewController(animated: true)
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }

    // MARK: - State subscriptions

    // swiftlint:disable cyclomatic_complexity
    private func subscribeMessagePanelState() {
        viewModel.swiftUIModel.messagePanelState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? MessagePanelState else { return }
                switch state {
                case .sendMessage(let content, let parentId):
                    self.viewModel.sendMessage(withContent: content, parentId: parentId)
                case .sendPhoto:
                    self.takePicture()
                case .editMessage(content: let content, messageId: let messageId):
                    self.viewModel.editMessage(content: content, messageId: messageId)
                case .openGalery:
                    self.selectItemsFromPhotoLibrary()
                case .shareLocation:
                    self.startLocationSharing()
                case .recordAudio:
                    self.recordAudio()
                case .recordVido:
                    self.recordVideo()
                case .sendFile:
                    self.importDocument()
                case .registerTypingIndicator(let typingStatus):
                    self.viewModel.setIsComposingMsg(isComposing: typingStatus)
                case .joinActiveCall(call: let call, withVideo: let withVideo):
                    self.viewModel.joinActiveCall(call: call, withVideo: withVideo)
                }
            })
            .disposed(by: disposeBag)
    }
    // swiftlint:enable cyclomatic_complexity

    private func subscribeContextMenuState() {
        viewModel.swiftUIModel.contextMenuState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ContextMenu else { return }
                switch state {
                case .preview(let message):
                    self.presentPreview(message: message)
                case .forward(let message):
                    /*
                     Remove the tap gesture to ensure the contact selector
                     can receive taps. The tap gesture should be re-added
                     once the contact picker is dismissed.
                     */
                    self.view.removeGestureRecognizer(self.screenTapRecognizer)
                    self.viewModel.slectContactsToShareMessage(message: message)
                case .share(let items):
                    self.presentActivityControllerWithItems(items: items)
                case .saveFile(let url):
                    self.saveFile(url: url)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    private func subscribeLastMessage() {
        viewModel.lastMessageObservable
            .share()
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.viewModel.messageDisplayed()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Document import

    private func importDocument() {
        currentDocumentPickerMode = .picking
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item])
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true, completion: nil)
    }

    // MARK: - Alerts

    private func showNoPermissionsAlert(title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            let okAction = UIAlertAction(title: L10n.Global.ok, style: .default) { (_: UIAlertAction!) in }
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        }
    }

    // MARK: - Photo library

    private func presentBackgroundRecordingAlert() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: nil, message: L10n.DataTransfer.recordInBackgroundWarning, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: { [weak self] _ in
                UserDefaults.standard.setValue(true, forKey: fileRecordingLimitationInBackgroundKey)
                self?.recordVideoFile()
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func canRecordVideoFile() -> Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return UIDevice.current.userInterfaceIdiom != .pad || UserDefaults.standard.bool(forKey: fileRecordingLimitationInBackgroundKey)
    }

    private func recordVideoFile() {
        if canRecordVideoFile() {
            viewModel.recordVideoFile()
        } else {
            presentBackgroundRecordingAlert()
        }
    }

    func selectItemsFromPhotoLibrary() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var config = PHPickerConfiguration()
            config.selectionLimit = 0
            let pickerViewController = PHPickerViewController(configuration: config)
            pickerViewController.delegate = self
            self.present(pickerViewController, animated: true, completion: nil)
        }
    }

    func recordVideo() {
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus.authorized {
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized {
                recordVideoFile()
            } else {
                AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [weak self] (granted: Bool) in
                    guard let self = self else { return }
                    if granted == true {
                        self.recordVideoFile()
                    } else {
                        self.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                    }
                })
            }
        } else {
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: {[weak self] (granted: Bool) in
                guard let self = self else { return }
                if granted == true {
                    if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized {
                        self.recordVideoFile()
                    } else {
                        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [weak self] (granted: Bool) in
                            guard let self = self else { return }
                            if granted == true {
                                self.recordVideoFile()
                            } else {
                                self.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                            }
                        })
                    }
                } else {
                    self.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                }
            })
        }
    }

    func recordAudio() {
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus.authorized {
            viewModel.recordAudioFile()
        } else {
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { [weak self] (granted: Bool) in
                guard let self = self else { return }
                if granted == true {
                    self.viewModel.recordAudioFile()
                } else {
                    self.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                }
            })
        }
    }

    func takePicture() {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerController.SourceType.camera
            imagePicker.cameraDevice = UIImagePickerController.CameraDevice.rear
            imagePicker.modalPresentationStyle = .overFullScreen
            self.present(imagePicker, animated: false, completion: nil)
        }
    }

    func fixImageOrientation(image: UIImage) -> UIImage {
        UIGraphicsBeginImageContext(image.size)
        image.draw(at: .zero)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? image
    }

    // MARK: - PHPickerViewControllerDelegate

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        results.forEach { (result) in
            let imageFileName: String = result.itemProvider.suggestedName ?? "file"
            let provider = result.itemProvider
            switch getAssetTypeFrom(itemProvider: provider) {
            case .gif:
                provider.loadDataRepresentation(forTypeIdentifier: UTType.gif.identifier) { [weak self] (data, _) in
                    guard let self = self,
                          let data = data else { return }
                    self.viewModel.sendAndSaveFile(displayName: imageFileName + ".gif", imageData: data)
                }
            case .image:
                provider.loadObject(ofClass: UIImage.self) { [weak self] (object, _) in
                    guard let self = self,
                          let image = object as? UIImage,
                          let imageData = image.jpegData(compressionQuality: 0.5) else { return }
                    self.viewModel.sendAndSaveFile(displayName: imageFileName + ".jpeg", imageData: imageData)
                }
            case .video:
                provider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] (data, _) in
                    guard let self = self,
                          let data = data else { return }
                    self.viewModel.sendAndSaveFile(displayName: imageFileName + ".mov", imageData: data)
                }
            default:
                break
            }
        }
    }

    private func getAssetTypeFrom(itemProvider: NSItemProvider) -> FileTransferType {
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
            return .gif
        } else if itemProvider.canLoadObject(ofClass: UIImage.self) {
            return .image
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return .video
        } else {
            return .unknown
        }
    }

    // MARK: - UIImagePickerControllerDelegate
    // swiftlint:disable cyclomatic_complexity
    internal func imagePickerController(_ picker: UIImagePickerController,
                                        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        picker.dismiss(animated: true, completion: nil)

        var image: UIImage!

        if picker.sourceType == UIImagePickerController.SourceType.camera {
            if let img = info[.editedImage] as? UIImage {
                image = img
            } else if let img = info[.originalImage] as? UIImage {
                image = fixImageOrientation(image: img)
            }
            let imageFileName = "IMG.jpeg"
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            viewModel.sendAndSaveFile(displayName: imageFileName, imageData: imageData)
            return
        }
        guard picker.sourceType == UIImagePickerController.SourceType.photoLibrary,
              let phAsset = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset else { return }
        let imageFileName = phAsset.value(forKey: "filename") as? String ?? "Unknown"
        if phAsset.mediaType == .image {
            if let img = info[.editedImage] as? UIImage {
                image = img
            } else if let img = info[.originalImage] as? UIImage {
                image = img
            }
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            viewModel.sendAndSaveFile(displayName: imageFileName, imageData: imageData)
            return
        }
        guard phAsset.mediaType == .video else { return }
        PHImageManager
            .default()
            .requestAVAsset(forVideo: phAsset,
                            options: PHVideoRequestOptions(),
                            resultHandler: { (asset, _, _) in
                                guard let asset = asset as? AVURLAsset,
                                      let videoData = NSData(contentsOf: asset.url) else {
                                    return
                                }
                                self.viewModel.sendAndSaveFile(displayName: imageFileName, imageData: videoData as Data)
                            })
    }
    // swiftlint:enable cyclomatic_complexity

}

// MARK: - Location sharing
extension ConversationViewController {

    func startLocationSharing() {
        if checkLocationAuthorization() && isNotAlreadySharingWithThisContact() {
            if isLocationSharingDurationLimited {
                viewModel.startSendingLocation(duration: TimeInterval(locationSharingDuration * 60))
            } else {
                viewModel.startSendingLocation()
            }
        }
    }

    private func isNotAlreadySharingWithThisContact() -> Bool {
        if viewModel.isAlreadySharingMyLocation() {
            let alert = UIAlertController.init(title: L10n.Alerts.alreadylocationSharing,
                                               message: nil,
                                               preferredStyle: .alert)
            alert.addAction(.init(title: L10n.Global.ok, style: UIAlertAction.Style.cancel))
            self.present(alert, animated: true, completion: nil)
            return false
        }
        return true
    }

    private func showGoToSettingsAlert(title: String) {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: L10n.Actions.goToSettings, style: .default, handler: { (_) in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, completionHandler: nil)
            }
        }))
        alertController.addAction(UIAlertAction(title: L10n.Global.cancel, style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

    private func checkLocationAuthorization() -> Bool {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied: showGoToSettingsAlert(title: L10n.Alerts.noLocationPermissionsTitle)
        case .authorizedAlways, .authorizedWhenInUse: return true
        @unknown default: break
        }
        return false
    }
}

// MARK: - ContactPickerDismissHandler
extension ConversationViewController: ContactPickerDismissHandler {
    func contactPickerDidDismiss() {
        view.addGestureRecognizer(screenTapRecognizer)
    }
}

// MARK: - UIDocumentPickerDelegate
extension ConversationViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if currentDocumentPickerMode == .picking {
            if let url = urls.first, url.startAccessingSecurityScopedResource() {
                let filePath = url.absoluteURL.path
                log.debug("Successfully imported \(filePath)")
                let fileName = url.absoluteURL.lastPathComponent
                do {
                    let data = try Data(contentsOf: url)
                    viewModel.sendAndSaveFile(displayName: fileName, imageData: data)
                } catch {
                    viewModel.sendFile(filePath: filePath, displayName: fileName)
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
        currentDocumentPickerMode = .none
    }
}

// MARK: - UIDocumentInteractionControllerDelegate
extension ConversationViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        if let navigationController = self.navigationController {
            return navigationController
        }
        return self
    }
}

// MARK: - Messages actions
extension ConversationViewController {
    func saveFile(url: URL) {
        if url.pathExtension.isImageExtension() {
            saveGIFOrImage(url: url)
        } else {
            saveFileToDocuments(fileURL: url)
        }
    }

    func presentPreview(message: MessageContentVM) {
        guard let url = message.url else { return }
        if message.player != nil {
            presentPlayer(message: message)
        } else if url.pathExtension.isImageExtension(),
                  let image = message.getImage(maxSize: 0) {
            viewModel.openFullScreenPreview(parentView: self, viewModel: nil, image: image, delegate: message)
        } else {
            openDocument(url: url)
        }
    }

    func presentActivityControllerWithItems(items: [Any]) {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        activityViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxX, width: 0, height: 0)
        self.present(activityViewController, animated: true, completion: nil)
    }

    func saveGIFOrImage(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }, completionHandler: { _, error in
            guard let error = error else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.showAlert(error: error)
            }
        })
    }

    @objc
    func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showAlert(error: error)
        }
    }

    func showAlert(error: Error) {
        let alert = UIAlertController(title: L10n.Conversation.errorSavingImage, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    func saveFileToDocuments(fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist at path: \(fileURL.path)")
            return
        }
        currentDocumentPickerMode = .saving
        let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true, completion: nil)
    }

    func presentPlayer(message: MessageContentVM) {
        viewModel.openFullScreenPreview(parentView: self, viewModel: message.player, image: nil, delegate: message)
    }

    func openDocument(url: URL) {
        DispatchQueue.main.async {
            let interactionController = UIDocumentInteractionController(url: url)
            interactionController.delegate = self
            interactionController.presentPreview(animated: true)
        }
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
