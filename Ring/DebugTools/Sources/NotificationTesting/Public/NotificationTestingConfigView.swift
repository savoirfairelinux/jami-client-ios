/*
 * Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

#if DEBUG_TOOLS_ENABLED

/// Configuration sheet for the push-notification test harness.
public struct NotificationTestingConfigView: View {

    public typealias SendClosure = (String, String, String, String) -> Void

    private static var lastIntervalText: String?

    private let conversationId: String
    private let accountId: String
    private let send: SendClosure

    @SwiftUI.State private var intervalText: String
    @SwiftUI.State private var isRunning: Bool
    @SwiftUI.State private var collectorURL: String
    @SwiftUI.State private var role: NotificationTesting.Role
    @SwiftUI.Environment(\.presentationMode) private var presentationMode

    public init(
        conversationId: String,
        accountId: String,
        send: @escaping SendClosure
    ) {
        self.conversationId = conversationId
        self.accountId = accountId
        self.send = send
        let initial = Self.lastIntervalText ?? Self.defaultIntervalText()
        _intervalText = SwiftUI.State(initialValue: initial)
        _isRunning = SwiftUI.State(initialValue: NotificationTesting.isIntervalSenderRunning)
        let defaults = NotificationTesting.sharedDefaults
        _collectorURL = SwiftUI.State(initialValue: defaults?.string(forKey: "DebugToolsServerURL") ?? "")
        let savedRole = defaults?.string(forKey: "DebugToolsRole").flatMap(NotificationTesting.Role.init(rawValue:))
        _role = SwiftUI.State(initialValue: savedRole ?? .sender)
    }

    private static func defaultIntervalText() -> String {
        let launchArgMinutes = UserDefaults.standard.double(forKey: "DebugToolsInterval")
        return launchArgMinutes > 0 ? String(Int(launchArgMinutes)) : "1"
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    intervalSection
                    sendNowButton
                    settingsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Notification Testing", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                isRunning = NotificationTesting.isIntervalSenderRunning
            }
        }
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INTERVAL SENDER")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.leading, 16)

            VStack(spacing: 0) {
                intervalRow
                rowDivider
                startStopRow
                rowDivider
                statusRow
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
    }

    private var intervalRow: some View {
        HStack {
            Text("Interval (minutes)")
            Spacer()
            TextField("1", text: $intervalText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .disabled(isRunning)
        }
        .padding()
    }

    private var startStopRow: some View {
        Button(action: toggle) {
            HStack {
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                Text(isRunning ? "Stop" : "Start")
                Spacer()
            }
            .foregroundColor(isRunning ? .red : .green)
            .padding()
        }
    }

    private var statusRow: some View {
        HStack {
            Text("Status")
            Spacer()
            Text(isRunning ? "Running" : "Stopped")
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 16)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETTINGS")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.leading, 16)

            VStack(spacing: 0) {
                collectorURLRow
                rowDivider
                roleRow
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
    }

    private var collectorURLRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Collector URL")
            TextField("http://192.168.x.y:8080/logs", text: $collectorURL)
                .font(.system(.caption, design: .monospaced))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: collectorURL) { newValue in
                    NotificationTesting.setCollectorURL(newValue)
                }
        }
        .padding()
    }

    private var roleRow: some View {
        HStack {
            Text("Role")
            Spacer()
            Picker("Role", selection: $role) {
                ForEach(NotificationTesting.Role.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: role) { newValue in
                NotificationTesting.setRole(newValue)
            }
        }
        .padding()
    }

    private var sendNowButton: some View {
        Button(action: sendNow) {
            HStack {
                Image(systemName: "paperplane.fill")
                Text("Send Now")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .cornerRadius(10)
        }
    }

    private func toggle() {
        if isRunning {
            NotificationTesting.stopIntervalSender()
            isRunning = false
        } else {
            let minutes = max(TimeInterval(intervalText) ?? 1, 1)
            Self.lastIntervalText = intervalText
            NotificationTesting.startIntervalSender(
                conversationId: conversationId,
                accountId: accountId,
                interval: minutes * 60,
                send: send
            )
            isRunning = true
        }
    }

    private func sendNow() {
        NotificationTesting.sendTestMessageNow(
            conversationId: conversationId,
            accountId: accountId,
            send: send
        )
    }
}

#endif
