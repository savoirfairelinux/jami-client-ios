/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import XCTest
@testable import Ring

final class CallControlsLayoutTests: XCTestCase {

    private func model(mute: Bool = false, videoMute: Bool = false,
                       canToggleMedia: Bool = true, canSwitchCamera: Bool = true,
                       canHold: Bool = false, canResume: Bool = false,
                       showsDialpad: Bool = false,
                       showsRaiseHand: Bool = false) -> CallControlsModel {
        CallControlsModel(isAudioMuted: mute, isVideoMuted: videoMute,
                          canToggleMedia: canToggleMedia, canSwitchCamera: canSwitchCamera,
                          canHold: canHold, canResume: canResume, showsDialpad: showsDialpad,
                          showsRaiseHand: showsRaiseHand)
    }

    private func plan(_ model: CallControlsModel? = nil,
                      speaker: Bool = false,
                      canPiP: Bool = true,
                      handRaised: Bool = false) -> CallControlsLayout.Plan {
        CallControlsLayout.plan(.init(model: model ?? self.model(),
                                      speakerActive: speaker,
                                      canStartPictureInPicture: canPiP,
                                      isHandRaised: handRaised))
    }

    private func action(_ intent: CallControlIntent,
                        in plan: CallControlsLayout.Plan) -> ControlAction? {
        (plan.primary + plan.supplemental + [plan.pictureInPicture].compactMap { $0 })
            .first { $0.intent == intent }
    }

    func testDialpadOnlyForSip() {
        XCTAssertNil(action(.showDialpad, in: plan(model(showsDialpad: false))))
        XCTAssertNotNil(action(.showDialpad, in: plan(model(showsDialpad: true))))
    }

    func testRaiseHandTracksTheCurrentState() {
        XCTAssertNil(plan(model(showsRaiseHand: false)).raiseHand)

        let lowered = plan(model(showsRaiseHand: true), handRaised: false).raiseHand
        XCTAssertEqual(lowered?.accessibilityLabel,
                       L10n.Accessibility.Calls.Default.raiseHand)
        XCTAssertEqual(lowered?.style, .normal)

        let raised = plan(model(showsRaiseHand: true), handRaised: true).raiseHand
        XCTAssertEqual(raised?.accessibilityLabel,
                       L10n.Accessibility.Calls.Alter.raiseHand)
        XCTAssertEqual(raised?.style, .active)
    }

    func testPictureInPictureGatedByAvailability() {
        XCTAssertNil(action(.startPictureInPicture, in: plan(canPiP: false)))
        let pictureInPicture = action(.startPictureInPicture, in: plan(canPiP: true))
        XCTAssertEqual(pictureInPicture?.accessibilityLabel,
                       L10n.Calls.startPictureInPicture)
    }

    func testFlipCameraRemainsVisibleWhenUnavailable() {
        let unavailable = action(
            .flipCamera,
            in: plan(model(videoMute: true, canSwitchCamera: false)))
        XCTAssertNotNil(unavailable)
        XCTAssertEqual(unavailable?.isEnabled, false)

        let mediaChangeUnavailable = action(
            .flipCamera,
            in: plan(model(canToggleMedia: false, canSwitchCamera: true)))
        XCTAssertEqual(mediaChangeUnavailable?.isEnabled, false)

        let available = action(.flipCamera, in: plan(model(canSwitchCamera: true)))
        XCTAssertEqual(available?.isEnabled, true)
        XCTAssertEqual(available?.accessibilityLabel,
                       L10n.Accessibility.Calls.Default.switchCamera)
    }

    func testPrimaryControlsRemainStableWhenCapabilitiesChange() {
        let available = plan(model(canSwitchCamera: true)).primary.map(\.intent)
        let unavailable = plan(model(canSwitchCamera: false)).primary.map(\.intent)
        XCTAssertEqual(unavailable, available)

        let sipAvailable = plan(model(canHold: true, showsDialpad: true))
            .supplemental.map(\.intent)
        let sipUnavailable = plan(model(showsDialpad: true)).supplemental.map(\.intent)
        XCTAssertEqual(sipUnavailable, sipAvailable)
    }

    func testSipAddsControlsWithoutReplacingVideoControls() {
        let sip = plan(model(canSwitchCamera: false, canHold: true, showsDialpad: true))
        let regular = plan(model(canSwitchCamera: false))

        XCTAssertEqual(sip.primary.map(\.intent), regular.primary.map(\.intent))
        XCTAssertEqual(sip.supplemental.map(\.intent), [.toggleHold, .showDialpad])
    }

    func testSipHoldRemainsVisibleWhenUnavailable() {
        let hold = action(.toggleHold, in: plan(model(showsDialpad: true)))

        XCTAssertNotNil(hold)
        XCTAssertEqual(hold?.isEnabled, false)
    }

    func testMuteShowsActiveStyle() {
        let mic = action(.toggleMic, in: plan(model(mute: true)))
        XCTAssertEqual(mic?.style, .active)
    }

    func testDisabledMediaPropagatesToMicAndCamera() {
        let layoutPlan = plan(model(canToggleMedia: false))
        XCTAssertEqual(action(.toggleMic, in: layoutPlan)?.isEnabled, false)
        XCTAssertEqual(action(.toggleCamera, in: layoutPlan)?.isEnabled, false)
        XCTAssertEqual(action(.toggleAudioOutput, in: layoutPlan)?.isEnabled, true,
                       "audio output is independent of the media re-invite gate")
    }

    func testSpeakerAnnouncesTheActionItWillPerform() {
        let active = action(.toggleAudioOutput, in: plan(speaker: true))
        XCTAssertEqual(active?.style, .active)
        XCTAssertEqual(active?.accessibilityLabel,
                       L10n.Accessibility.Calls.Alter.toggleSpeaker,
                       "a speaker that is on offers to turn itself off")

        let inactive = action(.toggleAudioOutput, in: plan(speaker: false))
        XCTAssertEqual(inactive?.accessibilityLabel,
                       L10n.Accessibility.Calls.Default.toggleSpeaker)
    }

    func testBarNeverOutgrowsTheWidthItIsGiven() {
        for slots in 1...9 {
            for width in stride(from: 280.0, through: 1366.0, by: 1.0) {
                let metrics = BarMetrics(availableWidth: CGFloat(width),
                                         slots: CGFloat(slots))
                XCTAssertLessThanOrEqual(metrics.totalWidth, CGFloat(width) + 0.001,
                                         "\(slots) slots in \(width) pt render "
                                            + "\(metrics.totalWidth) pt wide and widen "
                                            + "the whole call screen")
            }
        }
    }

    func testUnmeasuredBarStillRendersButFitsTheNarrowestPhone() {
        let metrics = BarMetrics(availableWidth: 0)

        XCTAssertGreaterThanOrEqual(metrics.button, 44,
                                    "the bar must be laid out — and tappable — "
                                        + "before it has been measured")
        XCTAssertLessThanOrEqual(metrics.totalWidth, 320,
                                 "an unmeasured bar must fit the narrowest phone, "
                                    + "or it widens the whole call screen")
    }
}
