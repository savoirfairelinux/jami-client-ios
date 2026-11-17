/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import SwiftUI
import AVFoundation

struct VideoPreviewScreen: View {
    let player: PlayerViewModel
    @ObservedObject var model: MediaPreviewModel
    @ObservedObject var overlayState: MediaPreviewPresenter
    let size: CGSize

    @StateObject private var coordinator = PlayerCoordinator()
    @SwiftUI.State private var chromeVisible = false

    private var showsControls: Bool {
        chromeVisible && overlayState.isExpanded && !overlayState.isDismissing && !model.isReplying
    }

    var body: some View {
        MediaPreviewShell(model: model,
                          overlayState: overlayState,
                          size: size,
                          chromeVisible: $chromeVisible,
                          allowsDismissDrag: true,
                          menuActions: model.menuActions(onDelete: { overlayState.deleteAndDismiss(model) }),
                          media: { onTap in
                              VideoPreviewContent(coordinator: coordinator,
                                                  showsPlayButton: showsControls,
                                                  onTap: onTap,
                                                  onTogglePause: player.togglePause,
                                                  onClose: { overlayState.dismiss() })
                          },
                          controls: {
                              VideoPreviewControls(coordinator: coordinator, player: player)
                          })
            .onAppear {
                coordinator.displayLayer.videoGravity = .resizeAspectFill
                coordinator.pendingViewModel = player
                coordinator.bind(to: player)
            }
            .onChange(of: model.isReplying) { replying in
                if replying && !coordinator.isPaused {
                    player.togglePause()
                }
            }
    }
}

struct VideoPreviewContent: View {
    @ObservedObject var coordinator: PlayerCoordinator
    let showsPlayButton: Bool
    let onTap: () -> Void
    let onTogglePause: () -> Void
    let onClose: () -> Void

    private let playButtonSize: CGFloat = 84
    private let playIconSize: CGFloat = 34

    var body: some View {
        ZStack {
            Color.black
            if coordinator.hasVideo {
                VideoLayerView(displayLayer: coordinator.displayLayer, coordinator: coordinator)
            }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .accessibilityElement()
                .accessibilityLabel(L10n.Global.video)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: L10n.Global.close, onClose)
            if showsPlayButton {
                playButton
                    .transition(.opacity)
            }
        }
        .animation(MediaPreviewLayout.chromeAnimation, value: showsPlayButton)
    }

    private var playButton: some View {
        Button(action: onTogglePause) {
            Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: playIconSize, weight: .medium))
                .foregroundColor(.white)
                .frame(width: playButtonSize, height: playButtonSize)
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .mediaPreviewGlass(in: Circle(), interactive: true)
        .accessibilityLabel(coordinator.isPaused ? L10n.Accessibility.audioPlayerPlay : L10n.Accessibility.audioPlayerPause)
        .accessibilityShowsLargeContentViewer()
    }
}

struct VideoPreviewControls: View {
    @ObservedObject var coordinator: PlayerCoordinator
    let player: PlayerViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button(action: player.muteAudio) {
                Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: NavBarIcon.glyphSize))
                    .foregroundColor(.white)
                    .frame(width: MediaPreviewLayout.control, height: MediaPreviewLayout.control)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(coordinator.isMuted ? L10n.Accessibility.audioPlayerUnmute : L10n.Accessibility.audioPlayerMute)
            .accessibilityShowsLargeContentViewer()
            MediaScrubberRow(elapsed: coordinator.elapsedTimeString, duration: coordinator.duration.durationString) {
                MediaSeekSlider(
                    onRegister: { sink in coordinator.sliderUpdate = sink },
                    onSeekStart: { coordinator.beginSeek(player) },
                    onSeekChange: { coordinator.changeSeek(to: $0, player: player) },
                    onSeekEnd: { coordinator.endSeek(player) }
                )
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .padding(.vertical, 5)
        .mediaPreviewGlass(in: Capsule())
        .frame(maxWidth: 600)
    }
}
