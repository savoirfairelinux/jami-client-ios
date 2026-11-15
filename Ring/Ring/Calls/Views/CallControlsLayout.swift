/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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

enum CallControlIntent: Hashable {
    case toggleMic
    case toggleCamera
    case toggleAudioOutput
    case hangUp
    case flipCamera
    case toggleHold
    case startPictureInPicture
    case showDialpad
    case toggleRaiseHand
    case addParticipant
    case toggleFullVideo
}

struct CallControlsModel: Equatable {

    let isAudioMuted: Bool
    let isVideoMuted: Bool
    let canToggleMedia: Bool
    let canSwitchCamera: Bool
    let canHold: Bool
    let canResume: Bool
    let showsDialpad: Bool
    let showsRaiseHand: Bool

    init(call: CallState, conference: ConferenceState? = nil, isSipAccount: Bool) {
        let hostedConference = call.mediaOwningHostedConference(in: conference)
        let media = hostedConference?.media ?? call.media
        let pendingMediaRequest = hostedConference == nil
            ? call.pendingMediaRequest
            : hostedConference?.pendingMediaRequest
        self.isAudioMuted = media.isAudioMuted
        self.isVideoMuted = media.isVideoMuted
        self.canToggleMedia = call.status.allows(.changeMedia)
            && pendingMediaRequest == nil
            && !(conference?.isHost == true && conference?.id == call.conferenceId
                    && conference?.hasAttachedHost == false)
        self.canSwitchCamera = media.hasVideo
        if isSipAccount, let conference = conference,
           conference.isHost, conference.id == call.conferenceId {
            self.canHold = conference.lifecycle == .activeAttached
            self.canResume = conference.lifecycle == .activeDetached
                || conference.lifecycle == .hold
        } else {
            let canHoldCall = isSipAccount && call.conferenceId == nil
            self.canHold = canHoldCall && call.status.allows(.hold)
            self.canResume = canHoldCall && call.status.allows(.resume)
        }
        self.showsDialpad = isSipAccount
        self.showsRaiseHand = !isSipAccount && conference != nil
    }

    init(isAudioMuted: Bool, isVideoMuted: Bool, canToggleMedia: Bool,
         canSwitchCamera: Bool, canHold: Bool, canResume: Bool, showsDialpad: Bool,
         showsRaiseHand: Bool) {
        self.isAudioMuted = isAudioMuted
        self.isVideoMuted = isVideoMuted
        self.canToggleMedia = canToggleMedia
        self.canSwitchCamera = canSwitchCamera
        self.canHold = canHold
        self.canResume = canResume
        self.showsDialpad = showsDialpad
        self.showsRaiseHand = showsRaiseHand
    }
}

struct ControlAction: Identifiable, Equatable {
    enum Style: Equatable {
        case normal
        case active
        case destructive
    }

    let intent: CallControlIntent
    let systemImage: String
    let accessibilityLabel: String
    let title: String
    let isOn: Bool?
    let style: Style
    let isEnabled: Bool

    init(intent: CallControlIntent,
         systemImage: String,
         accessibilityLabel: String,
         title: String? = nil,
         isOn: Bool? = nil,
         style: Style = .normal,
         isEnabled: Bool = true) {
        self.intent = intent
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.title = title ?? accessibilityLabel
        self.isOn = isOn
        self.style = style
        self.isEnabled = isEnabled
    }

    var id: CallControlIntent { intent }
}

enum CallControlsLayout {

    struct Context {
        let model: CallControlsModel
        let speakerActive: Bool
        let canStartPictureInPicture: Bool
        let canAddParticipant: Bool
        let isHandRaised: Bool
        let showsFullVideo: Bool?
    }

    struct Plan: Equatable {
        let pictureInPicture: ControlAction?
        let raiseHand: ControlAction?
        let more: [ControlAction]
        let primary: [ControlAction]
    }

