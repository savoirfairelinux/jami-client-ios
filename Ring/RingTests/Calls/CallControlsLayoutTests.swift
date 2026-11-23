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
                       hasNegotiatedVideo: Bool = true,
                       canHold: Bool = false, canResume: Bool = false,
                       showsDialpad: Bool = false,
                       showsRaiseHand: Bool = false) -> CallControlsModel {
        CallControlsModel(isAudioMuted: mute, isVideoMuted: videoMute,
                          canToggleMedia: canToggleMedia, canSwitchCamera: canSwitchCamera,
                          hasNegotiatedVideo: hasNegotiatedVideo,
                          canHold: canHold, canResume: canResume, showsDialpad: showsDialpad,
                          showsRaiseHand: showsRaiseHand)
    }

    private func plan(_ model: CallControlsModel? = nil,
                      canMinimize: Bool = true,
                      handRaised: Bool = false,
                      outputs: AudioOutputState = .idle) -> CallControlsLayout.Plan {
        CallControlsLayout.plan(.init(model: model ?? self.model(),
                                      canMinimize: canMinimize,
                                      canAddParticipant: true,
                                      isHandRaised: handRaised,
                                      showsFullVideo: nil,
                                      audioOutputs: outputs))
    }

    private func outputs(_ available: [AudioOutput], current: AudioOutput,
                         isDefault: Bool = true) -> AudioOutputState {
        AudioOutputState(available: available, current: current, isDefault: isDefault)
    }

    private func action(_ intent: CallControlIntent,
                        in plan: CallControlsLayout.Plan) -> ControlAction? {
        (plan.primary + plan.more + [plan.minimize].compactMap { $0 })
            .first { $0.intent == intent }
    }

    func testCameraIsHighlightedOnlyWhenVideoWasTurnedOff() {
        let turnedOff = action(.toggleCamera,
                               in: plan(model(videoMute: true, canSwitchCamera: false)))
        XCTAssertEqual(turnedOff?.style, .active)
        XCTAssertEqual(turnedOff?.systemImage, "video.slash.fill")

        let audioOnly = action(.toggleCamera,
                               in: plan(model(videoMute: true, canSwitchCamera: false,
                                              hasNegotiatedVideo: false)))
        XCTAssertEqual(audioOnly?.style, .normal)
        XCTAssertEqual(audioOnly?.systemImage, "video.fill")
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

    func testMinimizeGatedByAvailability() {
        XCTAssertNil(action(.minimize, in: plan(canMinimize: false)))
        let minimize = action(.minimize, in: plan(canMinimize: true))
        XCTAssertEqual(minimize?.accessibilityLabel, L10n.Calls.minimize)
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
        XCTAssertEqual(mediaChangeUnavailable?.isEnabled, true,
                       "switching cameras is local and needs no media negotiation")

        let available = action(.flipCamera, in: plan(model(canSwitchCamera: true)))
        XCTAssertEqual(available?.isEnabled, true)
        XCTAssertEqual(available?.accessibilityLabel,
                       L10n.Accessibility.Calls.Default.switchCamera)
    }

    func testAudioOutputTakesFlipSlotOnlyWhileCameraIsOff() {
        let phone = outputs([.iPhone, .speaker], current: .iPhone)

        let cameraOff = plan(model(videoMute: true), outputs: phone)
        XCTAssertEqual(cameraOff.primary.map(\.intent),
                       [.toggleMic, .toggleCamera, .audioOutput, .hangUp])

        XCTAssertNotNil(action(.flipCamera, in: plan(model(videoMute: false), outputs: phone)))
        XCTAssertNotNil(action(.flipCamera,
                               in: plan(model(videoMute: true),
                                        outputs: outputs([.speaker], current: .speaker))),
                        "a single output leaves nothing to switch")
    }

    func testAudioOutputButtonStyle() {
        let earpiece = action(.audioOutput,
                              in: plan(model(videoMute: true),
                                       outputs: outputs([.iPhone, .speaker], current: .iPhone)))
        XCTAssertEqual(earpiece?.style, .normal)
        XCTAssertEqual(earpiece?.opensChoices, false)

        let speakerInAudioCall = action(.audioOutput,
                                        in: plan(model(videoMute: true),
                                                 outputs: outputs([.iPhone, .speaker],
                                                                  current: .speaker,
                                                                  isDefault: false)))
        XCTAssertEqual(speakerInAudioCall?.style, .active, "white marks a non-default output")

        let headset = AudioOutput.bluetooth(id: "a", name: "AirPods Pro")
        let threeOutputs = action(.audioOutput,
                                  in: plan(model(videoMute: true),
                                           outputs: outputs([.iPhone, .speaker, headset],
                                                            current: headset)))
        XCTAssertEqual(threeOutputs?.opensChoices, true)
        XCTAssertEqual(threeOutputs?.accessibilityValue, "AirPods Pro")
    }

    func testPrimaryControlsRemainStableWhenCapabilitiesChange() {
        let available = plan(model(canSwitchCamera: true)).primary.map(\.intent)
        let unavailable = plan(model(canSwitchCamera: false)).primary.map(\.intent)
        XCTAssertEqual(unavailable, available)

        let sipAvailable = plan(model(canHold: true, showsDialpad: true)).more.map(\.intent)
        let sipUnavailable = plan(model(showsDialpad: true)).more.map(\.intent)
        XCTAssertEqual(sipUnavailable, sipAvailable)
    }

    func testSipAddsControlsWithoutReplacingVideoControls() {
        let sip = plan(model(canSwitchCamera: false, canHold: true, showsDialpad: true))
        let regular = plan(model(canSwitchCamera: false))

        XCTAssertEqual(sip.primary.map(\.intent), regular.primary.map(\.intent))
        XCTAssertEqual(Array(sip.more.map(\.intent).suffix(2)), [.toggleHold, .showDialpad])
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
    }

    func testBarNeverOutgrowsTheWidthItIsGiven() {
        let docks = [Array(plan().more.prefix(1)) + plan().primary]
        for actions in docks {
            for width in stride(from: 280.0, through: 1366.0, by: 1.0) {
                let metrics = BarMetrics(availableWidth: CGFloat(width))
                let rowWidth = metrics.rowWidth(for: actions)
                XCTAssertLessThanOrEqual(rowWidth, CGFloat(width) + 0.001,
                                         "\(actions.count) controls in \(width) pt render "
                                            + "\(rowWidth) pt wide and widen "
                                            + "the whole call screen")
            }
        }
    }

    func testUnmeasuredBarStillRendersButFitsTheNarrowestPhone() {
        let metrics = BarMetrics(availableWidth: 0)

        XCTAssertGreaterThanOrEqual(metrics.button, 44,
                                    "the bar must be laid out — and tappable — "
                                        + "before it has been measured")
        XCTAssertLessThanOrEqual(metrics.rowWidth(for: Array(plan().more.prefix(1)) + plan().primary), 320,
                                 "an unmeasured bar must fit the narrowest phone, "
                                    + "or it widens the whole call screen")
    }
}
