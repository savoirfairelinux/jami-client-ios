/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import RxSwift
@testable import Ring

class MockURLProtocol: URLProtocol {
    // Handler to intercept request and return mock response
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is missing.")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
    }
}

final class AccountCreationTest: XCTestCase {

    let app = XCUIApplication()
    let disposeBag = DisposeBag()

    override func setUp() {
        super.setUp()
        app.launchEnvironment["SERVER_ADDRESS"] = "local"

        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Setup for mock name server
        URLProtocol.registerClass(MockURLProtocol.self)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        app.launch()
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
    }

    func testAccountCreationWithRegisteredName_NameNotFound() {
        // Set up the mock response for /addr/name
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url, url.path.contains("name/") else {
                throw NSError(domain: "MockError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Path not handled"])
            }
            // Extract `value` from the URL and create a mock response
            // For the /name/ route value is name
            let name = url.lastPathComponent // Get the dynamic part of the URL

            // Let's check if the name is in our list of registered names
            let names = ["alice", "bob", "charlie"]
            let isRegistered = names.contains(name)

            // The response for a name that is not found is:
            // "{"error": "name not registered"}"
            // The response for a name that is found is:
            // "{"name": "<name>", "addr": "<some_sha1>"}"
            let response: HTTPURLResponse
            let data: Data?
            if isRegistered {
                response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                data = "{\"name\": \"\(name)\", \"addr\": \"6ae999552a0d2dca14d62e2bc8b764d377b1dd6c\"}".data(using: .utf8)
            } else {
                response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                data = "{\"error\": \"name not registered\"}".data(using: .utf8)
            }
            return (response, data)
        }

        // Tap the "Join Jami" button
        app.scrollViews.otherElements.buttons["Join Jami"].tap()

        app.textFields["Enter user name"].tap()

        // Directly insert the name "notfound" into the text field
        app.textFields["Enter user name"].typeText("notfound")

        // Create an expectation with a timeout
        let expectation = XCTestExpectation(description: "Waiting for a name registration answer")
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)

        // Ensure that the waiter completed due to the timeout
        XCTAssertEqual(result, .timedOut, "Waiter did not time out")

        // Verify the state of the "Join" button
        let joinButton = app.buttons["Join"]
        XCTAssertTrue(joinButton.isEnabled, "The Join button is not enabled")
    }
}
