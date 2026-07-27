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
import RxSwift
@testable import Ring

final class ParticipantTileUIViewTests: XCTestCase {

    private func makeProvider(name: String) -> AvatarProvider {
        let dbManager = DBManager(profileHepler: ProfileDataHelper(),
                                  conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(),
                                  dbConnections: DBContainer())
        let provider = AvatarProvider(
            profileService: ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                            dbManager: dbManager),
            size: Constants.AvatarSize.call160)
        provider.profileName = name
        return provider
    }

    private func makePendingProvider(name: String) -> (AvatarProvider, PublishSubject<Data?>) {
        let dbManager = DBManager(profileHepler: ProfileDataHelper(),
                                  conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(),
                                  dbConnections: DBContainer())
        let profileService = ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                             dbManager: dbManager)
        let avatarData = PublishSubject<Data?>()
        let provider = AvatarProvider(
            profileService: profileService,
            size: Constants.AvatarSize.call160,
            avatar: avatarData.asObservable(),
            displayName: Observable.just(name),
            isGroup: false,
            waitForFirstAvatar: true)
        return (provider, avatarData)
    }

    func testUncaptionedTileStaysSilentWhenProviderResolvesName() {
        let tile = ParticipantTileUIView(participantId: CallTestFixtures.peerUri)
        tile.apply(ParticipantTileState(showsVideo: false, showsName: false))

        tile.bindAvatar(makeProvider(name: profileName1))
        waitForMainScheduler()

        XCTAssertNil(tile.displayedName,
                     "a direct-call tile must not repeat the header's name")
        XCTAssertNil(tile.nameChipFrame,
                     "an uncaptioned tile must not leave an empty name plate")
    }

    func testLocalPreviewHasAnAccessibilityLabel() {
        let tile = ParticipantTileUIView(participantId: CanvasParticipant.localId)

        XCTAssertEqual(tile.accessibilityLabel, L10n.Accessibility.Conference.localPreview)
    }

    func testVideoTileOffersVideoScalingActionToVoiceOver() {
        let tile = ParticipantTileUIView(participantId: "peer")

        tile.canToggleVideoScaling = true
        tile.apply(ParticipantTileState(showsVideo: true))

        XCTAssertEqual(tile.accessibilityCustomActions?.count, 1)
        XCTAssertEqual(tile.accessibilityCustomActions?.first?.name,
                       L10n.Accessibility.Conference.showFullVideo)
    }

    func testAudioOnlyTileDoesNotOfferVideoScalingActionToVoiceOver() {
        let tile = ParticipantTileUIView(participantId: "peer")

        tile.canToggleVideoScaling = true
        tile.canToggleVideoScaling = false
        tile.apply(ParticipantTileState(showsVideo: false))

        XCTAssertNil(tile.accessibilityCustomActions)
    }

    func testCaptionedTileShowsResolvedName() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.apply(ParticipantTileState(showsVideo: false, showsName: true))

        tile.bindAvatar(makeProvider(name: "Alice"))
        waitForMainScheduler()

        XCTAssertEqual(tile.displayedName, "Alice")
    }

    func testCaptionPlateResizesForLateProfileName() throws {
        let tile = ParticipantTileUIView(participantId: CallTestFixtures.peerUri)
        tile.frame = CGRect(x: 0, y: 0, width: 184, height: 240)
        tile.apply(ParticipantTileState(showsVideo: false, showsName: true))
        let provider = makeProvider(name: profileName1)
        tile.bindAvatar(provider)
        waitForMainScheduler()

        tile.apply(ParticipantTileState(showsVideo: true, showsName: true))
        tile.layoutIfNeeded()
        let initial = try XCTUnwrap(tile.nameChipFrame)

        provider.profileName = jamiId1
        waitForMainScheduler()
        tile.layoutIfNeeded()

        let resolved = try XCTUnwrap(tile.nameChipFrame)
        let text = try XCTUnwrap(tile.nameTextFrame)
        XCTAssertEqual(tile.displayedName, jamiId1)
        XCTAssertGreaterThan(resolved.width, initial.width)
        XCTAssertTrue(resolved.contains(text), "the resolved name escaped its plate")
    }

    func testCaptionPlateStaysInsidePhysicalSafeAreaInRightToLeftLayout() throws {
        let tile = ParticipantTileUIView(participantId: CallTestFixtures.peerUri)
        tile.semanticContentAttribute = .forceRightToLeft
        tile.frame = CGRect(x: 0, y: 0, width: 400, height: 240)
        tile.contentInsets = UIEdgeInsets(top: 0, left: 44, bottom: 21, right: 0)
        tile.apply(ParticipantTileState(showsVideo: false, showsName: true))
        tile.bindAvatar(makeProvider(name: profileName1))
        waitForMainScheduler()
        tile.layoutIfNeeded()

        let chip = try XCTUnwrap(tile.nameChipFrame)
        let safeArea = UIEdgeInsetsInsetRect(tile.bounds, tile.contentInsets)
        XCTAssertTrue(safeArea.contains(chip),
                      "the caption crosses the physical safe area in RTL")
    }

    func testAvatarStaysUntilFirstVideoFrame() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.apply(ParticipantTileState(showsVideo: true))
        tile.bindAvatar(makeProvider(name: "Alice"))

        XCTAssertTrue(tile.showsAvatarPlaceholder,
                      "video enabled but no frame yet — avatar must stay")

        tile.videoView.markVideoContent()

        XCTAssertFalse(tile.showsAvatarPlaceholder,
                       "first frame arrived — avatar must give way to video")
    }

    func testUnresolvedAvatarIsNotShown() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.apply(ParticipantTileState(showsVideo: false))
        let (provider, _) = makePendingProvider(name: "Alice")

        tile.bindAvatar(provider)
        waitForMainScheduler()

        XCTAssertFalse(tile.showsAvatarPlaceholder,
                       "the tile must stay plain while the profile is unresolved")
    }

    func testAvatarAppearsAfterProfileResolutionWhenVideoIsUnavailable() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.apply(ParticipantTileState(showsVideo: false))
        let (provider, avatarData) = makePendingProvider(name: "Alice")
        tile.bindAvatar(provider)

        let resolved = expectation(description: "avatar resolved")
        let cancellable = provider.$isAvatarResolved
            .filter { $0 }
            .sink { _ in resolved.fulfill() }
        avatarData.onNext(nil)

        wait(for: [resolved], timeout: 1)
        waitForMainScheduler()
        XCTAssertTrue(tile.showsAvatarPlaceholder)
        withExtendedLifetime(cancellable) {}
    }

    func testAvatarResolvingAfterFirstVideoFrameDoesNotCoverVideo() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.apply(ParticipantTileState(showsVideo: true))
        let (provider, avatarData) = makePendingProvider(name: "Alice")
        tile.bindAvatar(provider)
        tile.videoView.markVideoContent()

        let resolved = expectation(description: "avatar resolved")
        let cancellable = provider.$isAvatarResolved
            .filter { $0 }
            .sink { _ in resolved.fulfill() }
        avatarData.onNext(nil)

        wait(for: [resolved], timeout: 1)
        XCTAssertFalse(tile.showsAvatarPlaceholder,
                       "a late avatar must remain behind the active video")
        withExtendedLifetime(cancellable) {}
    }

    func testAvatarShownWhileVideoDisabledEvenWithContent() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.bindAvatar(makeProvider(name: "Alice"))
        tile.videoView.markVideoContent()
        tile.apply(ParticipantTileState(showsVideo: false))

        XCTAssertTrue(tile.showsAvatarPlaceholder)
        XCTAssertTrue(tile.videoView.isHidden)
    }

    func testNoPlaceholderWhenVideoEnabledAfterContentExists() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.apply(ParticipantTileState(showsVideo: false))
        tile.videoView.markVideoContent()

        tile.apply(ParticipantTileState(showsVideo: true))

        XCTAssertFalse(tile.showsAvatarPlaceholder,
                       "renderer already has an image — show it immediately")
    }

    func testVideoContentCallbackFiresOncePerTransition() {
        let view = RendererLayerView()
        var reported: [Bool] = []
        view.onVideoContentChanged = { reported.append($0) }

        view.markVideoContent()
        view.markVideoContent()
        XCTAssertTrue(view.hasVideoContent)

        view.clearVideoContent()
        view.clearVideoContent()

        XCTAssertEqual(reported, [true, false])
        XCTAssertFalse(view.hasVideoContent)
    }

    func testAvatarReturnsWhenTheRemoteStopsSendingVideo() {
        let tile = ParticipantTileUIView(participantId: "peer")
        tile.bindAvatar(makeProvider(name: "Alice"))
        tile.apply(ParticipantTileState(showsVideo: true))
        tile.videoView.markVideoContent()
        XCTAssertFalse(tile.showsAvatarPlaceholder)

        tile.videoView.clearVideoContent()

        XCTAssertTrue(tile.showsAvatarPlaceholder,
                      "the peer muted their camera — the avatar must come back")
    }

}
