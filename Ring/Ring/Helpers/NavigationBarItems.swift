/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

import Combine
import RxCocoa
import RxSwift
import SwiftUI
import UIKit

final class HostingBarButtonItem<Content: View>: UIBarButtonItem {
    private let hosting: UIHostingController<WidthReportingView<Content>>

    init(_ content: Content) {
        var invalidateSize: () -> Void = {}
        if #available(iOS 16.0, *) {
            hosting = UIHostingController(rootView: WidthReportingView(content: content, onWidthChange: nil))
            hosting.sizingOptions = .intrinsicContentSize
        } else {
            hosting = UIHostingController(rootView: WidthReportingView(content: content,
                                                                       onWidthChange: { invalidateSize() }))
        }
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        super.init()
        customView = hosting.view
        invalidateSize = { [weak view = hosting.view] in view?.invalidateIntrinsicContentSize() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct WidthReportingView<Content: View>: View {
    let content: Content
    let onWidthChange: (() -> Void)?

    var body: some View {
        if let onWidthChange = onWidthChange {
            content.background(
                GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.size.width) { _ in onWidthChange() }
                }
            )
        } else {
            content
        }
    }
}

struct NavBarButtonGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: NavBarIcon.groupSpacing) {
            content
        }
        .padding(.horizontal, NavBarIcon.groupPadding)
        .imageScale(.large)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct NavBarIconButton<Icon: View>: View {
    private let accessibilityLabel: String
    private let accessibilityIdentifier: String
    private let action: () -> Void
    private let icon: Icon

    init(accessibilityLabel: String,
         accessibilityIdentifier: String,
         action: @escaping () -> Void,
         @ViewBuilder icon: () -> Icon) {
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action, label: {
            icon.navBarIconStyle()
        })
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

extension NavBarIconButton where Icon == Image {
    init(systemName: String,
         accessibilityLabel: String,
         accessibilityIdentifier: String,
         action: @escaping () -> Void) {
        self.init(accessibilityLabel: accessibilityLabel,
                  accessibilityIdentifier: accessibilityIdentifier,
                  action: action) {
            Image(systemName: systemName)
        }
    }
}

private var trailingBarItemSubscriptionKey: UInt8 = 0

extension UIViewController {
    func installTrailingBarItem(_ item: UIBarButtonItem,
                                menuRepresentation: UIMenu? = nil,
                                isVisible: AnyPublisher<Bool, Never> = Just(true).eraseToAnyPublisher()) {
        let subscription: AnyCancellable
        if #available(iOS 16.0, *) {
            let group = UIBarButtonItemGroup(barButtonItems: [item], representativeItem: nil)
            group.menuRepresentation = menuRepresentation
            navigationItem.trailingItemGroups = [group]
            subscription = isVisible
                .removeDuplicates()
                .sink { visible in
                    onMain { item.isHidden = !visible }
                }
        } else {
            subscription = keepRightBarButtonItem(item, isVisible: isVisible)
        }
        objc_setAssociatedObject(self, &trailingBarItemSubscriptionKey, subscription, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @available(iOS, deprecated: 16.0, message: "SwiftUI leaves trailingItemGroups alone; install through them only.")
    private func keepRightBarButtonItem(_ item: UIBarButtonItem,
                                        isVisible: AnyPublisher<Bool, Never>) -> AnyCancellable {
        let visible = CurrentValueSubject<Bool, Never>(true)
        let apply = { [weak self] in
            guard let self = self else { return }
            let shown = visible.value ? item : nil
            if self.navigationItem.rightBarButtonItem !== shown {
                self.navigationItem.rightBarButtonItem = shown
            }
        }
        let layout = rx.methodInvoked(#selector(UIViewController.viewDidLayoutSubviews))
            .subscribe(onNext: { _ in apply() })
        let visibility = isVisible
            .removeDuplicates()
            .sink { shown in
                onMain {
                    visible.send(shown)
                    apply()
                }
            }
        return AnyCancellable {
            layout.dispose()
            visibility.cancel()
        }
    }
}
