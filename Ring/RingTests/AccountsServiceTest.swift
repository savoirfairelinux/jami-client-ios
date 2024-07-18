/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import XCTest
@testable import Ring

final class AccountsServiceTest: XCTestCase {

    let account1 = "1"
    let account2 = "2"
    let account3 = "3"
    let account4 = "4"
    let account5 = "5"

    let device1 = "device1"
    let device2 = "device2"
    let device3 = "device3"
    let device4 = "device4"

    let deviceName1 = "Device 1"
    let deviceName2 = "Device 2"
    let deviceName3 = "Device 3"
    let deviceName4 = "Device 4"
    let newDeviceName1 = "New Device 1"

    let dBManager = DBManager(profileHepler: ProfileDataHelper(),
                              conversationHelper: ConversationDataHelper(),
                              interactionHepler: InteractionDataHelper(),
                              dbConnections: DBContainer())

    var accountService: MockAccountsService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        accountService = MockAccountsService(withAccountAdapter: AccountAdapter(), dbManager: self.dBManager)
    }

    override func tearDownWithError() throws {
        // Perform any necessary cleanup
        accountService = nil
        try super.tearDownWithError()
    }

    private func setupInitialAccounts(initialAccountIds: [String] ) {
        let initialAccounts = initialAccountIds.map { AccountModel(withAccountId: $0) }
        accountService.setAccountList(initialAccounts)
    }

    private func setupInitialDevices(for account: AccountModel, deviceIds: [String], deviceNames: [String]) {
        let initialDevices = zip(deviceIds, deviceNames).map { DeviceModel(withDeviceId: $0.0, deviceName: $0.1, isCurrent: false) }
        account.devices = initialDevices
    }

    func testAccountsChanged_RemovesAccountsCorrectly() throws {
        var initialAccountIds: [String] { [account1, account2, account3] }
        var newAccountIds: [String] { [account2, account3] }
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = newAccountIds

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 2)
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account2 }))
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account3 }))
        XCTAssertFalse(accountService.accountList.contains(where: { $0.id == account1 }))
    }

    func testAccountsChanged_AddsAccountsCorrectly() throws {
        let initialAccountIds = [account2, account3]
        let newAccountIds = [account2, account3, account4]
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = newAccountIds

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 3)
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account2 }))
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account3 }))
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account4 }))
    }

    func testAccountsChanged_NoChanges() throws {
        let initialAccountIds = [account1, account2, account3]
        let newAccountIds = [account1, account2, account3]
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = newAccountIds

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 3)
        XCTAssertTrue(accountService.accountList.contains { $0.id == account1 })
        XCTAssertTrue(accountService.accountList.contains { $0.id == account2 })
        XCTAssertTrue(accountService.accountList.contains { $0.id == account3 })
    }

    func testAccountsChanged_AllAccountsRemoved() throws {
        let initialAccountIds = [account1, account2, account3]
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = nil

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 0)
    }

    func testKnownDevicesChanged_RemoveOldDevices() {
        let account = AccountModel(withAccountId: account1)
        setupInitialDevices(for: account, deviceIds: [device1, device2], deviceNames: [deviceName1, deviceName2])
        self.accountService.setAccountList([account])

        let newDevices = [
            device2: deviceName2,
            device3: deviceName3
        ]

        accountService.knownDevicesChanged(for: account1, devices: newDevices)

        XCTAssertEqual(account.devices.count, 2)
        XCTAssertTrue(account.devices.contains { $0.deviceId == device2 })
        XCTAssertTrue(account.devices.contains { $0.deviceId == device3 })
        XCTAssertFalse(account.devices.contains { $0.deviceId == device1 })
    }

    func testKnownDevicesChanged_AddNewDevices() {
        let account = AccountModel(withAccountId: account1)
        setupInitialDevices(for: account, deviceIds: [device1], deviceNames: [deviceName1])
        self.accountService.setAccountList([account])

        let newDevices = [
            device1: deviceName1,
            device2: deviceName2,
            device3: deviceName3
        ]

        accountService.knownDevicesChanged(for: account1, devices: newDevices)

        XCTAssertEqual(account.devices.count, 3)
        XCTAssertTrue(account.devices.contains { $0.deviceId == device1 })
        XCTAssertTrue(account.devices.contains { $0.deviceId == device2 })
        XCTAssertTrue(account.devices.contains { $0.deviceId == device3 })
    }

    func testKnownDevicesChanged_UpdateDeviceNames() {
        let account = AccountModel(withAccountId: account1)
        setupInitialDevices(for: account, deviceIds: [device1], deviceNames: [deviceName1])
        self.accountService.setAccountList([account])

        let newDevices = [
            device1: newDeviceName1
        ]

        accountService.knownDevicesChanged(for: account1, devices: newDevices)

        XCTAssertEqual(account.devices.count, 1)
        XCTAssertEqual(account.devices.first?.deviceName, newDeviceName1)
    }

    func testKnownDevicesChanged_NoChange() {
        let account = AccountModel(withAccountId: account1)
        setupInitialDevices(for: account, deviceIds: [device1, device2], deviceNames: [deviceName1, deviceName2])
        self.accountService.setAccountList([account])

        let newDevices = [
            device1: deviceName1,
            device2: deviceName2
        ]

        accountService.knownDevicesChanged(for: account1, devices: newDevices)

        XCTAssertEqual(account.devices.count, 2)
        XCTAssertTrue(account.devices.contains { $0.deviceId == device1 && $0.deviceName == deviceName1 })
        XCTAssertTrue(account.devices.contains { $0.deviceId == device2 && $0.deviceName == deviceName2 })
    }

    func testKnownDevicesChanged_NonMatchingAccountId() {
        let account = AccountModel(withAccountId: account1)
        setupInitialDevices(for: account, deviceIds: [device1, device2], deviceNames: [deviceName1, deviceName2])
        self.accountService.setAccountList([account])

        let newDevices = [
            device2: deviceName2,
            device3: deviceName3
        ]

        accountService.knownDevicesChanged(for: account2, devices: newDevices)

        XCTAssertEqual(account.devices.count, 2)
        XCTAssertTrue(account.devices.contains { $0.deviceId == device1 && $0.deviceName == deviceName1 })
        XCTAssertTrue(account.devices.contains { $0.deviceId == device2 && $0.deviceName == deviceName2 })
    }

    func testPerformanceAccountsChanged() throws {
        let largeAccountList = (1...1000).map { AccountModel(withAccountId: "\($0)") }
        accountService.setAccountList(largeAccountList)
        accountService.mockAccountsId = (500...1500).map { "\($0)" }

        measure {
            accountService.accountsChanged()
        }
    }

    func testPerformanceKnownDevicesChanged() throws {
        // Setup a large number of mock devices
        let account = AccountModel(withAccountId: account1)
        let deviceIds = (1...1000).map { "device\($0)" }
        let deviceNames = (1...1000).map { "Device \($0)" }
        setupInitialDevices(for: account, deviceIds: deviceIds, deviceNames: deviceNames)

        accountService.setAccountList([account])

        let newDevices = Dictionary(uniqueKeysWithValues: zip(deviceIds, deviceNames))

        measure {
            accountService.knownDevicesChanged(for: account1, devices: newDevices)
        }
    }
}
