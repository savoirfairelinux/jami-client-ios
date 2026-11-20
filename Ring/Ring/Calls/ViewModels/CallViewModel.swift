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

import Foundation
import UIKit
import Combine

enum CallChromePolicy {
    static func canAutoHide(status: CallStatus, hasVideo: Bool) -> Bool {
        status == .current && hasVideo
    }
}

struct CanvasState: Equatable {
    let tiles: [CanvasTileModel]
    let mode: CanvasLayoutMode
    let style: CanvasTileStyle
    let scalingOverrides: [String: VideoScalingPolicy]

    init(tiles: [CanvasTileModel] = [],
         mode: CanvasLayoutMode = .grid,
         style: CanvasTileStyle = .plain,
         scalingOverrides: [String: VideoScalingPolicy] = [:]) {
        self.tiles = tiles
        self.mode = mode
        self.style = style
        self.scalingOverrides = scalingOverrides
    }

    var showsFloatingPreview: Bool {
        tiles.contains { $0.participant.isLocalPreview }
            && tiles.contains { !$0.participant.isLocalPreview }
    }
}

struct PrimaryVideo: Equatable {
    let tileId: String
    let showsWholeFrame: Bool
}

@MainActor
final class CallViewModel: ObservableObject { // swiftlint:disable:this type_body_length

    // MARK: - Published state

    @Published private(set) var call: CallState?
    @Published private(set) var conference: ConferenceState?
    @Published private(set) var controls: CallControlsModel?
    @Published private(set) var canvas = CanvasState()

    var tiles: [CanvasTileModel] { canvas.tiles }
    var canvasMode: CanvasLayoutMode { canvas.mode }
    @Published private(set) var statusLine = ""
    @Published private(set) var shouldDismiss = false
    @Published var showsDialpad = false
    @Published private(set) var canStartPictureInPicture = false
    @Published private(set) var showsReturnCapsule = false
    @Published var showsParticipants = false
    @Published private(set) var participantRows: [ConferenceParticipantRow] = []
    @Published private(set) var pendingRows: [PendingParticipantRow] = []
    @Published private(set) var canAddParticipant = false
    @Published var showsMoreActions = false
    private var pendingMoreAction: CallControlIntent?
    @Published private(set) var speakerActive = false
    private var localCameraOn: Bool?
    @Published private(set) var chromeVisible = true
    @Published private(set) var contentHidden = false
    @Published private(set) var primaryVideo: PrimaryVideo?

    var showsChrome: Bool { chromeVisible && !contentHidden }

    var controlsPlan: CallControlsLayout.Plan? {
        controls.map { controls in
            CallControlsLayout.plan(
                .init(model: controls,
                      speakerActive: speakerActive,
                      canMinimize: call?.status.isTerminal == false,
                      canAddParticipant: canAddParticipant,
                      isHandRaised: localHandRaised,
                      showsFullVideo: primaryVideo?.showsWholeFrame))
        }
    }

    @Published private(set) var header = CallHeaderModel.empty

    // MARK: - Dependencies

    private let callService: CallService
    private let videoService: VideoService
    private let audio: AudioService
    private let profileService: ProfilesService
    private let nameService: NameService
    private let isSipAccount: Bool
    private let localJamiId: String
    private let localDeviceId: String

    var onAddParticipant: (() -> Void)?
    var onMinimize: ((CallConversationRoute) -> Void)?
    var onRestore: PiPRestoreHandler?

    private let pip: PiPControlling
    private let orientationMonitor = DeviceOrientationMonitor()
    private let tileComposer: CallTileComposer
    private var callId: CallId
    private var eventTask: Task<Void, Never>?
    private var durationTimer: AnyCancellable?
    private var audioCancellable: AnyCancellable?
    private var autoHideWork: DispatchWorkItem?
    private var wasAutoHideable = false
    private let autoHideDelay: TimeInterval
    private var avatars: CallParticipantAvatars?
    private var peerName = ""
    private var addParticipantAfterRosterDismissal = false
    private var observedPeerURI: String?
    private var peerNameCancellable: AnyCancellable?
    private var chromeCancellable: AnyCancellable?
    private var chromePinCancellable: AnyCancellable?
    /// A sheet is open over the call, so the controls stay until it closes.
    private var chromePinned = false

    private enum PiPFeed: Equatable {
        case participant(PiPSourceSelector.Selection)
        case localCamera(CGAffineTransform)

