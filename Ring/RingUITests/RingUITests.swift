//
//  RingUITests.swift
//  RingUITests
//
//  Created by Edric on 16-06-23.
//  Copyright © 2016 Savoir-faire Linux. All rights reserved.
//

import XCTest
@testable import Ring


class RingUITests: XCTestCase {

    let app = XCUIApplication()
    let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())

    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.

        // Setup for mock name server
        URLProtocol.registerClass(MockURLProtocol.self)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        // Set the name service URL to localhost

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
                data = "{\"name\": \"\(name)\", \"addr\": \"\(name.sha1())\"}".data(using: .utf8)
            } else {
                response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                data = "{\"error\": \"name not registered\"}".data(using: .utf8)
            }
            return (response, data)
        }

        // Tap the "Join Jami" button
        app.scrollViews.otherElements.buttons["Join Jami"].tap()

        // Directly insert the name "notfound" into the text field
        app.textFields["Enter your name"].tap()
        app.textFields["Enter your name"].typeText("notfound")

        // Wait for a response from the name service (expect not found)

        // Verify the state of the "Join" button
    }
}
