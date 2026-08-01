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
        ZStack(alignment: .bottomTrailing) {
            documentList
            newDocumentButton
        }
        // The tabs beside this one are a Form and a List, which carry the
        // grouped background through the bottom safe area. The empty state has
        // no scroll view to do that, so it says the same thing here.
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .bottom))
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
                        Button {
                            open(document.id, viewModel.title(of: document))
                        } label: {
                            row(for: document)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .modifier(DocumentRemovalActions(document: document,
                                                         viewModel: viewModel))
                    }
                }
            }
            // The new-document button stands in this corner; without the inset
            // it covers the last row, which then cannot be tapped.
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: Layout.buttonSize + Layout.margin * 2)
            }
        }
    }

    /// The document's label inside the button that opens it.
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
        }
        .frame(minHeight: Layout.rowHeight)
        .contentShape(Rectangle())
    }

    private var newDocumentButton: some View {
        Button {
            viewModel.startNaming()
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

    private func open(_ documentId: String, _ name: String) {
        stateEmitter.openDocument(in: viewModel, documentId: documentId, name: name)
    }

    private enum Layout {
        static let margin: CGFloat = 16
        static let textSpacing: CGFloat = 2
        static let rowHeight: CGFloat = 44
        static let buttonSize: CGFloat = 56
        static let shadow: CGFloat = 4
    }
}

private struct DocumentRemovalActions: ViewModifier {

    let document: CollaborativeDocument
    let viewModel: CollabDocumentsVM

    @SwiftUI.State private var confirming: Removal?

    /**
     A removal waiting to be confirmed.

     The two are asked apart because they are not the same question: one takes a
     document away from everybody for good, the other only reclaims what this
     device chose to keep.
     */
    private struct Removal: Identifiable {
        let everywhere: Bool

        var id: String { everywhere ? "all" : "here" }
    }

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if document.storedLocally {
                    Button {
                        confirming = Removal(everywhere: false)
                    } label: {
                        Label(L10n.Collab.removeLocallyAction,
                              systemImage: "minus.circle")
                    }
                    .tint(.jamiWarning)
                }
                if viewModel.canRemoveEverywhere(document) {
                    Button {
                        confirming = Removal(everywhere: true)
                    } label: {
                        Label(L10n.Collab.removeEverywhereAction,
                              systemImage: "trash")
                    }
                    .tint(.jamiFailure)
                }
            }
            .alert(item: $confirming, content: removalAlert)
    }

    private func removalAlert(for removal: Removal) -> Alert {
        Alert(title: Text(removal.everywhere ? L10n.Collab.removeTitle
                            : L10n.Collab.removeLocallyTitle),
              message: Text(removal.everywhere
                                ? L10n.Collab.removeMessage(viewModel.title(of: document))
                                : L10n.Collab.removeLocallyMessage(viewModel.title(of: document))),
              primaryButton: .destructive(Text(L10n.Collab.remove)) {
                if removal.everywhere {
                    viewModel.removeEverywhere(document)
                } else {
                    viewModel.removeLocally(document)
                }
              },
              secondaryButton: .cancel(Text(L10n.Global.cancel)))
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
