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

import UIKit
import Combine

final class CallAvatarView: UIView {

    private let imageView = UIImageView()
    private let monogramLabel = UILabel()
    private let symbolView = UIImageView()

    private var cancellables = Set<AnyCancellable>()
    private weak var boundProvider: AvatarProvider?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isHidden = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        monogramLabel.textColor = .white
        monogramLabel.textAlignment = .center
        symbolView.tintColor = .white
        symbolView.contentMode = .center

        for subview in [imageView, monogramLabel, symbolView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
            NSLayoutConstraint.activate([
                subview.leadingAnchor.constraint(equalTo: leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: trailingAnchor),
                subview.topAnchor.constraint(equalTo: topAnchor),
                subview.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        monogramLabel.font = .systemFont(
            ofSize: AvatarMetrics.monogramFontSize(for: bounds.width), weight: .semibold)
        symbolView.image = UIImage(
            systemName: "person.fill",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: AvatarMetrics.iconSize(for: bounds.width), weight: .semibold))
    }

    func bind(_ provider: AvatarProvider?) {
        guard provider !== boundProvider else { return }
        boundProvider = provider
        cancellables.removeAll()
        isHidden = provider?.isAvatarResolved != true

        guard let provider = provider else {
            render(image: nil, name: "")
            return
        }
        provider.$avatar
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak provider] image in
                self?.render(image: image, name: provider?.profileName ?? "")
            }
            .store(in: &cancellables)
        provider.$profileName
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak provider] name in
                self?.render(image: provider?.avatar, name: name)
            }
            .store(in: &cancellables)
        provider.$isAvatarResolved
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak provider] isResolved in
                guard let self = self else { return }
                guard isResolved else {
                    self.isHidden = true
                    return
                }
                self.render(image: provider?.avatar, name: provider?.profileName ?? "")
                self.isHidden = false
            }
            .store(in: &cancellables)
    }

    private func render(image: UIImage?, name: String) {
        if let image = image {
            imageView.image = image
            imageView.isHidden = false
            monogramLabel.isHidden = true
            symbolView.isHidden = true
            backgroundColor = .clear
            return
        }
        imageView.isHidden = true
        backgroundColor = avatarBackgroundColor(for: name)
        if !name.isEmpty && !name.isSHA1() {
            monogramLabel.text = String(name.prefix(1)).uppercased()
            monogramLabel.isHidden = false
            symbolView.isHidden = true
        } else {
            monogramLabel.isHidden = true
            symbolView.isHidden = false
        }
    }
}
