/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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

import MobileCoreServices
import Photos
import PhotosUI
import Reusable
import RxRelay
import RxSwift
import SwiftUI
import SwiftyBeaver
import UIKit

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

enum DocumentPickerMode {
    case picking
    case saving
    case none
}

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class ConversationViewController: UIViewController,
                                  UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                                  StoryboardBased, ViewModelBased, ContactPickerDelegate,
                                  PHPickerViewControllerDelegate {
    // MARK: StateableResponsive

    let disposeBag = DisposeBag()

    let log = SwiftyBeaver.self

    var viewModel: ConversationViewModel!
    var isExecutingDeleteMessage: Bool = false
    private var isLocationSharingDurationLimited: Bool {
        return UserDefaults.standard.bool(forKey: limitLocationSharingDurationKey)
    }

    private var locationSharingDuration: Int {
        return UserDefaults.standard.integer(forKey: locationSharingDurationKey)
    }

    @IBOutlet var currentCallButton: UIButton!
    @IBOutlet var currentCallLabel: UILabel!
    @IBOutlet var scanButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var callButtonHeightConstraint: NSLayoutConstraint!
    var currentDocumentPickerMode: DocumentPickerMode = .none

    let tapAction = BehaviorRelay<Bool>(value: false)
    var screenTapRecognizer: UITapGestureRecognizer!

    private lazy var locationManager: CLLocationManager = .init()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        setupUI()
        setupBindings()
        screenTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        view.addGestureRecognizer(screenTapRecognizer)
        addSwiftUIView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.layer.shadowOpacity = 0
        viewModel.setMessagesAsRead()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavTitle(profileImageData: viewModel.profileImageData.value,
                      displayName: viewModel.displayName.value,
                      username: viewModel.userName.value)
        updateNavigationBarShadow()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.setMessagesAsRead()
    }

    @objc
    func screenTapped() {
        tapAction.accept(true)
    }

    private func addSwiftUIView() {
        viewModel.swiftUIModel.hideNavigationBar
            .subscribe(onNext: { [weak self] hide in
                guard let self = self else { return }
                if self.navigationItem.rightBarButtonItems?.isEmpty == hide { return }
                if hide {
                    self.navigationController?.navigationBar.setBackgroundImage(
                        UIImage(),
                        for: .default
                    )
                    self.navigationItem.titleView = UIView()
                    self.navigationItem.rightBarButtonItems = []
                    self.navigationItem.setHidesBackButton(true, animated: false)
                } else {
                    self.configureNavigationBar()
                    self.setRightNavigationButtons()
                    self.setupNavTitle(profileImageData: self.viewModel.profileImageData.value,
                                       displayName: self.viewModel.displayName.value,
                                       username: self.viewModel.userName.value)
                    self.updateNavigationBarShadow()
                }
            })
            .disposed(by: disposeBag)

        viewModel.swiftUIModel.subscribeScreenTapped(screenTapped: tapAction.asObservable())

        viewModel.swiftUIModel.messagePanelState
            .subscribe(onNext: { [weak self] state in
                guard let self = self, let state = state as? MessagePanelState else { return }
                switch state {
                case let .sendMessage(content, parentId):
                    self.viewModel.sendMessage(withContent: content, parentId: parentId)
                case .sendPhoto:
                    self.takePicture()
                case let .editMessage(content: content, messageId: messageId):
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
                }
            })
            .disposed(by: disposeBag)
        viewModel.swiftUIModel.contextMenuState
            .subscribe(onNext: { [weak self] state in
                guard let self = self, let state = state as? ContextMenu else { return }
                switch state {
                case let .preview(message):
                    self.presentPreview(message: message)
                case let .forward(message):
                    /*
                     Remove the tap gesture to ensure the contact selector
                     can receive taps. The tap gesture should be re-added
                     once the contact picker is dismissed.
                     */
                    self.view.removeGestureRecognizer(self.screenTapRecognizer)
                    self.viewModel.slectContactsToShareMessage(message: message)
                case let .share(items):
                    self.presentActivityControllerWithItems(items: items)
                case let .saveFile(url):
                    self.saveFile(url: url)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
        let messageListView = MessagesListView(model: viewModel.swiftUIModel)
        let swiftUIView = UIHostingController(rootView: messageListView)
        addChild(swiftUIView)
        swiftUIView.view.frame = view.frame
        view.addSubview(swiftUIView.view)
        swiftUIView.view.translatesAutoresizingMaskIntoConstraints = false
        swiftUIView.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        swiftUIView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
            .isActive = true
        swiftUIView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
            .isActive = true
        swiftUIView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0)
            .isActive = true
        swiftUIView.didMove(toParent: self)
        view.backgroundColor = UIColor.systemBackground
        view.sendSubviewToBack(swiftUIView.view)

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

    private func importDocument() {
        currentDocumentPickerMode = .picking
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item])
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        present(documentPicker, animated: true, completion: nil)
    }

    private func showNoPermissionsAlert(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (_: UIAlertAction!) in }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }

    // MARK: photo library

    private func presentBackgroundRecordingAlert() {
        let alert = UIAlertController(
            title: nil,
            message: L10n.DataTransfer.recordInBackgroundWarning,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: L10n.Global.ok,
            style: .default,
            handler: { [weak self] _ in
                UserDefaults.standard.setValue(true, forKey: fileRecordingLimitationInBackgroundKey)
                self?.recordVideoFile()
            }
        ))
        present(alert, animated: true, completion: nil)
    }

    private func canRecordVideoFile() -> Bool {
        /* According to Apple, warning about camera performance in the background
         should be presented for iPad devices running on versions lower than iOS 16
         */
        if #available(iOS 16.0, *) {
            return true
        }

        return UIDevice.current.userInterfaceIdiom != .pad || UserDefaults.standard
            .bool(forKey: fileRecordingLimitationInBackgroundKey)
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
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus
            .authorized {
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus
                .authorized {
                recordVideoFile()
            } else {
                AVCaptureDevice.requestAccess(
                    for: AVMediaType.video,
                    completionHandler: { [weak self] (granted: Bool) in
                        guard let self = self else { return }
                        if granted == true {
                            self.recordVideoFile()
                        } else {
                            self.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                        }
                    }
                )
            }
        } else {
            AVCaptureDevice.requestAccess(
                for: AVMediaType.audio,
                completionHandler: { [weak self] (granted: Bool) in
                    guard let self = self else { return }
                    if granted == true {
                        if AVCaptureDevice
                            .authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus
                            .authorized {
                            self.recordVideoFile()
                        } else {
                            AVCaptureDevice.requestAccess(
                                for: AVMediaType.video,
                                completionHandler: { (granted: Bool) in
                                    if granted == true {
                                        self.recordVideoFile()
                                    } else {
                                        self
                                            .showNoPermissionsAlert(title: L10n.Alerts
                                                                        .noMediaPermissionsTitle)
                                    }
                                }
                            )
                        }
                    } else {
                        self.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                    }
                }
            )
        }
    }

    func recordAudio() {
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == AVAuthorizationStatus
            .authorized {
            viewModel.recordAudioFile()
        } else {
            AVCaptureDevice.requestAccess(
                for: AVMediaType.audio,
                completionHandler: { [weak self] (granted: Bool) in
                    guard let self = self else { return }
                    if granted == true {
                        self.viewModel.recordAudioFile()
                    } else {
                        self.showNoPermissionsAlert(title: L10n.Alerts.noMediaPermissionsTitle)
                    }
                }
            )
        }
    }

    func takePicture() {
        if UIImagePickerController
            .isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerController.SourceType.camera
            imagePicker.cameraDevice = UIImagePickerController.CameraDevice.rear
            imagePicker.modalPresentationStyle = .overFullScreen
            present(imagePicker, animated: false, completion: nil)
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
        for result in results {
            let imageFileName: String = result.itemProvider.suggestedName ?? "file"
            let provider = result.itemProvider
            switch getAssetTypeFrom(itemProvider: provider) {
            case .gif:
                provider
                    .loadDataRepresentation(forTypeIdentifier: UTType.gif
                                                .identifier) { [weak self] data, _ in
                        guard let self = self,
                              let data = data else { return }
                        self.viewModel.sendAndSaveFile(
                            displayName: imageFileName + ".gif",
                            imageData: data
                        )
                    }
            case .image:
                provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    guard let self = self,
                          let image = object as? UIImage,
                          let imageData = image.jpegData(compressionQuality: 0.5) else { return }
                    self.viewModel.sendAndSaveFile(
                        displayName: imageFileName + ".jpeg",
                        imageData: imageData
                    )
                }
            case .video:
                provider
                    .loadDataRepresentation(forTypeIdentifier: UTType.movie
                                                .identifier) { [weak self] data, _ in
                        guard let self = self,
                              let data = data else { return }
                        self.viewModel.sendAndSaveFile(
                            displayName: imageFileName + ".mov",
                            imageData: data
                        )
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
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController
                                .InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)

        var image: UIImage!

        if picker.sourceType == UIImagePickerController.SourceType.camera {
            // image from camera
            if let img = info[.editedImage] as? UIImage {
                image = img
            } else if let img = info[.originalImage] as? UIImage {
                image = fixImageOrientation(image: img)
            }
            // copy image to tmp
            let imageFileName = "IMG.jpeg"
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            viewModel.sendAndSaveFile(displayName: imageFileName, imageData: imageData)
            return
        }
        guard picker.sourceType == UIImagePickerController.SourceType.photoLibrary,
              let phAsset = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset
        else { return }
        let imageFileName = phAsset.value(forKey: "filename") as? String ?? "Unknown"
        // image from library
        if phAsset.mediaType == .image {
            if let img = info[.editedImage] as? UIImage {
                image = img
            } else if let img = info[.originalImage] as? UIImage {
                image = img
            }
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            viewModel.sendAndSaveFile(displayName: imageFileName, imageData: imageData)
            // self.viewModel.sendImageFromPhotoLibraty(image: image, imageName: imageFileName, localIdentifier: phAsset.localIdentifier)
            return
        }
        guard phAsset.mediaType == .video else { return }
        PHImageManager
            .default()
            .requestAVAsset(forVideo: phAsset,
                            options: PHVideoRequestOptions(),
                            resultHandler: { asset, _, _ in
                                guard let asset = asset as? AVURLAsset,
                                      let videoData = NSData(contentsOf: asset.url)
                                else {
                                    return
                                }
                                self.viewModel.sendAndSaveFile(
                                    displayName: imageFileName,
                                    imageData: videoData as Data
                                )
                            })
    }

    // swiftlint:disable function_body_length
    func setupNavTitle(profileImageData: Data?, displayName: String? = nil, username: String?) {
        let isPortrait = UIScreen.main.bounds.size.width < UIScreen.main.bounds.size.height
        let imageSize = isPortrait ? CGFloat(36.0) : CGFloat(32.0)
        let imageOffsetY = CGFloat(5.0)
        let infoPadding = CGFloat(8.0)
        let maxNameLength = CGFloat(128.0)
        var userNameYOffset = CGFloat(9.0)
        var nameSize = CGFloat(18.0)
        let navbarFrame = navigationController?.navigationBar.frame
        let totalHeight = (44 + (navbarFrame?.origin.y ?? 0)) / 2

        // Replace "< Home" with a back arrow while we are crunching everything to the left side of
        // the bar for now.
        navigationController?.navigationBar.backIndicatorImage = UIImage(named: "back_button")
        navigationController?.navigationBar
            .backIndicatorTransitionMaskImage = UIImage(named: "back_button")
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "",
            style: UIBarButtonItem.Style.plain,
            target: nil,
            action: nil
        )
        navigationItem.setHidesBackButton(false, animated: false)

        let titleView = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: view.frame.width - 32,
            height: totalHeight
        ))

        let profileImageView = UIImageView(frame: CGRect(
            x: 0,
            y: imageOffsetY,
            width: imageSize,
            height: imageSize
        ))
        profileImageView.frame = CGRect(x: 0, y: 0, width: imageSize, height: imageSize)
        profileImageView.center = CGPoint(x: imageSize / 2, y: titleView.center.y)

        if let profileName = displayName, !profileName.isEmpty {
            profileImageView.addSubview(AvatarView(
                profileImageData: profileImageData,
                username: profileName,
                size: 30
            ))
            titleView.addSubview(profileImageView)
        } else if let bestId = username {
            profileImageView.addSubview(AvatarView(
                profileImageData: profileImageData,
                username: bestId,
                size: 30
            ))
            titleView.addSubview(profileImageView)
        }

        var dnlabelYOffset: CGFloat = 0
        if !isPortrait {
            userNameYOffset = 0
        } else if UIDevice.current.hasNotch {
            if displayName == nil || displayName == "" {
                userNameYOffset = 7
            } else if username == nil || username == "" {
                dnlabelYOffset = 7
            } else {
                dnlabelYOffset = 2
                userNameYOffset = 18
            }
        } else {
            if displayName == nil || displayName == "" {
                userNameYOffset = 1
            } else if username == nil || username == "" {
                dnlabelYOffset = 1
            } else {
                dnlabelYOffset = -4
                userNameYOffset = 10
            }
        }

        if let name = displayName, !name.isEmpty {
            let dnlabel = UILabel(frame: CGRect(
                x: imageSize + infoPadding,
                y: dnlabelYOffset,
                width: maxNameLength,
                height: 20
            ))
            dnlabel.text = name
            dnlabel.font = UIFont.systemFont(ofSize: nameSize)
            dnlabel.textColor = UIColor.jamiButtonDark
            dnlabel.textAlignment = .left
            titleView.addSubview(dnlabel)
            nameSize = 14.0
        }

        if isPortrait || displayName == nil || displayName == "" {
            let frame = CGRect(x: imageSize + infoPadding,
                               y: userNameYOffset,
                               width: maxNameLength,
                               height: 24)

            let unlabel = UILabel(frame: frame)
            unlabel.text = username
            unlabel.font = UIFont.systemFont(ofSize: nameSize)
            unlabel.textColor = UIColor.jamiButtonDark
            unlabel.textAlignment = .left
            titleView.addSubview(unlabel)
        }
        let tapGesture = UITapGestureRecognizer()
        titleView.addGestureRecognizer(tapGesture)
        tapGesture.rx.event
            .throttle(
                Durations.switchThrottlingDuration.toTimeInterval(),
                scheduler: MainScheduler.instance
            )
            .bind(onNext: { [weak self] _ in
                self?.contactTapped()
            })
            .disposed(by: disposeBag)
        titleView.backgroundColor = UIColor.clear

        navigationItem.titleView = titleView
    }

    func contactTapped() {
        viewModel.showContactInfo()
    }

    private func setRightNavigationButtons() {
        // do not show call buttons for swarm with multiple participants
        if viewModel.conversation.getParticipants().count > 1 {
            return
        }
        let audioCallItem = UIBarButtonItem()
        audioCallItem.image = UIImage(asset: Asset.callButton)
        audioCallItem.rx.tap.throttle(
            Durations.halfSecond.toTimeInterval(),
            scheduler: MainScheduler.instance
        )
        .subscribe(onNext: { [weak self] in
            self?.placeAudioOnlyCall()
        })
        .disposed(by: disposeBag)

        let videoCallItem = UIBarButtonItem()
        videoCallItem.image = UIImage(asset: Asset.videoRunning)
        videoCallItem.rx.tap.throttle(
            Durations.halfSecond.toTimeInterval(),
            scheduler: MainScheduler.instance
        )
        .subscribe(onNext: { [weak self] in
            self?.placeCall()
        })
        .disposed(by: disposeBag)

        // Items are from right to left
        if viewModel.isAccountSip {
            navigationItem.rightBarButtonItem = audioCallItem
        } else {
            navigationItem.rightBarButtonItems = [videoCallItem, audioCallItem]
        }
    }

    func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        Observable<(Data?, String?, String)>.combineLatest(
            viewModel.profileImageData.asObservable(),
            viewModel.displayName.asObservable(),
            viewModel.userName.asObservable()
        ) { profileImage, displayName, username in
            (profileImage, displayName, username)
        }
        .observe(on: MainScheduler.instance)
        .subscribe { [weak self] profileData in
            self?.setupNavTitle(profileImageData: profileData.element?.0,
                                displayName: profileData.element?.1,
                                username: profileData.element?.2)
        }
        .disposed(by: disposeBag)

        setRightNavigationButtons()
        viewModel.showCallButton
            .observe(on: MainScheduler.instance)
            .startWith(viewModel.haveCurrentCall())
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
            .disposed(by: disposeBag)
    }

    func placeCall() {
        viewModel.startCall()
    }

    func placeAudioOnlyCall() {
        viewModel.startAudioCall()
    }

    func setupBindings() {
        viewModel.shouldDismiss
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] dismiss in
                guard let self = self, dismiss else { return }
                _ = self.navigationController?.popViewController(animated: true)
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }

    func updateNavigationBarShadow() {
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
        navigationController?.navigationBar.layer.shadowOpacity = 0.1
    }

    // MARK: ContactPickerDelegate

    func presentContactPicker(contactPickerVC: ContactPickerViewController) {
        addChild(contactPickerVC)
        var statusBarHeight: CGFloat = 0
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let statusBarManager = windowScene.statusBarManager {
            statusBarHeight = statusBarManager.statusBarFrame.height
        }
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let newFrame = CGRect(
            x: 0,
            y: -statusBarHeight,
            width: screenWidth,
            height: screenHeight + statusBarHeight
        )
        let initialFrame = CGRect(
            x: 0,
            y: screenHeight,
            width: screenWidth,
            height: screenHeight + statusBarHeight
        )
        contactPickerVC.view.frame = initialFrame
        view.addSubview(contactPickerVC.view)
        contactPickerVC.didMove(toParent: self)
        UIView.animate(withDuration: 0.2, animations: { [weak contactPickerVC] in
            guard let contactPickerVC = contactPickerVC else { return }
            contactPickerVC.view.frame = newFrame
        }, completion: { _ in
        })
    }
}

