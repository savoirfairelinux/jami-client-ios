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
    case more
    case flipCamera
    case toggleHold
    case addParticipant
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
        self.isAudioMuted = hostedConference?.isAudioMuted ?? media.isAudioMuted
        self.isVideoMuted = media.isVideoMuted
        self.canToggleMedia = call.status.allows(.changeMedia)
            && pendingMediaRequest == nil
            && !(conference?.isHost == true && conference?.id == call.conferenceId
                 && conference?.hasAttachedHost == false)
        self.canSwitchCamera = media.hasVideo
        let canHoldSession = isSipAccount && call.conferenceId == nil
        self.canHold = canHoldSession && call.status.allows(.hold)
        self.canResume = canHoldSession && call.status.allows(.resume)
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
    var style: Style = .normal
    var isEnabled: Bool = true

    var id: CallControlIntent { intent }
}

enum CallControlsLayout {

    struct Context {
        let model: CallControlsModel
        let speakerActive: Bool
        let canAddParticipant: Bool
        let canStartPictureInPicture: Bool
        let isRegularWidth: Bool
    }

    struct Plan: Equatable {
        var primary: [ControlAction]
        var overflow: [ControlAction]
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
            accessibilityLabel: L10n.Accessibility.Calls.Default.toggleVideo,
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

        let secondary = secondaryActions(context)

        if context.isRegularWidth {
            var inline = [mic, camera, audioOutput] + secondary
            inline.insert(hangUp, at: inline.count / 2)
            return Plan(primary: inline, overflow: [])
        }

        let more = ControlAction(
            intent: .more,
            systemImage: "ellipsis",
            accessibilityLabel: L10n.Calls.moreActions,
            isEnabled: !secondary.isEmpty)
        return Plan(primary: [mic, camera, hangUp, audioOutput, more],
                    overflow: secondary)
    }

    private static func secondaryActions(_ context: Context) -> [ControlAction] {
        let model = context.model
        var actions: [ControlAction] = []

        if model.canSwitchCamera {
            actions.append(ControlAction(
                            intent: .flipCamera,
                            systemImage: "arrow.triangle.2.circlepath.camera",
                            accessibilityLabel: L10n.Accessibility.Calls.Default.switchCamera))
        }
        if model.canHold || model.canResume {
            actions.append(ControlAction(
                            intent: .toggleHold,
                            systemImage: model.canResume ? "play.fill" : "pause.fill",
                            accessibilityLabel: model.canResume
                                ? L10n.Accessibility.Calls.Alter.pauseCall
                                : L10n.Accessibility.Calls.Default.pauseCall))
        }
        if context.canAddParticipant {
            actions.append(ControlAction(
                            intent: .addParticipant,
                            systemImage: "person.badge.plus",
                            accessibilityLabel: L10n.Accessibility.Calls.Default.addParticipant))
        }
        if context.canStartPictureInPicture {
            actions.append(ControlAction(
                            intent: .startPictureInPicture,
                            systemImage: "pip.enter",
                            accessibilityLabel: L10n.Calls.pictureInPicture))
        }
        if model.showsDialpad {
            actions.append(ControlAction(
                            intent: .showDialpad,
                            systemImage: "circle.grid.3x3.fill",
                            accessibilityLabel: L10n.Accessibility.Calls.Default.showDialpad))
        }
        return actions
    }
}
