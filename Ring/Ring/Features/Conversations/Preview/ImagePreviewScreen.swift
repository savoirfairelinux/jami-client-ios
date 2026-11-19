/*
 *  Copyright (C) 2020-2026 Savoir-faire Linux Inc.
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
import VisionKit

struct ImagePreviewScreen: View {
    let image: UIImage
    @ObservedObject var model: MediaPreviewModel
    @ObservedObject var overlayState: MediaPreviewPresenter
    let size: CGSize

    @SwiftUI.State private var chromeVisible = false
    @SwiftUI.State private var isZoomed = false
    @SwiftUI.State private var analyzesText = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        MediaPreviewShell(model: model,
                          overlayState: overlayState,
                          size: size,
                          chromeVisible: $chromeVisible,
                          allowsDismissDrag: !isZoomed && !model.isShowingText,
                          menuActions: model.menuActions(onDelete: { overlayState.deleteAndDismiss(model) }),
                          media: { onTap in
                              ZoomableImageView(image: image,
                                                collapsedSize: overlayState.hasSourceFrame ? overlayState.sourceFrame.size : nil,
                                                expandedSize: size,
                                                analyzesText: analyzesText,
                                                showsText: model.isShowingText,
                                                isZoomed: $isZoomed,
                                                onTextAvailable: textAvailabilityChanged,
                                                onSingleTap: onTap)
                                  .accessibilityElement()
                                  .accessibilityLabel(L10n.Conversation.replyQuotePhoto)
                                  .accessibilityAddTraits([.isButton, .isImage])
                                  .accessibilityAction(named: L10n.Global.close) { overlayState.dismiss() }
                          },
                          controls: {
                              if model.canShowText && !model.isReacting && !voiceOverEnabled {
                                  MediaPreviewLiveTextButton(isActive: model.isShowingText,
                                                             action: model.toggleShowingText)
                                      .frame(maxWidth: .infinity, alignment: .trailing)
                                      .transition(.opacity)
                              }
                          })
            .onChange(of: chromeVisible) { visible in
                if visible && !overlayState.isDismissing {
                    analyzesText = true
                }
            }
            .onChange(of: overlayState.isDismissing) { dismissing in
                if dismissing {
                    isZoomed = false
                    analyzesText = false
                    model.isShowingText = false
                }
            }
    }

    private func textAvailabilityChanged(_ available: Bool) {
        withAnimation(MediaPreviewLayout.chromeAnimation) {
            model.updateTextAvailability(available)
        }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let collapsedSize: CGSize?
    let expandedSize: CGSize
    let analyzesText: Bool
    let showsText: Bool
    @Binding var isZoomed: Bool
    let onTextAvailable: (Bool) -> Void
    let onSingleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ZoomableImageScrollView {
        let scrollView = ZoomableImageScrollView()
        scrollView.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        scrollView.addGestureRecognizer(tap)
        return scrollView
    }

    func updateUIView(_ scrollView: ZoomableImageScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.setImage(image)
        scrollView.setTransitionSizes(collapsed: collapsedSize, expanded: expandedSize)
        if !isZoomed && scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        }
        context.coordinator.updateLiveText(image: image, imageView: scrollView.imageView,
                                           analyzes: analyzesText, showsText: showsText)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ZoomableImageView
        private let doubleTapZoomScale: CGFloat = 3
        private let singleTapDelay: TimeInterval = 0.2
        private let doubleTapSlop: CGFloat = 44
        private var pendingSingleTap: DispatchWorkItem?
        private var lastTapLocation: CGPoint = .zero
        private var isSecondTap = false
        private var liveText: AnyObject?

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomableImageScrollView)?.imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ZoomableImageScrollView)?.centerImage()
            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale
            scrollView.isScrollEnabled = zoomed
            if parent.isZoomed != zoomed {
                parent.isZoomed = zoomed
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if liveTextHandles(touch) {
                return false
            }
            let location = touch.location(in: nil)
            isSecondTap = pendingSingleTap != nil
                && hypot(location.x - lastTapLocation.x, location.y - lastTapLocation.y) < doubleTapSlop
            if isSecondTap {
                pendingSingleTap?.cancel()
                pendingSingleTap = nil
            }
            return true
        }

        func updateLiveText(image: UIImage, imageView: UIImageView, analyzes: Bool, showsText: Bool) {
            guard #available(iOS 16.0, *), ImageAnalyzer.isSupported else { return }
            let session = liveText as? ImageLiveTextSession ?? makeLiveTextSession()
            if analyzes {
                session.analyze(image)
            } else {
                session.cancelPendingAnalysis()
            }
            session.setActive(showsText, on: imageView)
        }

        @available(iOS 16.0, *)
        private func makeLiveTextSession() -> ImageLiveTextSession {
            let session = ImageLiveTextSession()
            session.onTextAvailable = { [weak self] available in
                self?.parent.onTextAvailable(available)
            }
            liveText = session
            return session
        }

        private func liveTextHandles(_ touch: UITouch) -> Bool {
            if #available(iOS 16.0, *), let session = liveText as? ImageLiveTextSession {
                return session.handlesTouch(touch)
            }
            return false
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            if isSecondTap {
                handleDoubleTap(recognizer)
                return
            }
            lastTapLocation = recognizer.location(in: nil)
            let singleTap = DispatchWorkItem { [weak self] in
                self?.pendingSingleTap = nil
                self?.parent.onSingleTap()
            }
            pendingSingleTap = singleTap
            DispatchQueue.main.asyncAfter(deadline: .now() + singleTapDelay, execute: singleTap)
        }

        private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? ZoomableImageScrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }
            let point = recognizer.location(in: scrollView.imageView)
            let size = CGSize(width: scrollView.bounds.width / doubleTapZoomScale,
                              height: scrollView.bounds.height / doubleTapZoomScale)
            let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                              width: size.width, height: size.height)
            scrollView.zoom(to: rect, animated: true)
        }
    }
}

@available(iOS 16.0, *)
@MainActor
private final class ImageLiveTextSession: NSObject, ImageAnalysisInteractionDelegate {
    private static let analyzer = ImageAnalyzer()

    var onTextAvailable: ((Bool) -> Void)?
    private let interaction = ImageAnalysisInteraction()
    private var image: UIImage?
    private var analysis: ImageAnalysis?
    private var analysisTask: Task<Void, Never>?

    override init() {
        super.init()
        interaction.delegate = self
        interaction.preferredInteractionTypes = []
        interaction.isSupplementaryInterfaceHidden = true
    }

    deinit {
        analysisTask?.cancel()
    }

    func analyze(_ image: UIImage) {
        guard image !== self.image else { return }
        self.image = image
        analysis = nil
        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
            let configuration = ImageAnalyzer.Configuration([.text])
            let result = try? await Self.analyzer.analyze(image, configuration: configuration)
            guard let self = self, !Task.isCancelled, image === self.image else { return }
            self.analysisTask = nil
            self.analysis = result
            self.onTextAvailable?(result?.hasResults(for: .text) ?? false)
        }
    }

    func cancelPendingAnalysis() {
        guard let task = analysisTask else { return }
        task.cancel()
        analysisTask = nil
        image = nil
    }

    func setActive(_ active: Bool, on imageView: UIImageView) {
        guard active != (interaction.view != nil) else { return }
        if active {
            guard let analysis = analysis else { return }
            imageView.isUserInteractionEnabled = true
            imageView.addInteraction(interaction)
            interaction.analysis = analysis
            interaction.preferredInteractionTypes = .automatic
            interaction.selectableItemsHighlighted = true
        } else {
            interaction.resetTextSelection()
            interaction.selectableItemsHighlighted = false
            interaction.preferredInteractionTypes = []
            interaction.analysis = nil
            imageView.removeInteraction(interaction)
            imageView.isUserInteractionEnabled = false
        }
    }

    func handlesTouch(_ touch: UITouch) -> Bool {
        guard let view = interaction.view else { return false }
        return handles(touch.location(in: view))
    }

    private func handles(_ point: CGPoint) -> Bool {
        interaction.hasActiveTextSelection || interaction.hasInteractiveItem(at: point)
    }

    func interaction(_ interaction: ImageAnalysisInteraction,
                     shouldBeginAt point: CGPoint,
                     for interactionType: ImageAnalysisInteraction.InteractionTypes) -> Bool {
        handles(point)
    }
}

final class ZoomableImageScrollView: UIScrollView {
    let imageView = UIImageView()
    private var fittedBoundsSize: CGSize = .zero
    private var collapsedSize: CGSize?
    private var expandedSize: CGSize = .zero

    init() {
        super.init(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        minimumZoomScale = 1
        maximumZoomScale = 5
        bouncesZoom = true
        isScrollEnabled = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage) {
        guard imageView.image !== image else { return }
        imageView.image = image
        fittedBoundsSize = .zero
        setNeedsLayout()
    }

    func setTransitionSizes(collapsed: CGSize?, expanded: CGSize) {
        guard collapsed != collapsedSize || expanded != expandedSize else { return }
        collapsedSize = collapsed
        expandedSize = expanded
        fittedBoundsSize = .zero
        setNeedsLayout()
    }

    private var fillAmount: CGFloat {
        guard let collapsed = collapsedSize else { return 0 }
        let widthSpan = expandedSize.width - collapsed.width
        let heightSpan = expandedSize.height - collapsed.height
        let progress = widthSpan >= heightSpan
            ? (expandedSize.width - bounds.width) / max(widthSpan, 1)
            : (expandedSize.height - bounds.height) / max(heightSpan, 1)
        return min(max(progress, 0), 1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != fittedBoundsSize && zoomScale == minimumZoomScale {
            fitImage()
        }
        centerImage()
    }

    private func fitImage() {
        fittedBoundsSize = bounds.size
        guard let imageSize = imageView.image?.size,
              imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }
        let fill = fillAmount
        guard fill > 0, let collapsed = collapsedSize else {
            let fitScale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
            let fittedSize = CGSize(width: imageSize.width * fitScale, height: imageSize.height * fitScale)
            imageView.frame = CGRect(origin: .zero, size: fittedSize)
            contentSize = fittedSize
            return
        }
        let collapsedScale = max(collapsed.width / imageSize.width, collapsed.height / imageSize.height)
        let expandedScale = min(expandedSize.width / imageSize.width, expandedSize.height / imageSize.height)
        let scale = expandedScale + (collapsedScale - expandedScale) * fill
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        imageView.frame = CGRect(x: min(0, (bounds.width - fittedSize.width) / 2),
                                 y: min(0, (bounds.height - fittedSize.height) / 2),
                                 width: fittedSize.width, height: fittedSize.height)
        contentSize = CGSize(width: min(fittedSize.width, bounds.width), height: min(fittedSize.height, bounds.height))
    }

    func centerImage() {
        let horizontalInset = max(0, (bounds.width - contentSize.width) / 2)
        let verticalInset = max(0, (bounds.height - contentSize.height) / 2)
        let inset = UIEdgeInsets(top: verticalInset, left: horizontalInset,
                                 bottom: verticalInset, right: horizontalInset)
        if contentInset != inset {
            contentInset = inset
        }
    }
}