// MARK: Location sharing

extension ConversationViewController {
    func startLocationSharing() {
        if checkLocationAuthorization(), isNotAlreadySharingWithThisContact() {
            if isLocationSharingDurationLimited {
                viewModel.startSendingLocation(duration: TimeInterval(locationSharingDuration * 60))
            } else {
                viewModel.startSendingLocation()
            }
        }
    }

    private func isNotAlreadySharingWithThisContact() -> Bool {
        if viewModel.isAlreadySharingMyLocation() {
            let alert = UIAlertController(title: L10n.Alerts.alreadylocationSharing,
                                          message: nil,
                                          preferredStyle: .alert)
            alert.addAction(.init(title: L10n.Global.ok, style: UIAlertAction.Style.cancel))
            present(alert, animated: true, completion: nil)

            return false
        }
        return true
    }

    private func showGoToSettingsAlert(title: String) {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(
            title: L10n.Actions.goToSettings,
            style: .default,
            handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, completionHandler: nil)
                }
            }
        ))

        alertController.addAction(UIAlertAction(
            title: L10n.Global.cancel,
            style: .cancel,
            handler: nil
        ))

        present(alertController, animated: true, completion: nil)
    }

    private func checkLocationAuthorization() -> Bool {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .restricted,
             .denied: showGoToSettingsAlert(title: L10n.Alerts.noLocationPermissionsTitle)
        case .authorizedAlways, .authorizedWhenInUse: return true
        @unknown default: break
        }
        return false
    }
}

