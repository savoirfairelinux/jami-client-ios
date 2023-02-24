/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

import UIKit
import PhotosUI
import RxSwift
import Reusable
import SwiftyBeaver
import Photos
import MobileCoreServices
import SwiftUI

enum ContextMenu: State {
    case preview(message: MessageContentVM)
    case forward(message: MessageContentVM)
    case share(items: [Any])
    case saveGIFOrImage(url: URL)
}

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class ConversationViewController: UIViewController,
                                  UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                                  UIDocumentPickerDelegate, StoryboardBased, ViewModelBased,
                                  MessageAccessoryViewDelegate, ContactPickerDelegate,
                                  PHPickerViewControllerDelegate, UIDocumentInteractionControllerDelegate {

    // MARK: StateableResponsive
    let disposeBag = DisposeBag()

    let log = SwiftyBeaver.self

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var spinnerView: UIView!

    var viewModel: ConversationViewModel!
    var textFieldShouldEndEditing = false
    private let messageGroupingInterval = 10 * 60 // 10 minutes
    var bottomHeight: CGFloat = 0.00
    var isExecutingDeleteMessage: Bool = false

    @IBOutlet weak var currentCallButton: UIButton!
    @IBOutlet weak var currentCallLabel: UILabel!
    @IBOutlet weak var scanButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var callButtonHeightConstraint: NSLayoutConstraint!
    var bottomAnchor: NSLayoutConstraint?
    var keyboardDismissTapRecognizer: UITapGestureRecognizer!

    private lazy var locationManager: CLLocationManager = { return CLLocationManager() }()

    func setIsComposing(isComposing: Bool) {
        self.viewModel.setIsComposingMsg(isComposing: isComposing)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        messageAccessoryView.delegate = self
        self.configureRingNavigationBar()
        self.setupUI()
        self.setupBindings()
        /*
         Register to keyboard notifications to adjust tableView insets when the keybaord appears
         or disappears
         */
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(withNotification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(withNotification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.addSwiftUIView()
    }

    private func addSwiftUIView() {
        let transferHelper = TransferHelper(dataTransferService: self.viewModel.dataTransferService,
                                            conversationViewModel: self.viewModel)
        let swiftUIModel = MessagesListVM(injectionBag: self.viewModel.injectionBag,
                                          conversation: self.viewModel.conversation.value,
                                          transferHelper: transferHelper)
        swiftUIModel.hideNavigationBar
            .subscribe(onNext: { [weak self] (hide) in
                guard let self = self else { return }
                if self.navigationItem.rightBarButtonItems?.isEmpty == hide { return }
                if hide {
                    self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
                    self.navigationItem.titleView = UIView()
                    self.navigationItem.rightBarButtonItems = []
                    self.navigationItem.setHidesBackButton(true, animated: false)
                } else {
                    self.configureRingNavigationBar()
                    self.setRightNavigationButtons()
                    self.setupNavTitle(profileImageData: self.viewModel.profileImageData.value,
                                       displayName: self.viewModel.displayName.value,
                                       username: self.viewModel.userName.value)
                }
            })
            .disposed(by: self.disposeBag)
        swiftUIModel.contextMenuState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ContextMenu else { return }
                switch state {
                case .preview(let message):
                    if message.url == nil && message.player == nil { return }
                    self.viewModel.openFullScreenPreview(parentView: self, viewModel: message.player, image: message.getImage(), initialFrame: CGRect.zero, delegate: message)
                    self.messageAccessoryView.frame.size.height = 0
                    self.messageAccessoryView.isHidden = true
                case .forward(let message):
                    self.viewModel.slectContactsToShareMessage(message: message)
                case .share(let items):
                    self.presentActivityControllerWithItems(items: items)
                case .saveGIFOrImage(let url):
                    self.saveGIFOrImage(url: url)
                }
            })
            .disposed(by: self.disposeBag)
        self.viewModel.conversationCreated
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self, weak swiftUIModel] update in
                guard let self = self, let swiftUIModel = swiftUIModel, update else { return }
                swiftUIModel.conversation = self.viewModel.conversation.value
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        let messageListView = MessagesListView(model: swiftUIModel)
        let swiftUIView = UIHostingController(rootView: messageListView)
        addChild(swiftUIView)
        swiftUIView.view.frame = self.view.frame
        self.view.addSubview(swiftUIView.view)
        swiftUIView.view.translatesAutoresizingMaskIntoConstraints = false
        swiftUIView.view.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        bottomAnchor = swiftUIView.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0)
        bottomAnchor?.isActive = true
        swiftUIView.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0).isActive = true
        swiftUIView.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 0).isActive = true
        swiftUIView.didMove(toParent: self)
        self.view.backgroundColor = UIColor.systemBackground
        self.view.sendSubviewToBack(swiftUIView.view)
    }

    @objc
    private func applicationWillResignActive() {
        self.viewModel.setIsComposingMsg(isComposing: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.setBackgroundImage(nil, for: UIBarMetrics.default)
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.jamiNavigationBarShadow.cgColor
        self.setupNavTitle(profileImageData: self.viewModel.profileImageData.value,
                           displayName: self.viewModel.displayName.value,
                           username: self.viewModel.userName.value)
    }

    private func importDocument() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let filePath = urls[0].absoluteURL.path
        self.log.debug("Successfully imported \(filePath)")
        let fileName = urls[0].absoluteURL.lastPathComponent
        do {
            let data = try Data(contentsOf: urls[0])
            self.viewModel.sendAndSaveFile(displayName: fileName, imageData: data)
        } catch {
            self.viewModel.sendFile(filePath: filePath, displayName: fileName)
        }
    }

    private func showNoPermissionsAlert(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (_: UIAlertAction!) -> Void in }
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: photo library

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

    @objc
    func imageTapped() {
        let alert = UIAlertController.init(title: nil,
                                           message: nil,
                                           preferredStyle: .actionSheet)
        let pictureAction = UIAlertAction(title: L10n.Alerts.uploadPhoto, style: UIAlertAction.Style.default) {[weak self] _ in
            self?.selectItemsFromPhotoLibrary()
        }

        let recordVideoAction = UIAlertAction(title: L10n.Alerts.recordVideoMessage, style: UIAlertAction.Style.default) {[weak self] _ in
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus.authorized {
                if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized {
                    self?.messageAccessoryView.messageTextView.resignFirstResponder()
                    self?.viewModel.recordVideoFile()
                } else {
                    AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted: Bool) -> Void in
                        if granted == true {
                            self?.viewModel.recordVideoFile()
                        } else {
                            self?.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                        }
                    })
                }
            } else {
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (granted: Bool) -> Void in
                    if granted == true {
                        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized {
                            self?.viewModel.recordVideoFile()
                        } else {
                            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted: Bool) -> Void in
                                if granted == true {
                                    self?.viewModel.recordVideoFile()
                                } else {
                                    self?.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                                }
                            })
                        }
                    } else {
                        self?.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                    }
                })
            }
        }

        let recordAudioAction = UIAlertAction(title: L10n.Alerts.recordAudioMessage, style: UIAlertAction.Style.default) { [weak self] _ in
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus.authorized {
                self?.viewModel.recordAudioFile()
            } else {
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (granted: Bool) -> Void in
                    if granted == true {
                        self?.viewModel.recordAudioFile()
                    } else {
                        self?.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                    }
                })
            }
        }

        let documentsAction = UIAlertAction(title: L10n.Alerts.uploadFile, style: UIAlertAction.Style.default) { _ in
            self.importDocument()
        }

        let cancelAction = UIAlertAction(title: L10n.Alerts.profileCancelPhoto, style: UIAlertAction.Style.cancel)

        alert.addAction(pictureAction)
        alert.addAction(recordVideoAction)
        alert.addAction(recordAudioAction)
        alert.addAction(documentsAction)
        alert.addAction(locationSharingAction())
        alert.addAction(cancelAction)
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxX, width: 0, height: 0)
        self.present(alert, animated: true, completion: nil)
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

    func importImage() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
            imagePicker.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
            imagePicker.modalPresentationStyle = .overFullScreen
            self.present(imagePicker, animated: true, completion: nil)
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        results.forEach { (result) in
            let imageFileName: String = result.itemProvider.suggestedName ?? "file"
            let provider = result.itemProvider
            switch self.getAssetTypeFrom(itemProvider: provider) {
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
    // swiftlint:disable cyclomatic_complexity
    internal func imagePickerController(_ picker: UIImagePickerController,
                                        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        picker.dismiss(animated: true, completion: nil)

        var image: UIImage!

        if picker.sourceType == UIImagePickerController.SourceType.camera {
            // image from camera
            if let img = info[.editedImage] as? UIImage {
                image = img
            } else if let img = info[.originalImage] as? UIImage {
                image = self.fixImageOrientation(image: img)
            }
            // copy image to tmp
            let imageFileName = "IMG.jpeg"
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            self.viewModel.sendAndSaveFile(displayName: imageFileName, imageData: imageData)
            return
        }
        guard picker.sourceType == UIImagePickerController.SourceType.photoLibrary,
              let phAsset = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset else { return }
        let imageFileName = phAsset.value(forKey: "filename") as? String ?? "Unknown"
        // image from library
        if phAsset.mediaType == .image {
            if let img = info[.editedImage] as? UIImage {
                image = img
            } else if let img = info[.originalImage] as? UIImage {
                image = img
            }
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            self.viewModel.sendAndSaveFile(displayName: imageFileName, imageData: imageData)
            // self.viewModel.sendImageFromPhotoLibraty(image: image, imageName: imageFileName, localIdentifier: phAsset.localIdentifier)
            return
        }
        guard phAsset.mediaType == .video else { return }
        PHImageManager
            .default()
            .requestAVAsset(forVideo: phAsset,
                            options: PHVideoRequestOptions(),
                            resultHandler: { (asset, _, _) -> Void in
                                guard let asset = asset as? AVURLAsset,
                                      let videoData = NSData(contentsOf: asset.url) else {
                                    return
                                }
                                self.viewModel.sendAndSaveFile(displayName: imageFileName, imageData: videoData as Data)
                            })
    }

    func saveGIFOrImage(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }
        ) {[weak self] (_, error) in
            if let error = error {
                self?.showAlert(error: error)
            }
        }
    }
    func showAlert(error: Error) {
        let allert = UIAlertController(title: L10n.Conversation.errorSavingImage, message: error.localizedDescription, preferredStyle: .alert)
        allert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(allert, animated: true)
    }
    @objc
    func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            self.showAlert(error: error)
        }
    }

    @objc
    func dismissKeyboard() {
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }

    @objc
    func keyboardDidShow(withNotification notification: Notification) {
        guard let userInfo: Dictionary = notification.userInfo else {
            return
        }
        guard let keyboardFrame: NSValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardRectangle = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardRectangle.height

        if keyboardHeight != self.messageAccessoryView.frame.height {
            self.view.addGestureRecognizer(keyboardDismissTapRecognizer)
        }
        self.updateMessagesOffset()
    }

    func updateMessagesOffset() {
        self.bottomHeight = self.messageAccessoryView.frame.height
        self.bottomAnchor?.constant = -self.bottomHeight
    }

    @objc
    func keyboardWillHide(withNotification notification: Notification) {
        self.updateMessagesOffset()
    }

    func setupNavTitle(profileImageData: Data?, displayName: String? = nil, username: String?) {
        let isPortrait = UIScreen.main.bounds.size.width < UIScreen.main.bounds.size.height
        let imageSize = isPortrait ? CGFloat(36.0) : CGFloat(32.0)
        let imageOffsetY = CGFloat(5.0)
        let infoPadding = CGFloat(8.0)
        let maxNameLength = CGFloat(128.0)
        var userNameYOffset = CGFloat(9.0)
        var nameSize = CGFloat(18.0)
        let navbarFrame = self.navigationController?.navigationBar.frame
        let totalHeight = (44 + (navbarFrame?.origin.y ?? 0)) / 2

        // Replace "< Home" with a back arrow while we are crunching everything to the left side of the bar for now.
        self.navigationController?.navigationBar.backIndicatorImage = UIImage(named: "back_button")
        self.navigationController?.navigationBar.backIndicatorTransitionMaskImage = UIImage(named: "back_button")
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItem.Style.plain, target: nil, action: nil)
        self.navigationItem.setHidesBackButton(false, animated: false)

        let titleView: UIView = UIView.init(frame: CGRect(x: 0, y: 0, width: view.frame.width - 32, height: totalHeight))

        let profileImageView = UIImageView(frame: CGRect(x: 0, y: imageOffsetY, width: imageSize, height: imageSize))
        profileImageView.frame = CGRect.init(x: 0, y: 0, width: imageSize, height: imageSize)
        profileImageView.center = CGPoint.init(x: imageSize / 2, y: titleView.center.y)

        if let profileName = displayName, !profileName.isEmpty {
            profileImageView.addSubview(AvatarView(profileImageData: profileImageData, username: profileName, size: 30))
            titleView.addSubview(profileImageView)
        } else if let bestId = username {
            profileImageView.addSubview(AvatarView(profileImageData: profileImageData, username: bestId, size: 30))
            titleView.addSubview(profileImageView)
        }

        var dnlabelYOffset: CGFloat = 0
        if !isPortrait {
            userNameYOffset = 0
        } else if UIDevice.current.hasNotch {
            if displayName == nil || displayName == "" {
                userNameYOffset = 7
            } else {
                dnlabelYOffset = 2
                userNameYOffset = 18
            }
        } else {
            if displayName == nil || displayName == "" {
                userNameYOffset = 1
            } else {
                dnlabelYOffset = -4
                userNameYOffset = 10
            }
        }

        if let name = displayName, !name.isEmpty {
            let dnlabel: UILabel = UILabel.init(frame: CGRect.init(x: imageSize + infoPadding, y: dnlabelYOffset, width: maxNameLength, height: 20))
            dnlabel.text = name
            dnlabel.font = UIFont.systemFont(ofSize: nameSize)
            dnlabel.textColor = UIColor.jamiMain
            dnlabel.textAlignment = .left
            titleView.addSubview(dnlabel)
            nameSize = 14.0
        }

        if isPortrait || displayName == nil || displayName == "" {
            let frame = CGRect.init(x: imageSize + infoPadding,
                                    y: userNameYOffset,
                                    width: maxNameLength,
                                    height: 24)

            let unlabel: UILabel = UILabel.init(frame: frame)
            unlabel.text = username
            unlabel.font = UIFont.systemFont(ofSize: nameSize)
            unlabel.textColor = UIColor.jamiMain
            unlabel.textAlignment = .left
            titleView.addSubview(unlabel)
        }
        let tapGesture = UITapGestureRecognizer()
        titleView.addGestureRecognizer(tapGesture)
        tapGesture.rx.event
            .throttle(Durations.switchThrottlingDuration.toTimeInterval(), scheduler: MainScheduler.instance)
            .bind(onNext: { [weak self] _ in
                self?.contactTapped()
            })
            .disposed(by: disposeBag)
        titleView.backgroundColor = UIColor.clear

        self.navigationItem.titleView = titleView
    }

    func contactTapped() {
        self.viewModel.showContactInfo()
    }

    private func setRightNavigationButtons() {
        // do not show call buttons for swarm with multiple participants
        if self.viewModel.conversation.value.getParticipants().count > 1 {
            return
        }
        let audioCallItem = UIBarButtonItem()
        audioCallItem.image = UIImage(asset: Asset.callButton)
        audioCallItem.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.placeAudioOnlyCall()
            })
            .disposed(by: self.disposeBag)

        let videoCallItem = UIBarButtonItem()
        videoCallItem.image = UIImage(asset: Asset.videoRunning)
        videoCallItem.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.placeCall()
            })
            .disposed(by: self.disposeBag)

        // Items are from right to left
        if self.viewModel.isAccountSip {
            self.navigationItem.rightBarButtonItem = audioCallItem
        } else {
            self.navigationItem.rightBarButtonItems = [videoCallItem, audioCallItem]
        }
    }

    func setupUI() {
        self.messageAccessoryView.sendButton.contentVerticalAlignment = .fill
        self.messageAccessoryView.sendButton.contentHorizontalAlignment = .fill
        spinnerView.backgroundColor = UIColor.jamiMsgBackground
        self.view.backgroundColor = UIColor.jamiMsgTextFieldBackground

        if self.viewModel.isAccountSip {
            self.messageAccessoryView.frame.size.height = 0
            self.messageAccessoryView.isHidden = true
        }

        self.messageAccessoryView.shareButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.imageTapped()
            })
            .disposed(by: self.disposeBag)

        self.messageAccessoryView.cameraButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.takePicture()
            })
            .disposed(by: self.disposeBag)

        Observable<(Data?, String?, String)>.combineLatest(self.viewModel.profileImageData.asObservable(),
                                                           self.viewModel.displayName.asObservable(),
                                                           self.viewModel.userName.asObservable()) { profileImage, displayName, username in
            return (profileImage, displayName, username)
        }
        .observe(on: MainScheduler.instance)
        .subscribe({ [weak self] profileData -> Void in
            self?.setupNavTitle(profileImageData: profileData.element?.0,
                                displayName: profileData.element?.1,
                                username: profileData.element?.2)
            return
        })
        .disposed(by: self.disposeBag)

        self.setRightNavigationButtons()
        self.viewModel.showCallButton
            .observe(on: MainScheduler.instance)
            .startWith(self.viewModel.haveCurrentCall())
            .subscribe(onNext: { [weak self] show in
                if show {
                    DispatchQueue.main.async {
                        if self?.viewModel.currentCallId.value.isEmpty ?? true {
                            return
                        }
                        self?.currentCallButton.isHidden = false
                        self?.currentCallLabel.isHidden = false
                        self?.callButtonHeightConstraint.constant = 60
                    }
                    return
                }
                self?.currentCallButton.isHidden = true
                self?.currentCallLabel.isHidden = true
                self?.callButtonHeightConstraint.constant = 0
            })
            .disposed(by: disposeBag)
        currentCallButton.rx.tap
            .throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.viewModel.openCall()
            })
            .disposed(by: self.disposeBag)
        viewModel.bestName
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] name in
                guard !name.isEmpty else { return }
                let placeholder = L10n.Conversation.messagePlaceholder + name
                self?.messageAccessoryView.setPlaceholder(placeholder: placeholder)
            })
            .disposed(by: self.disposeBag)
    }

    func placeCall() {
        self.textFieldShouldEndEditing = true
        self.messageAccessoryView.messageTextView.resignFirstResponder()
        self.resignFirstResponder()
        self.viewModel.startCall()
    }

    func placeAudioOnlyCall() {
        self.textFieldShouldEndEditing = true
        self.messageAccessoryView.messageTextView.resignFirstResponder()
        self.resignFirstResponder()
        self.viewModel.startAudioCall()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.textFieldShouldEndEditing = false
        self.messagesLoadingFinished()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.viewModel.setIsComposingMsg(isComposing: false)
        self.textFieldShouldEndEditing = true
        self.viewModel.setMessagesAsRead()
    }

    private func messagesLoadingFinished() {
        self.spinnerView.isHidden = true
    }

    override var inputAccessoryView: UIView {
        return self.messageAccessoryView
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    lazy var messageAccessoryView: MessageAccessoryView = {
        return MessageAccessoryView.loadFromNib()
    }()

    func setupBindings() {
        self.messageAccessoryView.sendButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                guard let payload = self?.messageAccessoryView.messageTextView.text, !payload.isEmpty else {
                    return
                }
                let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self?.messageAccessoryView.messageTextView.text = ""
                    return
                }
                self?.viewModel.setIsComposingMsg(isComposing: false)
                self?.viewModel.sendMessage(withContent: trimmed)
                self?.messageAccessoryView.messageTextView.text = ""
                self?.messageAccessoryView.setEmojiButtonVisibility(hide: false)
            })
            .disposed(by: self.disposeBag)

        self.messageAccessoryView.emojisButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                self?.viewModel.sendMessage(withContent: "👍")
            })
            .disposed(by: self.disposeBag)

        self.messageAccessoryView.messageTextViewHeight.asObservable()
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.updateMessagesOffset()
            })
            .disposed(by: self.disposeBag)

        self.messageAccessoryView.messageTextViewContent.asObservable()
            .subscribe(onNext: { [weak self] _ in
                self?.messageAccessoryView.editingChanges()
            })
            .disposed(by: self.disposeBag)
        self.viewModel.shouldDismiss
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] dismiss in
                guard let self = self, dismiss else { return }
                _ = self.navigationController?.popViewController(animated: true)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
        self.viewModel.showInvitation
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] show in
                guard let self = self else { return }
                if show {
                    if self.view.window?.rootViewController is InvitationViewController {
                        return
                    }
                    self.messageAccessoryView.isHidden = true
                    self.navigationItem.rightBarButtonItems = []
                    self.viewModel.openInvitationView(parentView: self)
                } else {
                    self.messageAccessoryView.isHidden = false
                    self.setRightNavigationButtons()
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    // Avoid the keyboard to be hidden when the Send button is touched
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return textFieldShouldEndEditing
    }

    // MARK: open file

    func openDocument(messageModel: MessageViewModel) {
        let conversation = self.viewModel.conversation.value
        let accountId = self.viewModel.conversation.value.accountId
        guard let url = messageModel.transferedFile(conversationID: conversation.id, accountId: accountId, isSwarm: conversation.isSwarm()),
              FileManager().fileExists(atPath: url.path) else { return }
        let interactionController = UIDocumentInteractionController(url: url)
        interactionController.delegate = self
        interactionController.presentPreview(animated: true)
    }

    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        if let navigationController = self.navigationController {
            return navigationController
        }
        return self
    }

    func presentActivityControllerWithItems(items: [Any]) {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        activityViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxX, width: 0, height: 0)
        self.present(activityViewController, animated: true, completion: nil)
    }

    // MARK: ContactPickerDelegate

    func presentContactPicker(contactPickerVC: ContactPickerViewController) {
        self.addChild(contactPickerVC)
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let newFrame = CGRect(x: 0, y: -statusBarHeight, width: screenWidth, height: screenHeight + statusBarHeight)
        let initialFrame = CGRect(x: 0, y: screenHeight, width: screenWidth, height: screenHeight + statusBarHeight)
        contactPickerVC.view.frame = initialFrame
        self.view.addSubview(contactPickerVC.view)
        contactPickerVC.didMove(toParent: self)
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self = self else { return }
            contactPickerVC.view.frame = newFrame
            self.inputAccessoryView.isHidden = true
        }, completion: {  _ in
        })
    }

    func contactPickerDismissed() {
        self.inputAccessoryView.isHidden = false
    }
}

