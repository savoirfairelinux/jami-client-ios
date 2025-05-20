import SwiftUI

struct ShareView: View {
    let items: [NSExtensionItem]
    let accountList: [String]
    let conversationsByAccount: [String: [String]]
    let closeAction: () -> Void

    @State private var expandedAccounts: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Shared Content")
                        .font(.headline)

                    if items.isEmpty {
                        Text("No items shared.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(items.indices, id: \.self) { index in
                            Text("Item \(index + 1): \(items[index].description)")
                                .font(.subheadline)
                        }
                    }

                    Divider()

                    Text("Accounts & Conversations")
                        .font(.headline)

                    if accountList.isEmpty {
                        Text("No accounts available.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(accountList, id: \.self) { account in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedAccounts.contains(account) },
                                    set: { expanded in
                                        if expanded {
                                            expandedAccounts.insert(account)
                                        } else {
                                            expandedAccounts.remove(account)
                                        }
                                    }
                                ),
                                content: {
                                    let conversations = conversationsByAccount[account] ?? []
                                    if conversations.isEmpty {
                                        Text("No conversations.")
                                            .foregroundColor(.gray)
                                            .padding(.leading, 10)
                                    } else {
                                        ForEach(conversations, id: \.self) { convo in
                                            Text(convo)
                                                .padding(.leading, 10)
                                        }
                                    }
                                },
                                label: {
                                    Text(account)
                                        .font(.subheadline)
                                        .bold()
                                }
                            )
                            .padding(.vertical, 4)
                        }
                    }

                    Spacer()

                    Button("Close", action: closeAction)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Share Extension")
        }
    }
}
