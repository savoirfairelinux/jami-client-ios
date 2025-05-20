import SwiftUI

struct ShareView: View {
    let items: [NSExtensionItem]
    let accountList: [String]
    let closeAction: () -> Void

    var body: some View {
        NavigationView {
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

                Text("Available Accounts")
                    .font(.headline)

                if accountList.isEmpty {
                    Text("No accounts available.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(accountList, id: \.self) { account in
                        Text(account)
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
            .navigationTitle("Share Extension")
        }
    }
}