    static func plan(_ context: Context) -> Plan {
        let model = context.model

        let mic = ControlAction(
            intent: .toggleMic,
            systemImage: model.isAudioMuted ? "mic.slash.fill" : "mic.fill",
            accessibilityLabel: model.isAudioMuted
                ? L10n.Calls.unmuteAudio : L10n.Calls.muteAudio,
            style: model.isAudioMuted ? .active : .normal,
            isEnabled: model.canToggleMedia)

        let cameraTurnedOff = model.isVideoMuted && model.canSwitchCamera
        let camera = ControlAction(
            intent: .toggleCamera,
            systemImage: cameraTurnedOff ? "video.slash.fill" : "video.fill",
            accessibilityLabel: model.isVideoMuted
                ? L10n.Accessibility.Calls.Default.toggleVideo
                : L10n.Accessibility.Calls.Alter.toggleVideo,
            style: cameraTurnedOff ? .active : .normal,
            isEnabled: model.canToggleMedia)

        let audioOutput = ControlAction(
            intent: .toggleAudioOutput,
            systemImage: context.speakerActive ? "speaker.wave.3.fill" : "speaker.fill",
            accessibilityLabel: context.speakerActive
                ? L10n.Accessibility.Calls.Alter.toggleSpeaker
                : L10n.Accessibility.Calls.Default.toggleSpeaker,
            title: L10n.Calls.speaker,
            isOn: context.speakerActive)

        let hangUp = ControlAction(
            intent: .hangUp,
            systemImage: "phone.down.fill",
            accessibilityLabel: L10n.Accessibility.Calls.Default.endCall,
            style: .destructive)

        let pictureInPicture: ControlAction? = context.canStartPictureInPicture
            ? ControlAction(intent: .startPictureInPicture,
                            systemImage: "pip.enter",
                            accessibilityLabel: L10n.Calls.startPictureInPicture)
            : nil

        let fullVideo: ControlAction? = context.showsFullVideo.map { showsFullVideo in
            ControlAction(intent: .toggleFullVideo,
                          systemImage: "aspectratio",
                          accessibilityLabel: L10n.Calls.showFullVideo,
                          isOn: showsFullVideo)
        }

        let raiseHand: ControlAction? = model.showsRaiseHand
            ? raiseHandAction(isRaised: context.isHandRaised)
            : nil

        let addParticipant: ControlAction? = context.canAddParticipant
            ? ControlAction(intent: .addParticipant,
                            systemImage: "person.fill.badge.plus",
                            accessibilityLabel: L10n.Accessibility.Calls.Default.addParticipant)
            : nil

        var sip: [ControlAction] = []
        if model.showsDialpad {
            let dialpad = ControlAction(
                intent: .showDialpad,
                systemImage: "circle.grid.3x3.fill",
                accessibilityLabel: L10n.Accessibility.Calls.Default.showDialpad,
                title: L10n.Smartlist.dialpad)
            sip = [holdAction(model), dialpad]
        }

        let more = [audioOutput] + [fullVideo, addParticipant].compactMap { $0 } + sip
        let primary = [mic, camera,
                       flipCameraAction(isEnabled: model.canToggleMedia
                                            && model.canSwitchCamera), hangUp]
        return Plan(pictureInPicture: pictureInPicture, raiseHand: raiseHand,
                    more: more, primary: primary)
    }

    private static func raiseHandAction(isRaised: Bool) -> ControlAction {
        ControlAction(
            intent: .toggleRaiseHand,
            systemImage: "hand.raised.fill",
            accessibilityLabel: isRaised
                ? L10n.Accessibility.Calls.Alter.raiseHand
                : L10n.Accessibility.Calls.Default.raiseHand,
            title: L10n.Calls.raiseHand,
            isOn: isRaised,
            style: isRaised ? .active : .normal)
    }

    private static func flipCameraAction(isEnabled: Bool) -> ControlAction {
        ControlAction(intent: .flipCamera,
                      systemImage: "arrow.triangle.2.circlepath",
                      accessibilityLabel: L10n.Accessibility.Calls.Default.switchCamera,
                      isEnabled: isEnabled)
    }

    private static func holdAction(_ model: CallControlsModel) -> ControlAction {
        ControlAction(
            intent: .toggleHold,
            systemImage: model.canResume ? "play.fill" : "pause.fill",
            accessibilityLabel: model.canResume
                ? L10n.Accessibility.Calls.Alter.pauseCall
                : L10n.Accessibility.Calls.Default.pauseCall,
            title: L10n.Calls.hold,
            isOn: model.canResume,
            isEnabled: model.canHold || model.canResume)
    }
}
