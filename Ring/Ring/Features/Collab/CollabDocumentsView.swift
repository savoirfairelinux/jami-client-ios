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

    var body: some View {
        documentSection
            .onAppear(perform: viewModel.reload)
            .alert(isPresented: $viewModel.failed) {
                Alert(title: Text(viewModel.failureMessage))
            }
    }

    @ViewBuilder private var documentSection: some View {
        if viewModel.documents.isEmpty {
            Section {
                Text(L10n.Collab.noDocuments)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DocumentsLayout.margin)
                    .padding(.vertical, DocumentsLayout.margin * 2)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
            Section(header: Text(L10n.Collab.documents)) {
                ForEach(viewModel.documents, id: \.id) { document in
                    DocumentRow(document: document,
                                viewModel: viewModel,
                                open: { open(document.id, viewModel.title(of: document)) })
                }
            }
        }
    }

    private func open(_ documentId: String, _ name: String) {
        stateEmitter.openDocument(in: viewModel, documentId: documentId, name: name)
    }
}

private enum DocumentsLayout {
    static let margin: CGFloat = 16
    static let textSpacing: CGFloat = 2
    static let rowHeight: CGFloat = 44
}

struct CollabNewDocumentButton: View {
    @ObservedObject var viewModel: CollabDocumentsVM

    private enum Layout {
        static let margin: CGFloat = 16
        static let size: CGFloat = 56
        static let shadowRadius: CGFloat = 4
    }

    var body: some View {
        Button(action: viewModel.startNaming) {
            Label(L10n.Collab.newDocument, systemImage: "square.and.pencil")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: Layout.size, height: Layout.size)
                .background(Color.jami)
                .clipShape(Circle())
                .shadow(radius: Layout.shadowRadius)
        }
        .padding(Layout.margin)
        .accessibilityLabel(L10n.Collab.newDocument)
    }
}

/**
 One document in the list, with everything that can be done to it.

 The removals are reachable two ways. The menu is on every row, because what a
 row offers depends on who wrote the document and whether this device is still
 holding it: a swipe that answers on some rows and not on others teaches the
 reader that the list does not answer at all. The swipe stays for the reader who
 already knows it is there, and both routes end at the same confirmation.
 */
private struct DocumentRow: View {

    /// The row's icon, which the menu's own Open item repeats.
    private static let symbol = "doc.richtext"

    let document: CollaborativeDocument
    let viewModel: CollabDocumentsVM
    let open: () -> Void

    @SwiftUI.State private var confirming: CollabDocumentRemoval?
    @ScaledMetric private var menuSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            Button(action: open) {
                label
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            actionsMenu
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            ForEach(viewModel.removals(for: document)) { removal in
                Button {
                    confirming = removal
                } label: {
                    Label(removal.swipeTitle, systemImage: removal.symbol)
                }
                .tint(tint(for: removal))
                .accessibilityLabel(removal.menuTitle)
            }
        }
        .alert(item: $confirming, content: removalAlert)
    }

    private var label: some View {
        HStack(spacing: DocumentsLayout.margin) {
            Image(systemName: DocumentRow.symbol)
                .foregroundColor(Color.jami)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DocumentsLayout.textSpacing) {
                Text(viewModel.title(of: document))
                    .foregroundColor(Color(UIColor.label))
                Text(viewModel.subtitle(of: document))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(minHeight: DocumentsLayout.rowHeight)
        .contentShape(Rectangle())
    }

    private var actionsMenu: some View {
        Menu {
            Button(action: open) {
                Label(L10n.Collab.open, systemImage: DocumentRow.symbol)
            }
            ForEach(viewModel.removals(for: document)) { removal in
                Button(role: removal == .forEveryone ? ButtonRole.destructive : nil) {
                    confirming = removal
                } label: {
                    Label(removal.menuTitle, systemImage: removal.symbol)
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.secondary)
                .frame(width: menuSize, height: menuSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.Collab.menu)
    }

    private func removalAlert(for removal: CollabDocumentRemoval) -> Alert {
        return Alert(title: Text(removal.alertTitle),
                     message: Text(removal.alertMessage(for: viewModel.title(of: document))),
                     primaryButton: .destructive(Text(L10n.Collab.remove)) {
                        viewModel.perform(removal, on: document)
                     },
                     secondaryButton: .cancel(Text(L10n.Global.cancel)))
    }

    /// Only asked for a swipe button; the menu colours its own destructive item.
    private func tint(for removal: CollabDocumentRemoval) -> Color {
        switch removal {
        case .fromThisDevice: return .jamiWarning
        case .forEveryone: return .jamiFailure
        }
    }
}

private extension ConversationStatePublisher {
    /// One place for the state a document is opened with, whichever tap asked.
    func openDocument(in viewModel: CollabDocumentsVM, documentId: String, name: String) {
        self.emitState(
            ConversationState.openCollabDocument(accountId: viewModel.accountId,
                                                 conversationId: viewModel.conversationId,
                                                 documentId: documentId,
                                                 name: name))
    }
}

/**
 The naming prompt, held apart from the list.

 An alert belongs over the whole screen, and the list is only the lower half of
 one: `SwarmInfoView` renders this beside its own alerts, and it watches the
 documents' view model so that raising the prompt does not redraw the screen
 around it.
 */
struct CollabNewDocumentPrompt: View {

    @ObservedObject var viewModel: CollabDocumentsVM
    let stateEmitter: ConversationStatePublisher

    var body: some View {
        if viewModel.isNaming {
            CollabNamePrompt(title: L10n.Collab.newDocument,
                             confirm: L10n.Collab.create,
                             name: $viewModel.pendingName,
                             onCancel: { viewModel.isNaming = false },
                             onConfirm: create)
        }
    }

    private func create() {
        viewModel.isNaming = false
        viewModel.create(named: viewModel.pendingName) { documentId, name in
            stateEmitter.openDocument(in: viewModel, documentId: documentId, name: name)
        }
    }
}

/// Asking a document for its name, in the shape the swarm-info screen already
/// uses to ask for a title or a description.
struct CollabNamePrompt: View {

    let title: String
    let confirm: String
    @Binding var name: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        CustomAlert(content: {
            VStack(spacing: Layout.spacing) {
                Text(title)
                    .font(.headline)
                TextField(L10n.Collab.documentNameHint, text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                HStack {
                    Button(action: onCancel) {
                        Text(L10n.Global.cancel)
                            .foregroundColor(.jami)
                            .frame(minWidth: Layout.buttonWidth, minHeight: Layout.buttonHeight)
                    }
                    Spacer()
                    Button(action: onConfirm) {
                        Text(confirm)
                            .bold()
                            .foregroundColor(.jami)
                            .frame(minWidth: Layout.buttonWidth, minHeight: Layout.buttonHeight)
                    }
                }
            }
        })
    }

    private enum Layout {
        static let spacing: CGFloat = 20
        static let buttonWidth: CGFloat = 60
        static let buttonHeight: CGFloat = 44
    }
}
