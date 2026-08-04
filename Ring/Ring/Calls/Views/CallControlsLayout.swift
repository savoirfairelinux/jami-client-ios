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
}

struct CallControlsModel: Equatable {

    let isAudioMuted: Bool
    let isVideoMuted: Bool
    let canToggleMedia: Bool
    let canSwitchCamera: Bool
    let canHold: Bool
    let canResume: Bool
    let showsDialpad: Bool

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
    }

    init(isAudioMuted: Bool, isVideoMuted: Bool, canToggleMedia: Bool,
         canSwitchCamera: Bool, canHold: Bool, canResume: Bool, showsDialpad: Bool) {
        self.isAudioMuted = isAudioMuted
        self.isVideoMuted = isVideoMuted
        self.canToggleMedia = canToggleMedia
        self.canSwitchCamera = canSwitchCamera
        self.canHold = canHold
        self.canResume = canResume
        self.showsDialpad = showsDialpad
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
    let style: Style
    let isEnabled: Bool

    init(intent: CallControlIntent,
         systemImage: String,
         accessibilityLabel: String,
         style: Style = .normal,
         isEnabled: Bool = true) {
        self.intent = intent
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
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
    }

    struct Plan: Equatable {
        let primary: [ControlAction]
        let supplemental: [ControlAction]
        let pictureInPicture: ControlAction?
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

        let camera = ControlAction(
            intent: .toggleCamera,
            systemImage: model.isVideoMuted ? "video.slash.fill" : "video.fill",
            accessibilityLabel: model.isVideoMuted
                ? L10n.Accessibility.Calls.Default.toggleVideo
                : L10n.Accessibility.Calls.Alter.toggleVideo,
            style: model.isVideoMuted ? .active : .normal,
            isEnabled: model.canToggleMedia)

        let audioOutput = ControlAction(
            intent: .toggleAudioOutput,
            systemImage: context.speakerActive ? "speaker.wave.3.fill" : "speaker.wave.2.fill",
            accessibilityLabel: context.speakerActive
                ? L10n.Accessibility.Calls.Alter.toggleSpeaker
                : L10n.Accessibility.Calls.Default.toggleSpeaker,
            style: context.speakerActive ? .active : .normal)

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

        let supplemental: [ControlAction]
        if model.showsDialpad {
            let dialpad = ControlAction(
                intent: .showDialpad,
                systemImage: "circle.grid.3x3.fill",
                accessibilityLabel: L10n.Accessibility.Calls.Default.showDialpad)
            supplemental = [holdAction(model), dialpad]
        } else {
            supplemental = []
        }

        let primary = [audioOutput, mic, camera,
                       flipCameraAction(isEnabled: model.canToggleMedia
                                        && model.canSwitchCamera), hangUp]
        return Plan(primary: primary, supplemental: supplemental,
                    pictureInPicture: pictureInPicture)
    }

    private static func flipCameraAction(isEnabled: Bool) -> ControlAction {
        ControlAction(intent: .flipCamera,
                      systemImage: "arrow.triangle.2.circlepath.camera",
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
            isEnabled: model.canHold || model.canResume)
    }
}