        var participant: PiPSourceSelector.Selection? {
            if case .participant(let selection) = self { return selection }
            return nil
        }
    }

    private var pipFeed: PiPFeed?
    private weak var pipDistributor: FrameDistributor?
    private var scalingOverrides: [String: VideoScalingPolicy] = [:]

    private enum PiPState {
        case inactive
        case minimized
    }

    private var pipState = PiPState.inactive
    private var frozenForRecomposition = false
    private var revealWork: DispatchWorkItem?
    private static let revealFallbackDelay: TimeInterval = 1

    init(call: CallState,
         callService: CallService,
         videoService: VideoService,
         audio: AudioService,
         profileService: ProfilesService,
         nameService: NameService,
         isSipAccount: Bool = false,
         localJamiId: String = "",
         localDeviceId: String,
         pipController: PiPControlling = PiPController(),
         autoHideDelay: TimeInterval = 4) {
        self.callId = call.id
        self.autoHideDelay = autoHideDelay
        self.callService = callService
        self.videoService = videoService
        self.audio = audio
        self.profileService = profileService
        self.nameService = nameService
        self.isSipAccount = isSipAccount
        self.localJamiId = localJamiId
        self.localDeviceId = localDeviceId
        self.pip = pipController
        self.tileComposer = CallTileComposer(videoService: videoService,
                                             localJamiId: localJamiId,
                                             localDeviceId: localDeviceId)

        audioCancellable = audio.speakerActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.speakerActive = active
            }
        pip.onDidFailToStart = { [weak self] in
            self?.fallBackToReturnCapsule()
        }
        pip.onDidStop = { [weak self] in
            self?.revealContent()
        }
        pip.onRestoreRequested = { [weak self] completion in
            guard let self = self else {
                completion(false)
                return
            }
            self.showsDialpad = false
            self.showsParticipants = false
            self.showsMoreActions = false
            if self.pipState == .minimized {
                self.hideContentUntilWindowGrows()
            }
            self.requestRestore(then: completion)
        }
        apply(call: call)
        rebuildTiles()
        startObserving(callId: call.id, fallback: call)
        chromeCancellable = $chromeVisible
            .removeDuplicates()
            .sink { [weak self] visible in self?.setDurationTicking(visible) }
        chromePinCancellable = Publishers.CombineLatest3($showsMoreActions, $showsParticipants,
                                                         $showsDialpad)
            .map { $0 || $1 || $2 }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] pinned in self?.chromePinChanged(pinned) }
    }

    deinit {
        eventTask?.cancel()
        autoHideWork?.cancel()
        revealWork?.cancel()
    }

    // MARK: - Chrome visibility

    func screenTapped() {
        guard chromeCanAutoHide else { return }
        chromeVisible ? hideChrome() : revealChrome()
    }

    func revealChrome() {
        chromeVisible = true
        scheduleAutoHide()
    }

    func registerChromeInteraction() {
        guard chromeCanAutoHide else { return }
        revealChrome()
    }

    private var chromeCanAutoHide: Bool {
        guard let call = call else { return false }
        let hasVideo = call.effectiveMedia(in: conference).hasVideo
        return CallChromePolicy.canAutoHide(status: call.status, hasVideo: hasVideo)
    }

    private func hideChrome() {
        cancelAutoHide()
        chromeVisible = false
    }

    private func updateChromeForState() {
        let canHide = chromeCanAutoHide
        if canHide && !wasAutoHideable {
            scheduleAutoHide()
        } else if !canHide {
            cancelAutoHide()
            chromeVisible = true
        }
        wasAutoHideable = canHide
    }

    private func chromePinChanged(_ pinned: Bool) {
        chromePinned = pinned
        guard chromeCanAutoHide else { return }
        revealChrome()
    }

    private func scheduleAutoHide() {
        cancelAutoHide()
        guard chromeCanAutoHide, !chromePinned else { return }
        let work = DispatchWorkItem { [weak self] in self?.chromeVisible = false }
        autoHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay, execute: work)
    }

    private func cancelAutoHide() {
        autoHideWork?.cancel()
        autoHideWork = nil
    }

    // MARK: - Call observation

    private func startObserving(callId: CallId, fallback: CallState? = nil) {
        let previousTask = eventTask
        let callService = self.callService
        eventTask = Task { [weak self] in
            let events = await callService.events(for: callId, fallback: fallback)
            for await event in events {
                if Task.isCancelled { return }
                guard let self = self else { return }
                self.consume(event: event)
            }
        }
        previousTask?.cancel()
    }

    private func consume(event: CallSystemEvent) {
        switch event {
        case let .callAdded(call), let .callUpdated(call):
            guard call.id == callId else { return }
            apply(call: call)
            rebuildTiles()
        case let .callEnded(call, _):
            guard call.id == callId else { return }
            if call.status != .terminated(.endedLocally),
               let conference = conference,
               let survivor = conference.memberCallIds.first(where: { $0 != callId }) {
                retarget(to: survivor)
                return
            }
            self.call = call
            updatePiPSource()
            stopDurationTimer()
            shouldDismiss = true
        case let .callMatched(replaced, matched):
            guard replaced == callId else { return }
            retarget(to: matched.id)
        case let .conferenceUpdated(conference):
            guard call?.conferenceId == conference.id
                    || conference.memberCallIds.contains(callId) else { return }
            updateRecompositionFreeze(previous: self.conference, incoming: conference)
            self.conference = conference
            rebuildCanvas(mode: daemonCanvasMode())
            rebuildRows()
            rebuildControlsAndCapabilities()
            updateChromeForState()
            updatePiPSource()
        case let .conferenceEnded(confId, remainingCallId):
            guard conference?.id == confId else { return }
            conference = nil
            rebuildCanvas(mode: .grid)
            rebuildRows()
            if let remaining = remainingCallId, remaining != callId {
                retarget(to: remaining)
            } else {
                rebuildControlsAndCapabilities()
                updateChromeForState()
                updatePiPSource()
            }
        default:
            break
        }
    }

    var currentCallId: CallId { callId }

    private func retarget(to newCallId: CallId) {
        guard newCallId != callId else { return }
        callId = newCallId
        startObserving(callId: newCallId)
    }

    private func apply(call: CallState) {
        self.call = call
        let cameraOn = !call.effectiveMedia(in: conference).isVideoMuted
        if localCameraOn == false && cameraOn {
            audio.cameraTurnedOn()
        }
        localCameraOn = cameraOn
        configureIdentity(for: call)
        rebuildRows()
        rebuildControlsAndCapabilities()
        refreshStatusLine()
        updateChromeForState()
        updatePiPSource()
    }

    private func configureIdentity(for call: CallState) {
        if avatars == nil {
            avatars = CallParticipantAvatars(accountId: call.accountId,
                                             profileService: profileService,
                                             nameService: nameService,
                                             localJamiId: localJamiId)
        }
        let peerURI = call.peerUri
        guard peerURI != observedPeerURI else { return }
        peerNameCancellable?.cancel()
        peerNameCancellable = nil
        observedPeerURI = peerURI
        peerName = ""
        guard !peerURI.isEmpty, let avatars = avatars else { return }
        peerNameCancellable = avatars.provider(forUri: peerURI).$profileName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                guard let self = self, self.observedPeerURI == peerURI,
                      !name.isEmpty else { return }
                self.peerName = name
                self.rebuildHeader()
            }
    }

    private func rebuildHeader() {
        let next = CallHeaderModel(call: call, isConference: conference != nil,
                                   rows: participantRows, pending: pendingRows,
                                   peerName: peerName)
        if next != header { header = next }
    }

    private func daemonCanvasMode() -> CanvasLayoutMode {
        guard let conference = conference,
              conference.participants.count > 1,
              let active = conference.participants.first(where: \.isActive) else {
            return .grid
        }
        let isLocalSwarmParticipant = call?.peerUri.hasPrefix("swarm:") == true
            && active.isLocalDevice(
                localJamiId: localJamiId,
                localDeviceId: localDeviceId,
                isHostedLocally: conference.isHost)
        let activeId = isLocalSwarmParticipant ? CanvasParticipant.localId : active.id
        let othersVisible = conference.participants.contains {
            $0.id != active.id && $0.frame.width > 0 && $0.frame.height > 0
        }
        return othersVisible ? .spotlight(activeId) : .fullscreen(activeId)
    }

    private func updateRecompositionFreeze(previous: ConferenceState?,
                                           incoming: ConferenceState) {
        guard let previous = previous else {
            frozenForRecomposition = false
            return
        }
        let previousFrames = Dictionary(previous.participants.map { ($0.id, $0.frame) },
                                        uniquingKeysWith: { first, _ in first })
        let geometryChanged = incoming.participants.contains {
            previousFrames[$0.id] != $0.frame
        }
        if geometryChanged {
            frozenForRecomposition = false
        } else if incoming.layout != previous.layout {
            frozenForRecomposition = true
        }
    }

    // MARK: - Tiles

    private func rebuildTiles() {
        rebuildCanvas(mode: canvas.mode)
    }

    private func rebuildCanvas(mode: CanvasLayoutMode) {
        let composition = tileComposer.compose(
            call: call, conference: conference, avatars: avatars,
            frozenForRecomposition: frozenForRecomposition)
        let tileIds = Set(composition.tiles.map(\.participant.id))
        scalingOverrides = scalingOverrides.filter { tileIds.contains($0.key) }
        let state = CanvasState(
            tiles: composition.tiles,
            mode: mode,
            style: composition.style,
            scalingOverrides: scalingOverrides)
        if state != canvas {
            canvas = state
            syncPiPVideoTile()
        }
    }

    // MARK: - Duration

    private func refreshStatusLine() {
        let next = CallHeaderModel.statusLine(for: call)
        if next != statusLine { statusLine = next }
    }

    /// The duration only exists to be read, so it ticks only while the chrome shows it.
    private func setDurationTicking(_ ticking: Bool) {
        guard ticking else { return stopDurationTimer() }
        refreshStatusLine()
        guard durationTimer == nil else { return }
        durationTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshStatusLine() }
    }

    private func stopDurationTimer() {
        durationTimer?.cancel()
        durationTimer = nil
    }

    // MARK: - Intents

    // swiftlint:disable:next cyclomatic_complexity
    func perform(_ intent: CallControlIntent) {
        registerChromeInteraction()
        switch intent {
        case .toggleMic: toggleMuteAudio()
        case .toggleCamera: toggleMuteVideo()
        case .toggleAudioOutput: toggleSpeaker()
        case .hangUp: hangUp()
        case .flipCamera: switchCamera()
        case .toggleHold: toggleHold()
        case .minimize: minimize()
        case .showDialpad: showsDialpad = true
        case .toggleRaiseHand: toggleRaiseHand()
        case .addParticipant: addParticipantTapped()
        case .toggleFullVideo: toggleFullVideo()
        }
    }

    func primaryVideoChanged(_ video: PrimaryVideo?) {
        guard video != primaryVideo else { return }
        primaryVideo = video
    }

    func videoScalingChosen(_ policy: VideoScalingPolicy, forTileId id: String) {
        scalingOverrides[id] = policy
        rebuildTiles()
    }

    private func toggleFullVideo() {
        guard let video = primaryVideo else { return }
        videoScalingChosen(video.showsWholeFrame ? .aspectFill : .aspectFit,
                           forTileId: video.tileId)
    }

    func accept(withVideo: Bool) {
        Task { await callService.accept(callId, withVideo: withVideo) }
    }

    func hangUp() {
        shouldDismiss = true
        if let conference = conference, conference.isHost {
            let confId = conference.id
            Task { await callService.hangUpConference(confId) }
            return
        }
        Task { await callService.hangUp(callId) }
    }

    func toggleMuteAudio() {
        let callId = self.callId
        Task {
            await callService.toggleMute(callId, label: .defaultAudio)
        }
    }

    func toggleMuteVideo() {
        let callId = self.callId
        Task {
            await callService.toggleMute(callId, label: .defaultVideo)
        }
    }

    func toggleHold() {
        guard let controls = controls, controls.canHold || controls.canResume else { return }
        let hold = controls.canHold
        if let conference = conference, conference.isHost {
            let conferenceId = conference.id
            Task { await callService.holdConference(conferenceId, hold) }
            return
        }
        let callId = self.callId
        Task { await callService.hold(callId, hold) }
    }

    func toggleSpeaker() {
        audio.toggleSpeaker()
    }

    func switchCamera() {
        Task { [weak self] in
            guard let self = self else { return }
            await self.videoService.switchCamera()
            self.rebuildTiles()
            self.updatePiPSource()
        }
    }

    func screenAppeared() {
        orientationMonitor.start { [weak self] input in
            guard let self = self,
                  self.videoService.setCameraOrientation(input) else { return }
            self.rebuildTiles()
            self.updatePiPSource()
        }
    }

    func screenDisappeared() {
        guard pipState != .minimized else { return }
        orientationMonitor.stop()
    }

    func playDTMF(_ code: String) {
        callService.playDTMF(code: code)
    }

    func minimize() {
        guard canStartPictureInPicture else {
            minimizeToReturnCapsule()
            return
        }
        minimizeToPictureInPicture()
    }

    func returnToCall() {
        requestRestore()
    }

    private func minimizeToReturnCapsule() {
        guard let route = CallConversationRoute(call: call, conference: conference) else { return }
        showsReturnCapsule = true
        onMinimize?(route)
    }

    func minimizeToPictureInPicture() {
        guard let route = CallConversationRoute(call: call, conference: conference) else { return }
        pipState = .minimized
        pip.start()
        onMinimize?(route)
    }

    func tileTapped(_ participantId: String) {
        if conference != nil {
            showsParticipants = true
            return
        }
        let nextMode: CanvasLayoutMode
        switch canvas.mode {
        case .fullscreen:
            nextMode = .grid
        case .grid, .spotlight:
            guard participantId != CanvasParticipant.localId, tiles.count > 1 else { return }
            nextMode = .fullscreen(participantId)
        }
        rebuildCanvas(mode: nextMode)
    }

    // MARK: - Conference

    func avatarProvider(forUri uri: String) -> AvatarProvider {
        let resolver = avatars ?? makeAvatars()
        return resolver.provider(forUri: uri)
    }

    private func makeAvatars() -> CallParticipantAvatars {
        let resolver = CallParticipantAvatars(
            accountId: call?.accountId ?? conference?.accountId ?? "",
            profileService: profileService,
            nameService: nameService,
            localJamiId: localJamiId)
        avatars = resolver
        return resolver
    }

    var canModerateConference: Bool {
        conference?.isHost == true || participantRows.contains { $0.isLocal && $0.isModerator }
    }

    private func rebuildControlsAndCapabilities() {
        guard let call = call else {
            controls = nil
            canAddParticipant = false
            return
        }
        controls = CallControlsModel(call: call, conference: conference,
                                     isSipAccount: isSipAccount,
                                     localJamiId: localJamiId, localDeviceId: localDeviceId)
        canAddParticipant = call.status.isOngoing && !isSipAccount
            && (conference == nil || canModerateConference)
    }

    var localHandRaised: Bool {
        participantRows.first { $0.isLocal }?.isHandRaised ?? false
    }

    private func toggleRaiseHand() {
        guard let confId = conference?.id else { return }
        let raised = !localHandRaised
        Task { await callService.raiseHand("", in: confId, deviceId: "", raised: raised) }
    }

    func showGridLayout() {
        guard let confId = conference?.id else { return }
        Task { await callService.setLayout(.grid, in: confId) }
    }

    /// The daemon reports conference infos continuously — publish only real changes.
    private func rebuildRows() {
        let rows: [ConferenceParticipantRow]
        // `conferenceCreated` lands before the first infos, so a conference with no
        // participants yet is still the two people already talking — not nobody.
        if let conference = conference, !conference.participants.isEmpty {
            rows = ConferenceParticipants.rows(from: conference,
                                               localJamiId: localJamiId,
                                               localDeviceId: localDeviceId,
                                               peerUri: call?.peerUri ?? "")
        } else if let call = call, call.status.isOngoing {
            rows = ConferenceParticipants.rows(from: call, localJamiId: localJamiId)
        } else {
            rows = []
        }
        let pending = ConferenceParticipants.pendingRows(from: call?.pendingInvites ?? [])
        if rows != participantRows { participantRows = rows }
        if pending != pendingRows { pendingRows = pending }
        rebuildHeader()
    }

    func cancelInvite(_ invitedCallId: CallId) {
        Task { await callService.hangUp(invitedCallId) }
    }

    func perform(_ item: ConferenceMenuItem, on participantId: String) {
        guard let conference = conference,
              let info = conference.participants.first(where: { $0.id == participantId })
        else { return }
        let confId = conference.id
        let targetUri = info.resolvedUri(localJamiId: localJamiId,
                                         peerUri: call?.peerUri ?? "",
                                         isHostedLocally: conference.isHost)
        Task {
            switch item {
            case .maximize:
                await callService.setActiveParticipant(targetUri, in: confId)
                let next: ConferenceLayoutMode =
                    conference.layout == .grid ? .oneWithSmall : .one
                await callService.setLayout(next, in: confId)
            case .minimize:
                let next: ConferenceLayoutMode =
                    conference.layout == .one ? .oneWithSmall : .grid
                await callService.setLayout(next, in: confId)
            case .muteAudio:
                await callService.muteStream(targetUri, in: confId,
                                             deviceId: info.device,
                                             streamId: info.sinkId.raw,
                                             muted: !info.isAudioModeratorMuted)
            case .setModerator:
                await callService.setModerator(targetUri, in: confId,
                                               active: !info.isModerator)
            case .endCall:
                await callService.hangUpParticipant(targetUri, in: confId,
                                                    deviceId: info.device)
            case .raiseHand, .lowerHand:
                let isLocal = info.isLocalDevice(localJamiId: localJamiId,
                                                 localDeviceId: localDeviceId,
                                                 isHostedLocally: conference.isHost)
                await callService.raiseHand(isLocal ? "" : targetUri, in: confId,
                                            deviceId: isLocal ? "" : info.device,
                                            raised: item == .raiseHand)
            }
        }
    }

    func addParticipantTapped() {
        guard canAddParticipant else { return }
        addParticipantAfterRosterDismissal = showsParticipants
        showsParticipants = false
        if !addParticipantAfterRosterDismissal {
            onAddParticipant?()
        }
    }

    func selectMoreAction(_ intent: CallControlIntent) {
        pendingMoreAction = intent
        showsMoreActions = false
    }

    func moreActionsDismissed() {
        guard let intent = pendingMoreAction else { return }
        pendingMoreAction = nil
        perform(intent)
    }

    func participantsDismissed() {
        guard addParticipantAfterRosterDismissal else { return }
        addParticipantAfterRosterDismissal = false
        onAddParticipant?()
    }

    // MARK: - Picture in picture

    var pipSourceView: UIView { pip.sourceView }

    func setPiPVideoFrameProvider(_ provider: @escaping (String) -> CGRect?) {
        pip.sourceView.videoFrameProvider = provider
    }

    private func syncPiPVideoTile() {
        pip.sourceView.videoTileId = pipDistributor.flatMap { distributor in
            canvas.tiles.first { $0.distributor === distributor }?.participant.id
        }
    }

    private func updatePiPSource() {
        let feed = nextPiPFeed()
        guard feed != pipFeed else { return }
        let hadSource = pipFeed != nil
        pipFeed = feed
        switch feed {
        case .participant(let selection):
            let distributor = videoService.distributor(for: selection.sinkId)
            pipDistributor = distributor
            pip.update(distributor: distributor, fixedTransform: nil)
        case .localCamera(let transform):
            pipDistributor = videoService.localFrames
            pip.update(distributor: videoService.localFrames, fixedTransform: transform)
        case nil:
            pipDistributor = nil
            pip.update(distributor: nil, fixedTransform: nil)
        }
        syncPiPVideoTile()
        canStartPictureInPicture = feed != nil && pip.isSupported
        guard hadSource, feed == nil, call?.status.isTerminal == false else { return }
        fallBackToReturnCapsule()
    }

    private func fallBackToReturnCapsule() {
        guard pipState == .minimized else { return }
        pipState = .inactive
        showsReturnCapsule = true
    }

    private func nextPiPFeed() -> PiPFeed? {
        if let selection = PiPSourceSelector.select(call: call, conference: conference,
                                                    localJamiId: localJamiId,
                                                    localDeviceId: localDeviceId,
                                                    current: pipFeed?.participant) {
            return .participant(selection)
        }
        guard PiPSourceSelector.showsLocalCamera(call: call, conference: conference) else {
            return nil
        }
        return .localCamera(videoService.localLayerTransform)
    }

    private func requestRestore(then completion: PiPRestoreCompletion? = nil) {
        guard let onRestore = onRestore else {
            revealContent()
            completion?(false)
            return
        }
        onRestore { [weak self] restored in
            if restored {
                self?.pipState = .inactive
                self?.showsReturnCapsule = false
            } else {
                self?.revealContent()
            }
            completion?(restored)
        }
    }

    private func hideContentUntilWindowGrows() {
        contentHidden = true
        let work = DispatchWorkItem { [weak self] in self?.revealContent() }
        revealWork?.cancel()
        revealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealFallbackDelay,
                                      execute: work)
    }

    private func revealContent() {
        revealWork?.cancel()
        revealWork = nil
        contentHidden = false
    }
}
