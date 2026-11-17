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

struct ImagePreviewScreen: View {
    let image: UIImage
    @ObservedObject var model: MediaPreviewModel
    @ObservedObject var overlayState: MediaPreviewPresenter
    let size: CGSize

    @SwiftUI.State private var chromeVisible = false
    @SwiftUI.State private var isZoomed = false

    var body: some View {
        MediaPreviewShell(model: model,
                          overlayState: overlayState,
                          size: size,
                          chromeVisible: $chromeVisible,
                          allowsDismissDrag: !isZoomed,
                          menuActions: model.menuActions(onDelete: { overlayState.deleteAndDismiss(model) }),
                          media: { expandedSize, onTap in
                              ZoomableImageView(image: image,
                                                collapsedSize: overlayState.hasSourceFrame ? overlayState.sourceFrame.size : nil,
                                                expandedSize: expandedSize,
                                                isZoomed: $isZoomed,
                                                onSingleTap: onTap)
                                  .accessibilityElement()
                                  .accessibilityAddTraits([.isButton, .isImage])
                                  .accessibilityAction(named: L10n.Global.close) { overlayState.dismiss() }
                          },
                          controls: { EmptyView() })
            .onChange(of: overlayState.isDismissing) { dismissing in
                if dismissing {
                    isZoomed = false
                }
            }
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    let collapsedSize: CGSize?
    let expandedSize: CGSize
    @Binding var isZoomed: Bool
    let onSingleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ZoomableImageScrollView {
        let scrollView = ZoomableImageScrollView()
        scrollView.delegate = context.coordinator
        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleSingleTap))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(singleTap)
        return scrollView
    }

    func updateUIView(_ scrollView: ZoomableImageScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.setImage(image)
        scrollView.setTransitionSizes(collapsed: collapsedSize, expanded: expandedSize)
        if !isZoomed && scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageView
        private let doubleTapZoomScale: CGFloat = 3

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

        @objc
        func handleSingleTap() {
            parent.onSingleTap()
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
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
