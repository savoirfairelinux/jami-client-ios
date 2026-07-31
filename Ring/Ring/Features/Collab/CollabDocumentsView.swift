/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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

import SwiftUI

/// A document belongs to the conversation it was written in, so that is where
/// it is found: beside the members, from which one is opened or a new one
/// started.
struct CollabDocumentsView: View {

    @ObservedObject var viewModel: CollabDocumentsVM
    let stateEmitter: ConversationStatePublisher

    @SwiftUI.State private var isNaming = false
    @SwiftUI.State private var name = ""
    @SwiftUI.State private var confirming: Removal?

    /**
     A removal waiting to be confirmed.

     The two are asked apart because they are not the same question: one takes a
     document away from everybody for good, the other only reclaims what this
     device chose to keep.
     */
    private struct Removal: Identifiable {
        let document: CollaborativeDocument
        let everywhere: Bool

        var id: String { (everywhere ? "all:" : "here:") + document.id }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            documentList
            newDocumentButton
            if isNaming {
                CollabNamePrompt(title: L10n.Collab.newDocument,
                                 confirm: L10n.Collab.create,
                                 name: $name,
                                 onCancel: { isNaming = false },
                                 onConfirm: create)
            }
        }
        .onAppear(perform: viewModel.reload)
        .alert(isPresented: $viewModel.failed) {
            Alert(title: Text(viewModel.failureMessage))
        }
    }

    @ViewBuilder private var documentList: some View {
        if viewModel.documents.isEmpty {
            VStack {
                Spacer()
                Text(L10n.Collab.noDocuments)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Layout.margin)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section(header: Text(L10n.Collab.documents)) {
                    ForEach(viewModel.documents, id: \.id) { document in
                        row(for: document)
                    }
                }
            }
            .alert(item: $confirming) { removal in
                Alert(title: Text(removal.everywhere ? L10n.Collab.removeTitle
                                    : L10n.Collab.removeLocallyTitle),
                      message: Text(removal.everywhere
                                    ? L10n.Collab.removeMessage(viewModel.title(of: removal.document))
                                    : L10n.Collab.removeLocallyMessage(viewModel.title(of: removal.document))),
                      primaryButton: .destructive(Text(L10n.Collab.remove)) {
                        if removal.everywhere {
                            viewModel.removeEverywhere(removal.document)
                        } else {
                            viewModel.removeLocally(removal.document)
                        }
                      },
                      secondaryButton: .cancel(Text(L10n.Global.cancel)))
            }
        }
    }

    /**
     The row opens the document, and carries the removals it can offer.

     Buttons inside a list row need a borderless style, or the row answers for
     all three at once and every tap opens the document.
     */
    private func row(for document: CollaborativeDocument) -> some View {
        HStack(spacing: Layout.margin) {
            Image(systemName: "doc.richtext")
                .foregroundColor(Color.jami)
            VStack(alignment: .leading, spacing: Layout.textSpacing) {
                Text(viewModel.title(of: document))
                    .foregroundColor(Color(UIColor.label))
                Text(viewModel.subtitle(of: document))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if document.storedLocally {
                removalButton(icon: "trash",
                              label: L10n.Collab.removeLocallyTitle,
                              removal: Removal(document: document, everywhere: false))
            }
            if viewModel.canRemoveEverywhere(document) {
                removalButton(icon: "trash.slash",
                              label: L10n.Collab.removeTitle,
                              removal: Removal(document: document, everywhere: true))
            }
        }
        .frame(minHeight: Layout.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            open(document.id, viewModel.title(of: document))
        }
    }

    private func removalButton(icon: String, label: String, removal: Removal) -> some View {
        Button {
            confirming = removal
        } label: {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: Layout.actionSize, height: Layout.actionSize)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel(label)
    }

    private var newDocumentButton: some View {
        Button {
            name = ""
            isNaming = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                .background(Color.jami)
                .clipShape(Circle())
                .shadow(radius: Layout.shadow)
        }
        .padding(Layout.margin)
        .accessibilityLabel(L10n.Collab.newDocument)
    }

    private func create() {
        isNaming = false
        viewModel.create(named: name, then: open)
    }

    private func open(_ documentId: String, _ name: String) {
        stateEmitter.emitState(
            ConversationState.openCollabDocument(accountId: viewModel.accountId,
                                                 conversationId: viewModel.conversationId,
                                                 documentId: documentId,
                                                 name: name))
    }

    private enum Layout {
        static let margin: CGFloat = 16
        static let textSpacing: CGFloat = 2
        static let rowHeight: CGFloat = 44
        static let actionSize: CGFloat = 44
        static let buttonSize: CGFloat = 56
        static let shadow: CGFloat = 4
    }
}

/// Asking for a name, in the one place both the list and the conversation use.
struct CollabNamePrompt: View {

    let title: String
    let confirm: String
    @Binding var name: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(Layout.dimming)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            VStack(spacing: Layout.spacing) {
                Text(title)
                    .font(.headline)
                TextField(L10n.Collab.documentNameHint, text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack {
                    Button(action: onCancel) {
                        Text(L10n.Global.cancel)
                            .frame(minWidth: Layout.buttonWidth, minHeight: Layout.buttonHeight)
                    }
                    Spacer()
                    Button(action: onConfirm) {
                        Text(confirm)
                            .bold()
                            .frame(minWidth: Layout.buttonWidth, minHeight: Layout.buttonHeight)
                    }
                }
            }
            .padding(Layout.padding)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(Layout.corner)
            .padding(.horizontal, Layout.margin)
        }
    }

    private enum Layout {
        static let dimming: Double = 0.4
        static let spacing: CGFloat = 16
        static let padding: CGFloat = 20
        static let corner: CGFloat = 14
        static let margin: CGFloat = 40
        static let buttonWidth: CGFloat = 60
        static let buttonHeight: CGFloat = 44
    }
}
