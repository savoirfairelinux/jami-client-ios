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

    init(tiles: [CanvasTileModel] = [],
         mode: CanvasLayoutMode = .grid,
         style: CanvasTileStyle = .plain) {
        self.tiles = tiles
        self.mode = mode
        self.style = style
    }
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
    @Published var showsParticipants = false
    @Published private(set) var participantRows: [ConferenceParticipantRow] = []
    @Published private(set) var pendingRows: [PendingParticipantRow] = []
    @Published private(set) var canAddParticipant = false
    @Published private(set) var speakerActive = false
    @Published private(set) var chromeVisible = true
    @Published private(set) var moreExpanded = false
    @Published private(set) var contentHidden = false

    @Published private(set) var header = CallHeaderModel.empty

    // MARK: - Dependencies

    private let callService: CallService
    private let videoService: VideoService
    private let audio: AudioService
    private let profileService: ProfilesService
    private let nameService: NameService
    private let isSipAccount: Bool
    private let localJamiId: String

    var onAddParticipant: (() -> Void)?
    var onMinimize: ((CallConversationRoute) -> Void)?
    var onRestore: PiPRestoreHandler?

    private let pip: PiPControlling
    private let orientationMonitor = DeviceOrientationMonitor()
    private let tileComposer: CallTileComposer
    private var callId: CallId
    private var lastKnownConference: ConferenceState?
    private var eventTask: Task<Void, Never>?
    private var durationTimer: AnyCancellable?
    private var audioCancellable: AnyCancellable?
    private var autoHideWork: DispatchWorkItem?
    private var wasAutoHideable = false
    private static let autoHideDelay: TimeInterval = 4
    private var avatars: CallParticipantAvatars?
    private var peerName = ""
    private var observedPeerURI: String?
    private var peerNameCancellable: AnyCancellable?
    private var chromeCancellable: AnyCancellable?
    private var pipSource: PiPSourceSelector.Selection?

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
         pipController: PiPControlling = PiPController()) {
        self.callId = call.id
        self.callService = callService
        self.videoService = videoService
        self.audio = audio
        self.profileService = profileService
        self.nameService = nameService
        self.isSipAccount = isSipAccount
        self.localJamiId = localJamiId
        self.pip = pipController
        self.tileComposer = CallTileComposer(videoService: videoService,
                                             localJamiId: localJamiId)

        audioCancellable = audio.speakerActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.speakerActive = active
            }
        pip.onDidFailToStart = { [weak self] in
            guard let self = self, self.pipState == .minimized else { return }
            self.pipState = .inactive
            self.requestRestore()
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
    }

    deinit {
        eventTask?.cancel()
        autoHideWork?.cancel()
        revealWork?.cancel()
    }

    // MARK: - Chrome visibility

    func screenTapped() {
        guard chromeCanAutoHide else { return }
        if moreExpanded { setMoreExpanded(false); return }
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

    func toggleMoreExpanded() { setMoreExpanded(!moreExpanded) }

    func setMoreExpanded(_ open: Bool) {
        moreExpanded = open
        if open {
            cancelAutoHide()
            chromeVisible = true
        } else {
            scheduleAutoHide()
        }
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

    private func scheduleAutoHide() {
        cancelAutoHide()
        guard chromeCanAutoHide, !moreExpanded else { return }
        let work = DispatchWorkItem { [weak self] in self?.chromeVisible = false }
        autoHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoHideDelay, execute: work)
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
                await self.consume(event: event)
            }
        }
        previousTask?.cancel()
    }

    private func consume(event: CallSystemEvent) async {
        switch event {
        case let .callAdded(call), let .callUpdated(call):
            guard call.id == callId else { return }
            apply(call: call)
            rebuildTiles()
        case let .callEnded(call, _):
            guard call.id == callId else { return }
            if call.status != .terminated(.endedLocally),
               let session = conference ?? lastKnownConference {
                let snapshot = await callService.snapshot()
                guard !Task.isCancelled, call.id == callId else { return }
                if let remainingCallId = remainingCallId(
                    in: session, availableCalls: snapshot.calls
                ) {
                    retarget(to: remainingCallId)
                    return
                }
            }
            apply(call: call)
            rebuildTiles()
            stopDurationTimer()
            lastKnownConference = nil
            shouldDismiss = true
        case let .callMatched(replaced, matched):
            guard replaced == callId else { return }
            retarget(to: matched.id)
        case let .conferenceUpdated(conference):
            let isMember = call?.conferenceId == conference.id
                || conference.memberCallIds.contains(callId)
            let isTracked = self.conference?.id == conference.id
                || lastKnownConference?.id == conference.id
            guard isMember || isTracked else { return }
            lastKnownConference = conference
            guard isMember else {
                clearConferenceState()
                return
            }
            updateRecompositionFreeze(previous: self.conference, incoming: conference)
            self.conference = conference
            rebuildCanvas(mode: daemonCanvasMode())
            rebuildRows()
            rebuildControlsAndCapabilities()
            updateChromeForState()
            updatePiPSource()
        case let .conferenceEnded(confId, remainingCallId):
            let wasMember = conference?.id == confId
            guard wasMember || lastKnownConference?.id == confId else { return }
            clearConferenceState()
            lastKnownConference = nil
            if wasMember, let remaining = remainingCallId, remaining != callId {
                retarget(to: remaining)
            }
        default:
            break
        }
    }

    /// Ordered like the store's choice in `conferenceEnded` so both agree on
    /// which remaining call keeps the session alive.
    private func remainingCallId(in session: ConferenceState,
                                 availableCalls: [CallId: CallState]) -> CallId? {
        return session.memberCallIds
            .sorted { $0.raw < $1.raw }
            .first {
                $0 != callId && availableCalls[$0]?.status.isTerminal == false
            }
    }

    private func clearConferenceState() {
        guard conference != nil else { return }
        conference = nil
        frozenForRecomposition = false
        rebuildCanvas(mode: .grid)
        rebuildRows()
        rebuildControlsAndCapabilities()
        updateChromeForState()
        updatePiPSource()
    }

    var currentCallId: CallId { callId }

    private func retarget(to newCallId: CallId) {
        guard newCallId != callId else { return }
        lastKnownConference = nil
        callId = newCallId
        startObserving(callId: newCallId)
    }

    private func apply(call: CallState) {
        self.call = call
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
                                             nameService: nameService)
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
              let active = conference.participants.first(where: \.isActive) else {
            return .grid
        }
        let othersVisible = conference.participants.contains {
            $0.id != active.id && $0.frame.width > 0 && $0.frame.height > 0
        }
        return othersVisible ? .spotlight(active.id) : .fullscreen(active.id)
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
        let state = CanvasState(
            tiles: composition.tiles,
            mode: mode,
            style: composition.style)
        if state != canvas {
            canvas = state
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

    func accept(withVideo: Bool) {
        Task { await callService.accept(callId, withVideo: withVideo) }
    }

    func hangUp() {
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
        }
    }

    func screenAppeared() {
        orientationMonitor.start { [weak self] input in
            guard let self = self,
                  self.videoService.setCameraOrientation(input) else { return }
            self.rebuildTiles()
        }
    }

    func screenDisappeared() {
        guard pipState != .minimized else { return }
        orientationMonitor.stop()
    }

    func playDTMF(_ code: String) {
        callService.playDTMF(code: code)
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
            profileService: profileService, nameService: nameService)
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
                                     isSipAccount: isSipAccount)
        canAddParticipant = call.status.isOngoing && !isSipAccount
            && (conference == nil || canModerateConference)
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
            case .lowerHand:
                await callService.raiseHand(targetUri, in: confId,
                                            deviceId: info.device, raised: false)
            }
        }
    }

    func addParticipantTapped() {
        guard canAddParticipant else { return }
        onAddParticipant?()
    }

    // MARK: - Picture in picture

    var pipSourceView: UIView { pip.sourceView }

    private func updatePiPSource() {
        let selection = PiPSourceSelector.select(call: call, conference: conference,
                                                 localJamiId: localJamiId,
                                                 current: pipSource)
        guard selection != pipSource else { return }
        let hadSource = pipSource != nil
        pipSource = selection
        pip.update(distributor: selection.map { videoService.distributor(for: $0.sinkId) })
        canStartPictureInPicture = selection != nil && pip.isSupported
        guard hadSource, selection == nil, call?.status.isTerminal == false else { return }
        requestRestore()
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
