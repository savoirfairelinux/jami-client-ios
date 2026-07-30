/*
 *  Copyright (C) 2004-2026 Savoir-faire Linux Inc.
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

import UIKit

/**
 The saved versions of a document, listed beside it.

 Reading a version is comparing it with another: this stays on screen so that
 going from one to the next is a tap, and so that the version being read is
 visible as a place in the list rather than as a date in a bar.
 */
class CollabHistoryPanel: UIView {

    /// A version was picked: show it.
    var onSelect: ((CollaborativeVersion) -> Void)?

    /// The list was closed: the reading is over.
    var onClose: (() -> Void)?

    private let titleLabel = UILabel()
    private let table = UITableView(frame: .zero, style: .plain)

    private var entries = [(version: CollaborativeVersion, label: String)]()

    /// The version being read, which is the one to mark.
    private var shownCommitId = ""

    private static let cellId = "collabVersion"
    private static let headerHeight: CGFloat = 44
    private static let margin: CGFloat = 12

    init() {
        super.init(frame: .zero)
        self.setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        self.backgroundColor = .jamiFormBackground
        self.translatesAutoresizingMaskIntoConstraints = false

        self.titleLabel.text = L10n.Collab.history
        self.titleLabel.font = .preferredFont(forTextStyle: .headline)
        self.titleLabel.adjustsFontForContentSizeCategory = true
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.titleLabel)

        let close = UIButton(type: .system)
        close.setTitle(L10n.Global.close, for: .normal)
        close.titleLabel?.font = .preferredFont(forTextStyle: .body)
        close.titleLabel?.adjustsFontForContentSizeCategory = true
        close.addTarget(self, action: #selector(self.closePanel), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(close)

        self.table.dataSource = self
        self.table.delegate = self
        self.table.backgroundColor = .clear
        self.table.rowHeight = UITableView.automaticDimension
        self.table.estimatedRowHeight = CollabHistoryPanel.headerHeight
        self.table.register(UITableViewCell.self,
                            forCellReuseIdentifier: CollabHistoryPanel.cellId)
        self.table.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.table)

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(separator)

        let margin = CollabHistoryPanel.margin
        NSLayoutConstraint.activate([
            self.titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor,
                                                     constant: margin),
            self.titleLabel.topAnchor.constraint(equalTo: self.topAnchor),
            self.titleLabel.heightAnchor
                .constraint(equalToConstant: CollabHistoryPanel.headerHeight),

            close.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -margin),
            close.centerYAnchor.constraint(equalTo: self.titleLabel.centerYAnchor),
            close.leadingAnchor.constraint(greaterThanOrEqualTo: self.titleLabel.trailingAnchor,
                                           constant: margin),
            // A word is a small thing to aim at on a tablet held in one hand.
            close.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            close.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            separator.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            separator.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            self.table.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.table.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.table.topAnchor.constraint(equalTo: separator.bottomAnchor),
            self.table.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    func show(_ entries: [(version: CollaborativeVersion, label: String)]) {
        self.entries = entries
        self.table.reloadData()
    }

    /// Mark the version being read, or none when the document itself is shown.
    func mark(commitId: String) {
        self.shownCommitId = commitId
        self.table.reloadData()
    }

    @objc
    private func closePanel() {
        self.onClose?()
    }
}

extension CollabHistoryPanel: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.entries.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CollabHistoryPanel.cellId,
                                                 for: indexPath)
        let entry = self.entries[indexPath.row]
        cell.textLabel?.text = entry.label
        cell.textLabel?.font = .preferredFont(forTextStyle: .subheadline)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.backgroundColor = .clear
        let shown = entry.version.commitId == self.shownCommitId
        cell.accessoryType = shown ? .checkmark : .none
        // Which version is on screen is what this list is read for; a tick is
        // not something a screen reader announces on its own.
        cell.accessibilityLabel = shown
            ? L10n.Collab.versionShown(entry.label)
            : entry.label
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.onSelect?(self.entries[indexPath.row].version)
    }
}