extension ConversationViewController: ContactPickerViewControllerDelegate {
    func contactPickerDismissed() {
        view.addGestureRecognizer(screenTapRecognizer)
        setupNavTitle(profileImageData: viewModel.profileImageData.value,
                      displayName: viewModel.displayName.value,
                      username: viewModel.userName.value)
        updateNavigationBarShadow()
    }
}

extension ConversationViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
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

extension ConversationViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_: UIDocumentInteractionController)
    -> UIViewController {
        if let navigationController = navigationController {
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
        } else {
            openDocument(url: url)
        }
    }

    func presentActivityControllerWithItems(items: [Any]) {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.sourceView = view
        activityViewController.popoverPresentationController?
            .permittedArrowDirections = UIPopoverArrowDirection()
        activityViewController.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.maxX,
            width: 0,
            height: 0
        )
        present(activityViewController, animated: true, completion: nil)
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
    func image(_: UIImage, didFinishSavingWithError error: Error?,
               contextInfo _: UnsafeRawPointer) {
        if let error = error {
            showAlert(error: error)
        }
    }

    func showAlert(error: Error) {
        let allert = UIAlertController(
            title: L10n.Conversation.errorSavingImage,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        allert.addAction(UIAlertAction(title: "OK", style: .default))
        present(allert, animated: true)
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
        present(documentPicker, animated: true, completion: nil)
    }

    func presentPlayer(message: MessageContentVM) {
        viewModel.openFullScreenPreview(
            parentView: self,
            viewModel: message.player,
            image: nil,
            initialFrame: CGRect.zero,
            delegate: message
        )
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