// MARK: Location sharing
extension ConversationViewController {
    private func locationSharingAction() -> UIAlertAction {
        return UIAlertAction(title: L10n.Alerts.locationSharing, style: .default) { [weak self] _ in
            guard let self = self else { return }

            if self.canShareLocation() && self.isNotAlreadySharingWithThisContact() {
                self.askLocationSharingDuration()
            }
        }
    }

    private func askLocationSharingDuration() {
        let alert = UIAlertController.init(title: L10n.Alerts.locationSharingDurationTitle,
                                           message: nil,
                                           preferredStyle: .alert)

        alert.addAction(.init(title: L10n.Alerts.locationSharingDuration10min, style: .default, handler: { [weak self] _ in
            self?.viewModel.startSendingLocation(duration: 10 * 60)
        }))
        alert.addAction(.init(title: L10n.Alerts.locationSharingDuration1hour, style: .default, handler: { [weak self] _ in
            self?.viewModel.startSendingLocation(duration: 60 * 60)
        }))
        alert.addAction(.init(title: L10n.Alerts.profileCancelPhoto, style: UIAlertAction.Style.cancel))

        self.present(alert, animated: true, completion: nil)
    }

    private func isNotAlreadySharingWithThisContact() -> Bool {
        if self.viewModel.isAlreadySharingLocation() {
            let alert = UIAlertController.init(title: L10n.Alerts.alreadylocationSharing,
                                               message: nil,
                                               preferredStyle: .alert)
            alert.addAction(.init(title: L10n.Global.ok, style: UIAlertAction.Style.cancel))
            self.present(alert, animated: true, completion: nil)

            return false
        }
        return true
    }

    private func canShareLocation() -> Bool {
        if checkLocationAuthorization() {
            return checkLocationAuthorization()
        } else {
            self.showGoToSettingsAlert(title: L10n.Alerts.locationServiceIsDisabled)
            return false
        }
    }

    private func showGoToSettingsAlert(title: String) {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: L10n.Actions.goToSettings, style: .default, handler: { (_) in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, completionHandler: nil)
            }
        }))

        alertController.addAction(UIAlertAction(title: L10n.Actions.cancelAction, style: .cancel, handler: nil))

        self.present(alertController, animated: true, completion: nil)
    }

    private func checkLocationAuthorization() -> Bool {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied: self.showGoToSettingsAlert(title: L10n.Alerts.noLocationPermissionsTitle)
        case .authorizedAlways, .authorizedWhenInUse: return true
        @unknown default: break
        }

        return false
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
